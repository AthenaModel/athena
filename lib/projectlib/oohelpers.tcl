#-----------------------------------------------------------------------
# TITLE:
#    oohelpers.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectlib(n): TclOO Helpers
#
#    This module contains helper routines for use with TclOO
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Helper commands for use in class definitions
#
# Procs defined in the oo::define namespace are available to oo::define.


# typemethod method arglist body
#
# method   - A method name
# arglist  - An argument list
# 
# Defines a method on the class's class object.

proc ::oo::define::typemethod {method arglist body} {
    # FIRST, get the name of the class we're defining.
    set cls [namespace which [lindex [info level -1] 1]]

    # NEXT, define the typemethod.
    oo::objdefine $cls method $method $arglist $body
}

#-----------------------------------------------------------------------
# Helper commands for use in method bodies
#
# Procs defined in the oo::Helpers namespace are available in all 
# method bodies.

# mymethod method args
#
# method - A method name
# args   - Arguments to pass to it.
#
# This command mimics the Snit mymethod command; it returns a command
# prefix that can call any of the object's methods (including the 
# unexported ones).

proc ::oo::Helpers::mymethod {method args} {
    list [uplevel 1 {namespace which my}] $method {*}$args
}

