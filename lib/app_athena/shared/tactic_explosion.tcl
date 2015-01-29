#-----------------------------------------------------------------------
# TITLE:
#    tactic_explosion.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Mark II Tactic, EXPLOSION event
#
#    This module implements the EXPLOSION tactic. 
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# Tactic: EXPLOSION

tactic define EXPLOSION "Explosion Event" {system actor} {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    variable n          ;# Neighborhood in which to create explosion
    variable coverage   ;# Coverage fraction

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # Initialize as tactic bean
        next

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
        } elseif {$n ni [nbhood names]} {
            dict set errdict n "No such neighborhood: \"$n\"."
        }

        return [next $errdict]
    }

    method narrative {} {
        set narr ""

        set s(n)        [link make nbhood $n]
        set s(coverage) [format "%.2f" $coverage]

        set narr "EXPLOSION abstract event in $s(n) "
        append narr "(cov=$s(coverage))."
        
        return $narr
    }

    method execute {} {
        set owner [my agent]

        set s(n)        [link make nbhood $n]
        set s(coverage) [format "%.2f" $coverage]

        # NEXT, log execution
        set objects [list $owner $n]

        set msg "EXPLOSION([my id]): [my narrative]"

        sigevent log 2 tactic $msg {*}$objects

        # NEXT, create the explosion.
        driver::abevent create EXPLOSION $n $coverage
    }
}

# TACTIC:EXPLOSION
#
# Creates/Updates EXPLOSION tactic.

myorders define TACTIC:EXPLOSION {
    meta title      "Tactic: Explosion Event"
    meta sendstates PREP
    meta parmlist {tactic_id name n coverage}

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Neighborhood:" -for n
        nbhood n

        rcc "Coverage:" -for coverage
        frac coverage
    }

    method _validate {} {
        # FIRST, prepare the parameters
        my prepare tactic_id  -required -with {::strategy valclass tactic::EXPLOSION}
        my returnOnError

        set tactic [pot get $parms(tactic_id)]

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
        set tactic [pot get $parms(tactic_id)]
        my setundo [$tactic update_ {
            name n coverage
        } [array get parms]]
    }
}





