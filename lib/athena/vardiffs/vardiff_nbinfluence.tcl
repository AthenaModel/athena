#-----------------------------------------------------------------------
# TITLE:
#   vardiff_nbinfluence.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n) history variable differences: nbinfluence.n
#
#   The value is a dictionary of actors and their influences in the
#   the neighborhood; it includes only actors whose influence is positive.
#
#   The formatted value is a list of the actors by descending influence.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::nbinfluence {
    superclass ::athena::vardiff
    meta type     nbinfluence
    meta category political

    constructor {comp_ val1_ val2_ n_} {
        next $comp_ [list n $n_] $val1_ $val2_
    }

    method IsSignificant {} {
        expr {[my fmt1] ne [my fmt2]}
    }

    method score {} {
        return 1
    }

    method format {val} {
        if {[dict size $val] == 0} {
            return "*NONE*"
        }

        return [dict keys [lsort -stride 2 -index 1 -decreasing -real $val]]
    }
}

