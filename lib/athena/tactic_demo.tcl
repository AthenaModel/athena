#-----------------------------------------------------------------------
# TITLE:
#    tactic_demo.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Mark II Tactic, DEMOnstration event
#
#    This module implements the DEMO tactic. 
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# Tactic: DEMO

::athena::tactic define DEMO "Demonstration Event" {system actor} {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    variable n          ;# Neighborhood in which to create demo
    variable g          ;# Civilian group that is demonstrating.
    variable coverage   ;# Coverage fraction

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # Initialize as tactic bean
        next

        # Initialize state variables
        set n          ""
        set g          ""
        set coverage   0.5

        # Initial state is invalid (no n, g)
        my set state invalid

        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    # No ObligateResources method is required; the tactic uses no resources.

    method SanityCheck {errdict} {
        if {$n eq ""} {
            dict set errdict n "No neighborhood selected."
        } elseif {$n ni [[my adb] nbhood names]} {
            dict set errdict n "No such neighborhood: \"$n\"."
        }

        if {$g eq ""} {
            dict set errdict g "No demonstrating group selected."
        } elseif {$g ni [[my adb] civgroup names]} {
            dict set errdict g "No such group: \"$g\"."
        }

        return [next $errdict]
    }

    method narrative {} {
        set narr ""

        set s(n)        [link make nbhood $n]
        set s(g)        [link make group $g]
        set s(coverage) [format "%.2f" $coverage]

        set narr "DEMO abstract event by $s(g) in $s(n) "
        append narr "(cov=$s(coverage))."
        
        return $narr
    }

    method execute {} {
        set owner [my agent]

        # FIRST, log execution
        set objects [list $owner $n $g]

        set msg "DEMO([my id]): [my narrative]"

        sigevent log 2 tactic $msg {*}$objects

        # NEXT, create the demo.
        driver::abevent create DEMO $n $coverage g $g
    }
}

# TACTIC:DEMO
#
# Creates/Updates DEMO tactic.

::athena::orders define TACTIC:DEMO {
    meta title      "Tactic: Demo Event"
    meta sendstates PREP
    meta parmlist   {tactic_id name n g coverage}

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Neighborhood:" -for n
        nbhood n

        rcc "Group:" -for g
        civgroup g

        rcc "Coverage:" -for coverage
        frac coverage
    }

    method _validate {} {
        # FIRST, prepare the parameters
        my prepare tactic_id  -required \
            -with [list $adb strategy valclass ::athena::tactic::DEMO]
        my returnOnError

        set tactic [$adb pot get $parms(tactic_id)]

        # Validation of initially invalid items or contingent items
        # takes place on sanity check.
        my prepare name      -toupper   -with [list $tactic valName]
        my prepare n         -toupper
        my prepare g         -toupper
        my prepare coverage  -num       -type rfraction

        my returnOnError

        my checkon coverage {
            if {$parms(coverage) == 0.0} {
                my reject coverage "Coverage must be greater than 0."
            }
        }
    }

    method _execute {{flunky ""}} {
        set tactic [$adb pot get $parms(tactic_id)]
        my setundo [$tactic update_ {
            name n g coverage
        } [array get parms]]
    }
}





