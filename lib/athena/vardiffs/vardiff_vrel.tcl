#-----------------------------------------------------------------------
# TITLE:
#   vardiff_vrel.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: vrel.g.a
#
#   A value is the vertical relationship of group g with actor a.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::vrel {
    superclass ::athena::vardiff
    meta type     vrel
    meta category political
    meta normfunc 1.0
    meta afactors {
        drivervrel 1.0
    }

    constructor {comp_ val1_ val2_ g_ a_} {
        next $comp_ [list g $g_ a $a_] $val1_ $val2_
    }

    method format {val} {
        return [format %.2f $val]
    }

    method fancy {val} {
        return [format "%.2f (%s)" $val [qrel longname $val]]
    }

    method context {} {
        return {&minus;1.0 &le; <i>x</i> &le; &plus;1.0}
    }

    method narrative {} {
        return [my DeltaNarrative \
            "Vertical relationship of group [my key g] with actor [my key a]"]
    }

    #-------------------------------------------------------------------
    # Input Differences

    method FindInputs {} {
        variable comp

        set g [my key g]
        set a [my key a]

        # FIRST, get the contributions
        foreach {drid val1 val2} [$comp contribs vrel $g $a] {
            my AddInput drivervrel $val1 $val2 $g $a $drid
        }
    }

}