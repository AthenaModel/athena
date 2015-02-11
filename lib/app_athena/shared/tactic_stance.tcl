#-----------------------------------------------------------------------
# TITLE:
#    tactic_stance.tcl
#
# AUTHOR:
#    Will Duquette
#    Dave Hanks
#
# DESCRIPTION:
#    athena_sim(1): Mark II Tactic STANCE
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

tactic define STANCE "Adopt a Stance" {actor} -onlock {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    variable mode      ;# BY_GROUP or BY_NBHOOD
    variable f         ;# A force group owned by the actor
    variable nlist     ;# A gofer::NBHOODS value
    variable glist     ;# A gofer::GROUPS value
    variable drel      ;# The designated relationship (aka STANCE)

    #-------------------------------------------------------------------
    # Constructor
    constructor {args} {
        # FIRST, Initialize as a tactic bean
        next

        # NEXT, Initialize state variables
        set mode BY_GROUP
        set f    {}
        set nlist [gofer::NBHOODS blank]
        set glist [gofer::GROUPS blank]
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
        } elseif {$f ni [group ownedby [my agent]]} {
            dict set errdict f \
                "[my agent] does not own a group called \"$f\"."
        }

        # glist/nlist
        switch -exact -- $mode {
            BY_GROUP {
                if {[catch {gofer::GROUPS validate $glist} result]} {
                    dict set errdict glist $result
                } 
            }

            BY_NBHOOD {
                if {[catch {gofer::NBHOODS validate $nlist} result]} {
                    dict set errdict nlist $result
                }
            }

            default { error "Unknown mode: \"$mode\"" }
        }

        return [next $errdict]
    }


    method narrative {} {
        set fgrp [link make group $f]

        append result \
            "Group $fgrp adopts a stance of [format %.2f $drel] " \
            "([qaffinity longname $drel]) toward "

        switch -exact -- $mode {
            BY_GROUP {
                append result [gofer::GROUPS narrative $glist]
            }

            BY_NBHOOD {
                append result "the group(s) in "
                append result [gofer::NBHOODS narrative $nlist]
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
            set nbhoods [gofer eval $nlist]
            set groups [list]
            foreach n $nbhoods {
                set groups [concat $groups [civgroup gIn $n]]
            }
        } else {
            set groups [gofer eval $glist]

            # We can't set stance with $f
            ldelete groups $f
        }

        # NEXT, determine which groups to ignore.
        set gIgnored [rdb eval "
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

            sigevent log 2 tactic $msg [my agent] {*}$logIds

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

        sigevent log 2 tactic $msg [my agent] {*}$logIds

        return 
    }

    #--------------------------------------------------------------------
    # Order Helper Typemethods

    # frcgrpsOwnedBy   tactic_id
    #
    # tactic_id   - A STANCE tactic id
    #
    # Returns a list of FRC groups owned by the actor who has the STANCE
    # tactic with the supplied id.

    typemethod frcgrpsOwnedBy {tactic_id} {
        if {![pot has $tactic_id]} {
            return [list]
        }

        set tactic [pot get $tactic_id]
        set owner [$tactic agent]

        return [frcgroup ownedby $owner]
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
        enum f -listcmd {tactic::STANCE frcgrpsOwnedBy $tactic_id}

        rcc "Mode:" -for mode
        selector mode {
            case BY_GROUP "By Group" {
                rcc "Groups:" -for glist
                gofer glist -typename gofer::GROUPS
            }

            case BY_NBHOOD "By Neighborhood" {
                rcc "Neighborhoods:" -for nlist
                gofer nlist -typename gofer::NBHOODS
            }
        }

        rcc "Designated Rel.:" -for drel
        rel drel -showsymbols yes
    }


    method _validate {} {
        # FIRST, prepare and validate the parameters
        my prepare tactic_id -required -with {::strategy valclass tactic::STANCE}
        my returnOnError

        set tactic [pot get $parms(tactic_id)]

        my prepare name -toupper -with [list $tactic valName]
        my prepare f    -toupper
        my prepare mode -toupper -selector
        my prepare drel -toupper -num -type qaffinity
        my prepare glist
        my prepare nlist
    }

    method _execute {{flunky ""}} {
        set tactic [pot get $parms(tactic_id)]
        my setundo [$tactic update_ {
            name f mode drel glist nlist
        } [array get parms]]
    }
}




