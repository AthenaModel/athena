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

    method IsSignificant {} {
        set lim [athena::compdb get [my type].limit]

        expr {[my score] >= $lim}
    }

    method format {val} {
        return [moneyfmt $val]
    }

    method context {} {
        return {<i>x</i> &ge; &plus;$0.00}
    }


    method score {} {
        my variable val1
        my variable val2 

        let score {100.0*abs(double($val2)-$val2)/max($val1, $val2)}
        format "%.2f" $score
    }
    method narrative {} {
        return [my DeltaNarrative "Production capacity"]
    }
}