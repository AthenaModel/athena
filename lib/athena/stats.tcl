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
        array set glists [lzipper $bsids]

        set rlist [list]

        # NEXT, build array of groups by belief system
        $adb eval {
            SELECT g, bsid FROM civgroups_view
        } {
            lappend glists($bsid) $g
        }

        # NEXT, compute composite mood 
        foreach {bsid glist} [array get glists] {
            set mood [$self moodByGroups $glist $t]
            lappend rlist $bsid $mood
        }
        
        return $rlist
    }

    # pbmood  t ?local?
    #
    # t       - a simulation time
    # local   - flag indicating whether only local groups are included
    #
    # Computes a rollup of playbox mood for a set of CIV groups. If 
    # local is 1, only local groups are rolled up, otherwise all CIV
    # groups are rolled up. The default for local is 1.

    method pbmood {t {local 1}} {
        set table "local_civgroups"

        if {!$local} {
            set table "civgroups"
        }

        set grps [$adb eval "SELECT g FROM $table"]

        return [$self moodByGroups $grps $t]
    }

    method satbybsys {t clist} {
        set bsids [$adb bsys system ids]

        set rlist [list]

        foreach bsid $bsids {
            set grps [$adb eval {
                SELECT g FROM civgroups_view
                WHERE bsid=$bsid
            }]

            set sat [$self satByGroups $grps $clist $t]

            lappend rlist $bsid $sat
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
            WHERE t=\$t AND g IN $glist
        " {
            if {$denom == 0.0} {
                set mood 0.0
            } else {
                let mood {$num/$denom}
            }
        }

        return $mood
    }

    method satByGroups {grps concerns t} {
        # FIRST, create SQL for the list of groups and concerns
        set glist "('[join $grps {', '}]')"
        set clist "('[join $concerns {', '}]')"

        # NEXT, roll up satisfaction by those groups and concerns
        $adb eval "
            SELECT total(sat*saliency*population) AS num,
                   total(saliency*population)     AS denom
            FROM hist_sat
            WHERE t=$t AND g IN $glist AND c IN $clist
        " {
            if {$denom == 0.0} {
                set sat 0.0
            } else {
                let sat {$num/$denom}
            }
        }

        return $sat    
    }
}
