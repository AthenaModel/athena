#-----------------------------------------------------------------------
# TITLE:
#   vardiff_nbunemp.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: nbunemp.n
#
#   A value is the unemployment rate in neighborhood n, as a percentage.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::nbunemp {
    superclass ::athena::vardiff
    meta type     nbunemp
    meta category economic
    meta normfunc maxabs
    meta leaf     1

    constructor {comp_ val1_ val2_ n_} {
        next $comp_ [list n $n_] $val1_ $val2_
    }

    method format {val} {
        return [format "%.2f%%" $val]
    }

    method narrative {} {
        return [my DeltaNarrative \
            "Unemployment rate in neighborhood [my key n]"]
    }

    method context {} {
        return {<i>x</i> &ge; &plus;0.0%}
    }
}