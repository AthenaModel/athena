#-----------------------------------------------------------------------
# TITLE:
#   vardiff_population.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n) variable differences: population.g
#
#   A value is the population of civilian group g.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::population {
    superclass ::athena::vardiff
    meta type     population
    meta category social

    constructor {comp_ val1_ val2_ g_} {
        next $comp_ [list g $g_] $val1_ $val2_
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