#-----------------------------------------------------------------------
# TITLE:
#    rolemap.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectlib(n): rolemap Types
#    
#    This module defines the "rolemap" dynaform_field(i) wrapper for
#    the projectgui(n) rolemapfield(n) widget.

#-----------------------------------------------------------------------
# rolemap field type

::marsutil::dynaform fieldtype define rolemap {
    typemethod attributes {} {
        return {
            rolespeccmd 
            textwidth
            listheight
            liststripe
            listwidth
        }
    }

    typemethod validate {idict} {
        dict with idict {}
        require {$rolespeccmd ne ""} \
            "No role specification command given"
    }

    typemethod create {w idict} {
        set context [dict get $idict context]

        rolemapfield $w \
            -state [expr {$context ? "disabled" : "normal"}] \
            {*}[asoptions $idict textwidth listheight liststripe listwidth]
    }

    typemethod reconfigure {w idict vdict} {
        # If the field has a -rolespeccmd, call it and apply the
        # results (note that rolemapfield will properly do nothing
        # if the resulting spec hasn't changed.)
        dict with idict {}

        if {$rolespeccmd ne ""} {
            $w configure -rolespec [formcall $vdict $rolespeccmd] 
        }
    }

    typemethod ready {w idict} {
        return [expr {[llength [$w cget -rolespec]] > 0}]
    }
}


