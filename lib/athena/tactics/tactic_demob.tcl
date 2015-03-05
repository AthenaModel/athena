#-----------------------------------------------------------------------
# TITLE:
#    tactic_demob.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Mark II Tactic, DEMOB
#
#    A DEMOB tactic demobilizes force or organization group personnel,
#    moving them out of the playbox.
#
#-----------------------------------------------------------------------

# FIRST, create the class.
::athena::tactic define DEMOB "Demobilize Personnel" {actor} {
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

    constructor {pot_ args} {
        next $pot_

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
        } elseif {$g ni [[my adb] group ownedby [my agent]]} {
            dict set errdict g \
                "[my agent] does not own a group called \"$g\"."
        }

        return [next $errdict]
    }


    method narrative {} {
        set gtext [::athena::link make group $g]

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
        assert {[[my adb] strategy ontick]}
        
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
            [my adb] personnel demob $g $trans(personnel)
        }

        [my adb] sigevent log 1 tactic "
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

::athena::orders define TACTIC:DEMOB {
    meta title      "Tactic: Demobilize Personnel"
    meta sendstates PREP
    meta parmlist   {tactic_id name g mode personnel percent}

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Group:" -for g
        enum g -listcmd {$order_ groupsOwnedByAgent $tactic_id}

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


    method _validate {} {
        # FIRST, prepare the parameters
        my prepare tactic_id  -required \
            -with [list $adb strategy valclass ::athena::tactic::DEMOB]
        my returnOnError

        set tactic [$adb bean get $parms(tactic_id)]

        my prepare name       -toupper  -with [list $tactic valName]
        my prepare g          -toupper  -type ident
        my prepare mode       -toupper  -selector
        my prepare personnel  -num      -type iquantity
        my prepare percent    -num      -type rpercent

        my returnOnError

        ::athena::fillparms parms [$tactic getdict]

        switch -exact -- $parms(mode) {
            ALL {
                # No checks to do
            }

            SOME   -
            EXCESS {
                if {$parms(personnel) == 0} {
                    my reject personnel "Mode requires personnel greater than 0."
                }
            }

            PERCENT {
                if {$parms(percent) == 0.0} {
                    my reject percent "Mode requires a percentage greater than 0.0%."
                }
            }

            default {
                error "Unexpected mode: \"$parms(mode)\""
            }
        }
    }

    method _execute {{flunky ""}} {
        set tactic [$adb bean get $parms(tactic_id)]
        my setundo [$tactic update_ {name g mode personnel percent} [array get parms]]
    }
}







