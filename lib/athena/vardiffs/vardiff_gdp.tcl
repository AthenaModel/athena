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
    meta normfunc maxabs
    meta leaf     1

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
        return {<i>x</i> &ge; $0.00}
    }

    method narrative {} {
        return [my DeltaNarrative "Gross Domestic Product"]
    }
}