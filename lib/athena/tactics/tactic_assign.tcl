#-----------------------------------------------------------------------
# TITLE:
#    tactic_assign.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Mark II Tactic, ASSIGN
#
#    An ASSIGN tactic assigns deployed force or organization personnel
#    to perform particular activities in a neighborhood.
#
#-----------------------------------------------------------------------

# FIRST, create the class.
::athena::tactic define ASSIGN "Assign Personnel" {actor} -onlock {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    variable g           ;# A FRC or ORG group
    variable n           ;# The neighborhood in which g is deployed.
    variable activity    ;# The activity to assign them to do.
    variable pmode       ;# Personnel mode: ALL, SOME, UPTO, ALLBUT, PERCENT
    variable personnel   ;# pmode=SOME,ALLBUT: Number of personnel.
    variable min         ;# pmode=UPTO: Min personnel
    variable max         ;# pmode=UPTO: Max personnel
    variable percent     ;# pmode=PERCENT: Percentage of personnel

    # Transient Arrays
    variable trans

    #-------------------------------------------------------------------
    # Constructor

    constructor {pot_ args} {
        next $pot_

        # Initialize state variables
        set g              ""
        set n              ""
        set activity       ""
        set pmode          ALL
        set personnel      0
        set min            0
        set max            0
        set percent        0.0

        # Initial state is invalid (no g, n, activity)
        my set state invalid

        # Transient data
        # 
        # personnel - Number of personnel to assign
        # cost      - How much it will cost
        set trans(personnel) 0
        set trans(cost)      0.0

        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    method SanityCheck {errdict} {
        # Check g
        if {$g eq ""} {
            dict set errdict g "No group selected."
        } elseif {$g ni [[my adb] group ownedby [my agent]]} {
            dict set errdict g \
                "[my agent] does not own a force group called \"$g\"."
        }

        # Check n
        if {[llength $n] == 0} {
            dict set errdict n \
                "No neighborhood selected."
        } elseif {$n ni [[my adb] nbhood names]} {
            dict set errdict n \
                "No such neighborhood: \"$n\"."
        }

        # Check activity
        if {$activity eq ""} {
            dict set errdict activity "No activity selected."
        } elseif {[catch {[my adb] activity check $g $activity}]} {
            dict set errdict activity \
                "Invalid activity for selected group: \"$activity\"." 
        }

        return [next $errdict]
    }

    method narrative {} {
        set s(g)        [::athena::link make group  $g]
        set s(n)        [::athena::link make nbhood $n]
        let s(activity) {$activity ne "" ? $activity : "???"}

        switch -exact -- $pmode {
            "ALL"     { set s(pmode) "all"                       }
            "SOME"    { set s(pmode) $personnel                  }
            "UPTO"    { set s(pmode) "at least $min, up to $max" }
            "ALLBUT"  { set s(pmode) "all but $personnel"        }
            "PERCENT" { set s(pmode) [format %0.1f%% $percent]   }
            default   { error "Unexpected pmode: \"$pmode\""     }
        }

        return "In $s(n), assign $s(pmode) of $s(g)'s unassigned personnel to do $s(activity)."
    }

    #-------------------------------------------------------------------
    # Obligation
    

    # ObligateResources coffer
    #
    # coffer  - The owning agent's coffer of resources.
    #
    # Obligates the personnel and cash required for the assignment,
    # as indicated by the pmode, if possible, and failing otherwise.

    method ObligateResources {coffer} {
        # FIRST, Obligate by mode.  We can't simply compute the number
        # of troops for the selected mode, because different modes
        # have different failure policies.

        switch -exact -- $pmode {
            ALL     { set flag [my ObligateALL     $coffer] }
            SOME    { set flag [my ObligateSOME    $coffer] }
            UPTO    { set flag [my ObligateUPTO    $coffer] }
            ALLBUT  { set flag [my ObligateALLBUT  $coffer] }
            PERCENT { set flag [my ObligatePERCENT $coffer] }

            default { error "Invalid pmode: \"$pmode\""     }
        }

        if {$flag} {
            $coffer spend $trans(cost)
            $coffer assign $g $n $trans(personnel)
        }
    }

    # ObligateALL coffer
    #
    # coffer  - The owning agent's coffer of resources.
    #
    # When mode is ALL, assigns all unassigned troops.  Returns 1 on
    # success, and 0 on failure.
    #
    # This tactic operates on a "best efforts" basis with respect to
    # personnel.  If there are no troops, it succeeds; if there are
    # troops, but we can't afford to deploy them, it fails.

    method ObligateALL {coffer} {
        # FIRST, retrieve relevant data.
        set available     [$coffer troops $g $n]
        set cash          [$coffer cash]
        set cost          [my TroopCost $available]


        # NEXT, if no troops are available, then we've done what we
        # can; we succeed on a best efforts basis.
        if {$available == 0} {
            return [my ObligateEmptyAssignment]
        }

        # NEXT, if we are not locking, can we afford the troops?
        if {[my InsufficientCash $cash $cost]} {
            return 0
        }

        # NEXT, save the assignment details
        set trans(personnel) $available
        set trans(cost)      $cost

        return 1
    }

    # ObligateSOME coffer
    #
    # coffer  - The owning agent's coffer of resources.
    #
    # When mode is SOME, obligates the specified number of personnel,
    # failing if the troops are not available or cannot be paid for.

    method ObligateSOME {coffer} {
        # FIRST, retrieve relevant data.
        set tactic_id [my id]
        set available [$coffer troops $g $n]
        set cash      [$coffer cash]
        set cost      [my TroopCost $personnel]

        # NEXT, Fail if there are insufficient troops.
        if {[my InsufficientPersonnel $available $personnel]} {
            return 0
        }

        # NEXT, cost only matters on tick.
        if {[my InsufficientCash $cash $cost]} {
            return 0
        }

        # NEXT, save the assignment details
        set trans(personnel) $personnel
        set trans(cost)      $cost

        return 1
    }

    # ObligateUPTO coffer
    #
    # coffer  - The owning agent's coffer of resources.
    #
    # When mode is UPTO, figures out how many troops we can
    # afford to assign, from min up to max, and obligates the assignment.  
    # Returns 1 on success, and 0 on failure.
    #
    # This tactic fails if it can't assign at least min troops.  It
    # will assign up to max if we can afford them.

    method ObligateUPTO {coffer} {
        # FIRST, retrieve relevant data.
        set available [$coffer troops $g $n]
        set cash      [$coffer cash]

        # NEXT, compute the cost of the minimum amount of troops, 
        # and the maximum quantity of troops we can afford.
        set minCost [my TroopCost $min]

        if {[[my adb] strategy locking]} {
            set affordableTroops $max
        } else {
            set affordableTroops [my TroopsFor $coffer $cash]
        }

        if {[my InsufficientPersonnel $available $min]} {
            return 0
        }

        if {[my InsufficientCash $cash $minCost]} {
            return 0
        }

        let troops {min($max,$affordableTroops, $available)}

        # NEXT, save the assignment details
        set trans(personnel) $troops
        set trans(cost)      [my TroopCost $troops]

        return 1
    }

    # ObligateALLBUT coffer
    #
    # coffer  - The owning agent's coffer of resources.
    #
    # When mode is ALLBUT, determines how many troops to assign
    # and obligates the assignment.  Returns 1 on
    # success, and 0 on failure.
    #
    # This tactic operates on a "best efforts" basis with respect to
    # personnel.  If there are personnel troops or less, it still succeeds; 
    # if there are troops to assign, but we can't afford to assign 
    # them, it fails.

    method ObligateALLBUT {coffer} {
        # FIRST, retrieve relevant data.
        set available [$coffer troops $g $n]
        set cash      [$coffer cash]

        # NEXT, if no troops are available, then we've done what we
        # can; we succeed on a best efforts basis.
        let troops {$available - $personnel}

        if {$troops <= 0} {
            return [my ObligateEmptyAssignment]
        }

        # NEXT, cost only matters on tick.
        set cost [my TroopCost $troops]

        if {[my InsufficientCash $cash $cost]} {
            return 0
        }

        # NEXT, save the assignment details
        set trans(personnel) $troops
        set trans(cost)      $cost

        return 1
    }

    # ObligatePERCENT coffer
    #
    # coffer  - The owning agent's coffer of resources.
    #
    # When mode is PERCENT, figures out how many troops to assign
    # and obligates the assignment.  Returns 1 on
    # success, and 0 on failure.
    #
    # This tactic operates on a "best efforts" basis with respect to
    # personnel.  It will always attempt to assign at least one troop.
    # If 0 are available, it succeeds with an empty assignment.
    # If there are troops to assign, but we can't afford to assign  
    # them, it fails.

    method ObligatePERCENT {coffer} {
        # FIRST, retrieve relevant data.
        set available [$coffer troops $g $n]
        set cash      [$coffer cash]


        # NEXT, if no troops are available, then we've done what we
        # can; we succeed on a best efforts basis.
        if {$available == 0} {
            return [my ObligateEmptyAssignment]
        }

        let troops {
            entier(ceil(double($percent)*$available/100.0))
        }

        # NEXT, cost only matters on tick.
        set cost [my TroopCost $troops]

        if {[my InsufficientCash $cash $cost]} {
            return 0
        }

        # NEXT, save the assignment details
        set trans(personnel) $troops
        set trans(cost)      $cost

        return 1
    }


    # ObligateEmptyAssignment
    #
    # In some cases we will successfully assign no one.  This
    # method sets up the trans() variables for these cases,
    # and returns 1 for a successful assignment.

    method ObligateEmptyAssignment {} {
        set trans(personnel) 0
        set trans(cost)      0.0
        return 1
    }

    # CostPerPerson
    #
    # Returns the cost per person for the chosen activity.

    method CostPerPerson {} {
        set gtype [[my adb] group gtype $g]
        return [money validate [[my adb] parm get activity.$gtype.$activity.cost]]
    }


    # TroopCost troops
    #
    # Returns the cost of assigning the specified number of troops
    # to the selected activity.

    method TroopCost {troops} {
        let cost {[my CostPerPerson] * $troops}

        return $cost
    }

    # TroopsFor coffer cash
    #
    # coffer - The owning agent's coffer of resources.
    # cash   - Some amount of money.
    #
    # Returns the maximum number of troops one can afford to assign
    # given the cash available.

    method TroopsFor {coffer cash} {
        set costPerPerson [my CostPerPerson]

        if {$costPerPerson == 0.0} {
            return [$coffer troops $g $n]
        }

        return [expr {entier(double($cash)/$costPerPerson)}]
    }



    #-------------------------------------------------------------------
    # Execution
    

    method execute {} {
        # FIRST, Pay the assignment cost and assign the troops.  Note
        # that the assignment might be empty.
        [my adb] personnel assign [my id] $g $n $activity $trans(personnel)
        [my adb] cash spend [my agent] ASSIGN $trans(cost)

        [my adb] sigevent log 2 tactic "
            ASSIGN: Actor {actor:[my agent]} assigns $trans(personnel) {group:$g} 
            personnel to $activity in {nbhood:$n}
        " [my agent] $n $g

    }
}

#-----------------------------------------------------------------------
# TACTIC:* orders

# TACTIC:ASSIGN
#
# Updates existing ASSIGN tactic.

::athena::orders define TACTIC:ASSIGN {
    meta title      "Tactic: Assign Personnel"
    meta sendstates PREP
    meta parmlist   {
        tactic_id name g n activity pmode personnel min max percent
    }

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Group:" -for g
        enum g -listcmd {$order_ groupsOwnedByAgent $tactic_id}

        rcc "Neighborhood:" -for n
        nbhood n

        rcc "Activity:" -for activity
        enum activity -listcmd {$order_ activitiesFor $g}

        rcc "Personnel Mode:" -for pmode
        selector pmode {
            case ALL "Assign all of the group's unassigned personnel" {}

            case SOME "Assign some of the group's unassigned personnel" {
                rcc "Personnel:" -for personnel
                text personnel
            }

            case UPTO "Assign no less than" {
                rcc "Min Personnel:" -for min
                text min
                label "and up to"

                rcc "Max Personnel:" -for max
                text max
            }

            case ALLBUT "Assign all but some of the group's unassigned personnel" {
                rcc "Personnel:" -for personnel
                text personnel
            }

            case PERCENT "Assign a percentage of the group's unassigned personnel" {
                rcc "Percentage:" -for percent
                text percent
            }
        }
    }


    method _validate {} {
        # FIRST, prepare the parameters
        my prepare tactic_id  -required \
            -with [list $adb strategy valclass ::athena::tactic::ASSIGN]
        my returnOnError

        # NEXT, get the tactic
        set tactic [$adb pot get $parms(tactic_id)]

        my prepare name       -toupper  -with [list $tactic valName]
        my prepare g          -toupper  -type ident
        my prepare n          -toupper  -type ident
        my prepare activity   -toupper  -type [list $adb activity asched]
        my prepare pmode      -toupper  -selector
        my prepare personnel  -num      -type iquantity
        my prepare min        -num      -type iquantity
        my prepare max        -num      -type iquantity
        my prepare percent    -num      -type rpercent

        my returnOnError

        # NEXT, do the cross checks
        fillparms parms [$tactic view]

        if {$parms(pmode) eq "SOME" && $parms(personnel) == 0} {
            my reject personnel "For pmode SOME, personnel must be positive."
        }

        if {$parms(pmode) eq "UPTO"} {
            if {$parms(max) < $parms(min)} {
                my reject max "For pmode UPTO, max must be greater than min."
            }

            if {$parms(max) == 0} {
                my reject max "For pmode UPTO, max must be greater than 0."
            }
        }

        if {$parms(pmode) eq "PERCENT"} {
            if {$parms(percent) == 0} {
                my reject max "For pmode PERCENT, percent must be positive."
            }
        }
    }

    method _execute {{flunky ""}} {
        set tactic [$adb pot get $parms(tactic_id)]
        my setundo [$tactic update_ {
            name g n activity pmode personnel min max percent
        } [array get parms]]
    }
}







