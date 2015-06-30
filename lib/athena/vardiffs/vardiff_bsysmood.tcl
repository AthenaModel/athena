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
#   A value is the mood of those civilian groups having belief system b.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::bsysmood {
    superclass ::athena::vardiff
    meta type     bsysmood
    meta category social

    constructor {comp_ val1_ val2_ b_} {
        next $comp_ [list b $b_] $val1_ $val2_
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

        set bsid [string range [my key b] 1 end]

        # FIRST, get the satisfaction inputs.
        $comp eval {
            SELECT g, c, sat1, sat2 FROM comp_sat WHERE bsid = $bsid
        } {
            my diffadd sat $sat1 $sat2 $g $c
        }

        # NEXT, get the population inputs
        $comp eval {
            SELECT g, pop1, pop2 FROM comp_civg WHERE bsid = $bsid
        } {
            my diffadd population $pop1 $pop2 $g
        }
    }
}