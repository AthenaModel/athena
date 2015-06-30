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

    # groupsbybys 
    #
    # This method returns a list of groups by belief system.  It's possible
    # that an empty list corresponds to a belief system.

    method groupsbybsys {} {
        # FIRST, get the belief system IDs
        set bsids [$adb bsys system ids]
        array set glists [lzipper $bsids]

        # NEXT, build array of groups by belief system
        $adb eval {
            SELECT g, bsid FROM civgroups_view
        } {
            lappend glists($bsid) $g
        }

        return [array get glists]
    }

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

        set glists [$self groupsbybsys]

        # NEXT, compute composite mood 
        foreach {bsid glist} $glists {
            set mood [$self moodbygroups $glist $t]
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

        set glist [$adb eval "SELECT g FROM $table"]

        return [$self moodbygroups $glist $t]
    }

    # satbybsys t clist
    #
    # t      - A simulation time in ticks
    # clist  - A list of concerns over which to roll up 
    #
    # This method rolls up satisfaction over a list of concerns at some
    # simulation time t by belief system.  If all four concerns are passed 
    # in the result is identical to a call to moodbybys.

    method satbybsys {t clist} {
        # FIRST, get the belief system IDs
        set bsids [$adb bsys system ids]

        set rlist [list]

        set glists [$self groupsbybsys]

        foreach {bsid glist} $glists {
            set sat [$self satbygroups $glist $clist $t]
            lappend rlist $bsid $sat
        }

        return $rlist
    }

    # satbynb t clist
    #
    # t      - A simulation time in ticks
    # clist  - A list of concerns over which to roll up
    #
    # This method rolls up satisfaction over a list of concerns at some
    # simulation time t by neighborhood. Note: a better solution to calling
    # this method with all four concerns would be to look it up out of the 
    # hist_nbhood table, where it is already computed.

    method satbynb {t clist} {
        set nbhoods [$adb nbhood names]
        array set glists [lzipper $nbhoods]

        set rlist [list]

        $adb eval {
            SELECT g, n FROM civgroups_view
        } {
            lappend glists($n) $g
        }

        foreach {n glist} [array get glists] {
            set sat [$self satbygroups $glist $clist $t]
            lappend rlist $n $sat
        }

        return $rlist
    }

    # pbsat t clist ?local?
    #
    # t       - A simulation time
    # clist   - A list of concerns
    # local   - Flag indicating whether only local groups should be included
    #
    # This method rolls up satisfaction for one or more concern over all
    # civilian groups in the playbox.  By default, only local groups are
    # included.  If clist contains all concerns, this call is equivalent to
    # a call to pbmood.

    method pbsat {t clist {local 1}} {
        set table "local_civgroups"

        if {!$local} {
            set table "civgroups"
        }

        set glist [$adb eval "SELECT g FROM $table"]

        return [$self satbygroups $glist $clist $t]
    }

    # moodbygroups grps t
    #
    # grps    - a list of civilian groups
    # t       - a time at which to compute composite mood 
    #
    # This method takes an arbitrary list of civilian groups and rolls up
    # mood for the specified time to create a composite mood. It is 
    # assumed that the list of groups contains CIV groups only.

    method moodbygroups {grps t} {
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

    # satbygroups grps concerns t
    #
    # grps        - A list of one or more civilian groups
    # concerns    - A list of one or more concerns
    # t           - A simulation time
    #
    # This method takes a list of civilian groups and a list of concerns
    # and rolls up satisfaction at the specified time to create a composite
    # satisfaction.  Normally, this would be used with one concern, but it 
    # doesn't have to be.  If all concerns are specified then this method 
    # should return the exact same result as moodbygroups above.  In that case,
    # it would be better to use moodbygroups instead of this method.

    method satbygroups {grps concerns t} {
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
