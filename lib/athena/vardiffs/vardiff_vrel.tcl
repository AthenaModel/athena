#-----------------------------------------------------------------------
# TITLE:
#   vardiff_vrel.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: vrel.g.a
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::vrel {
    superclass ::athena::vardiff
    meta type     vrel.g.a
    meta category social

    constructor {comp_ val1_ val2_ g_ a_} {
        next $comp_ [list g $g_ a $a_] $val1_ $val2_
    }

    method significant {} {
        set lim 0.2 ;# TBD: Need parameter

        expr {[my score] >= $lim}
    }

    method format {val} {
        return [qrel longname $val]
    }

    method context {} {
        format "%.1f vs %.1f" [my val1] [my val2]
    }

    method score {} {
        format "%.1f" [next]
    }
}