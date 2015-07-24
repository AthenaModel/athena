#-----------------------------------------------------------------------
# TITLE:
#   vardiff_personnel.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n) variable differences: personnel.n.g
#
#   A value is the personnel of FRC/ORG group g in nbhood n.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::personnel {
    superclass ::athena::vardiff
    meta type     personnel
    meta category social
    meta normfunc maxsum
    meta leaf     1

    constructor {comp_ val1_ val2_ n_ g_} {
        next $comp_ [list n $n_ g $g_] $val1_ $val2_
    }

    method narrative {} {
        return [my DeltaNarrative \
            "Personnel of group [my key g] deployed to neighborhood [my key n]"]
    }

    method context {} {
        return {<i>x</i> &ge; 0}
    }


}