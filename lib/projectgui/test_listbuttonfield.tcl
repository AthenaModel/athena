#-----------------------------------------------------------------------
# TITLE:
#    listbuttonfield.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    listbuttonfield(sim) package: Menu button that pops up an enumerated
#    choice.
#
#-----------------------------------------------------------------------

lappend auto_path ~/athena/mars/lib ~/athena/lib

package require projectgui

namespace import ::marsutil::* marsgui::* projectgui::*

ttk::label .lab -text "This is a listbuttonfield:"
listbuttonfield .field     \
    -changecmd [list echo "Got: "]  \
    -itemdict  {
        AN1  "Antigua"
        BE2  "Bermuda"
        CA3  "Canada"
        DE4  "Denmark"
        EU5  "Europe"
        FA6  "Fallujah"
        GE7  "Georgia"
        HO8  "Hobbiton"
        IO9  "Ionia"
        JA10 "Jackson Hole"
        KA11 "Kathmandu"
        LO12 "London"
        MA13 "Maryland"
        NA14 "Nantucket"
        ON15 "Ontario"
        PA16 "Pahrump"
        QU17 "Queensland"
        RO18 "Rochester"
        SA19 "Samarkand"
        TE20 "Temple City"
        UR21 "Urumchi"
        VA22 "Van Nuys"
        WI23 "Wilmington"
        XA24 "Xanadu"
        YE25 "Yellowstone"
        ZA26 "Zanzibar"
    }


pack .lab   -side top
pack .field -side left -fill x 

debugger new

