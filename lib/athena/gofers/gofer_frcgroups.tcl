#-----------------------------------------------------------------------
# TITLE:
#    gofer_frcgroups.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Force groups gofer -- A list of force groups produced 
#    according to various rules
#-----------------------------------------------------------------------

::athena::goferx define FRCGROUPS group {
    rc "" -width 3in -span 3
    label {
        Enter a rule for selecting a set of force groups:
    }
    rc

    rc
    selector _rule {
        case BY_VALUE "By name" {
            rc "Select groups from the following list:"
            rc
            enumlonglist raw_value -dictcmd {$adb_ frcgroup namedict} \
                -width 30 -height 10 
        }

        case OWNED_BY "Owned by Actor(s)" {
            rc "Select groups that are owned by any of the following actors:"

            rc
            enumlonglist alist -dictcmd {$adb_ actor namedict} \
                -width 30 -height 10
        }

        case DEPLOYED_TO "Deployed to Neighborhood(s)" {
            rc "Select groups that are deployed to "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following neighborhoods:"

            rc
            enumlonglist nlist -dictcmd {$adb_ nbhood namedict} \
                -width 30 -height 10
        }

        case NOT_DEPLOYED_TO "Not Deployed to Neighborhood(s)" {
            rc "Select groups that are not deployed to "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following neighborhoods:"

            rc
            enumlonglist nlist -dictcmd {$adb_ nbhood namedict} \
                -width 30 -height 10
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

#-----------------------------------------------------------------------
# Gofer Rules

# Rule: BY_VALUE
#
# Some set of force groups chosen by the user.

::athena::goferx rule FRCGROUPS BY_VALUE {raw_value} {
    method make {raw_value} {
        return [my validate [dict create raw_value $raw_value]]
    }

    method validate {gdict} {
        dict with gdict {}

        dict create raw_value \
            [my val_elist frcgroup "groups" $raw_value]
    }

    method narrative {gdict {opt ""}} {
        dict with gdict {}

        return [my nar_list "group" "these groups" $raw_value $opt]
    }

    method eval {gdict} {
        dict with gdict {}

        return $raw_value
    }
}

# Rule: OWNED_BY
#
# Force groups owned by actors.
# TBD: If we add a gofer::ORGGROUPS type, this should become a helper
# with a group type.

::athena::goferx rule FRCGROUPS OWNED_BY {alist} {
    method make {alist} {
        return [my validate [dict create alist $alist]]
    }

    method validate {gdict} {
        dict with gdict {}

        dict create alist \
            [my val_elist actor "actors" $alist]
    }

    method narrative {gdict {opt ""}} {
        dict with gdict {}

        set text [my nar_list "actor" "these actors" $alist $opt]

        return "force groups owned by $text"
    }

    method eval {gdict} {
        dict with gdict {}

        return [$adb eval "
            SELECT g FROM frcgroups_view
            WHERE a IN ('[join $alist {','}]')
        "]
    }

}

# Rule: DEPLOYED_TO
#
# Force groups who are deployed in any or all of a set of nbhoods.

::athena::goferx rule FRCGROUPS DEPLOYED_TO {anyall nlist} {
    method make {anyall nlist} {
        return [my validate [dict create anyall $anyall nlist $nlist]]
    }

    method validate {gdict} {
        return [my val_anyall_nlist $gdict]
    }

    method narrative {gdict {opt ""}} {
        set result "force groups that are deployed to "
        append result [my nar_anyall_nlist $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        return [my anyall_nlist_deployedTo $gdict]
    }
}

# Rule: NOT_DEPLOYED_TO
#
# Force groups who are not deployed in any or all of a set of nbhoods.

::athena::goferx rule FRCGROUPS NOT_DEPLOYED_TO {anyall nlist} {
    method make {anyall nlist} {
        return [my validate [dict create anyall $anyall nlist $nlist]]
    }

    method validate {gdict} {
        return [my val_anyall_nlist $gdict]
    }

    method narrative {gdict {opt ""}} {
        set result "force groups that are not deployed to "
        append result [my nar_anyall_nlist $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        return [my anyall_nlist_notDeployedTo $gdict]
    }
}


# Rule: SUPPORTING_ACTOR
#
# Force groups who have the desire and ability (i.e.,
# security) to contribute to the actor's support.

::athena::goferx rule FRCGROUPS SUPPORTING_ACTOR {anyall alist} {
    method make {anyall alist} {
        return [my validate [dict create anyall $anyall alist $alist]]
    }

    method validate {gdict} {
        return [my val_anyall_alist $gdict]
    }

    method narrative {gdict {opt ""}} {
        set result "force groups that actively support "
        append result [my nar_anyall_alist $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        return [my anyall_alist_supportingActor FRC $gdict]
    }
}

# Rule: LIKING_ACTOR
#
# Force groups who have a positive (LIKE or SUPPORT) vertical
# relationship with any or all of a set of actors.

::athena::goferx rule FRCGROUPS LIKING_ACTOR {anyall alist} {
    method make {anyall alist} {
        return [my validate [dict create anyall $anyall alist $alist]]
    }

    method validate {gdict} {
        return [my val_anyall_alist $gdict]
    }

    method narrative {gdict {opt ""}} {
        set result "force groups that like "
        append result [my nar_anyall_alist $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        return [my anyall_alist_likingActor FRC $gdict]
    }
}

# Rule: DISLIKING_ACTOR
#
# Force groups who have a negative (DISLIKE or OPPOSE) vertical
# relationship with any or all of a set of actors.

::athena::goferx rule FRCGROUPS DISLIKING_ACTOR {anyall alist} {
    method make {anyall alist} {
        return [my validate [dict create anyall $anyall alist $alist]]
    }

    method validate {gdict} {
        return [my val_anyall_alist $gdict]
    }

    method narrative {gdict {opt ""}} {
        set result "force groups that dislike "
        append result [my nar_anyall_alist $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        return [my anyall_alist_dislikingActor FRC $gdict]
    }
}

# Rule: LIKING_GROUP
#
# Force groups who have a positive (LIKE or SUPPORT) horizontal
# relationship with any or all of a set of groups.

::athena::goferx rule FRCGROUPS LIKING_GROUP {anyall glist} {
    method make {anyall glist} {
        return [my validate [dict create anyall $anyall glist $glist]]
    }

    method validate {gdict} { 
        return [my val_anyall_glist $gdict] 
    }

    method narrative {gdict {opt ""}} {
        set result "force groups that like "
        append result [my nar_anyall_glist $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        return [my anyall_glist_likingGroup FRC $gdict]
    }
}

# Rule: DISLIKING_GROUP
#
# Force groups who have a negative (DISLIKE or OPPOSE) horizontal
# relationship with any or all of a set of groups.

::athena::goferx rule FRCGROUPS DISLIKING_GROUP {anyall glist} {
    method make {anyall glist} {
        return [my validate [dict create anyall $anyall glist $glist]]
    }

    method validate {gdict} { 
        return [my val_anyall_glist $gdict] 
    }

    method narrative {gdict {opt ""}} {
        set result "force groups that dislike "
        append result [my nar_anyall_glist $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        return [my anyall_glist_dislikingGroup FRC $gdict]
    }
}

# Rule: LIKED_BY_GROUP
#
# Force groups for whom any or all of set of groups have a positive 
# (LIKE or SUPPORT) horizontal relationship.

::athena::goferx rule FRCGROUPS LIKED_BY_GROUP {anyall glist} {
    method make {anyall glist} {
        return [my validate [dict create anyall $anyall glist $glist]]
    }

    method validate {gdict} { 
        return [my val_anyall_glist $gdict] 
    }

    method narrative {gdict {opt ""}} {
        set result "force groups that are liked by "
        append result [my nar_anyall_glist $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        return [my anyall_glist_likedByGroup FRC $gdict]
    }
}

# Rule: DISLIKED_BY_GROUP
#
# Force groups for whom any or all of set of groups have a negative 
# (DISLIKE or OPPOSE) horizontal relationship.

::athena::goferx rule FRCGROUPS DISLIKED_BY_GROUP {anyall glist} {
    method make {anyall glist} {
        return [my validate [dict create anyall $anyall glist $glist]]
    }

    method validate {gdict} { 
        return [my val_anyall_glist $gdict] 
    }

    method narrative {gdict {opt ""}} {
        set result "force groups that are disliked by "
        append result [my nar_anyall_glist $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        return [my anyall_glist_dislikedByGroup FRC $gdict]
    }
}
