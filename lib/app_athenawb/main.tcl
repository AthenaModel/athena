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
    try {
        mod load
        mod apply
    } trap MODERROR {result} {
        set f [open "error.log" w]
        puts $f $result
        close $f

        if {[os flavor] eq "windows"} {
            wm withdraw .
            modaltextwin popup \
                -title   "Athena is shutting down" \
                -message $result
            exit 1
        }

        throw FATAL $result
    }

    # NEXT, Invoke the app.
    app init $argv
}

