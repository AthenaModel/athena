#-----------------------------------------------------------------------
# TITLE:
#    group.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Group Manager
#
#    This module is responsible for managing groups in general.
#    Most of the relevant code is in the frcgroup, orggroup, and civgroup
#    modules; this is just a few things that apply to all.
#
#-----------------------------------------------------------------------

snit::type group {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.


    # names
    #
    # Returns the list of neighborhood names

    typemethod names {} {
        set names [rdb eval {
            SELECT g FROM groups 
            ORDER BY g
        }]
    }

    # namedict
    #
    # Returns ID/longname dictionary

    typemethod namedict {} {
        return [rdb eval {
            SELECT g, longname FROM groups ORDER BY g
        }]
    }

    # validate g
    #
    # g         Possibly, a group short name.
    #
    # Validates a group short name

    typemethod validate {g} {
        if {![rdb exists {SELECT g FROM groups WHERE g=$g}]} {
            set names [join [group names] ", "]

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

    # gtype g
    #
    # g       A group short name
    #
    # Returns the group's type, CIV, ORG, or FRC.

    typemethod gtype {g} {
        return [rdb onecolumn {
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

    typemethod isLocal {g} {
        set gtype [$type gtype $g]

        if {$gtype eq "CIV"} {
            return 1
        } elseif {$gtype eq "FRC"} {
            return [rdb eval {
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

    typemethod ownedby {a} {
        return [rdb eval {
            SELECT g FROM agroups
            WHERE a=$a
        }]
    }

    # owner g
    #
    # g   - A group
    #
    # Returns a list of the owner of the force or org group, or "" if none.

    typemethod owner {g} {
        return [rdb onecolumn {
            SELECT a FROM agroups
            WHERE g=$g
        }]
    }

    # bsid g
    #
    # g  - A group
    #
    # Returns the group's belief system ID.

    typemethod bsid {g} {
        return [rdb onecolumn {
            SELECT bsid FROM groups_bsid_view WHERE g=$g
        }]
    }


    # maintPerPerson g
    #
    # g  - A group
    #
    # Returns the maintenance cost per person for the given force
    # or organization group.

    typemethod maintPerPerson {g} {
        return [rdb onecolumn {
            SELECT cost FROM agroups WHERE g=$g
        }]
    }

    # otherthan glist
    #
    # glist - A list of groups
    #
    # Returns a list of all groups other than those in glist.

    typemethod otherthan {glist} {
        return [rdb eval "
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

    typemethod otherthandict {glist} {
        return [rdb eval "
            SELECT g, longname FROM groups
            WHERE g NOT IN ('[join $glist {','}]')
        "]
    }

}





