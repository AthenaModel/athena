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
    meta normfunc maxsum

    constructor {comp_ val1_ val2_ g_} {
        next $comp_ [list g $g_] $val1_ $val2_
    }

    method narrative {} {
        return [my DeltaNarrative "Population of group [my key g]"]
    }

    method context {} {
        return {<i>x</i> &ge; 0}
    }
}