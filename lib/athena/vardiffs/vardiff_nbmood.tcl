#-----------------------------------------------------------------------
# TITLE:
#   vardiff_nbmood.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n) variable differences: nbmood.n
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::nbmood {
    superclass ::athena::vardiff
    meta type nbmood.n

    constructor {comp_ n_ val1_ val2_} {
        next $comp_ [list n $n_] $val1_ $val2_
    }

    method significant {} {
        expr {[my score] >= 10.0}
    }

    method format {val} {
        return [qsat longname $val]
    }

    method context {} {
        format "%.1f vs %.1f" [my val1] [my val2]
    }
}