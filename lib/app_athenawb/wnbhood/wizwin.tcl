#-----------------------------------------------------------------------
# TITLE:
#    wizwin.tcl
#
# AUTHOR:
#    Dave Hanks
#
# PACKAGE:
#   wnbhood(n) -- package for athena(1) nbhood ingestion wizard.
#
# PROJECT:
#   Athena Regional Stability Simulation
#
# DESCRIPTION:
#    Nbhood Wizard window
#
# TODO:
#    Add Window menu to all toplevel windows.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# wizwin

snit::widget ::wnbhood::wizwin {
    hulltype toplevel
    widgetclass Topwin

    #-------------------------------------------------------------------
    # Components

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
        adb wizlock on

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
        wm title $win "Neighborhood Ingestion Wizard"
        wm deiconify $win
        raise $win

        # NEXT, prepare to receive events
        notifier bind ::wnbhood::wizard   <update> $win [mymethod Refresh]
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
            -finishcmd [list ::wnbhood::wizard finish]

        # ROW 2, add a separator
        ttk::separator $win.sep2

        # ROW 3, Create the Status Line frame.
        ttk::frame $win.status    \
            -borderwidth        2 

        # Message line
        install msgline using messageline $win.status.msgline

        pack $win.status.msgline -fill both -expand yes

        # NEXT, add the initial wizard pages to the content notebook.

        $wizard add [wiznbhood $win.nbhood]

        # NEXT, manage all of the components.
        grid $win.sep0     -sticky ew
        grid $win.wizard   -sticky nsew
        grid $win.sep2     -sticky ew
        grid $win.status   -sticky ew
    }

    # save
    #
    # Saves the selected neighborhoods to the scenario

    method save {} {
        # FIRST get the max ID and neighborhood dictionary
        set ctr [$self MaxNbhoodID]
        set ndict [$win.nbhood getnbhoods]
        set num [dict size $ndict]

        # NEXT, if no neighborhoods, nothing to do
        if {$num == 0} {
            return
        }

        adb order transaction "Ingest $num Neighborhoods" {
            dict for {name data} $ndict {
                lassign $data refpt poly
                set id "N[format "%03d" $ctr]"
                set substr [Ident $name]
                append id $substr
            
                set parms(n)          $id
                set parms(refpoint)   $refpt
                set parms(longname)   $name
                set parms(polygon)    $poly
                set parms(controller) NONE

                adb order senddict gui NBHOOD:CREATE:RAW [array get parms]

                incr ctr
            }
        }
    }

    # MaxNbhoodID
    #
    # This method returns the maximum ID of any previously created
    # nbhood so that we can guarantee that newly created neighborhoods
    # have unique identifiers.

    method MaxNbhoodID {} {
        set num 0
        # FIRST, get the highest existing ID
        adb eval {
            SELECT n FROM nbhoods
        } {
            if {[string compare -length 1 "N" $n] == 0} {
                set str [string trimleft [string range $n 1 3] "0"]
                if {[string is integer -strict $str]} {
                    set num [expr max($num,$str)]
                }
            }
        }

        # NEXT, return the highest bumped up by one
        return [expr {$num+1}]
    }

    # puts text
    #
    # text     A text string
    #
    # Writes the text to the message line

    method puts {text} {
        $msgline puts $text
    }

    #---------------------------------------------------------------
    # Helper procs

    # Ident str
    #
    # Takes a string and converts it to a string that is a valid
    # Athena ::projectlib::ident type or an empty string

    proc Ident {str} {
        set substr [string toupper [string range $str 0 4]]
        regsub -all {[^A-Z0-9]+} $substr "" gid
        return $gid
    }
}

