#-----------------------------------------------------------------------
# TITLE:
#   vardiff_mood.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: mood.g
#
#   A value is the mood of group g.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::mood {
    superclass ::athena::vardiff
    meta type       mood
    meta category   social
    meta normfunc   100.0
    meta primary    1
    meta inputTypes {sat population}

    constructor {comp_ val1_ val2_ g_} {
        next $comp_ [list g $g_] $val1_ $val2_
    }

    method format {val} {
        return [format %.1f $val]
    }

    method fancy {val} {
        return [format "%.1f points (%s)" $val [qsat longname $val]]
    }

    method context {} {
        return {&minus;100.0 &le; <i>x</i> &le; &plus;100.0}
    }

    method narrative {} {
        return [my DeltaNarrative "Mood of group [my key g]" \
            "satisfaction points"]
    }



    #-------------------------------------------------------------------
    # Input Differences
    

    method FindInputs {} {
        variable comp

        set g [my key g]

        # FIRST, get the satisfaction inputs.
        $comp eval {
            SELECT c, sat1, sat2 FROM comp_sat WHERE g=$g
        } {
            my AddInput sat $sat1 $sat2 $g $c
        }

        # NEXT, get the population inputs
        $comp eval {
            SELECT pop1, pop2 FROM comp_civg WHERE g=$g
        } {
            my AddInput population $pop1 $pop2 $g
        }
    }
}