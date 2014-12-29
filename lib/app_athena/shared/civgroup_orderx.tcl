#-----------------------------------------------------------------------
# TITLE:
#    civgroup_orderx.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_athena(n): Civgroup Orders
#
#    This is an experimental mock-up of what the civilian group orders
#    might look like using the orderx order processing scheme.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# civgroup Order Classes

myorders define BSYS:PLAYBOX:UPDATE {
    superclass ::projectlib::orderx

    meta title      "Update Playbox-wide Belief System Parameters"
    meta sendstates {PREP}
    meta defaults   {
        gamma 1.0
    }

    method narrative {} {
        return "Set Playbox Gamma to [format %g [my get gamma]]"
    }

    method _validate {} {
        my prepare gamma -required -num -type ::simlib::rmagnitude
    }

    method _execute {{flunky ""}} {
        my setundo [bsys mutate update playbox "" [my getdict]]
        return
    }

}


