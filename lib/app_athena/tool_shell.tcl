#-----------------------------------------------------------------------
# TITLE:
#   tool_shell.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Athena "shell" tool.  Loads the code and pops up a debugger.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# tool::SHELL

tool define SHELL {
    usage       {0 0 ""}
    description "Debugging Shell"
} {
    EXPERIMENTAL.  Pops up a debugger window.
} {

    #-------------------------------------------------------------------
    # Execution 

    # execute argv
    #
    # Executes the tool given the command line arguments.

    typemethod execute {argv} {
        package require marsgui
        wm withdraw .
        marsgui::debugger new -app true

    }
}






