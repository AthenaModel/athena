#-----------------------------------------------------------------------
# TITLE:
#    tactic_service.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena_sim(1): Mark II Tactic, SERVICE tactic
#
#    This module implements the SERVICE tactic. 
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# Tactic: SERVICE

tactic define SERVICE "Update Level of Service" {system actor} -onlock {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    variable s      ;# The abstract service to change ALOS
    variable nlist  ;# A gofer::NBHOODS value
    variable los    ;# Actual level of service

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # Initialize as tactic bean
        next

        # Initialize state variables
        set nlist  [gofer::NBHOODS blank]
        set los    1.0
        set s      ENERGY

        # Initial state is invalid (empty nlist)
        my set state invalid

        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    # No ObligateResources method is required; the tactic uses no resources.

    method SanityCheck {errdict} {
        # nlist
        if {[catch {gofer::NBHOODS validate $nlist} result]} {
            dict set errdict nlist $result
        }

        if {$s eq ""} {
            dict set errdict s "No service type selected."
        } elseif {$s ni [eabservice names]} {
            dict set errdict s "No such service: $s"
        }

        return [next $errdict]
    }

    method narrative {} {
        # FIRST, get the owner and build the narrative appropriately
        set owner [my agent]
        set narr "Actor {actor:$owner} "
        set pct [format %.1f%% [expr {$los * 100.0}]]

        if {$owner eq "SYSTEM"} {
            set narr "The SYSTEM agent "
        }

        append narr "sets the actual level of $s service to "
        append narr "$pct of saturation level in "

        append narr [gofer::NBHOODS narrative $nlist]
        
        return $narr
    }

    method execute {} {
        # FIRST, get the owner
        set owner [my agent]
        set nbhoods {}

        set nbhoods [gofer eval $nlist]

        # NEXT, log execution
        set objects [concat $owner $nbhoods]

        set msg "SERVICE([my id]): [my narrative]"

        sigevent log 2 tactic $msg {*}$objects

        # NEXT, update actual LOS in the nbhoods specified
        service actual $nbhoods $s $los
    }
}

# TACTIC:SERVICE
#
# Creates/Updates SERVICE tactic.

order define TACTIC:SERVICE {
    title "Tactic: Update Level of Service"
    options -sendstates PREP

    form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {beanload}

        rcc "Neighborhoods:" -for nlist
        gofer nlist -typename gofer::NBHOODS

        rcc "Service Type:" -for s
        enum s -listcmd {eabservice names} -defvalue ENERGY

        rcc "ALOS:" -for los
        frac los
    }

} {
    # FIRST, prepare the parameters
    prepare tactic_id  -required -type tactic::SERVICE
    returnOnError

    set tactic [tactic get $parms(tactic_id)]

    # Validation of initially invalid items or contingent items
    # takes place on sanity check.
    prepare nlist     
    prepare s        -toupper -type eabservice
    prepare los -num          -type rfraction

    returnOnError -final

    # NEXT, modify the tactic
    setundo [$tactic update_ {
        nlist s los
    } [array get parms]]
}




