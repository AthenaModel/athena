#-----------------------------------------------------------------------
# TITLE: 
#    stats.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#   athena(n): Scenario statistics manager
#
# This module computes statistics about a scenario upon demand.  It is 
# comprised of methods that operate on the history tables to produce 
# the type of statistics that wouldn't be the sort of thing stored in 
# a history table on it's own because of performance concerns.
#
#-----------------------------------------------------------------------

snit::type ::athena::stats {
    #-------------------------------------------------------------------
    # Components

    component adb  ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Construcutor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of this type.

    constructor {adb_} {
        set adb $adb_
    }

    #-------------------------------------------------------------------
    # Public Methods

    # moodbybsys  t
    #
    # t   - a time in history
    #
    # This method computes a rollup of mood by group and belief system
    # and returns a dictionary of composite mood by belief system ID at
    # the supplied time in the scenarios history

    method moodbybsys {t} {
        # FIRST, get the belief system IDs
        set bsids [$adb bsys system ids]

        set rlist [list]

        foreach bsid $bsids {
            # NEXT get groups with this belief system
            set grps [$adb eval {
                SELECT g FROM civgroups_view
                WHERE bsid=$bsid
            }]

            set mood [$self moodByGroups $grps $t]
            lappend rlist $bsid $mood
        }
        
        return $rlist
    }

    #--------------------------------------------------------------------
    # Helper Methods

    # moodByGroups grps t
    #
    # grps    - a list of civilian groups
    # t       - a time at which to compute composite mood 
    #
    # This method takes an arbitrary list of civilian groups and rolls up
    # mood for the specified time to create a composite mood. It is 
    # assumed that the list of groups contains CIV groups only.

    method moodByGroups {grps t} {
        # FIRST, create SQL for the list of groups
        set glist "('[join $grps {', '}]')"

        # NEXT, roll up mood by those groups
        $adb eval "
            SELECT total(sat*saliency*population) AS num,
                   total(saliency*population)     AS denom
            FROM hist_sat
            WHERE t=$t AND g IN $glist
        " {
            if {$denom == 0.0} {
                set mood 0.0
            } else {
                let mood {$num/$denom}
            }
        }

        return $mood
    }
}
