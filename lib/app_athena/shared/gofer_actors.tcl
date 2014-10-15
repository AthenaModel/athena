#-----------------------------------------------------------------------
# TITLE:
#    gofer_actors.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Actors gofer
#    
#    gofer_actors: A list of actors produced according to 
#    various rules

#-----------------------------------------------------------------------
# gofer::ACTORS

gofer define ACTORS actor {
    rc "" -width 3in -span 3
    label {
        Enter a rule for selecting a set of actors.
    }
    rc

    rc
    selector _rule {
        case BY_VALUE "By name" {
            rc "Select actors from the following list:"
            rc
            enumlonglist raw_value -dictcmd {::actor namedict} \
                -width 30 -height 10 
        }

        case CONTROLLING "Controlling Neighborhood(s)" {
            rc {
                Select actors that are in control of the following 
                neighborhoods:
            }

            rc
            enumlonglist nlist -dictcmd {::nbhood namedict} \
                -width 30 -height 10
        }

        case INFLUENCE_IN "With Influence in Neighborhood(s)" {
            rc "Select actors that have influence in "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following neighborhoods:"

            rc
            enumlonglist nlist -dictcmd {::nbhood namedict} \
                -width 30 -height 10
        }

        case OWNING "Owning Group(s)" {
            rc {
                Select actors who own any of the following groups:
            }

            rc
            enumlonglist glist -dictcmd {::ptype fog namedict} \
                -width 30 -height 10 
        }

        case SUPPORTED_BY "Supported by Group(s)" {
            rc "Select actors that are actively supported by "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following groups:"
            rc
            enumlonglist glist -dictcmd {::group namedict} \
                -width 30 -height 10 

            rc {
                A group supports an actor if it contributes to the actor's 
                influence in some neighborhood.
            }
        }

        case LIKED_BY_GROUP "Liked by Group(s)" {
            rc "Select actors that are liked by "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following groups:"
            rc
            enumlonglist glist -dictcmd {::group namedict} \
                -width 30 -height 10 

            rc {
                An actor is liked by a group if the group's vertical 
                relationship  with the actor is LIKE or SUPPORT (i.e., the 
                relationship is greater than or equal to 0.2).
            }
        }

        case DISLIKED_BY_GROUP "Disiked by Group(s)" {
            rc "Select actors that are disliked by "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following groups:"
            rc
            enumlonglist glist -dictcmd {::group namedict} \
                -width 30 -height 10 

            rc {
                An actor is disliked by a group if the group's vertical 
                relationship  with the actor is DISLIKE or OPPOSE (i.e., the 
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
# Some set of actors chosen by the user.

gofer rule ACTORS BY_VALUE {raw_value} {
    typemethod construct {raw_value} {
        return [$type validate [dict create raw_value $raw_value]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create raw_value \
            [listval "actors" {actor validate} $raw_value]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [listnar "actor" "these actors" $raw_value $opt]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        return $raw_value
    }
}

# Rule: CONTROLLING
#
# Actors who are in control of any of a set of nbhoods.

gofer rule ACTORS CONTROLLING {nlist} {
    typemethod construct {nlist} {
        return [$type validate [dict create nlist $nlist]]
    }

    typemethod validate {gdict} {
        set nlist  [dict get $gdict nlist]
        dict create nlist [listval "neighborhoods" {nbhood validate} $nlist]
    }

    typemethod narrative {gdict {opt ""}} {
        set nlist  [dict get $gdict nlist]
        set text [listnar "" "these neighborhoods" $nlist $opt]
        set result "actors who are in control of $text"
    }

    typemethod eval {gdict} {
        # Get keys
        set nlist  [dict get $gdict nlist]

        return [rdb eval "
            SELECT DISTINCT controller
            FROM control_n
            WHERE n in ('[join $nlist {','}]')
            ORDER BY controller
        "]
    }
}

# Rule: INFLUENCE_IN
#
# Actors who have influence in any or all of a set of nbhoods.

gofer rule ACTORS INFLUENCE_IN {anyall nlist} {
    typemethod construct {anyall nlist} {
        return [$type validate [dict create anyall $anyall nlist $nlist]]
    }

    typemethod validate {gdict} {
        return [anyall_nlist validate $gdict]
    }

    typemethod narrative {gdict {opt ""}} {
        set result "actors who have influence in "
        append result [::gofer::anyall_nlist narrative $gdict $opt]
        return "$result"
    }

    typemethod eval {gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set nlist  [dict get $gdict nlist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $nlist]
        }

        return [rdb eval "
            SELECT a FROM (
                SELECT a, count(n) AS num
                FROM influence_na
                WHERE influence > 0
                AND n in ('[join $nlist {','}]')
                GROUP BY a 
            ) WHERE num >= \$num 
        "]
    }
}

# Rule: OWNING
#
# Actors who own any of a list of groups.

gofer rule ACTORS OWNING {glist} {
    typemethod construct {glist} {
        return [$type validate [dict create glist $glist]]
    }

    typemethod validate {gdict} { 
        set glist [dict get $gdict glist]

        dict create glist [listval "groups" {ptype fog validate} $glist]
    }

    typemethod narrative {gdict {opt ""}} {
        set glist [dict get $gdict glist]

        set text [listnar "group" "these groups" $glist $opt]

        return "actors who own $text"
    }

    typemethod eval {gdict} {
        set glist [dict get $gdict glist]

        return [rdb eval "
            SELECT DISTINCT a FROM (
                SELECT a FROM groups
                WHERE g IN ('[join $glist {','}]')
            )
        "]
    }
}


# Rule: SUPPORTED_BY
#
# Actors who are actively supported by any or all of a list of groups.

gofer rule ACTORS SUPPORTED_BY {anyall glist} {
    typemethod construct {anyall glist} {
        return [$type validate [dict create anyall $anyall glist $glist]]
    }

    typemethod validate {gdict} { 
        return [anyall_glist validate $gdict] 
    }

    typemethod narrative {gdict {opt ""}} {
        set result "actors who are actively supported by "
        append result [anyall_glist narrative $gdict $opt]
        return "$result"
    }

    typemethod eval {gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set glist  [dict get $gdict glist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $glist]
        }

        return [rdb eval "
            SELECT a FROM (
                SELECT a, count(support) AS num
                FROM support_nga
                WHERE g IN ('[join $glist {','}]') 
                AND support > 0
                GROUP BY a 
            ) WHERE num >= \$num 
        "]
    }
}

# Rule: LIKED_BY_GROUP
#
# Actors who are liked by any or all of a list of groups.

gofer rule ACTORS LIKED_BY_GROUP {anyall glist} {
    typemethod construct {anyall glist} {
        return [$type validate [dict create anyall $anyall glist $glist]]
    }

    typemethod validate {gdict} { 
        return [anyall_glist validate $gdict] 
    }

    typemethod narrative {gdict {opt ""}} {
        set result "actors who are liked by "
        append result [anyall_glist narrative $gdict $opt]
        return "$result"
    }

    typemethod eval {gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set glist  [dict get $gdict glist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $glist]
        }

        return [rdb eval "
            SELECT a FROM (
                SELECT a, count(vrel) AS num
                FROM uram_vrel
                WHERE g IN ('[join $glist {','}]') 
                AND vrel >= 0.2
                GROUP BY a 
            ) WHERE num >= \$num 
        "]
    }
}

# Rule: DISLIKED_BY_GROUP
#
# Actors who are disliked by any or all of a list of groups.

gofer rule ACTORS DISLIKED_BY_GROUP {anyall glist} {
    typemethod construct {anyall glist} {
        return [$type validate [dict create anyall $anyall glist $glist]]
    }

    typemethod validate {gdict} { 
        return [anyall_glist validate $gdict] 
    }

    typemethod narrative {gdict {opt ""}} {
        set result "actors who are disliked by "
        append result [anyall_glist narrative $gdict $opt]
        return "$result"
    }

    typemethod eval {gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set glist  [dict get $gdict glist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $glist]
        }

        return [rdb eval "
            SELECT a FROM (
                SELECT a, count(vrel) AS num
                FROM uram_vrel
                WHERE g IN ('[join $glist {','}]') 
                AND vrel <= -0.2
                GROUP BY a 
            ) WHERE num >= \$num 
        "]
    }
}

