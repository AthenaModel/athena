#-----------------------------------------------------------------------
# TITLE:
#    tactic_service.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena(n): Mark II Tactic, SERVICE tactic
#
#    This module implements the SERVICE tactic. 
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# Tactic: SERVICE

::athena::tactic define SERVICE "Update Level of Service" {system actor} -onlock {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    variable s      ;# The abstract service to change ALOS
    variable mode   ;# One of: EXACT, RDELTA, EDELTA or ADELTA
    variable deltap ;# Delta pct up or down when mode is not EXACT
    variable nlist  ;# A gofer::NBHOODS value
    variable los    ;# Actual level of service

    #-------------------------------------------------------------------
    # Constructor

    constructor {pot_ args} {
        next $pot_

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

        if {$deltap >= 0.0} {
            set dir "up"
        } else {
            set dir "down"
        }

        append narr "attempts to set the actual level of $s service "

        switch -exact -- $mode {
            EXACT {
                append narr "to $pct of saturation level in "
            }

            RDELTA {
                append narr "$dir by $pdel of current required level in "
            }

            EDELTA {
                append narr "$dir by $pdel of current expected level in "
            }

            ADELTA {
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
        let frac {$deltap / 100.0}

        set nbhoods [gofer eval $nlist]

        set ngood [list]
        set nbad  [list]

        # NEXT, determine which nbhoods get a new LOS and which don't
        # because they've already been updated
        foreach n $nbhoods {
            if {[[my adb] service changed $n $s]} {
                lappend nbad $n
            } else {
                lappend ngood $n
            }
        }

        # NEXT, log execution
        if {[llength $ngood] > 0} {
            set objects [concat $owner $ngood]
            set msg "SERVICE([my id]): [my narrative]"
            [my adb] sigevent log 2 tactic $msg {*}$objects
        }

        if {[llength $nbad] > 0} {
            set objects [concat $owner $nbad]
            set msg "SERVICE([my id]): "
            append msg "LOS already set by higher priority tactic(s) in " 
            append msg "these nbhoods: $nbad."
            [my adb] sigevent log 2 tactic $msg {*}$objects
        }

        # NEXT, if no nbhoods can be modified we are done
        if {[llength $ngood] == 0} {
            return
        }

        # NEXT, update actual LOS in the nbhoods specified
        switch -exact -- $mode {
            EXACT {
                # All nbhoods receive the same LOS
                [my adb] service actual $ngood $s $los
            }
            
            RDELTA - 
            EDELTA -
            ADELTA {
                # Change service in nbhoods by some delta
                [my adb] service delta $mode $ngood $s $frac
            }

            default {error "Unknown mode: \"$mode\""}
        }
    }
}

# TACTIC:SERVICE
#
# Creates/Updates SERVICE tactic.

::athena::orders define TACTIC:SERVICE {
    meta title      "Tactic: Update Level of Service"
    meta sendstates PREP
    meta parmlist   {tactic_id name nlist s mode los deltap}

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Neighborhoods:" -for nlist -span 3
        gofer nlist -typename NBHOODS

        rcc "Service:" -for s 
        enum s -listcmd {eabservice names} -defvalue ENERGY

        rcc "Level:" -for mode
        selector mode {
            case EXACT "Exactly this LOS" {
                cc "" -for los
                frac los
            }

            case RDELTA "Delta percent of RLOS" {
                cc "" -for deltap 
                text deltap
                c  
                label "% (+/-)"
            }

            case EDELTA "Delta percent of ELOS" {
                cc "" -for deltap 
                text deltap
                c  
                label "% (+/-)"
            }

            case ADELTA "Delta percent of current LOS" {
                cc "" -for deltap 
                text deltap
                c  
                label "% (+/-)"
            }
        }
    }

    method _validate {} {
        # FIRST, prepare the parameters
        my prepare tactic_id  -required \
            -with [list $adb strategy valclass ::athena::tactic::SERVICE]
        my returnOnError

        set tactic [$adb pot get $parms(tactic_id)]

        # Validation of initially invalid items or contingent items
        # takes place on sanity check.
        my prepare name   -toupper -with [list $tactic valName]
        my prepare nlist     
        my prepare s      -toupper -type eabservice
        my prepare mode   -toupper -selector
        my prepare deltap          -type rsvcpct
        my prepare los    -num     -type rfraction
    }

    method _execute {{flunky ""}} {
        set tactic [$adb pot get $parms(tactic_id)]
        my setundo [$tactic update_ {
            name nlist s los mode deltap
        } [array get parms]]
    }
}





