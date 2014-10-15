#-----------------------------------------------------------------------
# TITLE:
#   rolemapfield_test.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   This script creates a rolemapfield for testing.
#
#-----------------------------------------------------------------------

lappend auto_path ~/athena/mars/lib ~/athena/lib

package require projectgui

namespace import marsutil::* 
namespace import marsgui::*
namespace import projectlib::*
namespace import projectgui::*

# Define some role specs

set rs1 {
    CIV {CG1 CG2 CG3 CG4 CG5 CG6 CG7}
    FRC {FG1 FG2 FG3 FG4 FG5 FG6 FG7}
    ACTOR {A1 A2 A3 A4 A5 A6 A7}
}

set rs2 {
    GRP1 {CG1 CG2 CG3 CG4 CG5 CG6 CG7}
    GRP2 {FG1 FG2 FG3 FG4 FG5 FG6 FG7}
    NBHOOD {N1 N2 N3 N4 N5 N6 N7}
}

# Procedures
proc ChangeCmd {field} {
    puts "\nChanged: $field"
    array set vals [.rmf get]
    parray vals
}

# Create and pack the widget.

rolemapfield .rmf \
    -changecmd ChangeCmd \
    -rolespec $rs1

button .b1 -text "RS1" -command {.rmf configure -rolespec $rs1}
button .b2 -text "RS2" -command {.rmf configure -rolespec $rs2}

pack .b1 -side top -fill x
pack .b2 -side top -fill x
pack .rmf -side top -fill both -expand yes

