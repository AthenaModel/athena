#-----------------------------------------------------------------------
# TITLE:
#    tactic_spend.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Mark II Tactic, SPEND
#
#    A SPEND tactic spends cash-on-hand to particular economic sectors.
#
#-----------------------------------------------------------------------

# FIRST, create the class.
tactic define SPEND "Spend Cash-On-Hand" {actor} -onlock {
    #-------------------------------------------------------------------
    # Instance Variables

    variable mode    ;# ALL, EXACT, UPTO, PERCENT or EXCESS 
    variable amount  ;# Amount of money if mode is SOME
    variable percent ;# Percent of money to spend if mode is PERCENT
    variable goods   ;# Integer # of shares going to goods sector
    variable black   ;# Integer # of shares going to black sector
    variable pop     ;# Integer # of shares going to pop sector
    variable region  ;# Integer # of shares going to region sector
    variable world   ;# Integer # of shares going to world sector

    # Transient Data
    variable trans

    
    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # Initialize as tactic bean.
        next

        # Initialize state variables
        set mode    ALL
        set amount  0.0
        set percent 0.0
        set goods   1
        set black   1
        set pop     1
        set region  1
        set world   1

        set trans(amount) 0.0

        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    # No special SanityCheck is required, unless we default to 
    # all-zero shares.

    method narrative {} {
        set amt [moneyfmt $amount]

        set text ""
        switch -exact -- $mode {
            ALL {
                append text "Spend all remaining cash-on-hand "
            }

            EXACT {
                append text "Spend exactly \$$amt of cash-on-hand "
            }

            UPTO {
                append text "Spend up to \$$amt of cash-on-hand "
            }

            PERCENT {
                append text "Spend $percent% of cash-on-hand "
            }

            EXCESS {
                append text "Spend any cash-on-hand over \$$amt "
            }

            default {
                error "Invalid mode: \"$mode\""
            }
        }
        
        append text "according to the following profile: "
        append text [my GetPercentages]
        
        return $text
    }

    # ObligateResources coffer
    #
    # coffer  - A coffer object with the owning agent's current
    #           resources
    #
    # Obligates the money to be spent.

    method ObligateResources {coffer} {
        # FIRST, retrieve relevant data.
        let cash [$coffer cash]
        set spent 0.0

        # NEXT, depending on mode, try to obligate money
        switch -exact -- $mode {
            ALL {
                if {$cash > 0.0} {
                    set spent $cash
                }
            }

            EXACT {
                # This is the only one than could give rise to an error and
                # only if we are on a tick
                if {[my InsufficientCash $cash $amount]} {
                    return
                }

                set spent $amount
            }

            UPTO {
                let spent {max(0.0, min($cash, $amount))}
            }

            PERCENT {
                if {$cash > 0.0} {
                    let spent {double($percent/100.0) * $cash}
                }
            }

            EXCESS {
                let spent {max(0.0, $cash-$amount)}
            }

            default {
                error "Invalid mode: \"$mode\""
            }

        }
        
        set trans(amount) $spent

        # NEXT, obligate it.
        $coffer spend $trans(amount)
    }

    method execute {} {
        cash spendon [my agent] $trans(amount) [my GetProfile]

        sigevent log 2 tactic "
            SPEND: Actor {actor:[my agent]} spends $trans(amount)
            on [my GetPercentages]
        " [my agent]
    }

    #-------------------------------------------------------------------
    # Helpers

    # GetPercentages 
    #
    # Turns the shares into percentages and returns a string
    # showing them.
    
    method GetPercentages {} {
        set fracs [my GetProfile]
       
        set profile [list]
        dict for {sector value} $fracs {
            lappend profile "$sector: [string trim [percent $value]]"
        }
        
        return [join $profile "; "]
    }
    
    # GetProfile
    #
    # Turns the shares into fractions and returns a dictionary
    # of the non-zero fractions by sector.
    
    method GetProfile {} {
        let total 0.0
        
        foreach sector {goods black pop region world} {
            let total {$total + [set $sector]}
        }
        
        set result [dict create]
        
        foreach sector {goods black pop region world} {
            set share [set $sector]
            
            if {$share > 0.0} {
                let fraction {$share/$total}
                dict set result $sector $fraction
            }
        }

        return $result        
    }    
}

#-----------------------------------------------------------------------
# TACTIC:* orders

# TACTIC:SPEND
#
# Updates existing SPEND tactic.

myorders define TACTIC:SPEND {
    meta title      "Tactic: Spend Money"
    meta sendstates PREP
    meta parmlist {
        tactic_id name mode amount percent
        goods black pop region world
    }

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Mode:"   -for mode
        selector mode {
            case ALL "Spend all remaining cash-on-hand" {}

            case EXACT "Spend exactly this much cash-on-hand" {
                rcc "Amount:" -for amount
                text amount
            }

            case UPTO "Spend up to this much of cash-on-hand" {
                rcc "Amount:" -for amount
                text amount
            }

            case PERCENT "Spend this percentage of cash-on-hand" {
                rcc "Percent:" -for percent
                text percent
                label "%"
            }

            case EXCESS "Spend cash-on-hand in excess of given amount" {
                rcc "Amount:" -for amount
                text amount
            }
        }
        
        rcc "Goods:" -for goods
        text goods
        label "share(s)"        

        rcc "Black:" -for black
        text black
        label "share(s)"        

        rcc "Pop:" -for pop
        text pop
        label "share(s)"        

        rcc "Region:" -for region
        text region
        label "share(s)"        

        rcc "World:" -for world
        text world
        label "share(s)"        
    }


    method _validate {} {
        # FIRST, prepare the parameters
        my prepare tactic_id  -required -with {::strategy valclass tactic::SPEND}
        my returnOnError

        set tactic [pot get $parms(tactic_id)]

        my prepare name       -toupper  -with [list $tactic valName]
        my prepare mode       -toupper  -selector
        my prepare amount     -toupper  -type money
        my prepare percent    -toupper  -type rpercent
        my prepare goods      -num      -type iquantity
        my prepare black      -num      -type iquantity
        my prepare pop        -num      -type iquantity
        my prepare region     -num      -type iquantity
        my prepare world      -num      -type iquantity

        my returnOnError

        # NEXT, check cross-constraints
        fillparms parms [$tactic view]

        if {$parms(mode) ne "PERCENT" && 
            $parms(mode) ne "ALL"     &&
            $parms(amount) == 0.0} {
                my reject amount "You must specify an amount > 0.0"
        }

        if {$parms(mode) eq "PERCENT" && $parms(percent) == 0.0} {
            my reject percent "You must specify a percent > 0.0"
        }

        # At least one sector must get a positive share
        let total {
            $parms(goods) + $parms(black) + $parms(pop) + $parms(region) + 
            $parms(world)
        }
        
        if {$total == 0} {
            my reject goods "At least one sector must have a positive share."
        }
    }

    method _execute {{flunky ""}} {
        set tactic [pot get $parms(tactic_id)]
        my setundo [$tactic update_ {
            name mode amount percent goods black pop region world
        } [array get parms]]
    }
}







