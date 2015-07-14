#-----------------------------------------------------------------------
# TITLE:
#   vardiff_drivermood.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n) variable differences: drivermood.g.drid
#
#   A value is the total contribution of a driver to a particular curve.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::drivermood {
    superclass ::athena::vardiff
    meta type     drivermood
    meta category social

    constructor {comp_ val1_ val2_ g_ drid_} {
        next $comp_ [list g $g_ drid $drid_] $val1_ $val2_
    }

    method score {} {
        my format [next]
    }

    method format {val} {
        return [format %.1f $val]
    }

    method fancy {val} {
        return "[format %.1f $val] points"
    }

    method context {} {
        return {<i>x</i> &ge; 0.0}
    }

    method IsSignificant {} {
        set lim [athena::compdb get [my type].limit]

        expr {[my score] >= $lim}
    }

    method narrative {} {
        return [my DeltaNarrative  \
            "Total contribution to group [my key g]'s mood by this driver" \
            "satisfaction points"]
    }


}