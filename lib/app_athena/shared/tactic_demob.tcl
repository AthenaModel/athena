#-----------------------------------------------------------------------
# TITLE:
#    tactic_demob.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Mark II Tactic, DEMOB
#
#    A DEMOB tactic demobilizes force or organization group personnel,
#    moving them out of the playbox.
#
#-----------------------------------------------------------------------

# FIRST, create the class.
tactic define DEMOB "Demobilize Personnel" {actor} {
    #-------------------------------------------------------------------
    # Instance Variables

    variable g           ;# A FRC or ORG group
    variable mode        ;# ALL | SOME | PERCENT | EXCESS
    variable personnel   ;# Number of personnel, mode = SOME | EXCESS
    variable percent     ;# Percentage, for mode = PERCENT

    # Transient data
    variable trans

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # Initialize as tactic bean.
        next

        # Initialize state variables
        set g         ""
        set mode      ALL
        set personnel 0
        set percent   0

        my set state invalid   ;# Initially we're invalid: no group

        set trans(personnel) 0

        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    method SanityCheck {errdict} {
        if {$g eq ""} {
            dict set errdict g "No group selected."
        } elseif {$g ni [group ownedby [my agent]]} {
            dict set errdict g \
                "[my agent] does not own a group called \"$g\"."
        }

        return [next $errdict]
    }


    method narrative {} {
        set gtext [link make group $g]

        switch -exact -- $mode {
            ALL     { set ptext "all"                      }
            SOME    { set ptext $personnel                 }
            PERCENT { set ptext [format "%.1f%%" $percent] }
            EXCESS  { set ptext "all but $personnel"       }
            default {
                error "Unknown mode: \"$mode\""
            }
        }

        return "Demobilize $ptext of group $gtext's undeployed personnel."
    }

    # ObligateResources coffer
    #
    # coffer  - A coffer object with the owning agent's current
    #           resources
    #
    # Obligates the personnel to be demobilized.
    #
    # NOTE: DEMOB never executes on lock.

    method ObligateResources {coffer} {
        assert {[strategy ontick]}
        
        # FIRST, get the amount to demobilize.
        set undeployed [$coffer troops $g undeployed]

        switch -exact -- $mode {
            ALL { 
                set trans(personnel) $undeployed 
            }

            SOME {
                if {[my InsufficientPersonnel $undeployed $personnel]} {
                    return
                }
                set trans(personnel) $personnel
            }

            PERCENT {
                if {$undeployed == 0} {
                    set trans(personnel) 0
                } else {
                    let trans(personnel) {
                        entier(ceil(($percent/100.0)*$undeployed))
                    }
                }
            }

            EXCESS {
                let trans(personnel) {
                    max(0,$undeployed - $personnel)
                }
            }

            default {
                error "Unknown mode: \"$mode\""
            }
        }

        $coffer demobilize $g $trans(personnel)
    }

    method execute {} {
        # ALL, PERCENT, and EXCESS work on a best efforts basis; they
        # can succeed with 0 troops. 
        if {$trans(personnel) > 0} {
            personnel demob $g $trans(personnel)
        }

        sigevent log 1 tactic "
            DEMOB: Actor {actor:[my agent]} demobilizes $trans(personnel)
            {group:$g} personnel.
        " [my agent] $g
    }
}

#-----------------------------------------------------------------------
# TACTIC:* orders

# TACTIC:DEMOB
#
# Updates existing DEMOB tactic.

order define TACTIC:DEMOB {
    title "Tactic: Demobilize Personnel"
    options -sendstates PREP

    form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {beanload}

        rcc "Group:" -for g
        enum g -listcmd {tactic groupsOwnedByAgent $tactic_id}

        rcc "Mode:" -for mode
        selector mode {
            case ALL "Demobilize all of the group's undeployed personnel" {}

            case SOME "Demobilize a number of the group's undeployed personnel" {
                rcc "Personnel:" -for personnel
                text personnel
            }

            case PERCENT "Demobilize a percentage of the group's undeployed personnel" {
                rcc "Percentage:" -for percent
                text percent
                label "%"
            }

            case EXCESS "Demobilize all but a number of the group's undeployed personnel" {
                rcc "Personnel:" -for personnel
                text personnel
            }
        }
    }
} {
    # FIRST, prepare the parameters
    prepare tactic_id  -required -with {::pot valclass tactic::DEMOB}
    prepare g          -toupper  -type ident
    prepare mode       -toupper  -selector
    prepare personnel  -num      -type iquantity
    prepare percent    -num      -type rpercent

    returnOnError

    # NEXT, get the tactic and do cross-checks
    set tactic [pot get $parms(tactic_id)]

    fillparms parms [$tactic getdict]

    switch -exact -- $parms(mode) {
        ALL {
            # No checks to do
        }

        SOME   -
        EXCESS {
            if {$parms(personnel) == 0} {
                reject personnel "Mode requires personnel greater than 0."
            }
        }

        PERCENT {
            if {$parms(percent) == 0.0} {
                reject percent "Mode requires a percentage greater than 0.0%."
            }
        }

        default {
            error "Unexpected mode: \"$parms(mode)\""
        }
    }

    returnOnError -final

    # NEXT, update the tactic, saving the undo script
    set undo [$tactic update_ {g mode personnel percent} [array get parms]]

    # NEXT, modify the tactic
    setundo $undo
}






