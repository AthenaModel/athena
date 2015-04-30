#-----------------------------------------------------------------------
# TITLE:
#   vardiff_gdp.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: gdp
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::gdp {
    superclass ::athena::vardiff
    meta type     gdp
    meta category economic

    constructor {comp_ val1_ val2_} {
        next $comp_ "" $val1_ $val2_
    }

    method significant {} {
        set lim 0.2 ;# TBD: Need parameter

        expr {[my score] >= $lim}
    }

    method format {val} {
        return [moneyfmt $val]
    }

    method context {} {
        format "%.1f%%" [expr {100.0*([my val2]-[my val1])/[my val1]}]
    }

    method score {} {
        let score {abs([my val2]-[my val1])/[my val1]}
        format "%.2f" $score
    }
}