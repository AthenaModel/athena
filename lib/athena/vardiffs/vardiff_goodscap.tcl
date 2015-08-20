#-----------------------------------------------------------------------
# TITLE:
#   vardiff_goodscap.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: goodscap.n
#
#   A value is the GOODS production capacity of neighborhood n, in
#   dollars.
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::goodscap {
    superclass ::athena::vardiff
    meta type       goodscap
    meta category   economic
    meta normfunc   maxsum
    meta primary    1
    meta leaf       1
    meta inputTypes {}

    constructor {comp_ val1_ val2_ n_} {
        next $comp_ [list n $n_] $val1_ $val2_
    }

    method format {val} {
        return [moneyfmt $val]
    }

    method context {} {
        return {<i>x</i> &ge; $0.00}
    }

    method narrative {} {
        return [my DeltaNarrative "Production capacity"]
    }
}