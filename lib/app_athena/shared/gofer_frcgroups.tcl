#-----------------------------------------------------------------------
# TITLE:
#    gofer_frcgroups.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Force groups gofer
#    
#    gofer_frcgroups: A list of force groups produced according to 
#    various rules

#-----------------------------------------------------------------------
# gofer::FRCGROUPS

gofer define FRCGROUPS group {
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
            enumlonglist raw_value -dictcmd {::frcgroup namedict} \
                -width 30 -height 10 
        }

        case OWNED_BY "Owned by Actor(s)" {
            rc "Select groups that are owned by any of the following actors:"

            rc
            enumlonglist alist -dictcmd {::actor namedict} \
                -width 30 -height 10
        }

        case DEPLOYED_TO "Deployed to Neighborhood(s)" {
            rc "Select groups that are deployed to "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following neighborhoods:"

            rc
            enumlonglist nlist -dictcmd {::nbhood namedict} \
                -width 30 -height 10
        }

        case NOT_DEPLOYED_TO "Not Deployed to Neighborhood(s)" {
            rc "Select groups that are not deployed to "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following neighborhoods:"

            rc
            enumlonglist nlist -dictcmd {::nbhood namedict} \
                -width 30 -height 10
        }

        case SUPPORTING_ACTOR "Supporting Actor(s)" {
            rc "Select groups that actively support "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following actors:"

            rc
            enumlonglist alist -dictcmd {::actor namedict} \
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
            enumlonglist alist -dictcmd {::actor namedict} \
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
            enumlonglist alist -dictcmd {::actor namedict} \
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
            enumlonglist glist -dictcmd {::group namedict} \
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
            enumlonglist glist -dictcmd {::group namedict} \
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
            enumlonglist glist -dictcmd {::group namedict} \
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
            enumlonglist glist -dictcmd {::group namedict} \
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
# Helper Commands

# TBD

#-----------------------------------------------------------------------
# Gofer Rules

# Rule: BY_VALUE
#
# Some set of force groups chosen by the user.

gofer rule FRCGROUPS BY_VALUE {raw_value} {
    typemethod construct {raw_value} {
        return [$type validate [dict create raw_value $raw_value]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create raw_value \
            [listval "groups" {frcgroup validate} $raw_value]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [listnar "group" "these groups" $raw_value $opt]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        return $raw_value
    }
}

# Rule: OWNED_BY
#
# Force groups owned by actors.
# TBD: If we add a gofer::ORGGROUPS type, this should become a helper
# with a group type.

gofer rule FRCGROUPS OWNED_BY {alist} {
    typemethod construct {alist} {
        return [$type validate [dict create alist $alist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create alist \
            [listval "actors" {actor validate} $alist]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        set text [listnar "actor" "these actors" $alist $opt]

        return "force groups owned by $text"
    }

    typemethod eval {gdict} {
        dict with gdict {}

        return [rdb eval "
            SELECT g FROM frcgroups_view
            WHERE a IN ('[join $alist {','}]')
        "]
    }

}

# Rule: DEPLOYED_TO
#
# Force groups who are deployed in any or all of a set of nbhoods.

gofer rule FRCGROUPS DEPLOYED_TO {anyall nlist} {
    typemethod construct {anyall nlist} {
        return [$type validate [dict create anyall $anyall nlist $nlist]]
    }

    typemethod validate {gdict} {
        return [anyall_nlist validate $gdict]
    }

    typemethod narrative {gdict {opt ""}} {
        set result "force groups that are deployed to "
        append result [::gofer::anyall_nlist narrative $gdict $opt]
        return "$result"
    }

    typemethod eval {gdict} {
        return [anyall_nlist deployedTo $gdict]
    }
}

# Rule: NOT_DEPLOYED_TO
#
# Force groups who are not deployed in any or all of a set of nbhoods.

gofer rule FRCGROUPS NOT_DEPLOYED_TO {anyall nlist} {
    typemethod construct {anyall nlist} {
        return [$type validate [dict create anyall $anyall nlist $nlist]]
    }

    typemethod validate {gdict} {
        return [anyall_nlist validate $gdict]
    }

    typemethod narrative {gdict {opt ""}} {
        set result "force groups that are not deployed to "
        append result [::gofer::anyall_nlist narrative $gdict $opt]
        return "$result"
    }

    typemethod eval {gdict} {
        return [anyall_nlist notDeployedTo $gdict]
    }
}


# Rule: SUPPORTING_ACTOR
#
# Force groups who have the desire and ability (i.e.,
# security) to contribute to the actor's support.

gofer rule FRCGROUPS SUPPORTING_ACTOR {anyall alist} {
    typemethod construct {anyall alist} {
        return [$type validate [dict create anyall $anyall alist $alist]]
    }

    typemethod validate {gdict} {
        return [anyall_alist validate $gdict]
    }

    typemethod narrative {gdict {opt ""}} {
        set result "force groups that actively support "
        append result [::gofer::anyall_alist narrative $gdict $opt]
        return "$result"
    }

    typemethod eval {gdict} {
        return [anyall_alist supportingActor FRC $gdict]
    }
}

# Rule: LIKING_ACTOR
#
# Force groups who have a positive (LIKE or SUPPORT) vertical
# relationship with any or all of a set of actors.

gofer rule FRCGROUPS LIKING_ACTOR {anyall alist} {
    typemethod construct {anyall alist} {
        return [$type validate [dict create anyall $anyall alist $alist]]
    }

    typemethod validate {gdict} {
        return [anyall_alist validate $gdict]
    }

    typemethod narrative {gdict {opt ""}} {
        set result "force groups that like "
        append result [::gofer::anyall_alist narrative $gdict $opt]
        return "$result"
    }

    typemethod eval {gdict} {
        return [anyall_alist likingActor FRC $gdict]
    }
}

# Rule: DISLIKING_ACTOR
#
# Force groups who have a negative (DISLIKE or OPPOSE) vertical
# relationship with any or all of a set of actors.

gofer rule FRCGROUPS DISLIKING_ACTOR {anyall alist} {
    typemethod construct {anyall alist} {
        return [$type validate [dict create anyall $anyall alist $alist]]
    }

    typemethod validate {gdict} {
        return [anyall_alist validate $gdict]
    }

    typemethod narrative {gdict {opt ""}} {
        set result "force groups that dislike "
        append result [::gofer::anyall_alist narrative $gdict $opt]
        return "$result"
    }

    typemethod eval {gdict} {
        return [anyall_alist dislikingActor FRC $gdict]
    }
}

# Rule: LIKING_GROUP
#
# Force groups who have a positive (LIKE or SUPPORT) horizontal
# relationship with any or all of a set of groups.

gofer rule FRCGROUPS LIKING_GROUP {anyall glist} {
    typemethod construct {anyall glist} {
        return [$type validate [dict create anyall $anyall glist $glist]]
    }

    typemethod validate {gdict} { 
        return [anyall_glist validate $gdict] 
    }

    typemethod narrative {gdict {opt ""}} {
        set result "force groups that like "
        append result [anyall_glist narrative $gdict $opt]
        return "$result"
    }

    typemethod eval {gdict} {
        return [anyall_glist likingGroup FRC $gdict]
    }
}

# Rule: DISLIKING_GROUP
#
# Force groups who have a negative (DISLIKE or OPPOSE) horizontal
# relationship with any or all of a set of groups.

gofer rule FRCGROUPS DISLIKING_GROUP {anyall glist} {
    typemethod construct {anyall glist} {
        return [$type validate [dict create anyall $anyall glist $glist]]
    }

    typemethod validate {gdict} { 
        return [anyall_glist validate $gdict] 
    }

    typemethod narrative {gdict {opt ""}} {
        set result "force groups that dislike "
        append result [anyall_glist narrative $gdict $opt]
        return "$result"
    }

    typemethod eval {gdict} {
        return [anyall_glist dislikingGroup FRC $gdict]
    }
}

# Rule: LIKED_BY_GROUP
#
# Force groups for whom any or all of set of groups have a positive 
# (LIKE or SUPPORT) horizontal relationship.

gofer rule FRCGROUPS LIKED_BY_GROUP {anyall glist} {
    typemethod construct {anyall glist} {
        return [$type validate [dict create anyall $anyall glist $glist]]
    }

    typemethod validate {gdict} { 
        return [anyall_glist validate $gdict] 
    }

    typemethod narrative {gdict {opt ""}} {
        set result "force groups that are liked by "
        append result [anyall_glist narrative $gdict $opt]
        return "$result"
    }

    typemethod eval {gdict} {
        return [anyall_glist likedByGroup FRC $gdict]
    }
}

# Rule: DISLIKED_BY_GROUP
#
# Force groups for whom any or all of set of groups have a negative 
# (DISLIKE or OPPOSE) horizontal relationship.

gofer rule FRCGROUPS DISLIKED_BY_GROUP {anyall glist} {
    typemethod construct {anyall glist} {
        return [$type validate [dict create anyall $anyall glist $glist]]
    }

    typemethod validate {gdict} { 
        return [anyall_glist validate $gdict] 
    }

    typemethod narrative {gdict {opt ""}} {
        set result "force groups that are disliked by "
        append result [anyall_glist narrative $gdict $opt]
        return "$result"
    }

    typemethod eval {gdict} {
        return [anyall_glist dislikedByGroup FRC $gdict]
    }
}
