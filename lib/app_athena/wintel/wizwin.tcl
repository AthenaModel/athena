#-----------------------------------------------------------------------
# TITLE:
#    wizwin.tcl
#
# AUTHOR:
#    Will Duquette
#
# PACKAGE:
#   wintel(n) -- package for athena(1) intel ingestion wizard.
#
# PROJECT:
#   Athena Regional Stability Simulation
#
# DESCRIPTION:
#    Intel Wizard window
#
# TODO:
#    Add Window menu to all toplevel windows.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# wizwin

snit::widget ::wintel::wizwin {
    hulltype toplevel
    widgetclass Topwin

    #-------------------------------------------------------------------
    # Components

    component toolbar               ;# Application tool bar
    component wizard                ;# Wizard manager
    component msgline               ;# The message line

    #-------------------------------------------------------------------
    # Options

    delegate option * to hull

    #-------------------------------------------------------------------
    # Instance variables

    # TBD

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, enter the wizard state.  We are in process.
        sim wizard on

        # NEXT, withdraw the hull widget until it's populated.
        wm withdraw $win

        # NEXT, get the options
        $self configurelist $args

        # NEXT, create components.
        $self CreateComponents
        
        # NEXT, Allow the created widget sizes to propagate to
        # $win, so the window gets its default size; then turn off 
        # propagation.  From here on out, the user is in control of the 
        # size of the window.

        update idletasks
        grid propagate $win off

        # NEXT, start the wizard going.
        $wizard start

        # NEXT, restore the window
        wm title $win "Intel Ingestion Wizard"
        wm deiconify $win
        raise $win

        # NEXT, prepare to receive events
        notifier bind ::wintel::wizard   <update> $win [mymethod Refresh]
        notifier bind ::wintel::simevent <update> $win [mymethod Refresh]
    }

    destructor {
        notifier forget $self
        wizard cleanup
    }

    # Refresh args
    #
    # Refreshes the wizard.

    method Refresh {args} {
        $wizard refresh
    }


    #-------------------------------------------------------------------
    # Components

    # CreateComponents
    #
    # Creates the main window's components.

    method CreateComponents {} {
        # FIRST, prepare the grid.
        grid rowconfigure $win 0 -weight 0 ;# Separator
        grid rowconfigure $win 1 -weight 1 ;# Content
        grid rowconfigure $win 2 -weight 0 ;# Separator
        grid rowconfigure $win 3 -weight 0 ;# Status Line

        grid columnconfigure $win 0 -weight 1

        # NEXT, put in the row widgets

        # ROW 0, add a separator between the menu bar and the rest of the
        # window.
        ttk::separator $win.sep0

        # ROW 1, create the wizard manager.
        install wizard using wizman $win.wizard \
            -cancelcmd [list destroy $win]      \
            -finishcmd [list ::wintel::wizard finish]

        # ROW 2, add a separator
        ttk::separator $win.sep2

        # ROW 3, Create the Status Line frame.
        ttk::frame $win.status    \
            -borderwidth        2 

        # Message line
        install msgline using messageline $win.status.msgline

        pack $win.status.msgline -fill both -expand yes

        # NEXT, add the initial wizard pages to the content notebook.

        $wizard add [wizscenario $win.scenario]
        $wizard add [wiztigr     $win.tigr]
        $wizard add [wizsorter   $win.sorter]
        $wizard add [wizevents   $win.events]
        $wizard add [wizexport   $win.export]

        # NEXT, manage all of the components.
        grid $win.sep0     -sticky ew
        grid $win.wizard   -sticky nsew
        grid $win.sep2     -sticky ew
        grid $win.status   -sticky ew
    }



    # puts text
    #
    # text     A text string
    #
    # Writes the text to the message line

    method puts {text} {
        $msgline puts $text
    }

}

