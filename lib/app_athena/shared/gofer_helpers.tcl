#-----------------------------------------------------------------------
# TITLE:
#    gofer_helpers.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Application-specific helper routines used by multiple gofer types.
#    All of these commands are defined in the ::gofer:: namespace and 
#    are available for use by gofer rules.

namespace eval ::gofer {}

#-------------------------------------------------------------------
# Gdict Pattern: anyall/alist
#
# anyall  - An eanyall value (ANY, ALL)
# alist   - A list of actors
#

# TBD: gofer pattern?  gofer helper? gofer ensemble?
snit::type ::gofer::anyall_alist {
    pragma -hasinstances no
    typeconstructor { namespace path ::projectlib::gofer }

    # validate gdict
    #
    # gdict - A gdict with keys anyall, alist
    #
    # Validates a gdict that allows the user to specify any/all of 
    # a list of actors.

    typemethod validate {gdict} {
        dict with gdict {}

        set result [dict create]

        dict set result anyall [eanyall validate $anyall]
        dict set result alist [listval "actors" {actor validate} $alist]
        return $result
    }

    # narrative gdict ?opt?
    #
    # gdict - A gdict with keys anyall, alist
    # opt   - Possibly "-brief"
    #
    # Produces part of a narrative string for the gdict:
    #
    #   actor <actor>
    #   {any of|all of} these actors (<alist>)

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        if {[llength $alist] > 1} {
            if {$anyall eq "ANY"} {
                append result "any of "
            } else {
                append result "all of "
            }
        }

        append result [listnar "actor" "these actors" $alist $opt]

        return "$result"
    }

    # supportingActor gtype gdict
    #
    # gtype  - A group type, or ""
    # gdict  - A gdict with keys anyall, alist
    #
    # Finds all groups of the given type that support any or all actors
    # in the list.
    typemethod supportingActor {gtype gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set alist  [dict get $gdict alist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $alist]
        }

        if {$gtype ne ""} {
            set gtypeClause "AND gtype=\$gtype"
        } else {
            set gtypeClause ""
        }

        return [rdb eval "
            SELECT g FROM (
                SELECT g, count(support) AS num
                FROM groups
                JOIN support_nga USING (g)
                WHERE support_nga.a IN ('[join $alist {','}]') 
                AND support > 0
                $gtypeClause
                GROUP BY g 
            ) WHERE num >= \$num 
        "]
    }

    # likingActor gtype gdict
    #
    # gtype  - A group type, or ""
    # gdict  - A gdict with keys anyall, alist
    #
    # Finds all groups of the given type that "like" any or all actors
    # in the list.
    typemethod likingActor {gtype gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set alist  [dict get $gdict alist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $alist]
        }

        if {$gtype ne ""} {
            set gtypeClause "AND gtype=\$gtype"
        } else {
            set gtypeClause ""
        }

        return [rdb eval "
            SELECT g FROM (
                SELECT g, count(vrel) AS num
                FROM groups
                JOIN uram_vrel USING (g)
                WHERE uram_vrel.a IN ('[join $alist {','}]') 
                AND vrel >= 0.2
                $gtypeClause
                GROUP BY g 
            ) WHERE num >= \$num 
        "]
    }

    # dislikingActor gtype gdict
    #
    # gtype  - A group type, or ""
    # gdict  - A gdict with keys anyall, alist
    #
    # Finds all groups of the given type that "like" any or all actors
    # in the list.
    typemethod dislikingActor {gtype gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set alist  [dict get $gdict alist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $alist]
        }

        if {$gtype ne ""} {
            set gtypeClause "AND gtype=\$gtype"
        } else {
            set gtypeClause ""
        }

        return [rdb eval "
            SELECT g FROM (
                SELECT g, count(vrel) AS num
                FROM groups
                JOIN uram_vrel USING (g)
                WHERE uram_vrel.a IN ('[join $alist {','}]') 
                AND vrel <= -0.2
                $gtypeClause
                GROUP BY g 
            ) WHERE num >= \$num 
        "]
    }
}

#-------------------------------------------------------------------
# Gdict Pattern: anyall/glist
#
# anyall  - An eanyall value (ANY, ALL)
# glist   - A list of groups of any group type
#

