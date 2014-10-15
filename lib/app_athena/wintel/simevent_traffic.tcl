#-----------------------------------------------------------------------
# TITLE:
#    simevent_traffic.tcl
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
#    athena_sim(1): Simulation Event, TRAFFIC
#
#    This module implements the TRAFFIC event, which represents
#    a transportation network blockage or breakdown in a neighborhood at 
#    a particular week.
# 
#-----------------------------------------------------------------------

# FIRST, create the class.
::wintel::simevent define TRAFFIC "Traffic" {
    A "Traffic" event represents a significant disturbance or 
    blockage of the transportation network which causes hardship on 
    civilian groups.  The event will affect all groups in the neighborhood.<p>

    Set the "Duration" parameter to the length of the congestion in weeks;
    set the "Coverage" parameter to the fraction of the neighborhood's
    residents who are aware of the problem and whose attitudes are affected
    by it (nominally 1.0).<p>

} {
    A "Traffic" event is represented in Athena as a "block" in the 
    SYSTEM agent's strategy.  The block will contain an ABSIT tactic
    that creates a TRAFFIC abstract situation.  See the <i>Athena
    Rules Document</i> for the attitude affects of this situation.<p>
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

        set text "Traffic in $t(n) ($pcov)"

        if {[my get duration] > 1} {
            append text " for [my get duration] weeks"
        }

        append text "."
    }

    method sendevent {} {
        my tactic [my block SYSTEM 1] ABSIT \
            stype    TRAFFIC                \
            n        [my get n]             \
            coverage [my get coverage]      \
            resolver NONE                   \
            duration [my get duration]
    }
}


#-----------------------------------------------------------------------
# EVENT:* orders

# SIMEVENT:TRAFFIC
#
# Updates existing TRAFFIC event.

order define SIMEVENT:TRAFFIC {
    title "Event: Random Traffic in Neighborhood"
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
    prepare event_id  -required -type ::wintel::simevent::TRAFFIC
    prepare duration  -num      -type ipositive
    prepare coverage  -num      -type rposfrac
 
    returnOnError -final

    # NEXT, update the event.
    set e [::wintel::simevent get $parms(event_id)]
    $e update_ {duration coverage} [array get parms]

    return
}






