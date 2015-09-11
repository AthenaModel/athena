#-----------------------------------------------------------------------
# TITLE:
#   vardiff_bsyssat.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: bsyssat.b.c
#
#   A value is a composite satisfaction with concern c across civilian 
#   groups having belief system b.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::bsyssat {
    superclass ::athena::vardiff
    meta type       bsyssat
    meta category   social
    meta normfunc   100.0
    meta primary    1
    meta inputTypes {sat population saliency}

    constructor {comp_ val1_ val2_ b_ c_} {
        next $comp_ [list b $b_ c $c_] $val1_ $val2_
    }

    method format {val} {
        return [format "%.1f" $val]
    }

    method fancy {val} {
        return [format "%.1f points (%s)" $val [qsat longname $val]]
    }

    method context {} {
        return {&minus;100.0 &le; <i>x</i> &le; +100.0}
    }

    method narrative {} {
        return [my DeltaNarrative \
"The satisfaction with respect to [my key c] of groups having belief system [my key b]" \
                "satisfaction points"]
    }


    #-------------------------------------------------------------------
    # Input Differences
    
    method FindInputs {} {
        variable comp

        set bsid [string range [my key b] 1 end]
        set c    [my key c]

        # FIRST, get the satisfaction inputs.
        $comp eval {
            SELECT g, c, sat1, sat2, saliency1, saliency2
            FROM comp_sat WHERE bsid = $bsid AND c = $c
        } {
            my AddInput sat      $sat1      $sat2      $g $c
            my AddInput saliency $saliency1 $saliency2 $g $c
        }

        # NEXT, get the population inputs
        $comp eval {
            SELECT g, pop1, pop2 FROM comp_civg WHERE bsid = $bsid
        } {
            my AddInput population $pop1 $pop2 $g
        }
    }
}