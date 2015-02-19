#-----------------------------------------------------------------------
# TITLE:
#    gofer_civgroups.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): CIVGROUPS gofer - A list of civilian groups produced 
#    according to various rules
#
#-----------------------------------------------------------------------

::athena::goferx define CIVGROUPS group {
    rc "" -width 5in -span 3
    label {
        Enter a rule for selecting a set of civilian groups:
    }
    rc

    rc "" -span 3
    selector _rule {
        case BY_VALUE "By name" {
            rc "Select groups from the following list:"
            rc
            enumlonglist raw_value -dictcmd {$adb_ civgroup namedict} \
                -width 30 -height 10 
        }

        case MEGA "Megafilter" {
            rc "Select Civilian Groups:" -span 2
            rc
            rcc "Starting&nbsp;with:"
            selector base -defvalue ALL {
                case ALL "All civilian groups" {}
                case THESE "These civilian groups" {
                    rcc ""
                    listbutton glist -dictcmd {$adb_ civgroup namedict} \
                        -emptymessage "No groups selected."         \
                        -listwidth    40
                }
            } 


            rc "As filtered by:" -span 2

            rcc "Residing:"
            enumlong where -defvalue IGNORE \
                -dictcmd {::gofer::CIVGROUPS::ewhere asdict longname}
         
            when {$where ne "IGNORE"} {
                rcc ""
                listbutton nlist -dictcmd {$adb_ nbhood namedict}  \
                    -emptymessage "No neighborhoods selected." \
                    -listwidth    40
            }

            rcc "Living&nbsp;By:"
            enumlong livingby -defvalue IGNORE \
                -dictcmd {::gofer::CIVGROUPS::elivingby asdict longname}

            rcc "With&nbsp;Mood:"
            enumlong mood -defvalue IGNORE \
                -dictcmd {::gofer::CIVGROUPS::emood asdict longname}

            rcc "By&nbsp;Actors:"
            enumlong byactors -defvalue IGNORE \
                -dictcmd {::gofer::CIVGROUPS::ebyactors asdict longname}

            when {$byactors ne "IGNORE"} {
                label " "
                enumlong awhich -defvalue ALL -dictcmd {::eanyall deflist}

                rcc ""
                listbutton alist -dictcmd {$adb_ actor namedict} \
                    -emptymessage "No actors selected."      \
                    -listwidth    40
            } 

            rcc "By&nbsp;Groups:"
            enumlong bygroups -defvalue IGNORE \
                -dictcmd {::gofer::CIVGROUPS::ebygroups asdict longname}

            when {$bygroups ne "IGNORE"} {
                label " "
                enumlong hwhich -defvalue ALL -dictcmd {::eanyall deflist}

                rcc ""
                listbutton hlist -dictcmd {$adb_ group namedict} \
                    -emptymessage "No groups selected."      \
                    -listwidth    40
            } 
        }

        case RESIDENT_IN "Resident in Neighborhood(s)" {
            rc "Select groups that reside in any of the following neighborhoods:"
            rc
            enumlonglist nlist -dictcmd {$adb_ nbhood namedict} \
                -width 30 -height 10
        }

        case NOT_RESIDENT_IN "Not Resident in Neighborhood(s)" {
            rc "Select groups that do not reside in any of the following neighborhoods:"
            rc
            enumlonglist nlist -dictcmd {$adb_ nbhood namedict} \
                -width 30 -height 10
        }

        case MOOD_IS_GOOD "Mood is Good" { 
            rc "Select groups whose mood is good."
            rc
            rc {
                A group's mood is good if it is Satisfied or Very
                Satisfied, i.e., it is greater than 20.0.
            }
        }

        case MOOD_IS_BAD "Mood is Bad" { 
            rc "Select groups whose mood is bad."
            rc
            rc {
                A group's mood is bad if it is Dissatisfied or Very
                Dissatisfied, i.e., it is less than &minus;20.0.
            }
        }

        case MOOD_IS_AMBIVALENT "Mood is Ambivalent" { 
            rc "Select groups whose mood is ambivalent."
            rc
            rc {
                A group's mood is ambivalent if it is between
                &minus;20.0 and 20.0.
            }
        }

        case SUPPORTING_ACTOR "Supporting Actor(s)" {
            rc "Select groups that actively support "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following actors:"

            rc
            enumlonglist alist -dictcmd {$adb_ actor namedict} \
                -width 30 -height 10

            rc {
                A group supports an actor if it contributes to the actor's 
                influence in some neighborhood.
            }
        }

        case LIKING_ACTOR "Liking Actor(s)" {
            rc "Select groups that like "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following actors:"

            rc
            enumlonglist alist -dictcmd {$adb_ actor namedict} \
                -width 30 -height 10

            rc {
                A group likes an actor if its vertical relationship 
                with the actor is LIKE or SUPPORT (i.e., the 
                relationship is greater than or equal to 0.2).
            }
        }

        case DISLIKING_ACTOR "Disliking Actor(s)" {
            rc "Select groups that dislike "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following actors:"

            rc
            enumlonglist alist -dictcmd {$adb_ actor namedict} \
                -width 30 -height 10

            rc {
                A group dislikes an actor if its vertical relationship 
                with the actor is DISLIKE or OPPOSE (i.e., the 
                relationship is less than or equal to &minus;0.2).
            }
        }

        case LIKING_GROUP "Liking Group(s)" {
            rc "Select groups that like "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following groups:"

            rc
            enumlonglist glist -dictcmd {$adb_ group namedict} \
                -width 30 -height 10

            rc {
                Group F likes group G if its horizontal relationship 
                with G is LIKE or SUPPORT (i.e., the 
                relationship is greater than or equal to 0.2).
            }
        }

        case DISLIKING_GROUP "Disliking Group(s)" {
            rc "Select groups that dislike "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following groups:"

            rc
            enumlonglist glist -dictcmd {$adb_ group namedict} \
                -width 30 -height 10

            rc {
                Group F dislikes group G if its horizontal relationship 
                with G is DISLIKE or OPPOSE (i.e., the 
                relationship is less than or equal to &minus;0.2).
            }
        }

        case LIKED_BY_GROUP "Liked by Group(s)" {
            rc "Select groups that are liked by "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following groups:"

            rc
            enumlonglist glist -dictcmd {$adb_ group namedict} \
                -width 30 -height 10

            rc {
                Group F is liked by group G if G's horizontal relationship 
                with F is LIKE or SUPPORT (i.e., the 
                relationship is greater than or equal to 0.2).
            }
        }

        case DISLIKED_BY_GROUP "Disliked by Group(s)" {
            rc "Select groups that are disliked by "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following groups:"

            rc
            enumlonglist glist -dictcmd {$adb_ group namedict} \
                -width 30 -height 10

            rc {
                Group F is disliked by group G if G's horizontal relationship 
                with F is DISLIKE or OPPOSE (i.e., the 
                relationship is less than or equal to &minus;0.2).
            }
        }
    }
}

