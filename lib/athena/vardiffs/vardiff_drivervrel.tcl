#-----------------------------------------------------------------------
# TITLE:
#   vardiff_drivervrel.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n) variable differences: drivervrel.g.a.drid
#
#   A value is the total contribution of a driver to a particular curve.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::drivervrel {
    superclass ::athena::vardiff
    meta type     drivervrel
    meta category political
    meta normfunc maxabs
    meta leaf     1

    constructor {comp_ val1_ val2_ g_ a_ drid_} {
        next $comp_ [list g $g_ a $a_ drid $drid_] $val1_ $val2_
    }

    method format {val} {
        return [format %.01f $val]
    }

    method context {} {
        return {<i>x</i> &ge; 0.0}
    }

    method narrative {} {
        return [my DeltaNarrative \
            "Total contribution by driver [my key drid] to group [my key g]'s relationship with actor [my key a]"  \
            "satisfaction points"]
    }
}