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
#   A value is the support of neighborhood n for actor a.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::support {
    superclass ::athena::vardiff
    meta type     support
    meta category political

    constructor {comp_ val1_ val2_ n_ a_} {
        next $comp_ [list n $n_ a $a_] $val1_ $val2_
    }

    method score {} {
        my variable val1
        my variable val2

        let score {
            100.0 - 100.0*(min(double($val1),double($val2))/max($val1,$val2))
        }

        return [my format $score]
    }


    method significant {} {
        set lim [athena::compdb get [my type].limit]

        expr {[my score] >= $lim}
    }

    method format {val} {
        format %.1f $val
    }

    method score {} {
        format "%.1f" [next]
    }
}

