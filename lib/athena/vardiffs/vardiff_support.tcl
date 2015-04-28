#-----------------------------------------------------------------------
# TITLE:
#   vardiff_support.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n) history variable differences: support.n.a
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::support {
    superclass ::athena::vardiff
    meta type     support.n.a
    meta category political

    constructor {comp_ val1_ val2_ n_ a_} {
        next $comp_ [list n $n_ a $a_] $val1_ $val2_
    }

    method significant {} {
        set lim 0.1
        expr {[my score] >= $lim}
    }

    method format {val} {
        format %.1f $val
    }

    method score {} {
        format "%.1f" [next]
    }
}

