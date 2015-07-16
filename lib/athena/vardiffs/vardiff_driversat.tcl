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
        return [my DeltaNarrative \
            "Total contribution to group [my key g]'s satisfaction with [my key c] by this driver" \
            "satisfaction points"]
    }


}