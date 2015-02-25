#-----------------------------------------------------------------------
# TITLE:
#    tactic_flow.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Mark II Tactic, FLOW
#
#    A FLOW tactic flows civilian personnel from one group to another.
#    This is a SYSTEM tactic; it never executes on lock.
#
#-----------------------------------------------------------------------

# FIRST, create the class.
::athena::tactic define FLOW "Flow Personnel" {system} {
    #-------------------------------------------------------------------
    # Instance Variables

    variable f           ;# The source civilian group
    variable g           ;# The destination civilian group
    variable mode        ;# ALL | RATE | UPTO | ALLBUT
    variable personnel   ;# Number of personnel, mode = UPTO, ALLBUT
    variable percent     ;# Percentage, for mode = RATE

    #-------------------------------------------------------------------
    # Constructor

    constructor {pot_ args} {
        next $pot_

        # Initialize state variables
        set f         ""
        set g         ""
        set mode      ALL
        set personnel 0
        set percent   0

        my set state invalid   ;# Initially we're invalid: no groups

        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    # Never fails due to lack of resources.

    method SanityCheck {errdict} {
        if {$f eq ""} {
            dict set errdict f "No group selected."
        } elseif {$f ni [[my adb] civgroup names]} {
            dict set errdict f \
                "No such civilian group: \"$f\"."
        }

        if {$g eq ""} {
            dict set errdict g "No group selected."
        } elseif {$g ni [[my adb] civgroup names]} {
            dict set errdict g \
                "No such civilian group: \"$g\"."
        }

        return [next $errdict]
    }


    method narrative {} {
        set s(f) [link make group $f]
        set s(g) [link make group $g]

        switch -exact -- $mode {
            ALL { 
                return "Flow all remaining members of $s(f) into $s(g)."
            }

            RATE {
                set s(pct) [format "%.1f" $percent]
                return \
                "Flow population from $s(f) to $s(g) at a rate of $s(pct)%/year."
            }

            UPTO {
                return "Flow up to $personnel members of $s(f) into $s(g)."
            }

            ALLBUT {
                return "Flow all but $personnel members of $s(f) into $s(g)."
            }

            default {
                error "Unknown mode: \"$mode\""
            }
        }
    }

    method execute {} {
        # FIRST, get the current population of group f.
        set population [[my adb] demog getg $f population]
        
        
        # NEXT, determine the number of people to move.
        switch -exact -- $mode {
            ALL {
                set delta $population
            }
            
            RATE {
                # The given rate is a percentage where we need a fraction,
                # so we need to divide by 100; and it's a yearly rate when
                # we need a weekly rate, so we need to divide by 52.
                #
                # Note: We could use the compound interest formula to
                # determine the weekly rate, but for our purposes the
                # difference turns out to be negligible.
                #
                # Note that [demog adjust] allows and will accumulate
                # fractional people; this is so that small rates of
                # change will still have effect given enough time.
                
                let weeklyRate {$percent/5200.0}
                let delta {$population*$weeklyRate}
            }

            UPTO {
                let delta {min($population,$personnel)}
            }

            ALLBUT {
                let delta {max(0,$population - $personnel)}
            }

            default {
                error "Unknown mode: \"$text1\""
            }
        }

        # NEXT, if we found no personnel to move, we done.
        if {$delta == 0} {
            return
        }

        # NEXT, add the adjustment to the pending list.
        [my adb] personnel flow $f $g $delta
        
        # NEXT, log the changes.
        set m [civgroup getg $f n]
        set n [civgroup getg $g n]
        
        [my adb] sigevent log 2 tactic "
            FLOW: $delta people moved from {group:$f} in {nbhood:$m}
            to {group:$g} in {nbhood:$n}
        " $f $g $m $n
    }
}

#-----------------------------------------------------------------------
# TACTIC:* orders

# TACTIC:FLOW
#
# Updates existing FLOW tactic.

::athena::orders define TACTIC:FLOW {
    meta title      "Tactic: Flow Personnel"
    meta sendstates PREP
    meta parmlist   {tactic_id name f g mode percent personnel}

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Source Group:" -for f
        enum f -listcmd {$adb_ civgroup names}

        rcc "Destination Group:" -for g
        enum g -listcmd {lexcept [$adb_ civgroup names] $f}

        rcc "Mode:" -for mode
        selector mode {
            case ALL "Flow all of the group's remaining members" {}

            case RATE "Flow members at a yearly rate of" {
                rcc "Rate:" -for percent
                text percent
                label "%/year, e.g., 5 is 5%/year"
            }

            case UPTO "Flow up to some number of the group's members" {
                rcc "Personnel:" -for personnel
                text personnel
            }

            case ALLBUT "Flow all but some number of the group's members" {
                rcc "Personnel:" -for personnel
                text personnel
            }
        }
    }


    method _validate {} {
        # FIRST, prepare the parameters
        my prepare tactic_id  -required \
            -with [list $adb strategy valclass ::athena::tactic::FLOW]
        my returnOnError

        set tactic [$adb pot get $parms(tactic_id)]

        my prepare name       -toupper  -with [list $tactic valName]
        my prepare f          -toupper  -type ident
        my prepare g          -toupper  -type ident
        my prepare mode       -toupper  -selector
        my prepare personnel  -num      -type iquantity
        my prepare percent    -num      -type rpercent

        my returnOnError

        fillparms parms [$tactic getdict]

        switch -exact -- $parms(mode) {
            ALL {
                # No checks to do
            }

            UPTO   -
            ALLBUT {
                if {$parms(personnel) == 0} {
                    my reject personnel "Mode requires personnel greater than 0."
                }
            }

            RATE {
                if {$parms(percent) == 0.0} {
                    my reject percent \
                        "Mode requires a percentage rate greater than 0.0%."
                }
            }

            default {
                error "Unexpected mode: \"$parms(mode)\""
            }
        }
    }

    method _execute {{flunky ""}} {
        set tactic [$adb pot get $parms(tactic_id)]
        my setundo [$tactic update_ {
            name f g mode personnel percent
        } [array get parms]]
    }
}







