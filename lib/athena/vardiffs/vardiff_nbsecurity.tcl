#-----------------------------------------------------------------------
# TITLE:
#   vardiff_nbsecurity.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n) history variable differences: nbsecurity.n
#
#   A value is the average security of all civilian groups resident in
#   neighborhood n.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::nbsecurity {
    superclass ::athena::vardiff
    meta type       nbsecurity
    meta category   military
    meta normfunc   100.0
    meta primary    1
    meta inputTypes {population security}

    constructor {comp_ val1_ val2_ n_} {
        next $comp_ [list n $n_] $val1_ $val2_
    }

    method format {val} {
        return [format %.1f $val]
    }

    method fancy {val} {
        return [format "%.1f points (%s)" $val [qsecurity longname $val]]
    }

    method context {} {
        return {&minus;100.0 &le; <i>x</i> &le; +100.0}
    }

    method narrative {} {
        return [my DeltaNarrative \
            "Security of population in neighborhood [my key n]" \
            "security points"]
    }

    #-------------------------------------------------------------------
    # Input Differences
    
    method FindInputs {} {
        variable comp

        set n [my key n]

        # NEXT, get the population inputs
        $comp eval {
            SELECT g, pop1, pop2 FROM comp_civg WHERE n = $n
        } {
            my AddInput population $pop1 $pop2 $g
        }

        $comp eval {
            SELECT n, g, security1, security2 FROM comp_nbgroup
            WHERE n = $n 
        } {
            my AddInput security $security1 $security2 $n $g
        }
    }
}

