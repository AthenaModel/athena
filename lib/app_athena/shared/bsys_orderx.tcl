#-----------------------------------------------------------------------
# TITLE:
#    bsystem_orderx.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_athena(n): Belief System Orders
#
#    This is an experimental mock-up of what the belief system orders
#    might look like using the orderx order processing scheme.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# BSys Order Classes

myorders define BSYS:PLAYBOX:UPDATE {
    superclass ::athena_order

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

myorders define BSYS:SYSTEM:ADD {
    superclass ::athena_order

    meta title      "Add New Belief System"
    meta sendstates PREP
    meta defaults   {
        sid ""
    }

    method _validate {} {
        my prepare sid -num -type ::marsutil::count
        my returnOnError

        my checkon sid {
            if {$parms(sid) in [bsys system ids]} {
                my reject sid \
                    "Belief system ID is already in use: \"$parms(sid)\""
            }
        }
    }

    method _execute {{flunky ""}} {
        lassign [::bsys mutate add system $parms(sid)] sid undo
        my setundo $undo
        return
    }
}


myorders define BSYS:SYSTEM:UPDATE {
    superclass ::athena_order

    meta title      "Update Belief System Metadata"
    meta sendstates PREP
    meta defaults   {
        sid         ""
        name        ""
        commonality ""
    }
    meta form       {
        rcc "System ID:" -for sid
        text sid -context yes \
            -loadcmd {bsys::viewload system}

        rcc "Name:" -for name
        text name

        rcc "Commonality Fraction:" -for commonality
        range commonality          \
            -datatype    rfraction \
            -showsymbols no        \
            -resetvalue  1.0 
    }

    method _validate {} {
        my prepare sid          -required -toupper -type {bsys editable}
        my prepare name
        my prepare commonality            -num     -type ::simlib::rfraction

        my returnOnError

        my checkon name {
            set oldID [bsys system id $parms(name)]
            if {$oldID ne "" && $oldID ne $parms(sid)} {
                my reject name \
                    "name is in use by another system: \"$parms(name)\""
            }
        }
    }

    method _execute {{flunky ""}} {
        my setundo [bsys mutate update system $parms(sid) [array get parms]]

        return
    }
}

