#-----------------------------------------------------------------------
# TITLE:
#    gofer_nbhoods.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Neighborhoods gofer
#    
#    gofer_nbhoods: A list of neighborhoods produced according to 
#    various rules

#-----------------------------------------------------------------------
# gofer::NBHOODS

::athena::goferx define NBHOODS nbhood {
    rc "" -width 3in -span 3
    label {
        Enter a rule for selecting a set of neighborhoods.
    }
    rc

    rc
    selector _rule {
        case BY_VALUE "By name" {
            rc "Select neighborhoods from the following list:"
            rc
            enumlonglist nlist -dictcmd {::nbhood namedict} \
                -width 30 -height 10 
        }

        case CONTROLLED_BY "Controlled by Actor(s)" {
            rc {
                Select neighborhoods that are controlled by any of
                the following actors:
            }

            rc
            enumlonglist alist -dictcmd {::actor namedict} \
                -width 30 -height 10
        }

        case NOT_CONTROLLED_BY "Not Controlled by Actor(s)" {
            rc {
                Select neighborhoods that are not controlled by any of
                the following actors:
            }

            rc
            enumlonglist alist -dictcmd {::actor namedict} \
                -width 30 -height 10
        }

        case WITH_DEPLOYMENT "With Deployment of Group(s)" {
            rc "Select neighborhoods in which "
            enumlong anyall -defvalue ANY -dictcmd {::eanyall deflist}
            label " the following force groups are deployed:"

            rc
            enumlonglist glist -dictcmd {::frcgroup namedict} \
                -width 30 -height 10
        }

        case WITHOUT_DEPLOYMENT "Without Deployment of Group(s)" {
            rc {
                Select neighborhoods in which none of the following
                groups are deployed:
            }

            rc
            enumlonglist glist -dictcmd {::frcgroup namedict} \
                -width 30 -height 10
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
# Some set of nbhoods chosen by the user.

::athena::goferx rule NBHOODS BY_VALUE {nlist} {
    typemethod construct {nlist} {
        return [$type validate [dict create nlist $nlist]]
    }

    typemethod validate {gdict} {
        dict with gdict {}

        dict create nlist \
            [listval "neighborhoods" {nbhood validate} $nlist]
    }

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        return [listnar "neighborhood" "these neighborhoods" $nlist $opt]
    }

    typemethod eval {gdict} {
        dict with gdict {}

        return $nlist
    }
}

# Rule: CONTROLLED_BY
#
# Nbhoods that are controlled by any of a set of actors.

::athena::goferx rule NBHOODS CONTROLLED_BY {alist} {
    typemethod construct {alist} {
        return [$type validate [dict create alist $alist]]
    }

    typemethod validate {gdict} {
        set alist  [dict get $gdict alist]
        dict create alist [listval "actors" {actor validate} $alist]
    }

    typemethod narrative {gdict {opt ""}} {
        set alist  [dict get $gdict alist]
        set text [listnar "actor" "any of these actors" $alist $opt]
        set result "neighborhoods controlled by $text"
    }

    typemethod eval {gdict} {
        # Get keys
        set alist  [dict get $gdict alist]

        # TBD: [nbhood controlled_by $alist]?
        return [rdb eval "
            SELECT DISTINCT n
            FROM control_n
            WHERE controller IN ('[join $alist {','}]')
            ORDER BY n
        "]
    }
}

# Rule: NOT_CONTROLLED_BY
#
# Nbhoods that are not controlled by any of a set of actors.

::athena::goferx rule NBHOODS NOT_CONTROLLED_BY {alist} {
    typemethod construct {alist} {
        return [$type validate [dict create alist $alist]]
    }

    typemethod validate {gdict} {
        set alist  [dict get $gdict alist]
        dict create alist [listval "actors" {actor validate} $alist]
    }

    typemethod narrative {gdict {opt ""}} {
        set alist  [dict get $gdict alist]
        set text [listnar "actor" "any of these actors" $alist $opt]
        set result "neighborhoods not controlled by $text"
    }

    typemethod eval {gdict} {
        # Get keys
        set alist  [dict get $gdict alist]

        return [rdb eval "
            SELECT DISTINCT n
            FROM control_n
            WHERE controller NOT IN ('[join $alist {','}]')
            ORDER BY n
        "]
    }
}



# Rule: WITH_DEPLOYMENT
#
# Nbhoods in which any or all of a set of force groups are deployed.

::athena::goferx rule NBHOODS WITH_DEPLOYMENT {anyall glist} {
    typemethod construct {anyall glist} {
        return [$type validate [dict create anyall $anyall glist $glist]]
    }

    typemethod validate {gdict} { 
        return [anyall_glist validate $gdict frcgroup] 
    }

    typemethod narrative {gdict {opt ""}} {
        set result "neighborhoods with deployments of "
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
            SELECT n FROM (
                SELECT n, count(g) AS num
                FROM deploy_ng
                WHERE g IN ('[join $glist {','}]')
                AND personnel > 0
                GROUP BY n
            ) WHERE num >= \$num
        "]
    }
}

# Rule: WITHOUT_DEPLOYMENT
#
# Nbhoods in which none of a set of force groups are deployed.

::athena::goferx rule NBHOODS WITHOUT_DEPLOYMENT {glist} {
    typemethod construct {glist} {
        return [$type validate [dict create glist $glist]]
    }

    typemethod validate {gdict} { 
        set glist  [dict get $gdict glist]
        dict create glist [listval "groups" {frcgroup validate} $glist]
    }

    typemethod narrative {gdict {opt ""}} {
        set glist  [dict get $gdict glist]
        set text [listnar "group" "any of these groups" $glist $opt]
        set result "neighborhoods without deployments of $text"
        return "$result"
    }

    typemethod eval {gdict} {
        # Get keys
        set glist [dict get $gdict glist]

        set num [llength $glist]

        return [rdb eval "
            SELECT n FROM (
                SELECT n, count(g) AS num
                FROM deploy_ng
                WHERE g IN ('[join $glist {','}]')
                AND personnel = 0
                GROUP BY n
            ) WHERE num = $num
        "]
    }
}
