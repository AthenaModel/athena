#!/bin/sh
# -*-tcl-*-
# The next line restarts using tclsh \
exec tclsh "$0" "$@"

#-----------------------------------------------------------------------
# TITLE:
#    athena_cell
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Athena: cellmodel(5) IDE
#
#    This script is the launcher for the athena_cell(1) application,
#    which is defined by the app_cell(n) package.
#     
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Set up the auto_path, so that we can find the correct libraries.  
# In development, there might be directories loaded from TCLLIBPATH;
# strip them out.

# First, remove all TCLLIBPATH directories from the auto_path.

if {[info exists env(TCLLIBPATH)]} {
    set old_path $auto_path
    set auto_path [list]

    foreach dir $old_path {
        if {$dir ni $env(TCLLIBPATH)} {
            lappend auto_path $dir
        }
    }
}

# Next, get the Athena-specific directories.

set appdir  [file normalize [file dirname [info script]]]
set libdir  [file normalize [file join $appdir .. lib]]

# Add Athena libs to the new lib path.
lappend auto_path $libdir

#-------------------------------------------------------------------
# Next, require Tcl

package require Tcl 8.6
package require Tk 8.6

package require kiteinfo

#-----------------------------------------------------------------------
# Main Program 

# main argv
#
# argv       Command line arguments
#
# This is the main program; it is invoked at the bottom of the file.

proc main {argv} {
    package require app_cellide

    # NEXT, Invoke the app.
    app init $argv
}

#-----------------------------------------------------------------------
# Run the program

# FIRST, run the main routine, to set everything up.
main $argv



