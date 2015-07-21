#-----------------------------------------------------------------------
# TITLE:
#   vardiff_support.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n) history variable differences: support.n.a
#
#   A value is the support of neighborhood n for actor a.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::support {
    superclass ::athena::vardiff
    meta type     support
    meta category political
    meta normfunc 1.0
    meta afactors {
        population 1.0
        personnel  1.0
        security   1.0
        vrel       1.0
    }

    constructor {comp_ val1_ val2_ n_ a_} {
        next $comp_ [list n $n_ a $a_] $val1_ $val2_
    }

    method format {val} {
        format "%.2f" $val
    }

    method context {} {
        return {<i>x</i> &ge; 0.0}
    }

    #-------------------------------------------------------------------
    # Input Differences

    method FindInputs {} {
        variable comp

        set n [my key n]
        set a [my key a]

        # FIRST, get the list of actors who support actor a in n.
        # TBD: We don't have history for that, yet.  For now, assume
        # that a supports a.
        set alist [list $a]

        # NEXT, get the population for civgroups in n.
        set glist [list]

        $comp eval {
            SELECT g, pop1, pop2 FROM comp_civg WHERE n = $n
        } {
            lappend glist $g
            my AddInput population $pop1 $pop2 $g
        }

        # NEXT, get the personnel figures for non-civgroups in n.
        $comp eval "
            SELECT g, personnel1, personnel2 FROM comp_nbgroup
            WHERE n = :n
            AND gtype != 'CIV'
        " {
            lappend glist $g
            my AddInput personnel $personnel1 $personnel2 $n $g
        }

        # NEXT, get the security figures for groups in n.
        $comp eval "
            SELECT g, security1, security2 FROM comp_nbgroup
            WHERE n = :n
            AND g IN ('[join $glist ',']')
        " {
            let diff {abs($security1 - $security2)}
            my AddInput security $security1 $security2 $n $g
        }

        # NEXT, get the vertical relationships.
        $comp eval "
            SELECT g, a AS b, vrel1, vrel2 FROM comp_vrel 
            WHERE g IN ('[join $glist ',']') 
            AND   a IN ('[join $alist ',']')
        " {
            my AddInput vrel $vrel1 $vrel2 $g $b
        }
    }

    method narrative {} {
        return [my DeltaNarrative \
            "Support for actor [my key a] from neighborhood [my key n]"]
    }

}

