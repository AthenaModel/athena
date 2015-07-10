#-----------------------------------------------------------------------
# TITLE:
#   vardiff_drivervrel.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n) variable differences: drivervrel.g.a.drid
#
#   A value is the total contribution of a driver to a particular curve.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::drivervrel {
    superclass ::athena::vardiff
    meta type     drivervrel
    meta category political

    constructor {comp_ val1_ val2_ g_ a_ drid_} {
        next $comp_ [list g $g_ a $a_ drid $drid_] $val1_ $val2_
    }

    method score {} {
        my format [next]
    }

    method format {val} {
        return [format %.1f $val]
    }

    method IsSignificant {} {
        set lim [athena::compdb get [my type].limit]

        expr {[my score] >= $lim}
    }

    method narrative {} {
        return [my DeltaNarrative \
            "Total contribution to group [my key g]'s relationship with actor [my key a] by this driver" \
            "satisfaction points"]
    }
}