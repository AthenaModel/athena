#-----------------------------------------------------------------------
# TITLE:
#   vardiff_sat.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: sat.g.c
#
#   A value is civilian group g's satisfaction with concern c.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::sat {
    superclass ::athena::vardiff
    meta type     sat
    meta category social

    constructor {comp_ val1_ val2_ g_ c_} {
        next $comp_ [list g $g_ c $c_] $val1_ $val2_
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
        set c [my key c]

        # FIRST, get the contributions
        foreach {drid val1 val2} [$comp contribs sat $g $c] {
            my diffadd driversat $val1 $val2 $g $c $drid
        }

        # NEXT, for SFT only, get security changes.
        # TBD: No vardiff for group security yet.
    }
}