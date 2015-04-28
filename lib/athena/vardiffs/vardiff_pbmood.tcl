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
#   Two sets of playbox mood are supported: local and all
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::pbmood {
    superclass ::athena::vardiff
    meta type     pbmood.set
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