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

    Set the "Level of Service" parameter to represent the actual level of
    transportation service being provided to the neighborhood's
    residents (nominally 1.0).<p>

} {
    A "Traffic" event is represented in Athena as a "block" in the 
    SYSTEM agent's strategy.  The block will contain a SERVICE tactic
    that sets the actual level of transportation service (LOS) being 
    provided to the residents of the neighborhood.  See the <i>Athena
    Rules Document</i> for the attitude affects of this service.<p>
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

        my set los 1.0


        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    method narrative {} {
        set t(n)   [nbhood fullname [my get n]]
        set t(los) [string trim [percent [my get los]]]

        set text "Transportation service in $t(n) ($t(los))."
    }

    method sendevent {} {
        my tactic [my block SYSTEM 1] SERVICE \
            s     TRANSPORT                                     \
            nlist [gofer construct NBHOODS BY_VALUE [my get n]] \
            los   [my get los]
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

        rcc "Level of Service:" -for los
        posfrac los
    }
} {
    # FIRST, prepare the parameters
    prepare event_id  -required -with {::pot valclass ::wintel::simevent::TRAFFIC}
    prepare los  -num      -type rposfrac
 
    returnOnError -final

    # NEXT, update the event.
    set e [::pot get $parms(event_id)]
    $e update_ {los} [array get parms]

    return
}






