#-----------------------------------------------------------------------
# TITLE:
#    broadcast.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Tactic API for the BROADCAST tactic
#
#    This module manages broadcasts from strategy execution, when
#    broadcasts are determined, to assessment.
#
#-----------------------------------------------------------------------

snit::type ::athena::broadcast {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Instance Variables

    # Pending broadcasts
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
    # Methods
    
    # reset
    # 
    # Clears any pending broadcasts.  This command is for use at the
    # beginning of strategy execution, to make sure that there are no
    # pending broadcasts hanging around to cause trouble.
    #
    # Note that the [assess] method should always leave the list
    # empty; nevertheless, it is better to be sure.

    method reset {} {
        set pending [list]
    }

    # mark tactic
    #
    # tactic   - A BROADCAST tactic object
    #
    # Marks this tactic for attempted broadcast at the end of 
    # strategy execution.

    method mark {tactic} {
        lappend pending $tactic
    }

    # assess
    #
    # Assesses the attitude effects of all pending broadcasts by
    # calling the IOM rule set for each pending broadcast.
    #
    # This command is called at the end of strategy execution, once
    # all actors have made their decisions and CAP access is clear.

    method assess {} {
        # FIRST, assess each of the pending broadcasts
        foreach tactic $pending {
            $tactic assess
        }

        # NEXT, clear the list.
        $self reset

        return
    }
}



