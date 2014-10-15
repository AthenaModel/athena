#-----------------------------------------------------------------------
# TITLE:
#    enumbutton.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    enumbutton(sim) package: Menu button that pops up an enumerated
#    choice.
#
#-----------------------------------------------------------------------

lappend auto_path ~/athena/mars/lib ~/athena/lib

package require projectgui

namespace import ::marsutil::* marsgui::* projectgui::*


ttk::label .lab -text "This is an enumbutton:"
enumbutton .eb \
    -command GotValue \
    -enumdict {
        a "Frederick"
        b "Johnson"
        c "Jehosaphat"
    }

proc GotValue {symbol} {
    puts "They chose <$symbol>"
}

pack .lab -side left
pack .eb -side left


