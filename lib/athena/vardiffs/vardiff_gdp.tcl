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
#   A value is the GDP from the economic model, in dollars.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::gdp {
    superclass ::athena::vardiff
    meta type     gdp
    meta category economic

    constructor {comp_ val1_ val2_} {
        next $comp_ "" $val1_ $val2_
    }

    method IsSignificant {} {
        set lim [athena::compdb get [my type].limit]

        expr {[my score] >= $lim}
    }

    method format {val} {
        return [moneyfmt $val]
    }

    method context {} {
        format "%.1f%%" [my score]
    }

    method score {} {
        my variable val1
        my variable val2 

        let score {100.0*abs(double($val2)-$val2)/max($val1, $val2)}
        format "%.2f" $score
    }

    method narrative {} {
        return [my DeltaNarrative "Gross Domestic Product"]
    }
}