#-----------------------------------------------------------------------
# TITLE:
#   vardiff_pbsat.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: pbsat.set
#
#   Two sets of playbox satisfaction are supported: local and all
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::pbsat {
    superclass ::athena::vardiff
    meta type     pbsat.c.set
    meta category social

    constructor {comp_ val1_ val2_ c_ set_} {
        next $comp_ [list c $c_ set $set_] $val1_ $val2_
    }

    method significant {} {
        set lim 15.0 ;# TBD: Need parameter

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