#-----------------------------------------------------------------------
# TITLE:
#    simevent_drought.tcl
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
#    athena_sim(1): Simulation Event, DROUGHT
#
#    This module implements the DROUGHT event, which represents
#    a drought in a neighborhood at a particular week.
# 
#-----------------------------------------------------------------------

# FIRST, create the class.
::wintel::simevent define DROUGHT "Drought" {
    A "Drought" event represents a shortage of water for agricultural
    and industrial purposes in a neighborhood (rather than a shortage
    of drinking water). "Drought" will affect all civilian groups in the 
    neighborhood, but will affect subsistence agriculture groups more.<p>

    Set the "Duration" parameter to the length of the drought in weeks;
    set the "Coverage" parameter to the fraction of the neighborhood's
    residents who are aware of the drought and whose attitudes are affected
    by it (nominally 1.0).<p>
} {
    A "Drought" event is represented in Athena as a "block" in the 
    SYSTEM agent's strategy.  The block will contain an ABSIT tactic
    that creates a DROUGHT abstract situation.  See the <i>Athena
    Rules Document</i> for the attitude affects of this situation.  All
    residents are affected, but those living by subsistence agriculture
    will be affected more than others.<p>

    Note that DROUGHT is distinct from the NOWATER abstract situation,
    which reflects a water supply that has been disabled by enemy action,
    and also from the BADWATER abstract situation, which reflects a 
    water supply that has been contaminated.
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

        set text "Drought in $t(n) ($pcov)"

        if {[my get duration] > 1} {
            append text " for [my get duration] weeks"
        }

        append text "."
    }


    method sendevent {} {
        my tactic [my block SYSTEM 1] ABSIT \
            stype    DROUGHT                \
            n        [my get n]             \
            coverage [my get coverage]      \
            resolver NONE                   \
            duration [my get duration]
    }
}


#-----------------------------------------------------------------------
# EVENT:* orders

# SIMEVENT:DROUGHT
#
# Updates existing DROUGHT event.

order define SIMEVENT:DROUGHT {
    title "Event: Drought in Neighborhood"
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
    prepare event_id  -required -type ::wintel::simevent::DROUGHT
    prepare duration  -num      -type ipositive
    prepare coverage  -num      -type rposfrac
 
    returnOnError -final

    # NEXT, update the event.
    set e [::wintel::simevent get $parms(event_id)]
    $e update_ {duration coverage} [array get parms]

    return
}






