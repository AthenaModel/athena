#-----------------------------------------------------------------------
# TITLE:
#   vardiff_nbmood.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n) variable differences: nbmood.n
#
#   A value is the mood of the civilian groups residing in 
#   neighborhood n.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::nbmood {
    superclass ::athena::vardiff
    meta type       nbmood
    meta category   social
    meta normfunc   100.0
    meta primary    1
    meta inputTypes {sat population saliency}

    constructor {comp_ val1_ val2_ n_} {
        next $comp_ [list n $n_] $val1_ $val2_
    }

    method format {val} {
        return [format %.1f $val]
    }

    method fancy {val} {
        return [format "%.1f points (%s)" $val [qsat longname $val]]
    }

    method context {} {
        return {&minus;100.0 &le; <i>x</i> &le; +100.0}
    }

    method narrative {} {
        return [my DeltaNarrative "Mood of neighborhood [my key n]" \
            "satisfaction points"]
    }



    #-------------------------------------------------------------------
    # Input Differences
    
    method FindInputs {} {
        variable comp

        set n [my key n]

        # FIRST, get the satisfaction and saliency inputs.
        $comp eval {
            SELECT g, c, sat1, sat2, saliency1, saliency2 
            FROM comp_sat WHERE n = $n
        } {
            my AddInput sat      $sat1      $sat2      $g $c
            my AddInput saliency $saliency1 $saliency2 $g $c
        }

        # NEXT, get the population inputs
        $comp eval {
            SELECT g, pop1, pop2 FROM comp_civg WHERE n = $n
        } {
            my AddInput population $pop1 $pop2 $g
        }
    }

}