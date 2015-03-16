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
    meta type support.n.a

    constructor {comp_ n_ a_ val1_ val2_} {
        next $comp_ [list n $n_ a $a_] $val1_ $val2_
    }

    method significant {} {
        expr {[my fmt1] != [my fmt2]}
    }

    method format {val} {
        format %.1f $val
    }
}

