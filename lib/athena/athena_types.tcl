#-----------------------------------------------------------------------
# TITLE:
#    athena_types.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Data Validation Types
#
#    This module defines simple data types that are library-specific and
#    hence don't fit in projtypes(n).
#
#-----------------------------------------------------------------------

namespace eval ::athena:: {
    namespace export   \
        eanyall        \
        ecivcasconcern \
        edoes          \
        eexecstatus    \
        eresource      \
        eflagstatus    \
        eexecmode      \
        ePrioUpdate    \
        eroe           \
        esanity        \
        esimstate      \
        einputmode     \
        rgamma         \
        rcov           \
        rsvcpct        \
        refpoint       \
        refpoly        \
        tclscript
}


# Any of vs. All of
enum ::athena::eanyall {
    ANY "Any of"
    ALL "All of"
}

# Concern for civilian casualties
enum ::athena::ecivcasconcern {
    NONE   "None"
    LOW    "Low"
    MEDIUM "Medium"
    HIGH   "High"
}

# Does vs Doesn't
enumx create ::athena::edoes {
    DOES   { longname "Does"     }
    DOESNT { longname "Does not" }
}

# Block/tactic execution status
enumx create ::athena::eexecstatus {
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

enumx create ::athena::eresource {
    CASH        {text Cash       icon ::projectgui::icon::dollar13r    }
    PERSONNEL   {text Personnel  icon ::projectgui::icon::personnel13r }
    CAP         {text CAP        icon ::projectgui::icon::cap13p       }
    OTHER       {text Other      icon ::projectgui::icon::other13r     }
    WARNING     {text Warning    icon ::projectgui::icon::warning13r   }
    ERROR       {text Error      icon ::projectgui::icon::error13r     }
}


# Condition flag status
enumx create ::athena::eflagstatus {
    ""            {text -           icon ::projectgui::icon::dash13      }
    0             {text "Unmet"     icon ::projectgui::icon::smthumbdn13 }
    1             {text "Met"       icon ::projectgui::icon::smthumbup13 }
}

# Block Execution Mode
enumx create ::athena::eexecmode {
    ALL  {longname "All tactics or none"}
    SOME {longname "As many tactics as possible"}
}

# Priority tokens

enum ::athena::ePrioUpdate {
    top    "To Top"
    raise  "Raise"
    lower  "Lower"
    bottom "To Bottom"
}

# eroe: rule of engagement in ROE tactics
enum ::athena::eroe {
    ATTACK "attack"
    DEFEND "defend against"
}

# esanity: Severity levels used by sanity checkers
enum ::athena::esanity {
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

enum ::athena::esimstate {
    PREP     Prep
    RUNNING  Running
    PAUSED   Paused
    WIZARD   Wizard
}

# Magic Input Mode

enum ::athena::einputmode {
    transient  "Transient"
    persistent "Persistent"
}

# rgamma: The range for the belief system playbox gamma

::marsutil::range ::athena::rgamma -min 0.0 -max 2.0

# rcoverage: The range for the coverage fractions

::marsutil::range ::athena::rcov -min 0.0 -max 1.0

# rsvcpct: The range of percentages for abstract services to be changed

::marsutil::range ::athena::rsvcpct -min -100.0 

# refpoint
#
# A refpoint is a location expressed as a map reference.  On validation,
# it is transformed into a location in map coordinates.

snit::type ::athena::refpoint {
    pragma -hasinstances no
    typemethod validate {ref} {
        if {[catch {
            set point [latlong frommgrs $ref] 
        } result]} {
            throw INVALID $result
        }
        return $point
    }
}

# refpoly
#
# A refpoly is a polygon expressed as a list of map reference strings.
# On validation, it is transformed into a flat list of locations in
# map coordinates.

snit::type ::athena::refpoly {
    pragma -hasinstances no

    typemethod validate {poly} {
        if {[catch {
            foreach ref $poly {
                lappend coords {*}[latlong frommgrs $ref]
            }
        } result]} {
            throw INVALID $result
        }

        return [polygon validate $coords]
    }
}

# tclscript
#
# This experimental type is for validating Tcl Scripts, e.g., those
# used by the EXECUTIVE tactic.

snit::type ::athena::tclscript {
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





