#-----------------------------------------------------------------------
# TITLE:
#   vardiff_sat.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: sat.g.c
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::sat {
    superclass ::athena::vardiff
    meta type     sat.g.c
    meta category social

    constructor {comp_ val1_ val2_ g_ c_} {
        next $comp_ [list g $g_ c $c_] $val1_ $val2_
    }

    method significant {} {
        set lim 25.0 ;# TBD: Need parameter

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