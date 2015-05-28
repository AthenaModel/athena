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
#   A value is the vertical relationship of group g with actor a.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::vrel {
    superclass ::athena::vardiff
    meta type     vrel
    meta category social

    constructor {comp_ val1_ val2_ g_ a_} {
        next $comp_ [list g $g_ a $a_] $val1_ $val2_
    }

    method significant {} {
        set lim [athena::compdb get [my type].limit]

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