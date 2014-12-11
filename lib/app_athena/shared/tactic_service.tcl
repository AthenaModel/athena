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
    variable mode   ;# One of: EXACT, REQ, EXPECT or DELTA
    variable deltap ;# Delta pct of ALOS up or down when mode is DELTA
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
        set deltap 0.0
        set mode   EXACT
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
        set pct  [format %.1f%% [expr {$los * 100.0}]]
        set mult [expr {$deltap >= 0.0 ? 1.0 : -1.0}]
        set pdel [format %.1f%% [expr {$deltap * $mult}]]

        if {$owner eq "SYSTEM"} {
            set narr "The SYSTEM agent "
        }

        append narr "sets the actual level of $s service "

        switch -exact -- $mode {
            EXACT {
                append narr "to $pct of saturation level in "
            }

            REQ {
                append narr "to the required LOS in "
            }

            EXPECT {
                append narr "to the expected LOS in "
            }

            DELTA {
                if {$deltap >= 0.0} {
                    set dir "up"
                } else {
                    set dir "down"
                }
                append narr "$dir by $pdel of current actual level in "
            }

            default {error "Unknown mode: \"$mode\""}
        }

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

        set glist [list]
        foreach n $nbhoods {
            lappend glist {*}[civgroup gIn $n]
        }

        set gclause "g IN ('[join $glist {','}]') AND s='$s'"

        # NEXT, update actual LOS in the nbhoods specified
        switch -exact -- $mode {
            EXACT {
                # All nbhoods receive the same LOS
                service actual $nbhoods $s $los
            }
            
            REQ {
                # Set LOS to the required level by groups in nbhoods
                rdb eval "
                    UPDATE service_sg
                    SET new_actual = required
                    WHERE $gclause
                "
            }

            EXPECT {
                # Set LOS to the expected level by groups in nbhoods
                rdb eval "
                    UPDATE service_sg
                    SET new_actual = expected
                    WHERE $gclause
                "
            }

            DELTA {
                # Set LOS up or down by a percentage of current ALOS
                # by groups in nbhoods
                let frac {$deltap / 100.0}
                rdb eval "
                    UPDATE service_sg
                    SET new_actual = max(0.0,min(1.0,actual + (actual * $frac)))
                    WHERE $gclause
                "
            }

            default {error "Unknown mode: \"$mode\""}
        }
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

        rcc "Neighborhoods:" -for nlist -span 3
        gofer nlist -typename gofer::NBHOODS

        rcc "Service:" -for s 
        enum s -listcmd {eabservice names} -defvalue ENERGY

        rcc "Level:" -for mode
        selector mode {
            case EXACT "Exactly this LOS" {
                cc "" -for los
                frac los
            }

            case REQ "Set to Required LOS" {}

            case EXPECT "Set to Expected LOS" {}

            case DELTA "Change by (+/-)" {
                cc "" -for deltap 
                text deltap
                c  
                label "% of ALOS"
            }
        }
    }

} {
    # FIRST, prepare the parameters
    prepare tactic_id  -required -with {::pot valclass tactic::SERVICE}
    returnOnError

    set tactic [pot get $parms(tactic_id)]

    # Validation of initially invalid items or contingent items
    # takes place on sanity check.
    prepare nlist     
    prepare s      -toupper -type eabservice
    prepare mode   -toupper -selector
    prepare deltap          -type rpercentpm
    prepare los    -num     -type rfraction

    returnOnError -final

    # NEXT, modify the tactic
    setundo [$tactic update_ {
        nlist s los mode deltap
    } [array get parms]]
}




