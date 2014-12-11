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

oo::class create ::bsys::BSYS:PLAYBOX:UPDATE {
    superclass ::projectlib::orderx

    meta title      "Update Playbox-wide Belief System Parameters"
    meta sendstates {PREP}
    meta form       {}

    constructor {} {
        my defparm gamma 1.0
        next
    }

    # Q: How would I do a returnOnError if I needed to?
    method CheckParms {} {
        my prepare gamma -required -num -type ::simlib::rmagnitude
    }

    method ExecuteOrder {} {
        my setundo [bsys mutate update playbox "" [my getdict]]
        return
    }

}

oo::class create ::bsys::BSYS:SYSTEM:ADD {
    superclass ::projectlib::orderx

    meta title      "Add New Belief System"
    meta sendstates {PREP}
    meta form       {}

    constructor {} {
        my defparm sid
        next
    }

    method CheckParms {} {
        my variable parms

        my prepare sid -num -type ::marsutil::count

        my returnOnError

        my validate sid {
            if {$parms(sid) in [bsys system ids]} {
                my reject sid \
                    "Belief system ID is already in use: \"$parms(sid)\""
            }
        }
    }

    method ExecuteOrder {} {
        my variable parms
        lassign [::bsys mutate add system $parms(sid)] sid undoScript
        my setundo $undoScript
        return
    }

}
