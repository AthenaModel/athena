#-----------------------------------------------------------------------
# TITLE:
#   vardiff_unemp.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: unemp
#
#   A value is the unemployment rate for the playbox, as a percentage.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::unemp {
    superclass ::athena::vardiff
    meta type     unemp
    meta category economic

    constructor {comp_ val1_ val2_} {
        next $comp_ "" $val1_ $val2_
    }

    method IsSignificant {} {
        set lim [athena::compdb get [my type].limit]

        expr {[my score] >= $lim}
    }

    method format {val} {
        return [format "%.2f%%" $val]
    }

    method score {} {
        format "%.2f" [next]
    }

    method narrative {} {
        return [my DeltaNarrative "Unemployment rate"]
    }

    method context {} {
        return {<i>x</i> &ge; &plus;0.0%}
    }


}