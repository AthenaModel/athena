#-----------------------------------------------------------------------
# TITLE:
#    gofer_rule.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Abstract base class for gofer rules.
#
#    This module defines the standard interface for gofer rule classes;
#    it also defines a variety of helper methods for formatting 
#    narrative and validating inputs.
#    
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# gofer_rule: Abstract base class for gofer rules.

oo::class create ::athena::gofer_rule {
    #-------------------------------------------------------------------
    # Instance Variables

    variable adb          ;# The athenadb(n) handle
    variable gtype        ;# The gofer type to which the rule belongs.
    variable rule         ;# The rule's name

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_ gtype_ rule_
    #
    # adb_   - The athenadb(n) handle
    # gtype_ - The gofer type to which the rule belongs.
    # rule_  - The rule's name
    #
    # Initializes the rule.

    constructor {adb_ gtype_ rule_} {
        set adb   $adb_
        set gtype $gtype_
        set rule  $rule_
    }

    #-------------------------------------------------------------------
    # Standard Methods
    
    method make {args} {
        error "[self]: make method not overridden"
    }

    method validate {gdict} {
        error "[self]: validate method not overridden"
    }

    method narrative {gdict {opt ""}} {
        error "[self]: narrative method not overridden"
    }

    method eval {gdict} {
        error "[self]: eval method not overridden"
    }

    #-------------------------------------------------------------------
    # Validation Helpers
 
    # val_list noun vcmd list
    #
    # noun   - A plural noun for use in error messages
    # vcmd   - The validation command for the list members
    # list   - The list to validate
    #
    # Attempts to validate the list, returning it in canonical
    # form for the validation type.  Throws an error if any
    # list member is invalid, or if the list is empty.

    method val_list {noun vcmd list} {
        set out [list]
        foreach elem $list {
            lappend out [{*}$vcmd $elem]
        }

        if {[llength $out] == 0} {
            throw INVALID "No $noun selected"
        }

        return $out
    }

    # val_elist entity noun elist
    #
    # entity - The athenadb(n) entity type
    # noun   - A plural noun for use in error messages
    # elist  - The list to validate
    #
    # Attempts to validate a list of entities, where "entity" is the
    # name of an athenadb(n) subcommand with a "validate" subcommand,
    # returning the list it in canonical form for the validation type.  
    # Throws an error if any list member is invalid, or if the list is 
    # empty.

    method val_elist {entity noun elist} {
        set out [list]
        foreach elem $elist {
            lappend out [$adb $entity validate $elem]
        }

        if {[llength $out] == 0} {
            throw INVALID "No $noun selected"
        }

        return $out
    }

    # val_selector field value
    #
    # field  - The selector field within the rule's case.
    # value  - The selector value
    #
    # Validates a selector value.

    method val_selector {field value} {
        set dform [$gtype dynaform]
        set value [string toupper $value]
        set values [dynaform cases $dform $field [list _rule $rule]]

        if {$value ni $values} {
            error "Invalid \"$field\" value: \"$value\""
        }

        return $value
    }

    # val_anyall_alist gdict
    #
    # gdict - A gdict with keys anyall, alist
    #
    # Validates a gdict that allows the user to specify any/all of 
    # a list of actors.

    method val_anyall_alist {gdict} {
        dict with gdict {}

        set result [dict create]

        dict set result anyall [eanyall validate $anyall]
        dict set result alist [my val_elist actor "actors" $alist]
        return $result
    }
   
    # val_anyall_glist gdict ?gtype?
    #
    # gdict - A gdict with keys anyall, glist:
    # gtype - Group type; defaults to "group", but can be
    #         civgroup, frcgroup, orggroup, etc.
    #
    # Validates a gdict that allows the user to specify any/all of 
    # a list of groups.

    method val_anyall_glist {gdict {gtype group}} {
        dict with gdict {}

        set result [dict create]

        dict set result anyall [eanyall validate $anyall]
        dict set result glist [my val_elist $gtype "groups" $glist]
        return $result
    }


    # val_anyall_nlist gdict
    #
    # gdict - A gdict with keys anyall, nlist:
    #
    # Validates a gdict that allows the user to specify any/all of 
    # a list of neighborhoods.

    method val_anyall_nlist {gdict} {
        dict with gdict {}

        set result [dict create]

        dict set result anyall [eanyall validate $anyall]
        dict set result nlist [my val_elist nbhood "neighborhoods" $nlist]
        return $result
    }

    #-------------------------------------------------------------------
    # Narrative Helpers

    # joinlist list ?maxlen? ?delim?
    #
    # list   - A list
    # maxlen - If given, the maximum number of list items to show.
    #          If "", the default, there is no maximum.
    # delim  - If given, the delimiter to insert between items.
    #          Defaults to ", "
    #
    # Joins the elements of the list using the delimiter, 
    # replacing excess elements with "..." if maxlen is given.

    method joinlist {list {maxlen ""} {delim ", "}} {
        if {$maxlen ne "" && [llength $list] > $maxlen} {
            set list [lrange $list 0 $maxlen-1]
            lappend list ...
        }

        return [join $list $delim]
    }

    # nar_list snoun pnoun list ?-brief?
    #
    # snoun   - A singular noun, or ""
    # pnoun   - A plural noun
    # list    - A list of items
    # -brief  - If given, truncate list
    #
    # Returns a standard list narrative string.

    method nar_list {snoun pnoun list {opt ""}} {
        if {$opt eq "-brief"} {
            set maxlen 8
        } else {
            set maxlen ""
        }

        if {[llength $list] == 1} {
            if {$snoun ne ""} {
                set text "$snoun [lindex $list 0]"
            } else {
                set text [lindex $list 0]
            }
        } else {
            set text "$pnoun ([my joinlist $list $maxlen])" 
        }

        return $text
    }

    # nar_anyall_alist gdict ?opt?
    #
    # gdict - A gdict with keys anyall, alist
    # opt   - Possibly "-brief"
    #
    # Produces part of a narrative string for the gdict:
    #
    #   actor <actor>
    #   {any of|all of} these actors (<alist>)

    method nar_anyall_alist {gdict {opt ""}} {
        dict with gdict {}

        if {[llength $alist] > 1} {
            if {$anyall eq "ANY"} {
                append result "any of "
            } else {
                append result "all of "
            }
        }

        append result [my nar_list "actor" "these actors" $alist $opt]

        return "$result"
    }

    # nar_anyall_glist gdict ?opt?
    #
    # gdict - A gdict with keys anyall, glist
    # opt   - Possibly "-brief"
    #
    # Produces part of a narrative string for the gdict:
    #
    #   group <group>
    #   {any of|all of} these groups (<glist>)

    method nar_anyall_glist {gdict {opt ""}} {
        dict with gdict {}

        if {[llength $glist] > 1} {
            if {$anyall eq "ANY"} {
                append result "any of "
            } else {
                append result "all of "
            }
        }

        append result [my nar_list "group" "these groups" $glist $opt]

        return "$result"
    }


    # nar_anyall_nlist gdict ?opt?
    #
    # gdict - A gdict with keys anyall, nlist
    # opt   - Possibly "-brief"
    #
    # Produces part of a narrative string for the gdict:
    #
    #   neighborhood <neighborhood>
    #   {any of|all of} these neighborhoods (<nlist>)

    method nar_anyall_nlist {gdict {opt ""}} {
        dict with gdict {}

        if {[llength $nlist] > 1} {
            if {$anyall eq "ANY"} {
                append result "any of "
            } else {
                append result "all of "
            }
        }

        append result [my nar_list "neighborhood" "these neighborhoods" $nlist $opt]

        return "$result"
    }

    #-------------------------------------------------------------------
    # Other helpers

    # filterby listVar filterlist
    #
    # listVar   - A variable containing a list of items
    # filterlist - Another list of items
    # 
    # Computes the intersection of the two lists, and saves it back
    # to listVar.

    method filterby {listVar filterlist} {
        upvar 1 $listVar theList

        set result [list]

        foreach item $theList {
            if {$item in $filterlist} {
                lappend result $item
            }
        }

        set theList $result

        return $result
    }

    # groupsIn nlist
    #
    # Returns the civilian groups present in a list of neighborhoods.

    method groupsIn {nlist} {
        set out [list]
        foreach n $nlist {
            lappend out {*}[$adb demog gIn $n]
        }

        return $out
    }

    # groupsNotIn nlist
    #
    # Returns the groups not resident in a list of neighborhoods.

    method groupsNotIn {nlist} {
        set out [$adb civgroup names]
        foreach n $nlist {
            foreach g [$adb demog gIn $n] {
                ldelete out $g
            }
        }
        return $out
    }

    # nonempty glist
    #
    # glist   - A list of groups
    #
    # Returns the list, filtering out empty civilian groups.

    method nonempty {glist} {
        array set pop [$adb eval {
            SELECT g, population FROM gui_civgroups
        }]

        set result [list]
        foreach g $glist {
            if {[info exists pop($g)] && $pop($g) > 0} {
                lappend result $g
            }
        }

        return $result
    }
    

    # anyall_alist_supportingActor gtype gdict
    #
    # gtype  - A group type, or ""
    # gdict  - A gdict with keys anyall, alist
    #
    # Finds all groups of the given type that support any or all actors
    # in the list.
    method anyall_alist_supportingActor {gtype gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set alist  [dict get $gdict alist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $alist]
        }

        if {$gtype ne ""} {
            set gtypeClause "AND gtype='$gtype'"
        } else {
            set gtypeClause ""
        }
 
        return [$adb eval "
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

    # anyall_alist_likingActor gtype gdict
    #
    # gtype  - A group type, or ""
    # gdict  - A gdict with keys anyall, alist
    #
    # Finds all groups of the given type that "like" any or all actors
    # in the list.
    method anyall_alist_likingActor {gtype gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set alist  [dict get $gdict alist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $alist]
        }

        if {$gtype ne ""} {
            set gtypeClause "AND gtype='$gtype'"
        } else {
            set gtypeClause ""
        }

        return [$adb eval "
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

    # anyall_alist_dislikingActor gtype gdict
    #
    # gtype  - A group type, or ""
    # gdict  - A gdict with keys anyall, alist
    #
    # Finds all groups of the given type that "like" any or all actors
    # in the list.
    method anyall_alist_dislikingActor {gtype gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set alist  [dict get $gdict alist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $alist]
        }

        if {$gtype ne ""} {
            set gtypeClause "AND gtype='$gtype'"
        } else {
            set gtypeClause ""
        }

        return [$adb eval "
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

    # anyall_glist_likingGroup gtype gdict
    #
    # gtype  - A group type, or ""
    # gdict  - A gdict with keys anyall, glist
    #
    # Finds all groups of the given type that "like" any or all groups
    # in the list.
    method anyall_glist_likingGroup {gtype gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set glist  [dict get $gdict glist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $glist]
        }

        if {$gtype ne ""} {
            set gtypeClause "AND G.gtype='$gtype'"
        } else {
            set gtypeClause ""
        }

        return [$adb eval "
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

    # anyall_glist_dislikingGroup gtype gdict
    #
    # gtype  - A group type, or ""
    # gdict  - A gdict with keys anyall, glist
    #
    # Finds all groups of the given type that "dislike" any or all groups
    # in the list.
    method anyall_glist_dislikingGroup {gtype gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set glist  [dict get $gdict glist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $glist]
        }

        if {$gtype ne ""} {
            set gtypeClause "AND G.gtype='$gtype'"
        } else {
            set gtypeClause ""
        }

        return [$adb eval "
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

    # anyall_glist_likedByGroup gtype gdict
    #
    # gtype  - A group type, or ""
    # gdict  - A gdict with keys anyall, glist
    #
    # Finds all groups of the given type that are "liked" by any or all 
    # groups in the list.

    method anyall_glist_likedByGroup {gtype gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set glist  [dict get $gdict glist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $glist]
        }

        if {$gtype ne ""} {
            set gtypeClause "AND G.gtype='$gtype'"
        } else {
            set gtypeClause ""
        }

        return [$adb eval "
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

    # anyall_glist_dislikedByGroup gtype gdict
    #
    # gtype  - A group type, or ""
    # gdict  - A gdict with keys anyall, glist
    #
    # Finds all groups of the given type that are "disliked" by any or all 
    # groups in the list.

    method anyall_glist_dislikedByGroup {gtype gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set glist  [dict get $gdict glist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $glist]
        }

        if {$gtype ne ""} {
            set gtypeClause "AND G.gtype='$gtype'"
        } else {
            set gtypeClause ""
        }

        return [$adb eval "
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

    # anyall_nlist_deployedTo gdict
    #
    # gdict  - A gdict with keys anyall, nlist
    #
    # Finds all force groups that are deployed to any or all of the given
    # neighborhoods.

    method anyall_nlist_deployedTo {gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set nlist  [dict get $gdict nlist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $nlist]
        }

        return [$adb eval "
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

    # anyall_nlist_notDeployedTo gdict
    #
    # gdict  - A gdict with keys anyall, nlist
    #
    # Finds all force groups that are not deployed in any or all of the given
    # neighborhoods.
    method anyall_nlist_notDeployedTo {gdict} {
        # Get keys
        set anyall [dict get $gdict anyall]
        set nlist  [dict get $gdict nlist]

        if {$anyall eq "ANY"} {
            set num [expr {1}]
        } else {
            set num [llength $nlist]
        }

        return [$adb eval "
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

#-----------------------------------------------------------------------
# Test type and rule
#
# The following type is used for testing basic gofer rule functionality.

::athena::goferx define NULL none {
    selector _rule {
        case BY_VALUE "By name" {
            text raw_value
        }
    }
}

::athena::goferx rule NULL BY_VALUE {raw_value} {}

