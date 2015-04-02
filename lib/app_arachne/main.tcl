#-----------------------------------------------------------------------
# TITLE:
#   main.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# PACKAGE:
#   app_arachne(n): Arachne Implementation Package
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Arachne main program, as called by the apploader script, bin/athena.tcl.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Main Program 

# main argv
#
# argv       Command line arguments
#
# This is the main program; it is invoked at the bottom of the file.
# It determines the tool to invoke, and does so.

proc main {argv} {
    return [app init $argv]
}



