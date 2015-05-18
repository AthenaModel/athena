#-----------------------------------------------------------------------
# TITLE:
#    failurelist.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Sanity Check Failure List
#
#    This class subclasses and adapts ::projectlib::dictlist, providing
#    additional features for use by Athena sanity checkers.
#-----------------------------------------------------------------------

oo::class create ::athena::failurelist {
    superclass ::projectlib::dictlist

    #-------------------------------------------------------------------
    # Constructor

    # constructor
    # 
    # Configures the dictlist with the requisite columns, which are:
    #
    # severity - error|warning
    # code     - A code identifying the specific check
    # entity   - An entity reference, e.g., "nbhood" or "group/BLUE"
    # message  - A human-readable error message.


    constructor {} {
        next {
            severity
            code
            entity
            message
        }
    }

    #-------------------------------------------------------------------
    # Methods

    # severity
    #
    # Computes and returns the maximum severity level over all failures 
    # in the list.

    method severity {} {
        set sev OK

        foreach dict [my dicts] {
            set dsev [dict get $dict severity]
            if {[esanity gt $dsev $sev]} {
                set sev [string toupper $dsev]
            }
        }

        return $sev
    }    
}