#-------------------------------------------------------------------
# Enumerations

# TBD: Rename

# Filter Enum: where does a civgroup live?
enumx create ::gofer::CIVGROUPS::ewhere {
    IGNORE  {longname "Ignore"}
    IN      {longname "In These Neighborhoods"}
    NOTIN   {longname "Not In These Neighborhoods"}
}

# Filter Enum: does a civgroup live by subsistence agriculture or
# by the cash economy?
enumx create ::gofer::CIVGROUPS::elivingby {
    IGNORE  {longname "Ignore"}
    SA      {longname "Subsistence Agriculture"}
    CASH    {longname "Cash Economy"}
}

# Filter Enum: what is a civgroup's mood?
enumx create ::gofer::CIVGROUPS::emood {
    IGNORE     {longname "Ignore"}
    GOOD       {longname "Satisfied or better"}
    AMBIVALENT {longname "Ambivalent"}
    BAD        {longname "Dissatisfied or worse"}
}

# Filter Enum: what is a civgroup's relation to a set of actors?

enumx create ::gofer::CIVGROUPS::ebyactors {
    IGNORE      {longname "Ignore"}
    SUPPORTING  {longname "Supporting"}
    LIKING      {longname "Liking"}
    DISLIKING   {longname "Disliking"}
}

# Filter Enum: what is a civgroup's relation to a set of groups?

enumx create ::gofer::CIVGROUPS::ebygroups {
    IGNORE      {longname "Ignore"}
    LIKING      {longname "Liking"}
    DISLIKING   {longname "Disliking"}
    LIKED_BY    {longname "Liked by"}
    DISLIKED_BY {longname "Disliked by"}
}

#-----------------------------------------------------------------------
# Helper Commands

# TBD: Define a gofer_civgroup_rule base class, or add to gofer_rule.



