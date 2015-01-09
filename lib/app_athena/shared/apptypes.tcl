#-----------------------------------------------------------------------
# TITLE:
#    apptypes.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Application Data Types
#
#    This module defines simple data types are application-specific and
#    hence don't fit in projtypes(n).
#
# NOTE:
#    Certain types defined in this module assume that there is a valid 
#    mapref(n) object (or equivalent) called "::map".
#
#-----------------------------------------------------------------------


# Any of vs. All of
enum eanyall {
    ANY "Any of"
    ALL "All of"
}

# Does vs Doesn't
enumx create edoes {
    DOES   { longname "Does"     }
    DOESNT { longname "Does not" }
}

# Block/tactic execution status
enumx create eexecstatus {
    NONE {
        icon ::projectgui::icon::dash13      
        btext "Unknown"
        ttext "Unknown"
    }
    SKIP_BLOCK {
        icon ::projectgui::icon::dash13      
        btext "n/a"
        ttext "The tactic's block did not execute."        
    }
    SKIP_STATE {
        icon ::projectgui::icon::dash13      
        btext "Skipped; the block is disabled or invalid."
        ttext "Skipped; the tactic is disabled or invalid."     
    }
    SKIP_EMPTY {
        icon ::projectgui::icon::dash13      
        btext "Skipped; the block contains no tactics that could be executed."
        ttext "n/a"
    }
    SKIP_LOCK {
        icon ::projectgui::icon::dash13      
        btext "Skipped; the block does not execute on lock."
        ttext "Skipped; this tactic type does not execute on lock."
    }
    SKIP_TIME {
        icon ::projectgui::icon::clock13r
        btext "Skipped; the block's time constraints were not met."
        ttext "n/a"
    }
    SKIP_CONDITIONS {
        icon ::projectgui::icon::smthumbdn13
        btext "Skipped; the block's conditions were not met."
        ttext "n/a"
    }
    FAIL_RESOURCES {
        icon ::projectgui::icon::dollar13r
        btext "Failed due to insufficient resources for a required tactic."   
        ttext "Failed due to insufficient resources."
    }
    SUCCESS {
        icon ::projectgui::icon::check13     
        btext "The block executed successfully."
        ttext "The tactic executed successfully." 
    }
}

# Resource Error Types
#
# These are used to flag what kind of resource failure the tactic 
# had.
#
# NOTE: Resource failures that occur during obligation (i.e., during
# the actor's planning) should be colored red; resource failures that 
# occur during execution (after decisions can no longer be altered)
# should be colored purple.

enumx create eresource {
    CASH        {text Cash       icon ::projectgui::icon::dollar13r    }
    PERSONNEL   {text Personnel  icon ::projectgui::icon::personnel13r }
    CAP         {text CAP        icon ::projectgui::icon::cap13p       }
    OTHER       {text Other      icon ::projectgui::icon::other13r     }
    WARNING     {text Warning    icon ::projectgui::icon::warning13r   }
    ERROR       {text Error      icon ::projectgui::icon::error13r     }
}


# Condition flag status
enumx create eflagstatus {
    ""            {text -           icon ::projectgui::icon::dash13      }
    0             {text "Unmet"     icon ::projectgui::icon::smthumbdn13 }
    1             {text "Met"       icon ::projectgui::icon::smthumbup13 }
}

# Block Execution Mode
enumx create eexecmode {
    ALL  {longname "All tactics or none"}
    SOME {longname "As many tactics as possible"}
}

# Priority tokens

enum ePrioSched {
    top    "Top Priority"
    bottom "Bottom Priority"
}

enum ePrioUpdate {
    top    "To Top"
    raise  "Raise"
    lower  "Lower"
    bottom "To Bottom"
}

# esanity: Severity levels used by sanity checkers
enum esanity {
    OK      OK
    WARNING Warning
    ERROR   Error
}

# esimstate: The current simulation state
#
# PREP    - Scenario preparation.  The user can send orders to edit the
#           scenario.
# RUNNING - Time is advancing.  The user is generally not allowed to send
#           orders.  Certain orders can be sent by tactic, and of course
#           the simulation can be paused.
# PAUSED  - The scenario has been locked, but time is not advancing.  
#           Only certain orders may be used.
# WIZARD  - The application has popped up a Wizard window.  No orders may
#           be sent until the state has returned to PREP.

enum esimstate {
    PREP     Prep
    RUNNING  Running
    PAUSED   Paused
    WIZARD   Wizard
}

# esector: Econ Model sectors, used for the economic display variables
# in view(sim).

enum esector {
    GOODS goods
    POP   pop
    ELSE  else
}

# Magic Input Mode

enum einputmode {
    transient  "Transient"
    persistent "Persistent"
}

# Top Items for contributions reports

enum etopitems {
    ALL    "All Items"
    TOP5   "Top 5" 
    TOP10  "Top 10"
    TOP20  "Top 20"
    TOP50  "Top 50"
    TOP100 "Top 100"
}


# parmdb Parameter state

enum eparmstate { 
    all       "All Parameters"
    changed   "Changed Parameters"
}


# map types
enumx create eprojtype {
    REF  {proj ::marsutil::mapref}
    RECT {proj ::marsutil::maprect}
}

# rgamma: The range for the belief system playbox gamma

::marsutil::range rgamma -min 0.0 -max 2.0

# rcoverage: The range for the coverage fractions

::marsutil::range rcov -min 0.0 -max 1.0

# rpcf: The range for the Production Capacity Factor

::marsutil::range rpcf -min 0.0

# rpcf0: The range for the Production Capacity Factor at time 0.

::marsutil::range rpcf0 -min 0.1 -max 1.0

# rsvcpct: The range of percentages for abstract services to be changed

::marsutil::range rsvcpct -min -100.0 

# refpoint
#
# A refpoint is a location expressed as a map reference.  On validation,
# it is transformed into a location in map coordinates.

snit::type refpoint {
    pragma -hasinstances no

    typemethod validate {point} {
        map ref validate $point
        return [map ref2m $point]
    }
}

# refpoly
#
# A refpoly is a polygon expressed as a list of map reference strings.
# On validation, it is transformed into a flat list of locations in
# map coordinates.

snit::type refpoly {
    pragma -hasinstances no

    typemethod validate {poly} {
        map ref validate {*}$poly
        set coords [map ref2m {*}$poly]
        return polygon validate $coords
    }
}

# tclscript
#
# This experimental type is for validating Tcl Scripts, e.g., those
# used by the EXECUTIVE tactic.

snit::type tclscript {
    pragma -hasinstances no

    typemethod validate {script} {
        # FIRST, verify that the script contains at least a complete command.
        # This checks for unclosed braces and quotes, but not extra braces
        # and quotes at the end.
        if {![info complete $script]} {
            throw INVALID "Script is incomplete; check braces and quotes."
        }

        return $script
    }
}





