#-----------------------------------------------------------------------
# TITLE:
#   vardiff_security.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n) variable differences: security.n.g
#
#   A value is the security of group g in nbhood n.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::security {
    superclass ::athena::vardiff
    meta type     security
    meta category political
    meta normfunc 100.0
    meta leaf     1

    constructor {comp_ val1_ val2_ n_ g_} {
        next $comp_ [list n $n_ g $g_] $val1_ $val2_
    }

    method format {val} {
        return [format "%.1f" $val]
    }

    method fancy {val} {
        return [format "%.1f points (%s)" $val [qsecurity longname $val]]
    }

    method context {} {
        return {&minus;100.0 &le; <i>x</i> &le; +100.0}
    }

    method narrative {} {
        return [my DeltaNarrative \
            "Security of [my key g] in neighborhood [my key n]" \
            "security points"]
    }
}