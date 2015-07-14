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
    meta type     nbsecurity
    meta category political

    constructor {comp_ val1_ val2_ n_} {
        next $comp_ [list n $n_] $val1_ $val2_
    }

    method IsSignificant {} {
        set lim [athena::compdb get [my type].limit]

        set sym1 [qsecurity name [my val1]]
        set sym2 [qsecurity name [my val2]]

        expr {$sym1 ne $sym2 || [my score] >= $lim}
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

    method score {} {
        my format [next]
    }


    method narrative {} {
        return [my DeltaNarrative \
            "Security of population in neighborhood [my key n]" \
            "security points"]
    }
}

