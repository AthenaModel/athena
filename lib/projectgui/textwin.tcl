#-----------------------------------------------------------------------
# TITLE:
#    textwin.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectgui(n) package: Text Viewer Window widget.
#
# This is a window which displays text content.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::projectgui:: {
    namespace export textwin
}

#-----------------------------------------------------------------------
# Widget Definition

snit::widget ::projectgui::textwin {
    hulltype toplevel

    #-------------------------------------------------------------------
    # Options

    delegate option * to hull
    delegate method * to hull

    # The window title
    option -title \
        -configuremethod ConfigTitle

    method ConfigTitle {opt val} {
        set options($opt) $val
        wm title $win $val
    } 

    # The text to display
    option -text \
        -configuremethod ConfigText \
        -cgetmethod      CgetText

    method ConfigText {opt val} {
        $rotext del 1.0 end
        $rotext ins end $val
        $rotext see 1.0
        $rotext yview moveto 0.0
    }

    method CgetText {opt} {
        $rotext get 1.0 end
    }
        

    #-------------------------------------------------------------------
    # Components

    component rotext    ;# A rotext widget
    component msgline   ;# A messageline widget

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the rotext widget
        install rotext using ::marsgui::rotext $win.rotext \
            -width          80                             \
            -height         24                             \
            -yscrollcommand [list $win.yscroll set]        \
            -xscrollcommand [list $win.xscroll set]
        
        isearch enable $rotext
        isearch logger $rotext [list $win.msgline puts]

        # NEXT, create the scrollbars.
        ttk::scrollbar $win.yscroll \
            -orient  vertical       \
            -command [list $rotext yview]

        ttk::scrollbar $win.xscroll \
            -orient  horizontal     \
            -command [list $rotext xview]

        # NEXT, create the message line
        install msgline using messageline $win.msgline

        # NEXT, layout the widgets
        grid columnconfigure $win 0 -weight 1
        grid rowconfigure    $win 0 -weight 1

        grid $rotext      -row 0 -column 0 -sticky nsew
        grid $win.yscroll -row 0 -column 1 -sticky ns
        grid $win.xscroll -row 1 -column 0 -sticky ew
        grid $msgline     -row 2 -column 0 -sticky ew -columnspan 2


        # NEXT, Save the options.
        $self configurelist $args
    }
}

