#-----------------------------------------------------------------------
# TITLE:
#    simevent_riot.tcl
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
#    athena_sim(1): Simulation Event, RIOT
#
#    This module implements the RIOT event, which represents a violent 
#    public disturbance by residents of a neighborhood.
# 
#-----------------------------------------------------------------------

# FIRST, create the class.
::wintel::simevent define RIOT "Riot" {
    A "Riot" event represents a violent public disturbance by residents of 
    a neighborhood.  The cause of the riot and what the rioters target for 
    violence are not always related.  The event will affect all groups in 
    the neighborhood.<p>

    Adjust the coverage to set the fraction of the neighborhood's 
    population who are aware of the accident and whose attitudes
    are affected by it.<p>

    The duration of a "Riot" event is always 1 week; reports from 
    successive weeks will generate additional events.  
} {
    A "Riot" event is represented in Athena as a "block" in the 
    SYSTEM agent's strategy.  The block will contain a RIOT tactic that will 
    trigger a RIOT abstract event, as documented in the <i>Athena
    Rules Document</i>.<p>

    Note that "Riot" is distinct from the "Civilian Casualties" 
    event, which reflects actual civilian deaths.
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

        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    method canedit {} {
        return 1
    }

    method canextend {} {
        return 0
    }


    method narrative {} {
        set t(n) [nbhood fullname [my get n]]
        set pcov [string trim [percent [my get coverage]]]

        return "Riot in $t(n) ($pcov)."
    }


    method sendevent {} {
        my tactic [my block SYSTEM] RIOT \
            n        [my get n]          \
            coverage [my get coverage]
    }
}


#-----------------------------------------------------------------------
# EVENT:* orders

# SIMEVENT:RIOT
#
# Updates existing RIOT event.

order define SIMEVENT:RIOT {
    title "Event: Riot in Neighborhood"
    options -sendstates WIZARD

    form {
        rcc "Event ID" -for event_id
        text event_id -context yes \
            -loadcmd {beanload}

        rcc "Coverage:" -for coverage
        posfrac coverage
        label "Fraction of neighborhood"
    }
} {
    # FIRST, prepare the parameters
    prepare event_id  -required -type ::wintel::simevent::RIOT
    prepare coverage  -num      -type rposfrac
 
    returnOnError -final

    # NEXT, update the event.
    set e [::wintel::simevent get $parms(event_id)]
    $e update_ {coverage} [array get parms]

    return
}







