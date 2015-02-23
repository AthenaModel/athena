#-----------------------------------------------------------------------
# TITLE:
#   field_types.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   This package defines dynaform(n) field types for use with 
#   The field widgets defined in projectgui(n).  They need to be defined
#   here, because dynaforms are defined in non-GUI code.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# listbutton field type
#
# This is a dynaform field type that maps to listbutton(n): a 
# compact widget similar to a goferfield(n) for selecting one
# or more entries from a list.

::marsutil::dynaform fieldtype define listbutton {
    typemethod attributes {} {
        return {
             dict dictcmd emptymessage listrows listwidth message
             showmaxitems showkeys stripe width 
        }
    }

    typemethod validate {idict} {
        dict with idict {}
        require {$dict ne "" || $dictcmd ne ""} "No enumeration data given"
    }

    typemethod create {w idict} {
        set context [dict get $idict context]

        set wid [dict get $idict width]

        # This widget works better if the width is negative, setting a
        # minimum size.  Then it can widen to the wraplength.
        if {$wid ne "" && $wid > 0} {
            dict set idict width [expr {-$wid}]
        }

        listbuttonfield $w                                      \
            -itemdict [dict get $idict dict]                    \
            -state    [expr {$context ? "disabled" : "normal"}] \
            {*}[asoptions $idict emptymessage listrows listwidth message \
                showmaxitems showkeys stripe width]
    }

    typemethod reconfigure {w idict vdict} {
        # If the field has a -dictcmd, call it and apply the
        # results (only if they've changed).
        dict with idict {}

        if {$dictcmd ne ""} {
            set itemdict [formcall $vdict $dictcmd]

            if {$itemdict ne [$w cget -itemdict]} {
                $w configure -itemdict $itemdict 
            }
        }
    }

    typemethod ready {w idict} {
        return [expr {[dict size [$w cget -itemdict]] > 0}]
    }

}
