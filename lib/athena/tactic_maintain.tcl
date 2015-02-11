#-----------------------------------------------------------------------
# TITLE:
#    tactic_maintain.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena(n): Mark II Tactic, MAINTAIN
#
#    A MAINTAIN tactic spends cash-on-hand to maintain goods sector 
#    production infrastructure
#
#-----------------------------------------------------------------------

# FIRST, create the class.
::athena::tactic define MAINTAIN "Maintain Infrastructure" {actor} {
    #-------------------------------------------------------------------
    # Instance Variables

    variable rmode   ;# Repair mode: FULL, UPTO
    variable level   ;# Desired level of repair if mode is UPTO
    variable fmode   ;# Funding mode: ALL, EXACT, PERCENT
    variable amount  ;# Max amount of money to spend regardless of rmode
    variable percent ;# Percent of money to spend if mode is PERCENT
    variable nlist   ;# List of nbhoods in which to maintain plants

    # Transient Data
    variable trans

    
    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # Initialize as tactic bean.
        next

        # Initialize state variables
        set rmode   FULL
        set fmode   ALL
        set level   0.0
        set amount  100000
        set percent 100
        set nlist   [gofer::NBHOODS blank]

        my set state invalid

        set trans(amount)   0.0
        set trans(nlist)    [list]
        set trans(repairs)  [dict create]
        set trans(repaired) 0

        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    method SanityCheck {errdict} {
        # nlist
        if {[catch {gofer::NBHOODS validate $nlist} result]} {
            dict set errdict nlist $result
        }

        # owner must not be automatically maintaining infrastructure
        set owner [my agent]

        if {$owner ne "SYSTEM" && [[my adb] actor get $owner auto_maintain]} {
            set errmsg "$owner has auto maintenance enabled."
            dict set errdict owner $errmsg
        }

        return [next $errdict]
    }

    method narrative {} {
        set ntext [gofer::NBHOODS narrative $nlist]
        set atext [moneyfmt $amount]
        set ptext [format "%.1f%%" $percent]
        set ltext [format "%.1f%%" $level]
        set anarr "Spend no more than "
        set enarr "capacity of the infrastructure owned in $ntext"

        switch -exact -- $fmode {
            ALL {
                set anarr "Spend as much cash-on-hand as possible to maintain"
            }

            EXACT {
                append anarr "\$$atext of cash-on-hand to maintain"
            }

            PERCENT {
                append anarr "$ptext of cash-on-hand to maintain"
            }

            default {
                error "Invalid fmode: \"$fmode\""
            }
        }

        set text ""
        switch -exact -- $rmode {
            FULL {
                return "$anarr full $enarr."
            }

            UPTO {
                return "$anarr at least $ltext $enarr."
            }

            default {
                error "Invalid rmode: \"$rmode\""
            }
        }
    }

    # ObligateResources coffer
    #
    # coffer  - A coffer object with the owning agent's current
    #           resourcemaxAmts
    #
    # Obligates the money to be spent.

    method ObligateResources {coffer} {
        # FIRST, retrieve relevant data.
        set cash  [$coffer cash]
        set owner [my agent]

        # Only going to deal in whole dollars
        let cash {entier($cash)}

        # NEXT, get nbhoods, the gofer may retrieve an empty list
        set trans(nlist) [my GetNbhoods]

        if {[llength $trans(nlist)] == 0} {
            return 0
        }

        # NEXT, the maximum possible amount of repair that could be
        # performed in one tick
        set rTime [parmdb get plant.repairtime]
        if {$rTime == 0.0} {
            set maxDeltaRho 1.0
        } else {
            let maxDeltaRho {1.0/$rTime}
        }

        # NEXT, the maximum repair level is either fully repaired or
        # the level of repair the user has requested
        # Note: This will need to be changed if more repair modes are
        # added
        set maxRho 1.0

        if {$rmode eq "UPTO"} {
            let maxRho {$level/100.0}
        }

        # NEXT, set up to book keep the repairs and their cost
        set trans(repairs) [dict create]
        set costProfile    [dict create]
        set totalCost 0.0
         
        # NEXT, go through each neighborhood that has plants owned by
        # this actor and compute the amount and cost of repairs
        foreach n $trans(nlist) {
            # FIRST, the current level of repair at the start of the tick
            set currRho [plant get [list $n $owner] rho]

            # NEXT, the amount of repair is the difference between
            # the maximum and the current levl
            let deltaRho {$maxRho - $currRho}

            # NEXT, if the current level of repair is already greater 
            # than the max, nothing to do
            if {$deltaRho <= 0.0} {
                continue
            }

            # NEXT, constrain the actual amount of repair by the maximum that
            # could be done in this tick
            let actualDeltaRho {min($deltaRho, $maxDeltaRho)}

            # NEXT, see if there's been any work done to these plants during
            # strategy execution
            let unrepaired {
                ($currRho+$actualDeltaRho) - [$coffer plants $n]
            }

            # NEXT, constrain the amount of repair further by whatever is
            # left unrepaired
            let actualDeltaRho {min($actualDeltaRho, $unrepaired)}

            # NEXT, these plants may have already had the maximum amount
            # of repair done to them
            if {$actualDeltaRho == 0.0} {
                continue
            }
                    
            # NEXT, determine the cost and bookkeep it, the actor may
            # not have enough money to pay for it all
            set nCost [plant repaircost $n $owner $actualDeltaRho]
            dict set costProfile $n $nCost
            let totalCost {$totalCost + $nCost}
        }

        # NEXT, if no cash, tactic fails
        if {$totalCost > 0.0 && $cash == 0} {
            my Fail CASH "Need \$[moneyfmt $totalCost] for repairs, have none."
            return 0
        }

        # NEXT, figure out the maximum amount that could possibly be
        # spent
        set maxAmt 0.0

        switch -exact -- $fmode  {
            ALL {
                set maxAmt $cash
            }

            EXACT {
                let maxAmt {min($cash, $amount)}
            }

            PERCENT {
                let maxAmt {$percent/100.0 * $cash}
            }

            default {
                error "Invalid fmode: \"$fmode\""
            }
        }

        set totalSpent 0.0
        # NEXT, use cost profile to determine the actual repair done
        foreach n [dict keys $costProfile] {
            # NEXT, the share of the cost in this neighborhood and the
            # actual amount spent
            set spend 0.0

            if {$totalCost > 0.0} {
                let share {[dict get $costProfile $n] / $totalCost}
                let spend {$share * min($totalCost, $maxAmt)}
                let totalSpent {$totalSpent + $spend}
            }

            # NEXT, the actual amount of repair done
            set dRho [plant repairlevel $n $owner $spend]
            dict set trans(repairs) $n $dRho
            $coffer repair $n $dRho
        }

        # NEXT, obligate cash
        $coffer spend $totalSpent
        set trans(amount) $totalSpent

        # NEXT, if there's no repair cost, no repairs are needed
        if {$totalCost == 0.0} {
            set trans(repaired) 1
        }

        return 1
    }
 
    method GetNbhoods {} {
        set nbhoods [gofer::NBHOODS eval $nlist]
        set owner [my agent]

        if {[llength $nbhoods] == 0} {
            my Fail WARNING "Gofer retrieved no neighborhoods."
            return ""
        }

        # NEXT, filter out any neighborhoods that have no infrastructure
        # owned by the actor
        # NOTE: non-local neighborhoods will also get filtered out here.
        set nbhoodsWithPlants [rdb eval {
            SELECT n FROM plants_na
            WHERE a = $owner
        }]

        set inNbhoods [list]

        foreach n $nbhoods {
            if {$n in $nbhoodsWithPlants} {
                lappend inNbhoods $n
            }
        }

        if {[llength $inNbhoods] == 0} {
            my Fail WARNING \
                "$owner has no infrastructure in the retrieved neighborhoods."
        }

        return $inNbhoods
    }

    method execute {} {
        set owner [my agent]

        [my adb] cash spend $owner MAINTAIN $trans(amount)

        set nbhoods [gofer::NBHOODS eval $nlist]
        set ntext   [gofer::NBHOODS narrative $nlist]

        if {$trans(repaired)} {
            sigevent log 2 tactic "
                MAINTAIN: Actor {actor:$owner} spends
                \$[moneyfmt $trans(amount)] since any
                infrastructure owned in $ntext have already 
                had the maximum amount of repair.
            " $owner {*}$nbhoods

        } else {
            sigevent log 2 tactic "
                MAINTAIN: Actor {actor:$owner} spends
                \$[moneyfmt $trans(amount)] to maintain any 
                infrastructure owned in $ntext.
            " $owner {*}$nbhoods
        }

        foreach n [dict keys $trans(repairs)] {
            plant repair $owner $n [dict get $trans(repairs) $n]
        }
    }
}

