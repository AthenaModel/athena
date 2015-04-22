#-----------------------------------------------------------------------
# TITLE:
#   main.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#   app_athenawb(n) Package, main module.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Commands

# main argv
#
# argv  - Arguments
#
# Application Main Procedure

proc main {argv} {
    # FIRST, get the application directory in the host file system.
    appdir init

    # NEXT, load the mods from the mods directory, if any, and
    # apply any applicable mods.
    mod load
    mod apply

    # NEXT, Invoke the app.
    app init $argv
}

