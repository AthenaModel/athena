#-----------------------------------------------------------------------
# TITLE:
#   vardiff_saliency.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: saliency.g.c
#
#   A value is civilian group g's saliency wrt concern c.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::saliency {
    superclass ::athena::vardiff
    meta type       saliency
    meta category   social
    meta normfunc   1.0
    meta primary    0
    meta leaf       1
    meta inputTypes {}

    constructor {comp_ val1_ val2_ g_ c_} {
        next $comp_ [list g $g_ c $c_] $val1_ $val2_
    }

    method format {val} {
        return [format %.1f $val]
    }

    method fancy {val} {
        return [format "%.1f (%s)" $val [qsaliency longname $val]]
    }

    method context {} {
        return {0.0 &le; <i>x</i> &le; +1.0}
    }

    method narrative {} {
        return [my DeltaNarrative \
            "Saliency of concern [my key c] for group [my key g]"]
    }
}