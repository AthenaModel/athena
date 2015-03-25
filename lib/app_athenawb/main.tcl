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

# errexit line...
#
# line   -  One or more lines of text, as distinct arguments.
#
# On Linux/OS X or when Tk is not loaded, writes the text to standard 
# output, and exits. On Windows, pops up a messagebox and exits when 
# the box is closed.

proc errexit {args} {
    set text [join $args \n]

    set f [open "error.log" w]
    puts $f $text
    close $f

    if {[os type] ne "win32" || !$::tkLoaded} {
         puts $text
    } else {
        wm withdraw .
        modaltextwin popup \
            -title   "Athena is shutting down" \
            -message $text
    }

    exit 1
}
