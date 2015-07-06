#-----------------------------------------------------------------------
# TITLE:
#   vardiff_pbsat.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: pbsat.c.set
#
#   The value is the composite satisfaction with concern c across one
#   of two sets: "all" civilian groups, and "local" groups,
#   those residing in local neighborhoods.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::pbsat {
    superclass ::athena::vardiff
    meta type     pbsat
    meta category social

    constructor {comp_ val1_ val2_ c_ set_} {
        next $comp_ [list c $c_ set $set_] $val1_ $val2_
    }

    method IsSignificant {} {
        set lim [athena::compdb get [my type].limit]

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

    #-------------------------------------------------------------------
    # Input Differences
    
    method FindDiffs {} {
        variable comp

        set c     [my key c]
        set local [expr {[my key set] eq "local"}]

        # FIRST, get the satisfaction inputs.
        $comp eval {
            SELECT g, sat1, sat2 FROM comp_sat WHERE c = $c AND local=$local
        } {
            my diffadd sat $sat1 $sat2 $g $c
        }

        # NEXT, get the population inputs
        $comp eval {
            SELECT g, pop1, pop2 FROM comp_civg WHERE local=$local
        } {
            my diffadd population $pop1 $pop2 $g
        }
    }

}