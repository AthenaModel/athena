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
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::bsysmood {
    superclass ::athena::vardiff
    meta type     bsysmood.b
    meta category social

    constructor {comp_ val1_ val2_ n_} {
        next $comp_ [list n $n_] $val1_ $val2_
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