#-----------------------------------------------------------------------
# TACTIC:* orders

# TACTIC:MAINTAIN
#
# Updates existing MAINTAIN tactic.

::athena::orders define TACTIC:MAINTAIN {
    meta title      "Tactic: Maintain Infrastructure"
    meta sendstates PREP
    meta parmlist   {tactic_id name nlist fmode amount percent rmode level}

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Nbhoods:" -for nlist -span 4 
        gofer nlist -typename gofer::NBHOODS

        rcc "Funding Mode:" -for fmode
        selector fmode {
            case ALL "Use as much cash-on-hand as possible" {}

            case EXACT "Use no more than an exact amount of cash-on-hand" {
                rcc "Amount:" -for amount
                text amount
                label "dollars"
            }

            case PERCENT "Use no more than a percentage of cash-on-hand" {
               rcc "Fund Percentage:" -for percent
               text percent
               label "%"
            }
        }

        rcc "Maintenance Mode:" -for rmode 
        selector rmode {
            case FULL "Maintain to full capacity" {}

            case UPTO "Maintain to a percentage of full capacity" {
                rcc "Capacity Percentage:" -for level 
                text level
                label "%"
            }
        }
    }


    method _validate {} {
        # FIRST, prepare the parameters
        my prepare tactic_id  -required -with {::strategy valclass ::athena::tactic::MAINTAIN}
        my returnOnError

        set tactic [$adb pot get $parms(tactic_id)]

        my prepare name    -toupper  -with [list $tactic valName]
        my prepare nlist
        my prepare rmode   -toupper  -selector
        my prepare fmode   -toupper  -selector
        my prepare amount  -type money
        my prepare level   -type rpercent
        my prepare percent -type rpercent

        my returnOnError

        # NEXT, check cross-constraints
        fillparms parms [$tactic view]

        if {$parms(rmode) eq "UPTO" && $parms(level) == 0.0} {
            my reject level "You must specify a capacity level > 0.0"
        }

        if {$parms(fmode) eq "PERCENT" && $parms(percent) == 0.0} {
            my reject percent "You must specify a percentage of cash > 0.0"
        }
    }

    method _execute {{flunky ""}} {
        set tactic [$adb pot get $parms(tactic_id)]
        my setundo [$tactic update_ {
            name nlist rmode amount fmode level percent
        } [array get parms]]
    }
}