# filterby glistVar filterlist
#
# glistVar   - A variable containing a list of civilian groups
# filterlist - Another list of civilian groups
# 
# Computes the intersection of the two lists, and saves it back
# to glistVar.

proc ::gofer::CIVGROUPS::filterby {glistVar filterlist} {
    upvar 1 $glistVar glist

    set glist [struct::set intersect $glist $filterlist]
}

# groupsIn nlist
#
# Returns the groups present in a list of neighborhoods.

proc gofer::CIVGROUPS$adb_ groupsIn {nlist} {
    set out [list]
    foreach n $nlist {
        lappend out {*}[demog gIn $n]
    }

    return $out
}

# groupsNotIn nlist
#
# Returns the groups not resident in a list of neighborhoods.

proc gofer::CIVGROUPS$adb_ groupsNotIn {nlist} {
    set out [civgroup names]
    foreach n $nlist {
        foreach g [demog gIn $n] {
            ldelete out $g
        }
    }
    return $out
}

# selectorValidate rule field value
#
# rule   - The gofer::CIVGROUPS rule
# field  - The selector field within that rule
# value  - The selector value
#
# Validates a selector value.

proc gofer::CIVGROUPS::selectorValidate {rule field value} {
    set dform [gofer::CIVGROUPS dynaform]
    set value [string toupper $value]
    set values [dynaform cases $dform $field [list _rule $rule]]

    if {$value ni $values} {
        error "Invalid \"$field\" value: \"$value\""
    }

    return $value
}

#-----------------------------------------------------------------------
# Gofer Rules

# Rule: BY_VALUE
#
# Some set of civilian groups chosen by the user.

::athena::goferx rule CIVGROUPS BY_VALUE {raw_value} {
    method construct {raw_value} {
        return [my validate [dict create raw_value $raw_value]]
    }

    method validate {gdict} {
        dict with gdict {}

        dict create raw_value \
            [my val_elist civgroup "groups" $raw_value]
    }

    method narrative {gdict {opt ""}} {
        dict with gdict {}

        return [my nar_list "group" "these groups" $raw_value $opt]
    }

    method eval {gdict} {
        dict with gdict {}

        return [my nonempty $raw_value]
    }
}

# Rule: MEGA
#
# Some set of civilian groups chosen by the user and filtered by
# an arbitrary number of criteria


