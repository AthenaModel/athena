#-----------------------------------------------------------------------
# TITLE:
#    simevent_explosion.tcl
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
#    athena_sim(1): Simulation Event, EXPLOSION
#
#    This module implements the EXPLOSION event, which represents
#    random explosions in a neighborhood at a particular week.
# 
#-----------------------------------------------------------------------

# FIRST, create the class.
::wintel::simevent define EXPLOSION "Explosion" {
    An "Explosion" event represents a large explosion or series of 
    explosions that are seen as a significant threat in the neighborhood.
    An "Explosion" event will affect all civilian groups in the 
    neighborhood.<p>

    Set the "Coverage" parameter to the fraction of the neighborhood's
    residents who are aware of the event and whose attitudes are
    affected by it.<p>

    The duration of an "Explosion" event is always 1 week; reports from 
    successive weeks will generate additional events.  
} {
    An "Explosion" event is represented in Athena as a "block" in the 
    SYSTEM agent's strategy.  The block will contain an EXPLOSION tactic that
    creates an EXPLOSION abstract event.  See the EXPLOSION rule set in the
    <i>Athena Rules Document</i> for the attitude effects.<p> 

    Note that "Explosion" is distinct from the "Civilian Casualties" 
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

        return "Explosion in $t(n) ($pcov)."
    }


    method sendevent {} {
        my tactic [my block SYSTEM] EXPLOSION \
            n        [my get n]               \
            coverage [my get coverage]
    }

    #-------------------------------------------------------------------
    # Order Helper Typemethods
}


#-----------------------------------------------------------------------
# EVENT:* orders

# SIMEVENT:EXPLOSION
#
# Updates existing EXPLOSION event.

order define SIMEVENT:EXPLOSION {
    title "Event: Explosion in Neighborhood"
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
    prepare event_id  -required -type ::wintel::simevent::EXPLOSION
    prepare coverage  -num      -type rposfrac
 
    returnOnError -final

    # NEXT, update the event.
    set e [::wintel::simevent get $parms(event_id)]
    $e update_ {coverage} [array get parms]

    return
}













