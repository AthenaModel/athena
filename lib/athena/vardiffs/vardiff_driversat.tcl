#-----------------------------------------------------------------------
# TITLE:
#   vardiff_driversat.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n) variable differences: driversat.g.c.drid
#
#   A value is the total contribution of a driver to a particular curve.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::driversat {
    superclass ::athena::vardiff
    meta type     driversat
    meta category social

    constructor {comp_ val1_ val2_ g_ c_ drid_} {
        next $comp_ [list g $g_ c $c_ drid $drid_] $val1_ $val2_
    }

    method score {} {
        my format [next]
    }

    method format {val} {
        return [format %.1f $val]
    }

    method significant {} {
        set lim [athena::compdb get [my type].limit]

        expr {[my score] >= $lim}
    }
}