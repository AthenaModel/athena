#-----------------------------------------------------------------------
# TITLE:
#    gofer_actors.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): ACTORS gofer - A list of actors produced according to 
#    various rules
#
# TBD: Global refs: ptype
#
#-----------------------------------------------------------------------


::athena::goferx define ACTORS actor {
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
            enumlonglist raw_value -dictcmd {$adb_ actor namedict} \
                -width 30 -height 10 
        }

        case CONTROLLING "Controlling Neighborhood(s)" {
            rc {
                Select actors that are in control of the following 
                neighborhoods:
            }

            rc
            enumlonglist nlist -dictcmd {$adb_ nbhood namedict} \
                -width 30 -height 10
        }

        case INFLUENCE_IN "With Influence in Neighborhood(s)" {
            rc "Select actors that have influence in "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following neighborhoods:"

            rc
            enumlonglist nlist -dictcmd {$adb_ nbhood namedict} \
                -width 30 -height 10
        }

        case OWNING "Owning Group(s)" {
            rc {
                Select actors who own any of the following groups:
            }

            rc
            enumlonglist glist -dictcmd {$adb_ ptype fog namedict} \
                -width 30 -height 10 
        }

        case SUPPORTED_BY "Supported by Group(s)" {
            rc "Select actors that are actively supported by "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following groups:"
            rc
            enumlonglist glist -dictcmd {$adb_ group namedict} \
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
            enumlonglist glist -dictcmd {$adb_ group namedict} \
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
            enumlonglist glist -dictcmd {$adb_ group namedict} \
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
# Gofer Rules

# Rule: BY_VALUE
#
# Some set of actors chosen by the user.

::athena::goferx rule ACTORS BY_VALUE {raw_value} {
    method make {raw_value} {
        return [my validate [dict create raw_value $raw_value]]
    }

    method validate {gdict} {
        dict with gdict {}

        dict create raw_value \
            [my val_elist actor "actors" $raw_value]
    }

    method narrative {gdict {opt ""}} {
        dict with gdict {}

        return [my nar_list "actor" "these actors" $raw_value $opt]
    }

    method eval {gdict} {
        dict with gdict {}

        return $raw_value
    }
}

# Rule: CONTROLLING
#
# Actors who are in control of any of a set of nbhoods.

::athena::goferx rule ACTORS CONTROLLING {nlist} {
    method make {nlist} {
        return [my validate [dict create nlist $nlist]]
    }

    method validate {gdict} {
        set nlist  [dict get $gdict nlist]
        dict create nlist [my val_elist nbhood "neighborhoods" $nlist]
    }

    method narrative {gdict {opt ""}} {
        set nlist  [dict get $gdict nlist]
        set text [my nar_list "" "these neighborhoods" $nlist $opt]
        set result "actors who are in control of $text"
    }

    method eval {gdict} {
        # Get keys
        set nlist  [dict get $gdict nlist]

        return [$adb eval "
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

::athena::goferx rule ACTORS INFLUENCE_IN {anyall nlist} {
    method make {anyall nlist} {
        return [my validate [dict create anyall $anyall nlist $nlist]]
    }

    method validate {gdict} {
        return [my val_anyall_nlist $gdict]
    }

    method narrative {gdict {opt ""}} {
        set result "actors who have influence in "
        append result [my nar_anyall_nlist $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set nlist  [dict get $gdict nlist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $nlist]
        }

        return [$adb eval "
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

::athena::goferx rule ACTORS OWNING {glist} {
    method make {glist} {
        return [my validate [dict create glist $glist]]
    }

    method validate {gdict} { 
        set glist [dict get $gdict glist]

        dict create glist [my val_list "groups" [list $adb ptype fog validate] $glist]
    }

    method narrative {gdict {opt ""}} {
        set glist [dict get $gdict glist]

        set text [my nar_list "group" "these groups" $glist $opt]

        return "actors who own $text"
    }

    method eval {gdict} {
        set glist [dict get $gdict glist]

        return [$adb eval "
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

::athena::goferx rule ACTORS SUPPORTED_BY {anyall glist} {
    method make {anyall glist} {
        return [my validate [dict create anyall $anyall glist $glist]]
    }

    method validate {gdict} { 
        return [my val_anyall_glist $gdict] 
    }

    method narrative {gdict {opt ""}} {
        set result "actors who are actively supported by "
        append result [my nar_anyall_glist $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set glist  [dict get $gdict glist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $glist]
        }

        return [$adb eval "
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

::athena::goferx rule ACTORS LIKED_BY_GROUP {anyall glist} {
    method make {anyall glist} {
        return [my validate [dict create anyall $anyall glist $glist]]
    }

    method validate {gdict} { 
        return [my val_anyall_glist $gdict] 
    }

    method narrative {gdict {opt ""}} {
        set result "actors who are liked by "
        append result [my nar_anyall_glist $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set glist  [dict get $gdict glist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $glist]
        }

        return [$adb eval "
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

::athena::goferx rule ACTORS DISLIKED_BY_GROUP {anyall glist} {
    method make {anyall glist} {
        return [my validate [dict create anyall $anyall glist $glist]]
    }

    method validate {gdict} { 
        return [my val_anyall_glist $gdict] 
    }

    method narrative {gdict {opt ""}} {
        set result "actors who are disliked by "
        append result [my nar_anyall_glist $gdict $opt]
        return "$result"
    }

    method eval {gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set glist  [dict get $gdict glist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $glist]
        }

        return [$adb eval "
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

