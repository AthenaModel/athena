#-----------------------------------------------------------------------
# TITLE:
#    tactic_riot.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Mark II Tactic, RIOT event
#
#    This module implements the RIOT tactic. 
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# Tactic: RIOT

tactic define RIOT "Riot Event" {system actor} {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    variable n          ;# Neighborhood in which to create riot
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

        set narr "RIOT abstract event in $s(n) "
        append narr "(cov=$s(coverage))."
        
        return $narr
    }

    method execute {} {
        set owner [my agent]

        set s(n)        [link make nbhood $n]
        set s(coverage) [format "%.2f" $coverage]

        # NEXT, log execution
        set objects [list $owner $n]

        set msg "RIOT([my id]): [my narrative]"

        sigevent log 2 tactic $msg {*}$objects

        # NEXT, create the riot.
        driver::abevent create RIOT $n $coverage
    }
}

# TACTIC:RIOT
#
# Creates/Updates RIOT tactic.

order define TACTIC:RIOT {
    title "Tactic: Riot Event"
    options -sendstates PREP

    form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {beanload}

        rcc "Neighborhood:" -for n
        nbhood n

        rcc "Coverage:" -for coverage
        frac coverage
    }

} {
    # FIRST, prepare the parameters
    prepare tactic_id  -required -type tactic::RIOT
    returnOnError

    set tactic [tactic get $parms(tactic_id)]

    # Validation of initially invalid items or contingent items
    # takes place on sanity check.
    prepare n         -toupper
    prepare coverage  -num       -type rfraction

    returnOnError

    validate coverage {
        if {$parms(coverage) == 0.0} {
            reject coverage "Coverage must be greater than 0."
        }
    }

    returnOnError -final


    # NEXT, modify the tactic
    setundo [$tactic update_ {
        n coverage
    } [array get parms]]
}




