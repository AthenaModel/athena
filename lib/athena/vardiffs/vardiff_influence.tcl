#-----------------------------------------------------------------------
# TITLE:
#   vardiff_influence.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) history variable differences: influence.n.a
#
#   The value is the influence an actor a has in neighborhood n.
#
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::influence {
    superclass ::athena::vardiff
    meta type       influence
    meta category   political
    meta normfunc   1.0
    meta leaf       1
    meta primary    1
    meta inputTypes {}

    constructor {comp_ val1_ val2_ n_ a_} {
        next $comp_ [list n $n_ a $a_] $val1_ $val2_
    }

    method format {val} {
        return [format %.2f $val]
    }

    method fancy {val} {
        return [my format $val]
    }

    method context {} {
        return {0.0 &le; <i>x</i> &le; 1.0}
    }

    method narrative {} {
        return [my DeltaNarrative \
            "Influence of actor [my key a] in neighborhood [my key n]"]
    }

}

