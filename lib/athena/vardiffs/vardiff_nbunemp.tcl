#-----------------------------------------------------------------------
# TITLE:
#   vardiff_nbunemp.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: unemp.n
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::nbunemp {
    superclass ::athena::vardiff
    meta type     unemp.n
    meta category economic

    constructor {comp_ val1_ val2_ n_} {
        next $comp_ [list n $n_] $val1_ $val2_
    }

    method significant {} {
        set lim 15.0 ;# TBD: Need parameter

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