#-----------------------------------------------------------------------
# TITLE:
#    simevent_flood.tcl
#
# AUTHOR:
#    Will Duquette
#
# PACKAGE:
#   wintel(n) -- package for athena(1) intel ingestion wizard.
#
# PROJECT:
#   Athena Regional Stability Simulation
#
# DESCRIPTION:
#    athena_sim(1): Simulation Event, FLOOD
#
#    This module implements the FLOOD event, which represents
#    a flood in a neighborhood at a particular week.
#
#    The "midlist", neighborhood, and start week are usually set on 
#    creation.
# 
#-----------------------------------------------------------------------

# FIRST, create the class.
::wintel::simevent define FLOOD "Flood" {
    A "Flood" event represents a natural disaster consisting of
    serious flooding in a neighborhood with attendant loss of life.

    Set the "Duration" parameter to the length of the flooding in weeks;
    set the "Coverage" parameter to the fraction of the neighborhood's
    residents who are aware of the flood and whose attitudes are affected
    by it (nominally 1.0).<p>

} {
    A "Flood" event is represented in Athena as a "block" in a
    the SYSTEM agent's strategy.  The block will contain an
    ABSIT tactic that will create a DISASTER abstract situation
    at the requested time for the requested duration.  See the <i>Athena
    Rules Document</i> for the attitude affects of this situation.
} {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    #
    # No type-specific parameters.

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Initialize as a event bean.
        next

        my set coverage 1.0

        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    method narrative {} {
        set t(n) [nbhood fullname [my get n]]
        set pcov [string trim [percent [my get coverage]]]
        
        set text "Flood in $t(n) ($pcov)"

        if {[my get duration] > 1} {
            append text " for [my get duration] weeks"
        }

        append text "."
    }

    method sendevent {} {
        my tactic [my block SYSTEM 1] ABSIT \
            stype    DISASTER               \
            n        [my get n]             \
            coverage [my get coverage]      \
            resolver NONE                   \
            duration [my get duration]
    }
}


#-----------------------------------------------------------------------
# EVENT:* orders

# SIMEVENT:FLOOD
#
# Updates existing FLOOD event.

order define SIMEVENT:FLOOD {
    title "Event: Flooding in Neighborhood"
    options -sendstates WIZARD

    form {
        rcc "Event ID" -for event_id
        text event_id -context yes \
            -loadcmd {beanload}

        rcc "Duration:" -for duration
        text duration -defvalue 1
        label "week(s)"

        rcc "Coverage:" -for coverage
        posfrac coverage
        label "Fraction of neighborhood"
    }
} {
    # FIRST, prepare the parameters
    prepare event_id  -required -with {::pot valclass ::wintel::simevent::FLOOD}
    prepare duration  -num      -type ipositive
    prepare coverage  -num      -type rposfrac
 
    returnOnError -final

    # NEXT, update the event.
    set e [::pot get $parms(event_id)]
    $e update_ {duration coverage} [array get parms]

    return
}






