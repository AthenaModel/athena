#-----------------------------------------------------------------------
# TITLE:
#   vardiff_nbunemp.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: nbunemp.n
#
#   A value is the unemployment rate in neighborhood n, as a percentage.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::nbunemp {
    superclass ::athena::vardiff
    meta type     nbunemp
    meta category economic

    constructor {comp_ val1_ val2_ n_} {
        next $comp_ [list n $n_] $val1_ $val2_
    }

    method IsSignificant {} {
        set lim [athena::compdb get [my type].limit]

        expr {[my score] >= $lim}
    }

    method format {val} {
        return [format "%.1f%%" $val]
    }

    method context {} {
        format "%.1f%%" [expr {[my val1]-[my val2]}]
    }

    method score {} {
        format "%.1f" [next]
    }
}