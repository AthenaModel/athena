#-----------------------------------------------------------------------
# TITLE:
#    nbstat.tcl
#
# AUTHOR:
#    Will Duquette
#    Dave Hanks
#
# DESCRIPTION:
#    athena_sim(1) Simulation Module: Neighborhood Status
#
#    This module computes the status of each neighborhood and of
#    the groups and units within it.  Most of the work is done by
#    the security(sim) and coverage(sim) submodules.
#
#    ::nbstat is a singleton object implemented as a snit::type.  To
#    initialize it, call "::nbstat start".  It can be re-initialized
#    on demand.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# nbstat

snit::type nbstat {
    # Make it an ensemble
    pragma -hastypedestroy 0 -hasinstances 0
    
    #-------------------------------------------------------------------
    # Start method

    typemethod start {} {
        log normal nbstat "start"

        # FIRST, initialize the sub-modules.
        security_model start
        coverage_model start

        # NEXT, do the initial analysis
        nbstat analyze

        # NEXT, Nbstat is up.
        log normal nbstat "start complete"
    }

    #-------------------------------------------------------------------
    # analyze

    # analyze
    #
    # Analyzes neighborhood status, as of the present
    # time, given the current contents of the RDB.

    typemethod analyze {} {
        # FIRST, call the submodules
        profile 1 security_model analyze
        profile 1 coverage_model analyze
    }
}








