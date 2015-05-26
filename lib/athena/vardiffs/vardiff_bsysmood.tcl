#-----------------------------------------------------------------------
# TITLE:
#   vardiff_bsysmood.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: bsysmood.b
#
#   A value is the mood of those civilian groups having belief system b.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::bsysmood {
    superclass ::athena::vardiff
    meta type     bsysmood
    meta category social

    constructor {comp_ val1_ val2_ b_} {
        next $comp_ [list b $b_] $val1_ $val2_
    }

    method significant {} {
        set lim 20.0 ;# TBD: Need parameter

        expr {[my score] >= $lim}
    }

    method format {val} {
        return [qsat longname $val]
    }

    method context {} {
        format "%.1f vs %.1f" [my val1] [my val2]
    }

    method score {} {
        format "%.1f" [next]
    }
}