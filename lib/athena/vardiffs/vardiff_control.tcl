#-----------------------------------------------------------------------
# TITLE:
#   vardiff_control.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n) history variable differences: control.n.
#
#   A value is the name of the actor controlling the neighborhood, or
#   "" if none.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::control {
    superclass ::athena::vardiff
    meta type     control
    meta category political

    constructor {comp_ val1_ val2_ n_} {
        next $comp_ [list n $n_] $val1_ $val2_  
    }

    method score {} {
        return 100.0
    }

    method format {val} {
        if {$val ne ""} {
            return $val
        } else {
            return "*NONE*"
        }
    }

    method fancy {val} {
        if {$val ne ""} {
            return "Actor $val is in control"
        } else {
            return "No actor is in control"
        }
    }

    method delta {} {}  ;# Delta doesn't make sense here.

    method narrative {} {
        return "Neighborhood [my key n] was controlled by [my fmt1], is controlled by [my fmt2]."
    }
}

