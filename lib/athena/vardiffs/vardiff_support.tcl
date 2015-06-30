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

    constructor {comp_ val1_ val2_ n_ a_} {
        next $comp_ [list n $n_ a $a_] $val1_ $val2_
    }

    method score {} {
        my variable val1
        my variable val2

        let score {
            100.0 - 100.0*(min(double($val1),double($val2))/max($val1,$val2))
        }

        return [my format $score]
    }


    method IsSignificant {} {
        set lim [athena::compdb get [my type].limit]

        expr {[my score] >= $lim}
    }

    method format {val} {
        format %.1f $val
    }

    #-------------------------------------------------------------------
    # Input Differences

    method FindDiffs {} {
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
            my diffadd population $pop1 $pop2 $g
        }

        # NEXT, get the personnel figures for non-civgroups in n.
        $comp eval "
            SELECT g, personnel1, personnel2 FROM comp_nbgroup
            WHERE n = :n
            AND gtype != 'CIV'
        " {
            lappend glist $g
            my diffadd personnel $personnel1 $personnel2 $n $g
        }

        # NEXT, get the security figures for groups in n.
        $comp eval "
            SELECT g, security1, security2 FROM comp_nbgroup
            WHERE n = :n
            AND g IN ('[join $glist ',']')
        " {
            let diff {abs($security1 - $security2)}
            puts "security $n $g $security1 $security2 $diff"
            my diffadd security $security1 $security2 $n $g
        }

        # NEXT, get the vertical relationships.
        $comp eval "
            SELECT g, a AS b, vrel1, vrel2 FROM comp_vrel 
            WHERE g IN ('[join $glist ',']') 
            AND   a IN ('[join $alist ',']')
        " {
            my diffadd vrel $vrel1 $vrel2 $g $b
        }
    }

}

