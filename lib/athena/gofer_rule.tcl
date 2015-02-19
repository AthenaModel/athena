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

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb   - The athenadb(n) handle
    #
    # Initializes the rule set.

    constructor {adb_} {
        set adb  $adb_
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
    

}
