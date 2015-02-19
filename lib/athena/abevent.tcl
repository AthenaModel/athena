#-----------------------------------------------------------------------
# TITLE:
#    abevent.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Tactic API for the abstract event tactics.
#
#    This module accumulates pending abstract events, and assesses them
#    as a group.
# 
#-----------------------------------------------------------------------

snit::type ::athena::abevent {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Instance Variables

    # Pending events
    variable pending {}
    

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        set adb $adb_
    }

    #-------------------------------------------------------------------
    # Public Methods

    # add dtype n cov args...
    #
    # dtype    - The abstract event type, i.e., the rule set name
    # n        - The affected neighborhood
    # coverage - The coverage fraction
    # args     - Event-type-specific parameters and values
    #
    # Creates an abstract event given the inputs.  The event is saved
    # in the pending events list for assessment at the end of the tick.

    method add {dtype n coverage args} {
        # Set up the rule set firing dictionary
        dict set fdict dtype      $dtype
        dict set fdict n          $n
        dict set fdict coverage   $coverage

        set fdict [dict merge $fdict $args]

        # Save it for later assessment.
        lappend pending $fdict
    }

    # reset 
    #
    # Clears the pending list.

    method reset {} {
        set pending [list]
    }

    # pending
    #
    # Returns the events in the pending list.

    method pending {} {
        return $pending
    }

    # assess 
    #
    # Assesses all pending abstract events.
    
    method assess {} {
        # FIRST, ensure that the pending list is cleared, even if there's
        # a bug in a ruleset.
        set alist $pending
        set pending [list]

        # NEXT, assess each pending event.
        foreach fdict $alist {
            array set evt $fdict
            set dtype $evt(dtype)

            $adb ruleset $dtype assess $fdict
        }
    }

}