::athena::goferx rule CIVGROUPS MEGA {
    base       glist
    where      nlist
    livingby
    mood
    byactors   awhich alist
    bygroups   hwhich hlist
} {
    variable defaultValues {
        base       ALL     glist {}
        where      IGNORE  nlist {}
        livingby   IGNORE
        mood       IGNORE
        byactors   IGNORE  awhich ALL alist {}
        bygroups   IGNORE  hwhich ALL hlist {}
    }

    # construct option value ...
    #
    # Option names are attribute names with "-".

    method construct {args} {
        set pdict [dict create]

        while {[llength $args] > 0} {
            set opt [lshift args]
            set parm [string range $opt 1 end]
            set value [lshift args]

            if {![dict exists $defaultValues $parm]} {
                error "Unknown option: $opt"
            }

            dict set pdict $parm $value
        }

        return [my validate $pdict]
    }

    method validate {gdict} {
        # FIRST, fill in the defaults.
        set gdict [dict merge $defaultValues $gdict]

        dict with gdict {}

        # base
        set base [selectorValidate MEGA base $base]
        dict set gdict base $base

        # glist
        if {$base eq "THESE"} {
            dict set gdict glist \
                [listval "groups" {civgroup validate} $glist]
        } else {
            dict set gdict glist [list]
        }

        # where
        set where [ewhere validate $where]
        dict set gdict where $where

        # nlist
        if {$where ne "IGNORE"} {
            dict set gdict nlist \
                [listval "neighborhoods" {nbhood validate} $nlist]
        } else {
            dict set gdict nlist [list]
        }

        # livingby
        dict set gdict livingby [elivingby validate $livingby]

        # mood
        dict set gdict mood [emood validate $mood]

        # byactors
        set byactors [ebyactors validate $byactors]
        dict set gdict byactors $byactors

        # awhich
        if {$byactors ne "IGNORE"} {
            dict set gdict awhich [eanyall validate $awhich]
        } else {
            dict set gdict awhich "ALL"
        }

        # alist
        if {$byactors ne "IGNORE"} {
            dict set gdict alist \
                [listval "actors" {actor validate} $alist]
        } else {
            dict set gdict alist [list]
        }

        # bygroups
        set bygroups [ebygroups validate $bygroups]
        dict set gdict bygroups $bygroups

        # hwhich
        if {$bygroups ne "IGNORE"} {
            dict set gdict hwhich [eanyall validate $hwhich]
        } else {
            dict set gdict hwhich "ALL"
        }

        # hlist
        if {$bygroups ne "IGNORE"} {
            dict set gdict hlist \
                [listval "groups" {group validate} $hlist]
        } else {
            dict set gdict hlist [list]
        }

        return $gdict
    }

    method narrative {gdict {opt ""}} {
        dict with gdict {}

        # base, glist
        if {$base eq "ALL"} {
            set result "all civilian groups"
        } else {
            set result [my nar_list group groups $glist -brief]
        }


        set clauses [list]

        # where, nlist
        if {$where ne "IGNORE"} {
            if {$where eq "IN"} {
                set clause "living in "
            } elseif {$where eq "NOTIN"} {
                set clause "not living in "
            } 

            append clause [my nar_list neighborhood neighborhoods $nlist -brief]

            lappend clauses $clause
        }

        # livingby

        if {$livingby eq "SA"} {
            lappend clauses "living by subsistence agriculture"
        } elseif {$livingby eq "CASH"} {
            lappend clauses "living by the cash economy"
        }

        # mood

        if {$mood eq "GOOD"} {
            lappend clauses "whose mood is satisfied or better"
        } elseif {$mood eq "AMBIVALENT"} {
            lappend clauses "whose mood is ambivalent"
        } elseif {$mood eq "BAD"} {
            lappend clauses "whose mood is dissatisfied or worse"
        }

        # byactors, awhich, alist
        if {$byactors ne "IGNORE"} {
            set adict [dict create anyall $awhich alist $alist]

            if {$byactors eq "SUPPORTING"} {
                set clause "supporting "
            } elseif {$byactors eq "LIKING"} {
                set clause "liking "
            } elseif {$byactors eq "DISLIKING"} {
                set clause "disliking "
            }

            append clause [gofer::anyall_alist narrative $adict -brief]
    
            lappend clauses $clause
        }

        # bygroups, hwhich, hlist
        if {$bygroups ne "IGNORE"} {
            set hdict [dict create anyall $hwhich glist $hlist]

            if {$bygroups eq "LIKING"} {
                set clause "liking "
            } elseif {$bygroups eq "DISLIKING"} {
                set clause "disliking "
            } elseif {$bygroups eq "LIKED_BY"} {
                set clause "liked by "
            } elseif {$bygroups eq "DISLIKED_BY"} {
                set clause "disliked by "
            }

            append clause [gofer::anyall_glist narrative $hdict -brief]
    
            lappend clauses $clause
        }

        if {[llength $clauses] > 0} {
            set result "Starting with $result, "
            append result "select those civilian groups "
            append result [join $clauses "; "]
        }

        return $result
    }

    method eval {gdict} {
        dict with gdict {}

        # base, glist
        if {$base eq "ALL"} {
            set result [my nonempty [civgroup names]]
        } else {
            set result [my nonempty $glist]
        }

        # where, nlist
        if {$where eq "IN"} {
            filterby result [groupsIn $nlist]
        } elseif {$where eq "NOTIN"} {
            filterby result [groupsNotIn $nlist]]
        } 

        # livingby

        if {$livingby eq "SA"} {
            filterby result [rdb eval {
                SELECT * FROM civgroups WHERE sa_flag
            }]
        } elseif {$livingby eq "CASH"} {
            filterby result [rdb eval {
                SELECT * FROM civgroups WHERE NOT sa_flag
            }]
        }

        # mood

        if {$mood eq "GOOD"} {
            filterby result [rdb eval {
                SELECT g FROM uram_mood
                WHERE mood >= 20.0
            }]
        } elseif {$mood eq "AMBIVALENT"} {
            filterby result [rdb eval {
                SELECT g FROM uram_mood
                WHERE mood > -20.0 AND mood < 20.0
            }]
        } elseif {$mood eq "BAD"} {
            filterby result [rdb eval {
                SELECT g FROM uram_mood
                WHERE mood <= -20.0
            }]
        }

        # byactors, awhich, alist
        set adict [dict create anyall $awhich alist $alist]
        switch -exact -- $byactors {
            IGNORE { 
                # Do nothing 
            }

            SUPPORTING {
                filterby result [anyall_alist supportingActor CIV $adict]
            }

            LIKING {
                filterby result [anyall_alist likingActor CIV $adict]

            }
            
            DISLIKING {
                filterby result [anyall_alist dislikingActor CIV $adict]
            }

            default { error "Unknown byactors value" }
        }

        # bygroups, hwhich, hlist
        set hdict [dict create anyall $hwhich glist $hlist]
        switch -exact -- $bygroups {
            IGNORE { 
                # Do nothing 
            }

            LIKING {
                filterby result [anyall_glist likingGroup CIV $hdict]

            }
            
            DISLIKING {
                filterby result [anyall_glist dislikingGroup CIV $hdict]
            }

            LIKED_BY {
                filterby result [anyall_glist likedbyGroup CIV $hdict]
            }

            DISLIKED_BY {
                filterby result [anyall_glist dislikedbyGroup CIV $hdict]
            }

            default { error "Unknown bygroups value" }
        }

        return $result
    }
}

