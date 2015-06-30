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

    constructor {comp_ val1_ val2_ n_ g_} {
        next $comp_ [list n $n_ g $g_] $val1_ $val2_
    }

    method score {} {
        my variable val1
        my variable val2

        expr {
            100.0 - 100.0*(min(double($val1),double($val2))/max($val1,$val2))
        }
    }

    method IsSignificant {} {
        set lim [athena::compdb get [my type].limit]

        expr {[my score] >= $lim}
    }
}