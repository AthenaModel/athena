#!/bin/sh
# -*-tcl-*-
# The next line restarts using tclsh \
exec tclsh "$0" "$@"

# tt.tcl

package require athena
package require projectgui

ttk::progressbar .progress \
    -orient horizontal \
    -length 200 \
    -mode indeterminate

. configure -background green

grid .progress -row 0 -column 0 -columnspan 2 -padx 2 -pady 2
.progress start

ttk::label .lab -text Running
grid .lab -row 0 -column 0

button .stop -text "Stop" -command [list .progress stop]
grid .stop -row 1 -column 0 -pady 4

button .exit -text "Exit" -command exit
grid .exit -row 1 -column 1 -pady 4

