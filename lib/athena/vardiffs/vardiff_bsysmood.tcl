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
    meta normfunc 100.0
    meta afactors {
        sat        1.0
        population 1.0
    }

    constructor {comp_ val1_ val2_ b_} {
        next $comp_ [list b $b_] $val1_ $val2_
    }

    method format {val} {
        return [format "%.1f" $val]
    }

    method fancy {val} {
        return [format "%.1f points (%s)" $val [qsat longname $val]]
    }

    method context {} {
        return {&minus;100.0 &le; <i>x</i> &le; &plus;100.0}
    }

    method narrative {} {
        return [my DeltaNarrative \
            "The mood of groups having belief system [my key b]" \
            "satisfaction points"]
    }

    #-------------------------------------------------------------------
    # Input Differences
    
    method FindInputs {} {
        variable comp

        set bsid [string range [my key b] 1 end]

        # FIRST, get the satisfaction inputs.
        $comp eval {
            SELECT g, c, sat1, sat2 FROM comp_sat WHERE bsid = $bsid
        } {
            my AddInput sat $sat1 $sat2 $g $c
        }

        # NEXT, get the population inputs
        $comp eval {
            SELECT g, pop1, pop2 FROM comp_civg WHERE bsid = $bsid
        } {
            my AddInput population $pop1 $pop2 $g
        }
    }
}