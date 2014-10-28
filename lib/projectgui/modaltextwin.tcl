#-----------------------------------------------------------------------
# TITLE:
#    modaltextwin.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectgui(n) package: modaltextwin
#
#    modaltextwin(n) defines an interface for popping up an error window
#    at program exit.  The window contains a read-only text widget
#    and an OK button.  On pressing OK, the program halts.
#
#    This is primarily for use on MS Windows, where there's no 
#    console output.
#
#-----------------------------------------------------------------------

namespace eval ::projectgui:: {
    namespace export modaltextwin
}

#-----------------------------------------------------------------------
# modaltextwin

snit::type ::projectgui::modaltextwin {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # dialog -- Name of the dialog widget

    typevariable dialog .modaltextwin

    # opts -- Array of option settings.  See popup for values

    typevariable opts -array {}

    # choice -- Ends the vwait.
    typevariable choice ""

    #-------------------------------------------------------------------
    # Public methods

    # popup option value....
    #
    # -message string - Message to display, verbatim.  Should be 
    #                   preformatted.
    # -title string   - Title of the dialog
    #
    # Pops up the dialog, displaying the text in a scrolled read-only
    # text widget.  The window will have the specified -title string.
    #
    # The command will wait until the user presses OK, and will then
    # terminate the application.

    typemethod popup {args} {
        # FIRST, get the option values
        $type ParsePopupOptions $args

        # NEXT, create the dialog
        toplevel $dialog           \
            -borderwidth 4         \
            -highlightthickness 0

        # NEXT, withdraw it; we don't want to see it yet
        wm withdraw $dialog

        # NEXT, handling the close button
        wm protocol $dialog WM_DELETE_WINDOW \
            [mytypemethod PopupClose]


        # NEXT, it must be on top
        wm attributes $dialog -topmost 1

        # NEXT, create and grid the standard widgets
            
        # Row 1: Text widget
        ttk::frame $dialog.top

       rotext $dialog.top.rotext                           \
            -width           60                            \
            -height          20                            \
            -xscrollcommand [list $dialog.top.xscroll set] \
            -yscrollcommand [list $dialog.top.yscroll set]

        ttk::scrollbar $dialog.top.xscroll \
            -orient horizontal             \
            -command [list $dialog.top.rotext xview]

        ttk::scrollbar $dialog.top.yscroll \
            -orient vertical               \
            -command [list $dialog.top.rotext yview]

        grid $dialog.top.rotext  -row 0 -column 0 -sticky nsew
        grid $dialog.top.yscroll -row 0 -column 1 -sticky ns
        grid $dialog.top.xscroll -row 1 -column 0 -sticky ew

        grid rowconfigure    $dialog.top 0 -weight 1
        grid columnconfigure $dialog.top 0 -weight 1

        # Row 3: button box
        ttk::frame $dialog.button
        
        ttk::button $dialog.button.ok  \
            -text    "OK"                      \
            -width   4                         \
            -command [mytypemethod PopupClose]

        pack $dialog.button.ok -padx 4 -pady 5

        pack $dialog.top    -side top    -fill both -expand yes
        pack $dialog.button -side bottom -fill x

        # NEXT, Set the title
        wm title $dialog $opts(-title)

        # NEXT, give it the right text.
        $dialog.top.rotext ins 1.0 $opts(-message)
        $dialog.top.rotext yview moveto 0.0
        $dialog.top.rotext see 1.0

        # NEXT, give it the right appearance
        osgui mktoolwindow $dialog .

        # NEXT, raise the button and set the focus
        wm deiconify $dialog
        wm attributes $dialog -topmost
        raise $dialog
        focus $dialog.button

        # NEXT, do the grab, and wait until they return.
        set choice {}

        grab set $dialog
        vwait [mytypevar choice]
        grab release $dialog
        
        # NEXT, remove the dialog.
        destroy $dialog
    }

    # ParsePopupOptions arglist
    #
    # arglist     List of popup args
    #
    # Parses the options into the opts array

    typemethod ParsePopupOptions {arglist} {
        # FIRST, set the option defaults
        array set opts {
            -message       {}
            -title         {Error, shutting down}
        }

        # NEXT, get the option values
        while {[llength $arglist] > 0} {
            set opt [::marsutil::lshift arglist]

            switch -exact -- $opt {
                -message       -
                -title         {
                    set opts($opt) [::marsutil::lshift arglist]
                }
                default {
                    error "Unknown option: \"$opt\""
                }
            }
        }
    }

    # PopupClose
    #
    # Called when the user closes the modaltextwin.

    typemethod PopupClose {} {
        set choice 1
    }
}


