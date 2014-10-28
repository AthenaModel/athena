#-----------------------------------------------------------------------
# FILE: main.tcl
#
#   Application Ensemble.
#
# PACKAGE:
#   app_cellide(n) -- cellide(1) implementation package
#
# PROJECT:
#   Athena S&RO Simulation
#
# AUTHOR:
#    Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Commands

# main argv
#
# argv  - Arguments
#
# Application main program.

proc main {argv} {
    app init $argv
}
