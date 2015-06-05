#-----------------------------------------------------------------------
# TITLE:
#    group.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Group Manager
#
#    This module is responsible for managing groups in general.
#    Most of the relevant code is in the frcgroup, orggroup, and civgroup
#    modules; this is just a few things that apply to all.
#
#-----------------------------------------------------------------------

snit::type ::athena::group {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        set adb $adb_
    }

    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.


    # names
    #
    # Returns the list of neighborhood names

    method names {{gtypes ""}} {
        set wClause ""
        if {[llength $gtypes] > 0} {
            set wClause "WHERE gtype IN ('" 
            append wClause [join $gtypes "' ,'"] "')"
        }
        
        set names [$adb eval "
            SELECT g FROM groups 
            $wClause
            ORDER BY g
        "]
    }

    # namedict
    #
    # Returns ID/longname dictionary

    method namedict {} {
        return [$adb eval {
            SELECT g, longname FROM groups ORDER BY g
        }]
    }

    # validate g
    #
    # g         Possibly, a group short name.
    #
    # Validates a group short name

    method validate {g} {
        if {![$self exists $g]} {
            set names [join [$self names] ", "]

            if {$names ne ""} {
                set msg "should be one of: $names"
            } else {
                set msg "none are defined"
            }

            return -code error -errorcode INVALID \
                "Invalid group, $msg"
        }

        return $g
    }

    # exists get
    #
    # g      - A group
    # 
    # Returns 1 if the group exists, and 0 otherwise.

    method exists {g} {
        return [dbexists $adb groups g $g]
    }

    # view g ?tag?
    #
    # g    - A group in the neighborhood
    # tag  - A view tag 
    #
    # Retrieves a view dictionary for the group. If tag is supplied it is
    # prepended to '_groups' and that is used as the SQL view for lookup.
    # By default the formatted view is used.

    method view {g {tag ""}} {
        if {$tag eq ""} {
            set table fmt_groups
        } else {
            append table $tag _groups
        }
        return [dbget $adb $table g $g]
    }

    # gtype g
    #
    # g       A group short name
    #
    # Returns the group's type, CIV, ORG, or FRC.

    method gtype {g} {
        return [$adb onecolumn {
            SELECT gtype FROM groups WHERE g=$g
        }]
    }

    # isLocal g
    #
    # g    A group
    #
    # Returns 1 if a group is local, and 0 otherwise.
    #
    # TBD: For now, a group is deemed to be local if it is a CIV group,
    # or if it is a FRC group with the local flag set.  Ultimately,
    # "local" should probably be an attribute of all groups.

    method isLocal {g} {
        set gtype [$self gtype $g]

        if {$gtype eq "CIV"} {
            return 1
        } elseif {$gtype eq "FRC"} {
            return [$adb eval {
                SELECT local FROM frcgroups WHERE g=$g
            }]
        } else {
            return 0
        }
    }

    # ownedby a
    #
    # a - An actor
    #
    # Returns a list of the force/org groups owned by actor a.

    method ownedby {a} {
        return [$adb eval {
            SELECT g FROM agroups
            WHERE a=$a
        }]
    }

    # owner g
    #
    # g   - A group
    #
    # Returns a list of the owner of the force or org group, or "" if none.

    method owner {g} {
        return [$adb onecolumn {
            SELECT a FROM agroups
            WHERE g=$g
        }]
    }

    # bsid g
    #
    # g  - A group
    #
    # Returns the group's belief system ID.

    method bsid {g} {
        return [$adb onecolumn {
            SELECT bsid FROM groups_bsid_view WHERE g=$g
        }]
    }


    # maintPerPerson g
    #
    # g  - A group
    #
    # Returns the maintenance cost per person for the given force
    # or organization group.

    method maintPerPerson {g} {
        return [$adb onecolumn {
            SELECT cost FROM agroups WHERE g=$g
        }]
    }

    # otherthan glist
    #
    # glist - A list of groups
    #
    # Returns a list of all groups other than those in glist.

    method otherthan {glist} {
        return [$adb eval "
            SELECT g FROM groups
            WHERE g NOT IN ('[join $glist {','}]')
        "]
    }

    # otherthandict glist
    #
    # glist - A list of groups
    #
    # Returns a dict of group ID/longname pairs other than those 
    # in glist.

    method otherthandict {glist} {
        return [$adb eval "
            SELECT g, longname FROM groups
            WHERE g NOT IN ('[join $glist {','}]')
        "]
    }

}





