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
#-----------------------------------------------------------------------


# esector: Econ Model sectors, used for the economic display variables
# in view(sim).

enum esector {
    GOODS goods
    POP   pop
    ELSE  else
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


# rpcf: The range for the Production Capacity Factor

::marsutil::range rpcf -min 0.0

# rpcf0: The range for the Production Capacity Factor at time 0.

::marsutil::range rpcf0 -min 0.1 -max 1.0

