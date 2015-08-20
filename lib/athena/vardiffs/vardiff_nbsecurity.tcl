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
    meta category   political
    meta normfunc   100.0
    meta leaf       1
    meta primary    1
    meta inputTypes {}

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
        return {&minus;100.0 &le; <i>x</i> &le; &plus;100.0}
    }

    method narrative {} {
        return [my DeltaNarrative \
            "Security of population in neighborhood [my key n]" \
            "security points"]
    }
}

