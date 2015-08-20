#-----------------------------------------------------------------------
# TITLE:
#   vardiff_sat.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: sat.g.c
#
#   A value is civilian group g's satisfaction with concern c.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::sat {
    superclass ::athena::vardiff
    meta type       sat
    meta category   social
    meta normfunc   100.0
    meta primary    1
    meta inputTypes {driversat}

    constructor {comp_ val1_ val2_ g_ c_} {
        next $comp_ [list g $g_ c $c_] $val1_ $val2_
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
        return [my DeltaNarrative \
            "Satisfaction of group [my key g] with [my key c]" \
            "satisfaction points"]
    }

    #-------------------------------------------------------------------
    # Input Differences

    method FindInputs {} {
        variable comp

        set g [my key g]
        set c [my key c]

        # FIRST, get the contributions
        foreach {drid val1 val2} [$comp contribs sat $g $c] {
            my AddInput driversat $val1 $val2 $g $c $drid
        }

        # NEXT, SFT depends on security as well (natural level)...but
        # we should managed that as a pseudo-driver.
    }
}