#-----------------------------------------------------------------------
# TITLE:
#   vardiff_pbmood.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   athena(n) variable differences: pbmood.set
#
#   The value is the average mood of the civilian groups in the playbox,
#   across one of two sets: "all" civilian groups, and "local" groups,
#   those residing in local neighborhoods.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::pbmood {
    superclass ::athena::vardiff
    meta type       pbmood
    meta category   social
    meta normfunc   100.0
    meta primary    1
    meta inputTypes {sat population saliency}

    constructor {comp_ val1_ val2_ set_} {
        puts "pbmood: $val1_ $val2_ $set_"
        next $comp_ [list set $set_] $val1_ $val2_
    }

    method format {val} {
        return [format %.1f $val]
    }

    method fancy {val} {
        return [format "%.1f points (%s)" $val [qsat longname $val]]
    }

    method context {} {
        return {&minus;100.0 &le; <i>x</i> &le; +100.0}
    }

    method narrative {} {
        return [my DeltaNarrative "Mood of the population of the playbox" \
            "satisfaction points"]
    }

    #-------------------------------------------------------------------
    # Input Differences
    

    method FindInputs {} {
        variable comp

        set local [expr {[my key set] eq "local"}]

        # FIRST, get the satisfaction inputs.
        $comp eval {
            SELECT g, c, sat1, sat2, saliency1, saliency2 
            FROM comp_sat WHERE local = $local
        } {
            my AddInput sat      $sat1      $sat2      $g $c
            my AddInput saliency $saliency1 $saliency2 $g $c
        }

        # NEXT, get the population inputs
        $comp eval {
            SELECT g, pop1, pop2 FROM comp_civg WHERE local = $local
        } {
            my AddInput population $pop1 $pop2 $g
        }
    }
}