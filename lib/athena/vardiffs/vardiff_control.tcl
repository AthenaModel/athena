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
#   A value is the name of an actor controlling the neighborhood, or
#   "" if none.
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff::control {
    superclass ::athena::vardiff
    meta type control.n

    constructor {comp_ n_ val1_ val2_} {
        next $comp_ [list n $n_]  $val1_ $val2_
    }

    method score {} {
        return 1
    }

    method format {val} {
        if {$val ne ""} {
            return $val
        } else {
            return "*NONE*"
        }
    }
}

