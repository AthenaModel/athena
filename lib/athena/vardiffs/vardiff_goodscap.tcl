#-----------------------------------------------------------------------
# TITLE:
#   vardiff_goodscap.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: goodscap.n
#
#   A value is the GOODS production capacity of neighborhood n, in
#   dollars.
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::goodscap {
    superclass ::athena::vardiff
    meta type     goodscap
    meta category economic

    constructor {comp_ val1_ val2_ n_} {
        next $comp_ [list n $n_] $val1_ $val2_
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