#-----------------------------------------------------------------------
# TITLE:
#    simevent_accident.tcl
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
#    athena_sim(1): Simulation Event, ACCIDENT
#
#    This module implements the ACCIDENT event, which represents
#    random accidents in a neighborhood at a particular week.
# 
#-----------------------------------------------------------------------

# FIRST, create the class.
::wintel::simevent define ACCIDENT "Accident" {
    An "Accident" event represents some small accident in the 
    neighborhood that temporarily causes the residents to fear for
    their lives.  "Accident" events will affect all civilian groups 
    in the neighborhood.<p>

    Adjust the coverage to set the fraction of the neighborhood's 
    population who are aware of the accident and whose attitudes
    are affected by it.<p>

    Note that the duration of an
    "Accident" event is always one week; accidents in 
    successive weeks are treated as individual events.

} {
    An "Accident" event is represented in Athena as a "block" in the 
    SYSTEM agent's strategy, containing an ACCIDENT tactic that will 
    trigger an ACCIDENT abstract event, as documented in the <i>Athena
    Rules Document</i>.<p>

    Note that "Accident" is distinct from the "Civilian Casualties" 
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

    method canextend {} {
        return 0
    }

    #-------------------------------------------------------------------
    # Operations

    method narrative {} {
        set t(n) [nbhood fullname [my get n]]

        set pcov [string trim [percent [my get coverage]]]
        set text "Accident in $t(n) ($pcov)."
    }


    method sendevent {} {
        my tactic [my block SYSTEM] ACCIDENT \
            n        [my get n]              \
            coverage [my get coverage]
    }
}


#-----------------------------------------------------------------------
# EVENT:* orders

# SIMEVENT:ACCIDENT
#
# Updates existing ACCIDENT event.

order define SIMEVENT:ACCIDENT {
    title "Event: Accident in Neighborhood"
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
    prepare event_id  -required -type ::wintel::simevent::ACCIDENT
    prepare coverage  -num      -type rposfrac
 
    returnOnError -final

    # NEXT, update the event.
    set e [::wintel::simevent get $parms(event_id)]
    $e update_ {coverage} [array get parms]

    return
}






