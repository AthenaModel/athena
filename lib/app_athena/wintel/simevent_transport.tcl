#-----------------------------------------------------------------------
# TITLE:
#    simevent_transport.tcl
#
# AUTHOR:
#    Will Duquette
#    Dave Hanks
#
# PACKAGE:
#   wintel(n) -- package for athena(1) intel ingestion wizard.
#
# PROJECT:
#   Athena Regional Stability Simulation
#
# DESCRIPTION:
#    athena_sim(1): Simulation Event, TRANSPORT
#
#    This module implements the TRANSPORT event, which represents
#    a transportation network blockage or breakdown in a neighborhood at 
#    a particular week.
# 
#-----------------------------------------------------------------------

# FIRST, create the class.
::wintel::simevent define TRANSPORT "Transport" {
    A "Transport" event represents a significant disturbance or 
    blockage of the transportation network which causes hardship on 
    civilian groups.  The event will affect all groups in the neighborhood.<p>

    Set the "Change Level of Service" parameter to represent the actual 
    percentage change in transportation service being provided to the 
    neighborhood's residents (nominally -10 percent of current level of
    service).<p>

} {
    A "Transport" event is represented in Athena as a "block" in the 
    SYSTEM agent's strategy.  The block will contain a SERVICE tactic
    that changes the actual level of transportation service (LOS) being 
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

        my set deltap -10.0


        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    method narrative {} {
        set t(n)      [nbhood fullname [my get n]]
        set t(deltap) [string trim [my get deltap]]

        set text \
            "Transportation service in $t(n) changes by $t(deltap)%."
    }

    method sendevent {} {
        my tactic [my block SYSTEM 1] SERVICE \
            s      TRANSPORT                                     \
            mode   ADELTA                                        \
            nlist  [gofer construct NBHOODS BY_VALUE [my get n]] \
            deltap [my get deltap]
    }
}


#-----------------------------------------------------------------------
# EVENT:* orders

# SIMEVENT:TRANSPORT
#
# Updates existing TRANSPORT event.

order define SIMEVENT:TRANSPORT {
    title "Event: Change in Transportation Service in Neighborhood"
    options -sendstates WIZARD

    form {
        rcc "Event ID" -for event_id
        text event_id -context yes \
            -loadcmd {beanload}

        rcc "Change Level of Service:" -for deltap
        text deltap
        c 
        label "%"
    }
} {
    # FIRST, prepare the parameters
    prepare event_id  -required -with {::pot valclass ::wintel::simevent::TRANSPORT}
    prepare deltap  -num      -type rsvcpct
 
    returnOnError -final

    # NEXT, update the event.
    set e [::pot get $parms(event_id)]
    $e update_ {deltap} [array get parms]

    return
}






