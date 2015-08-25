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
    meta normfunc 1.0
    meta leaf     1

    constructor {comp_ val1_ val2_ n_} {
        next $comp_ [list n $n_] $val1_ $val2_
    }

    method trivial {} {
        # Non-trivial if the actor ranking by influence has changed in the
        # neighborhood.
        expr {[my fmt1] eq [my fmt2]}
    }

    method format {val} {
        if {[dict size $val] == 0} {
            return "*NONE*"
        }

        return [dict keys [lsort -stride 2 -index 1 -decreasing -real $val]]
    }

    method fancy {val} {
        if {[dict size $val] == 0} {
            return "No actor has influence"
        }

        set result ""
        foreach a [dict keys [lsort -stride 2 -index 1 -decreasing -real $val]] {
            lappend result "$a ([format %.2f [dict get $val $a]])"
        }

        return [join $result ", "] 
    }

    method delta {} {
        # At present, any difference in rank ordering is important.
        return 1.0
    }  

    method context {} {
        return {&minus;1.0 &le; <i>x</i> &le; +1.0}
    }

    method narrative {} {
        append result \
            "In neighborhood [my key n], influence ranking was (" \
            [join [my fmt1] ", "] \
            "), is (" \
            [join [my fmt2] ", "] \
            ")." 
    }

}

