#-----------------------------------------------------------------------
# TITLE:
#   main.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# PACKAGE:
#   app_atool(n): Athena Tool Application Package
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Atool main program, as called by the apploader script, bin/atool.tcl.
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
    # FIRST, given no input display the help.
    if {[llength $argv] == 0} {
        tool use help
        return
    }

    # NEXT, get any options
    foroption opt argv {
        -verbose { set ::app_atool::verbose 1 }
    }

    # NEXT, get the subcommand and see if we have a matching tool.
    # Alternatively, we might have a script file to run.
    set tool [lshift argv]

    if {![tool exists $tool]} {
        throw FATAL [outdent "
            This command provides no tool called '$tool'. 
            See 'atool help' for usage information.
        "]
    }

    # NEXT, use the selected tool, passing along the remaining arguments.
    tool use $tool $argv
}

# vputs text...
#
# text...  - One or more text strings
#
# Joins its arguments together and prints them to stdout, only if
# -verbose is on.

proc vputs {args} {
    if {$::app_atool::verbose} {
        puts [join $args]
    }
}

