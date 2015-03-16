#-----------------------------------------------------------------------
# TITLE:
#   vardiff_nbsecurity.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n) history variable differences: nbsecurity.n
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::nbsecurity {
    superclass ::athena::vardiff
    meta type nbsecurity.n

    constructor {comp_ n_ val1_ val2_} {
        next $comp_ [list n $n_] $val1_ $val2_
    }

    method significant {} {
        set lim 20 ;# TBD: Need parm

        set sym1 [qsecurity name [my val1]]
        set sym2 [qsecurity name [my val2]]

        expr {$sym1 ne $sym2 || [my score] >= $lim}
    }

    method format {val} {
        return [qsecurity longname $val]
    }

    method context {} {
        format "%d vs %d" [my val1] [my val2]
    }
}

