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

    method IsSignificant {} {
        set lim [athena::compdb get [my type].limit]

        expr {[my score] >= $lim}
    }

    method format {val} {
        return [format %.1f $val]
    }

    method context {} {
        format "%.1f vs %.1f" [my val1] [my val2]
    }

    method score {} {
        format "%.1f" [next]
    }

    method narrative {} {
        return [my DeltaNarrative "Mood of the population of the playbox" \
            "satisfaction points"]
    }

    #-------------------------------------------------------------------
    # Input Differences
    

    method FindDiffs {} {
        variable comp

        set local [expr {[my key set] eq "local"}]

        # FIRST, get the satisfaction inputs.
        $comp eval {
            SELECT g, c, sat1, sat2 FROM comp_sat WHERE local = $local
        } {
            my diffadd sat $sat1 $sat2 $g $c
        }

        # NEXT, get the population inputs
        $comp eval {
            SELECT g, pop1, pop2 FROM comp_civg WHERE local = $local
        } {
            my diffadd population $pop1 $pop2 $g
        }
    }
}