snit::type ::gofer::anyall_glist {
    pragma -hasinstances no
    typeconstructor { namespace path ::projectlib::gofer }

    # validate gdict ?gtype?
    #
    # gdict - A gdict with keys anyall, glist:
    # gtype - Group type; defaults to "group", but can be
    #         civgroup, frcgroup, orggroup, etc.
    #
    # Validates a gdict that allows the user to specify any/all of 
    # a list of groups.

    typemethod validate {gdict {gtype group}} {
        dict with gdict {}

        set result [dict create]

        dict set result anyall [eanyall validate $anyall]
        dict set result glist [listval "groups" [list $gtype validate] $glist]
        return $result
    }

    # narrative gdict ?opt?
    #
    # gdict - A gdict with keys anyall, glist
    # opt   - Possibly "-brief"
    #
    # Produces part of a narrative string for the gdict:
    #
    #   group <group>
    #   {any of|all of} these groups (<glist>)

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        if {[llength $glist] > 1} {
            if {$anyall eq "ANY"} {
                append result "any of "
            } else {
                append result "all of "
            }
        }

        append result [listnar "group" "these groups" $glist $opt]

        return "$result"
    }

    # likingGroup gtype gdict
    #
    # gtype  - A group type, or ""
    # gdict  - A gdict with keys anyall, glist
    #
    # Finds all groups of the given type that "like" any or all groups
    # in the list.
    typemethod likingGroup {gtype gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set glist  [dict get $gdict glist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $glist]
        }

        if {$gtype ne ""} {
            set gtypeClause "AND G.gtype=\$gtype"
        } else {
            set gtypeClause ""
        }

        return [rdb eval "
            SELECT g FROM (
                SELECT G.g AS g, count(U.hrel) AS num
                FROM groups AS G
                JOIN uram_hrel AS U ON (U.f = G.g)
                WHERE U.g IN ('[join $glist {','}]') 
                AND U.hrel >= 0.2
                $gtypeClause
                GROUP BY G.g 
            ) WHERE num >= \$num 
        "]
    }

    # dislikingGroup gtype gdict
    #
    # gtype  - A group type, or ""
    # gdict  - A gdict with keys anyall, glist
    #
    # Finds all groups of the given type that "dislike" any or all groups
    # in the list.
    typemethod dislikingGroup {gtype gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set glist  [dict get $gdict glist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $glist]
        }

        if {$gtype ne ""} {
            set gtypeClause "AND G.gtype=\$gtype"
        } else {
            set gtypeClause ""
        }

        return [rdb eval "
            SELECT g FROM (
                SELECT G.g AS g, count(U.hrel) AS num
                FROM groups AS G
                JOIN uram_hrel AS U ON (U.f = G.g)
                WHERE U.f != U.g
                AND U.g IN ('[join $glist {','}]') 
                AND U.hrel <= -0.2
                $gtypeClause
                GROUP BY G.g 
            ) WHERE num >= \$num 
        "]
    }

    # likedByGroup gtype gdict
    #
    # gtype  - A group type, or ""
    # gdict  - A gdict with keys anyall, glist
    #
    # Finds all groups of the given type that are "liked" by any or all 
    # groups in the list.

    typemethod likedByGroup {gtype gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set glist  [dict get $gdict glist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $glist]
        }

        if {$gtype ne ""} {
            set gtypeClause "AND G.gtype=\$gtype"
        } else {
            set gtypeClause ""
        }

        return [rdb eval "
            SELECT g FROM (
                SELECT G.g AS g, count(U.hrel) AS num
                FROM groups AS G
                JOIN uram_hrel AS U USING (g)
                WHERE U.f IN ('[join $glist {','}]') 
                AND U.hrel >= 0.2
                $gtypeClause
                GROUP BY G.g 
            ) WHERE num >= \$num 
        "]
    }

    # dislikedByGroup gtype gdict
    #
    # gtype  - A group type, or ""
    # gdict  - A gdict with keys anyall, glist
    #
    # Finds all groups of the given type that are "disliked" by any or all 
    # groups in the list.

    typemethod dislikedByGroup {gtype gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set glist  [dict get $gdict glist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $glist]
        }

        if {$gtype ne ""} {
            set gtypeClause "AND G.gtype=\$gtype"
        } else {
            set gtypeClause ""
        }

        return [rdb eval "
            SELECT g FROM (
                SELECT G.g AS g, count(U.hrel) AS num
                FROM groups AS G
                JOIN uram_hrel AS U USING (g)
                WHERE U.f != U.g
                AND U.f IN ('[join $glist {','}]') 
                AND U.hrel <= -0.2
                $gtypeClause
                GROUP BY G.g 
            ) WHERE num >= \$num 
        "]
    }

}

#-------------------------------------------------------------------
# Gdict Pattern: anyall/nlist
#
# anyall  - An eanyall value (ANY, ALL)
# nlist   - A list of nbhoods of any neighborhood type

snit::type ::gofer::anyall_nlist {
    pragma -hasinstances no
    typeconstructor { namespace path ::projectlib::gofer }

    # validate gdict
    #
    # gdict - A gdict with keys anyall, nlist:
    #
    # Validates a gdict that allows the user to specify any/all of 
    # a list of neighborhoods.

    typemethod validate {gdict} {
        dict with gdict {}

        set result [dict create]

        dict set result anyall [eanyall validate $anyall]
        dict set result nlist [listval "neighborhoods" {nbhood validate} $nlist]
        return $result
    }

    # narrative gdict ?opt?
    #
    # gdict - A gdict with keys anyall, nlist
    # opt   - Possibly "-brief"
    #
    # Produces part of a narrative string for the gdict:
    #
    #   neighborhood <neighborhood>
    #   {any of|all of} these neighborhoods (<nlist>)

    typemethod narrative {gdict {opt ""}} {
        dict with gdict {}

        if {[llength $nlist] > 1} {
            if {$anyall eq "ANY"} {
                append result "any of "
            } else {
                append result "all of "
            }
        }

        append result [listnar "neighborhood" "these neighborhoods" $nlist $opt]

        return "$result"
    }

    # deployedTo gdict
    #
    # gdict  - A gdict with keys anyall, nlist
    #
    # Finds all force groups that are deployed to any or all of the given
    # neighborhoods.

    typemethod deployedTo {gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set nlist  [dict get $gdict nlist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $nlist]
        }

        return [rdb eval "
            SELECT g FROM (
                SELECT g, count(n) AS num
                FROM frcgroups
                JOIN deploy_ng USING (g)
                WHERE personnel > 0
                AND n in ('[join $nlist {','}]')
                GROUP BY g 
            ) WHERE num >= \$num 
        "]
    }

    # notDeployedTo gdict
    #
    # gdict  - A gdict with keys anyall, nlist
    #
    # Finds all force groups that are not deployed in any or all of the given
    # neighborhoods.
    typemethod notDeployedTo {gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set nlist  [dict get $gdict nlist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $nlist]
        }

        return [rdb eval "
            SELECT g FROM (
                SELECT g, count(n) AS num
                FROM frcgroups
                JOIN deploy_ng USING (g)
                WHERE personnel = 0
                AND n in ('[join $nlist {','}]')
                GROUP BY g 
            ) WHERE num >= \$num 
        "]
    }
}

