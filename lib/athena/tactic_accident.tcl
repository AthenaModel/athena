#-----------------------------------------------------------------------
# TITLE:
#    tactic_accident.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Mark II Tactic, ACCIDENT event
#
#    This module implements the ACCIDENT tactic. 
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# Tactic: ACCIDENT

::athena::tactic define ACCIDENT "Accident Event" {system actor} {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    variable n          ;# Neighborhood in which to create accident
    variable coverage   ;# Coverage fraction

    #-------------------------------------------------------------------
    # Constructor

    constructor {pot_ args} {
        next $pot_

        # Initialize state variables
        set n          ""
        set coverage   0.5

        # Initial state is invalid (no n)
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

        return [next $errdict]
    }

    method narrative {} {
        set narr ""

        set s(n)        [link make nbhood $n]
        set s(coverage) [format "%.2f" $coverage]

        set narr "ACCIDENT abstract event in $s(n) "
        append narr "(cov=$s(coverage))."
        
        return $narr
    }

    method execute {} {
        set owner [my agent]

        set s(n)        [link make nbhood $n]
        set s(coverage) [format "%.2f" $coverage]

        # NEXT, log execution
        set objects [list $owner $n]

        set msg "ACCIDENT([my id]): [my narrative]"

        [my adb] sigevent log 2 tactic $msg {*}$objects

        # NEXT, create the accident.
        [my adb] abevent add ACCIDENT $n $coverage
    }
}

# TACTIC:ACCIDENT
#
# Creates/Updates ACCIDENT tactic.

::athena::orders define TACTIC:ACCIDENT {
    meta title      "Tactic: Accident Event"
    meta sendstates PREP
    meta parmlist   {tactic_id name n coverage}

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Neighborhood:" -for n
        nbhood n

        rcc "Coverage:" -for coverage
        frac coverage
    }

    method _validate {} {
        my prepare tactic_id  -required \
            -with [list $adb strategy valclass ::athena::tactic::ACCIDENT]
        my returnOnError

        set tactic [$adb pot get $parms(tactic_id)]

        # Validation of initially invalid items or contingent items
        # takes place on sanity check.
        my prepare name      -toupper   -with [list $tactic valName]
        my prepare n         -toupper
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
            name n coverage
        } [array get parms]]
    }
}





