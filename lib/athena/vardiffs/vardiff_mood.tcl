#-----------------------------------------------------------------------
# TITLE:
#   vardiff_mood.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: mood.g
#
#   A value is the mood of group g.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::mood {
    superclass ::athena::vardiff
    meta type     mood
    meta category social

    constructor {comp_ val1_ val2_ g_} {
        next $comp_ [list g $g_] $val1_ $val2_
    }

    method IsSignificant {} {
        set lim [athena::compdb get [my type].limit]

        expr {[my score] >= $lim}
    }

    method format {val} {
        return [qsat longname $val]
    }

    method context {} {
        format "%.1f vs %.1f" [my val1] [my val2]
    }

    method score {} {
        format "%.1f" [next]
    }

    #-------------------------------------------------------------------
    # Input Differences
    

    method FindDiffs {} {
        variable comp

        set g [my key g]

        # FIRST, get the satisfaction inputs.
        $comp eval {
            SELECT H1.c    AS c,
                   H1.sat  AS sat1,
                   H2.sat  AS sat2
            FROM s1.hist_sat_raw AS H1
            JOIN s2.hist_sat_raw AS H2
            ON (H1.g = H2.g AND H1.c = H2.c AND H1.t = t1() AND H2.t = t2())
            WHERE H1.g = $g;
        } {
            my diffadd sat $sat1 $sat2 $g $c
        }

        # NEXT, get the population inputs
        $comp eval {
            SELECT H1.population AS pop1,
                   H2.population AS pop2
            FROM s1.hist_civg AS H1
            JOIN s2.hist_civg AS H2
            ON (H1.g = H2.g AND H1.t = t1() AND H2.t = t2())
            WHERE H1.g = $g;
        } {
            my diffadd population $pop1 $pop2 $g
        }

        # NEXT, get the contributions
        foreach {drid val1 val2} [$comp contribs mood $g] {
            my diffadd drivermood $val1 $val2 $g $drid
        }
    }
}