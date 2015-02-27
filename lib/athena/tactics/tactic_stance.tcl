#-----------------------------------------------------------------------
# TITLE:
#    tactic_stance.tcl
#
# AUTHOR:
#    Will Duquette
#    Dave Hanks
#
# DESCRIPTION:
#    athena(n): Mark II Tactic STANCE
#
#    This module implements the STANCE tactic, which allows an
#    actor to tell his force groups to adopt a particular stance
#    (designated relationship) toward particular groups or neighborhoods.
#    The designated relationship is taken into account when computing
#    neighborhood security.
#    
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# Tactic: STANCE

::athena::tactic define STANCE "Adopt a Stance" {actor} -onlock {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    variable mode      ;# BY_GROUP or BY_NBHOOD
    variable f         ;# A force group owned by the actor
    variable nlist     ;# A NBHOODS gofer value
    variable glist     ;# A GROUPS gofer value
    variable drel      ;# The designated relationship (aka STANCE)

    #-------------------------------------------------------------------
    # Constructor
    constructor {pot_ args} {
        next $pot_

        # NEXT, Initialize state variables
        set mode BY_GROUP
        set f    {}
        set nlist [[my adb] gofer NBHOODS blank]
        set glist [[my adb] gofer GROUPS blank]
        set drel  0.0

        # NEXT, Initial state is invalid (empty f, nlist and glist)
        my set state invalid

        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations
    
    method SanityCheck {errdict} {
        # f
        if {$f eq ""} {
            dict set errdict f \
                "No group selected."
        } elseif {$f ni [[my adb] group ownedby [my agent]]} {
            dict set errdict f \
                "[my agent] does not own a group called \"$f\"."
        }

        # glist/nlist
        switch -exact -- $mode {
            BY_GROUP {
                if {[catch {[my adb] gofer GROUPS validate $glist} result]} {
                    dict set errdict glist $result
                } 
            }

            BY_NBHOOD {
                if {[catch {[my adb] gofer NBHOODS validate $nlist} result]} {
                    dict set errdict nlist $result
                }
            }

            default { error "Unknown mode: \"$mode\"" }
        }

        return [next $errdict]
    }


    method narrative {} {
        set fgrp [::athena::link make group $f]

        append result \
            "Group $fgrp adopts a stance of [format %.2f $drel] " \
            "([qaffinity longname $drel]) toward "

        switch -exact -- $mode {
            BY_GROUP {
                append result [[my adb] gofer GROUPS narrative $glist]
            }

            BY_NBHOOD {
                append result "the group(s) in "
                append result [[my adb] gofer NBHOODS narrative $nlist]
            }

            default { error "Unknown mode: \"$mode\"" }
        }
        
        append result "."

        return $result
    }

    method execute {} {
        set nbhoods {}

        # FIRST, get the groups.
        if {$mode eq "BY_NBHOOD"} {
            set nbhoods [[my adb] gofer eval $nlist]
            set groups [list]
            foreach n $nbhoods {
                set groups [concat $groups [civgroup gIn $n]]
            }
        } else {
            set groups [[my adb] gofer eval $glist]

            # We can't set stance with $f
            ldelete groups $f
        }

        # NEXT, determine which groups to ignore.
        set gIgnored [[my adb] eval "
            SELECT g 
            FROM stance_fg
            WHERE f=\$f AND g IN ('[join $groups ',']')
        "]

        # NEXT, set f's designated relationship with each g
        set gSet [list]

        foreach g $groups {
            if {$g ni $gIgnored} {
                lappend gSet $g

                stance setfg $f $g $drel
            }
        }

        # NEXT, log what happened.
        set logIds [concat $nbhoods $gSet] 

        if {[llength $gSet] == 0} {
            set msg "
                STANCE: Actor {actor:[my agent]} directed group {group:$f} to 
                adopt a stance of [format %.2f $drel] 
                ([qaffinity longname $drel]) toward a number of groups; 
                however, $f's stances toward these groups were already set by
                higher-priority tactics.
            "

            [my adb] sigevent log 2 tactic $msg [my agent] {*}$logIds

            return 
        }

        set msg "
            STANCE: Actor {actor:[my agent]}'s group {group:$f} adopts stance
            of [format %.2f $drel] ([qaffinity longname $drel]) toward 
        "

        append msg "group(s): [join $gSet {, }]."

        if {[llength $gIgnored] > 0} {
            append msg " 
                Group {group:$f}'s stance toward these group(s) was
                already set by a prior tactic: [join $gIgnored {, }].
            "
        }

        [my adb] sigevent log 2 tactic $msg [my agent] {*}$logIds

        return 
    }
}

# TACTIC:STANCE
#
# Updates a STANCE tactic.

::athena::orders define TACTIC:STANCE {
    meta title      "Tactic: Force Group Stance"
    meta sendstates PREP
    meta parmlist   {tactic_id name f mode glist nlist drel}

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Force Group:" -for f
        enum f -listcmd {$order_ frcgroupsOwnedByAgent $tactic_id}

        rcc "Mode:" -for mode
        selector mode {
            case BY_GROUP "By Group" {
                rcc "Groups:" -for glist
                gofer glist -typename GROUPS
            }

            case BY_NBHOOD "By Neighborhood" {
                rcc "Neighborhoods:" -for nlist
                gofer nlist -typename NBHOODS
            }
        }

        rcc "Designated Rel.:" -for drel
        rel drel -showsymbols yes
    }


    method _validate {} {
        # FIRST, prepare and validate the parameters
        my prepare tactic_id -required \
            -with [list $adb strategy valclass ::athena::tactic::STANCE]
        my returnOnError

        set tactic [$adb pot get $parms(tactic_id)]

        my prepare name -toupper -with [list $tactic valName]
        my prepare f    -toupper
        my prepare mode -toupper -selector
        my prepare drel -toupper -num -type qaffinity
        my prepare glist
        my prepare nlist
    }

    method _execute {{flunky ""}} {
        set tactic [$adb pot get $parms(tactic_id)]
        my setundo [$tactic update_ {
            name f mode drel glist nlist
        } [array get parms]]
    }
}