# Rule: RESIDENT_IN
#
# Non-empty civilian groups resident in some set of neighborhoods.

::athena::goferx rule CIVGROUPS RESIDENT_IN {nlist} {
    method construct {nlist} {
        return [my validate [dict create nlist $nlist]]
    }

    method validate {gdict} {
        dict with gdict {}

        dict create nlist \
            [listval "neighborhoods" {nbhood validate} $nlist]
    }

    method narrative {gdict {opt ""}} {
        dict with gdict {}

        set text [my nar_list "" "these neighborhoods" $nlist $opt]

        return "non-empty civilian groups resident in $text"
    }

    method eval {gdict} {
        dict with gdict {}

        return [my nonempty [groupsIn $nlist]]
    }

}



# Rule: NOT_RESIDENT_IN
#
# Non-empty civilian groups not resident in any of some set of neighborhoods.

::athena::goferx rule CIVGROUPS NOT_RESIDENT_IN {nlist} {
    method construct {nlist} {
        return [my validate [dict create nlist $nlist]]
    }

    method validate {gdict} {
        dict with gdict {}

        dict create nlist \
            [listval "neighborhoods" {nbhood validate} $nlist]
    }

    method narrative {gdict {opt ""}} {
        dict with gdict {}

        set text [my nar_list "" "any of these neighborhoods" $nlist $opt]

        return "non-empty civilian groups not resident in $text"
    }

    method eval {gdict} {
        dict with gdict {}

        return [my nonempty [groupsNotIn $nlist]]
    }

}

# Rule: MOOD_IS_GOOD
#
# Civilian groups whose mood is Satisfied or Very Satisfied.

::athena::goferx rule CIVGROUPS MOOD_IS_GOOD {} {
    method validate {gdict} {
        return [dict create]
    }

    method construct {} {
        return [my validate {}]
    }

    method narrative {gdict {opt ""}} {
        return "civilian groups whose mood is good"
    }

    method eval {gdict} {
        return [my nonempty [rdb eval {
            SELECT g FROM uram_mood
            WHERE mood >= 20.0
        }]]
    }
}

# Rule: MOOD_IS_BAD
#
# Civilian groups whose mood is Dissatisfied or Very Dissatisfied.

::athena::goferx rule CIVGROUPS MOOD_IS_BAD {} {
    method validate {gdict} {
        return [dict create]
    }

    method construct {} {
        return [my validate {}]
    }

    method narrative {gdict {opt ""}} {
        return "civilian groups whose mood is bad"
    }

    method eval {gdict} {
        return [my nonempty [rdb eval {
            SELECT g FROM uram_mood
            WHERE mood <= -20.0
        }]]
    }
}

# Rule: MOOD_IS_AMBIVALENT
#
# Civilian groups whose mood is neither satisfied nor dissatisfied.

::athena::goferx rule CIVGROUPS MOOD_IS_AMBIVALENT {} {
    method validate {gdict} {
        return [dict create]
    }

    method construct {} {
        return [my validate {}]
    }

    method narrative {gdict {opt ""}} {
        return "civilian groups whose mood is ambivalent"
    }

    method eval {gdict} {
        return [my nonempty [rdb eval {
            SELECT g FROM uram_mood
            WHERE mood > -20.0 AND mood < 20.0
        }]]
    }
}

# Rule: SUPPORTING_ACTOR
#
# Civilian groups who have the desire and ability (i.e.,
# security) to contribute to the actor's support.

