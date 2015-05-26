#-----------------------------------------------------------------------
# TITLE:
#   vardiff_mood.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: mood.g
#
#   A value is the mood of group g.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::mood {
    superclass ::athena::vardiff
    meta type     mood
    meta category social

    constructor {comp_ val1_ val2_ g_} {
        next $comp_ [list g $g_] $val1_ $val2_
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