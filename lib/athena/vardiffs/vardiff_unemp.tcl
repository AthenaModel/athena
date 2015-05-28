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
        return [format "%.1f%%" $val]
    }

    method context {} {
        format "%.1f%%" [expr {[my val1]-[my val2]}]
    }

    method score {} {
        format "%.1f" [next]
    }
}