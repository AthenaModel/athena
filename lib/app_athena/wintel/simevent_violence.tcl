#-----------------------------------------------------------------------
# TITLE:
#    simevent_violence.tcl
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
#    athena_sim(1): Simulation Event, VIOLENCE
#
#    This module implements the VIOLENCE event, which represents
#    random violence in a neighborhood at a particular week.
# 
#-----------------------------------------------------------------------

# FIRST, create the class.
::wintel::simevent define VIOLENCE "Violence" {
    A "Random Violence" event represents random violence in a neighborhood 
    causing the residents to fear for their lives, short of actual civilian 
    casualties.  "Random Violence" events will affect all civilian groups 
    in the neighborhood.<p>

    Adjust the coverage to set the fraction of the neighborhood's 
    population who are aware of the violence and whose attitudes
    are affected by it.<p>

    Note that the duration of an
    "Accident" event is always one week; accidents in 
    successive weeks are treated as individual events.
} {
    A "Random Violence" event is represented in Athena as a "block" in the 
    SYSTEM agent's strategy, containing a VIOLENCE tactic that will 
    trigger a VIOLENCE abstract event, as documented in the <i>Athena
    Rules Document</i>.<p>

    Note that "Random Violence" is distinct from the "Civilian Casualties" 
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

        set text "Random Violence in $t(n) ($pcov)."
    }


    method sendevent {} {
        my tactic [my block SYSTEM] VIOLENCE \
            n        [my get n]              \
            coverage [my get coverage]
    }
}


#-----------------------------------------------------------------------
# EVENT:* orders

# SIMEVENT:VIOLENCE
#
# Updates existing VIOLENCE event.

::wintel::orders define SIMEVENT:VIOLENCE {
    meta title "Event: Random Violence in Neighborhood"

    meta defaults {
        event_id ""
        coverage ""
    }

    meta form {
        rcc "Event ID" -for event_id
        text event_id -context yes \
            -loadcmd {::wintel::wizard beanload}

        rcc "Coverage:" -for coverage
        posfrac coverage
        label "Fraction of neighborhood"
    }
    
    method _validate {} {
        my prepare event_id  -required \
            -with {::wintel::pot valclass ::wintel::simevent::VIOLENCE}
        my prepare coverage  -num      -type rposfrac
    }

    method _execute {{flunky ""}} {
        set e [::wintel::pot get $parms(event_id)]
        $e update_ {coverage} [array get parms]

        return
    }
}


