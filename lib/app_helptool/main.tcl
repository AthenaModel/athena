#-----------------------------------------------------------------------
# TITLE:
#   main.tcl
#
# PROJECT:
#   athena-sim - Athena Regional Stability Simulation
#
# DESCRIPTION:
#   app_helptool(n) Package, main module.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Commands

# main argv
#
# argv  - Arguments
#
# Dummy example main proc.

proc main {argv} {
    puts "[kiteinfo project] [kiteinfo version]: Help Tool"

    wm withdraw .

    app init $argv

    destroy .
}
