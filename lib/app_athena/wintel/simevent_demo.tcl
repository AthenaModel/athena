#-----------------------------------------------------------------------
# TITLE:
#    simevent_demo.tcl
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
#    athena_sim(1): Simulation Event, DEMO
#
#    This module implements the DEMO event, which represents a non-violent 
#    demonstration by residents of a neighborhood.
# 
#-----------------------------------------------------------------------

# FIRST, create the class.
::wintel::simevent define DEMO "Demonstration" {
    A "Demonstration" event represents a non-violent public assembly
    of people who are supporting a cause.  The event will affect all
    groups who reside in the neighborhood, but the effects will 
    depend on whether the residents like or dislike (have a positive
    or negative horizontal relationship with) the groups that are
    demonstrating.<p>

    Set the "Demonstrating Groups" parameter to the names of the 
    civilian groups who are demonstrating; and set the "Coverage" 
    parameter to indicate the fraction of the neighborhood's residents
    that are aware of the demonstration and whose attitudes are 
    affected by it.<p>

    One or more groups can demonstrate in the neighborhood during 
    the same week.  It doesn't matter whether they are demonstrating
    together or for separate (and possibly opposing) causes.<p>

    The duration of a "Demonstration" event is always 1 week; reports from 
    successive weeks will generate additional events.  
} {
    A "Demonstration" event is represented in Athena as a "block" in the 
    SYSTEM agent's strategy.  The block will contain a DEMO tactic for
    each individual group that is demonstrating in the neighborhood.
    This tactic triggers the DEMO rule set; see the <i>Athena
    Rules Document</i> for the attitude effects.
} {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters

    variable glist

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Initialize as a event bean.
        next

        # NEXT, initialize the variables
        set glist [list]

        # NEXT, Save the options
        my configure {*}$args

        # NEXT, default the glist.
        set nbhood [my get n]

        if {[llength $glist] == 0} {
            set glist [civgroup gIn [my get n]]
        }
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
        set t(glist) [join $glist ", "]
        set pcov [string trim [percent [my get coverage]]]

        return "Demonstration in $t(n) ($pcov) by $t(glist)."
    }

    method sendevent {} {
        set block_id [my block SYSTEM]
        foreach g $glist {
            my tactic $block_id DEMO \
                n        [my get n]          \
                coverage [my get coverage]   \
                g        $g
        }
    }
}


#-----------------------------------------------------------------------
# EVENT:* orders

# SIMEVENT:DEMO
#
# Updates existing DEMO event.

order define SIMEVENT:DEMO {
    title "Event: Demonstration in Neighborhood"
    options -sendstates WIZARD

    form {
        rcc "Event ID" -for event_id
        text event_id -context yes \
            -loadcmd {beanload}

        rcc "Demonstrating Groups:" -for glist
        enumlonglist glist \
            -showkeys yes  \
            -width    30   \
            -dictcmd  {civgroup namedict}


        rcc "Coverage:" -for coverage
        posfrac coverage
        label "Fraction of neighborhood"
    }
} {
    # FIRST, prepare the parameters
    prepare event_id   -required -with {::pot valclass ::wintel::simevent::DEMO}
    returnOnError

    set e [::pot get $parms(event_id)]

    prepare glist     -toupper -listof ::civgroup
    prepare coverage  -num     -type   rposfrac
   
 
    returnOnError -final

    # NEXT, update the event.
    $e update_ {glist coverage} [array get parms]

    return
}