::athena::goferx rule CIVGROUPS SUPPORTING_ACTOR {anyall alist} {
    method construct {anyall alist} {
        return [my validate [dict create anyall $anyall alist $alist]]
    }

    method validate {gdict} { 
        return [anyall_alist validate $gdict] 
    }

    method narrative {gdict {opt ""}} {
        set result "civilian groups that actively support "
        append result [anyall_alist narrative $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        return [my nonempty [anyall_alist supportingActor CIV $gdict]]
    }
}

# Rule: LIKING_ACTOR
#
# Civilian groups who have a positive (LIKE or SUPPORT) vertical
# relationship with any or all of a set of actors.

::athena::goferx rule CIVGROUPS LIKING_ACTOR {anyall alist} {
    method construct {anyall alist} {
        return [my validate [dict create anyall $anyall alist $alist]]
    }

    method validate {gdict} { 
        return [anyall_alist validate $gdict] 
    }

    method narrative {gdict {opt ""}} {
        set result "civilian groups that like "
        append result [anyall_alist narrative $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        return [my nonempty [anyall_alist likingActor CIV $gdict]]
    }
}

# Rule: DISLIKING_ACTOR
#
# Civilian groups who have a negative (DISLIKE or OPPOSE) vertical
# relationship with any or all of a set of actors.

::athena::goferx rule CIVGROUPS DISLIKING_ACTOR {anyall alist} {
    method construct {anyall alist} {
        return [my validate [dict create anyall $anyall alist $alist]]
    }

    method validate {gdict} { 
        return [anyall_alist validate $gdict] 
    }

    method narrative {gdict {opt ""}} {
        set result "civilian groups that dislike "
        append result [anyall_alist narrative $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        return [my nonempty [anyall_alist dislikingActor CIV $gdict]]
    }
}

# Rule: LIKING_GROUP
#
# Civilian groups who have a positive (LIKE or SUPPORT) horizontal
# relationship with any or all of a set of groups.

::athena::goferx rule CIVGROUPS LIKING_GROUP {anyall glist} {
    method construct {anyall glist} {
        return [my validate [dict create anyall $anyall glist $glist]]
    }

    method validate {gdict} { 
        return [anyall_glist validate $gdict] 
    }

    method narrative {gdict {opt ""}} {
        set result "civilian groups that like "
        append result [anyall_glist narrative $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        return [my nonempty [anyall_glist likingGroup CIV $gdict]]
    }
}

# Rule: DISLIKING_GROUP
#
# Civilian groups who have a negative (DISLIKE or OPPOSE) horizontal
# relationship with any or all of a set of groups.

::athena::goferx rule CIVGROUPS DISLIKING_GROUP {anyall glist} {
    method construct {anyall glist} {
        return [my validate [dict create anyall $anyall glist $glist]]
    }

    method validate {gdict} { 
        return [anyall_glist validate $gdict] 
    }

    method narrative {gdict {opt ""}} {
        set result "civilian groups that dislike "
        append result [anyall_glist narrative $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        return [my nonempty [anyall_glist dislikingGroup CIV $gdict]]
    }
}

# Rule: LIKED_BY_GROUP
#
# Civilian groups for whom any or all of set of groups have a positive 
# (LIKE or SUPPORT) horizontal relationship.

::athena::goferx rule CIVGROUPS LIKED_BY_GROUP {anyall glist} {
    method construct {anyall glist} {
        return [my validate [dict create anyall $anyall glist $glist]]
    }

    method validate {gdict} { 
        return [anyall_glist validate $gdict] 
    }

    method narrative {gdict {opt ""}} {
        set result "civilian groups that are liked by "
        append result [anyall_glist narrative $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        return [my nonempty [anyall_glist likedByGroup CIV $gdict]]
    }
}

# Rule: DISLIKED_BY_GROUP
#
# Civilian groups for whom any or all of set of groups have a negative 
# (DISLIKE or OPPOSE) horizontal relationship.

::athena::goferx rule CIVGROUPS DISLIKED_BY_GROUP {anyall glist} {
    method construct {anyall glist} {
        return [my validate [dict create anyall $anyall glist $glist]]
    }

    method validate {gdict} { 
        return [anyall_glist validate $gdict] 
    }

    method narrative {gdict {opt ""}} {
        set result "civilian groups that are disliked by "
        append result [anyall_glist narrative $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        return [my nonempty [anyall_glist dislikedByGroup CIV $gdict]]
    }
}


