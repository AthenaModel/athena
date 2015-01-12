#-----------------------------------------------------------------------
# TITLE:
#    simevent_civcas.tcl
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
#    athena_sim(1): Simulation Event, CIVCAS
#
#    This module implements the CIVCAS event, which represents
#    civilian casualties in a neighborhood at a particular week.
# 
#-----------------------------------------------------------------------

# FIRST, create the class.
::wintel::simevent define CIVCAS "Civilian Casualties" {
    A "Civilian Casualties" event represents some number of civilians
    killed in a neighborhood during the given week, either because they
    were directly targeted or as collateral damage resulting from
    conflict between force groups.<p>

    Set the "Casualties" parameter to reflect the number of people killed.<p>

    Note that the duration of a 
    "Civilian Casualties" event is always one week; casualties in 
    successive weeks are treated as individual events.
} {
    A "Civilian Casualties" event is represented in Athena as a "block" in the 
    SYSTEM agent's strategy.  The block will contain an ATTRIT tactic that 
    causes the specified number of casualties in the given neighborhood in
    the given week.  See the CIVCAS rule set in the <i>Athena Rules
    Document</i> for the attitude effects.
} {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    variable casualties

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Initialize as a event bean.
        next

        # NEXT, initialize the variables
        set casualties 1

        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    # CIVCAS events cannot extend over multiple weeks.
    method canextend {} {
        return 0
    }


    method narrative {} {
        set t(n) [nbhood fullname [my get n]]

        return "$casualties Civilian Casualties in $t(n)."
    }

    method sendevent {} {
        my tactic [my block SYSTEM] ATTRIT \
            n          [my get n]          \
            casualties [my get casualties]
    }

}


#-----------------------------------------------------------------------
# EVENT:* orders

# SIMEVENT:CIVCAS
#
# Updates existing CIVCAS event.

::wintel::orders define SIMEVENT:CIVCAS {
    meta title "Event: Civilian Casualties in Neighborhood"

    meta defaults {
        event_id   ""
        casualties ""
    }

    meta form {
        rcc "Event ID" -for event_id
        text event_id -context yes \
            -loadcmd {::wintel::wizard beanload}

        rcc "Casualties:" -for casualties
        text casualties 
        label "civilians killed"
    }
    
    method _validate {} {
        my prepare event_id   \
            -required -with {::wintel::pot valclass ::wintel::simevent::CIVCAS}
        my prepare casualties -num      -type ipositive
    }

    method _execute {{flunky ""}} {
        set e [::wintel::pot get $parms(event_id)]
        $e update_ {casualties} [array get parms]

        return
    }

}




