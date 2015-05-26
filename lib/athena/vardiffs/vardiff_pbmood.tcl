#-----------------------------------------------------------------------
# TITLE:
#   vardiff_pbmood.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: pbmood.set
#
#   The value is the average mood of the civilian groups in the playbox,
#   across one of two sets: "all" civilian groups, and "local" groups,
#   those residing in local neighborhoods.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::pbmood {
    superclass ::athena::vardiff
    meta type     pbmood
    meta category social

    constructor {comp_ val1_ val2_ set_} {
        next $comp_ [list set $set_] $val1_ $val2_
    }

    method significant {} {
        set lim 10.0 ;# TBD: Need parameter

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