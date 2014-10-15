#-----------------------------------------------------------------------
# FILE: app.tcl
#
#   Application Ensemble.
#
# PACKAGE:
#   app_cellide(n) -- athena_cell(1) implementation package
#
# PROJECT:
#   Athena S&RO Simulation
#
# AUTHOR:
#    Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Required Packages

# All needed packages are required in app_cellide.tcl.
 
#-----------------------------------------------------------------------
# app
#
# app_cellide(n) Application Ensemble
#
# This module defines app, the application ensemble.  app encapsulates 
# all of the functionality of athena_sim(1), including the application's 
# start-up behavior.  To invoke the  application,
#
# > package require app_cellide
# > app init $argv
#
# The app_cellide(n) package can be invoked by athena(1) and by 
# athena_test(1).

snit::type app {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Global Lookup Variables

    # Type Variable derivedfg
    #
    # The foreground color for derived data (as opposed to input data).
    # This color is used by a variety of data browsers throughout the
    # application.  TBD: Consider making this a preference.

    typevariable derivedfg "#008800"

    #-------------------------------------------------------------------
    # Application Initialization

    # init argv
    #
    # argv - Command line arguments (if any)
    #
    # Initializes the application.  This routine should be called once
    # at application start-up, and passed the arguments from the
    # shell command line.
    
    typemethod init {argv} {
        # FIRST, withdraw the "." window, so that we don't display a blank
        # window during initialization.
        wm withdraw .

        # NEXT, get the application directory
        appdir init

        # NEXT, initialize the non-GUI modules
        cmscript init
        snapshot init

        # NEXT, create statecontrollers.
        namespace eval ::sc {}

        # Have a syntactically correct model
        statecontroller ::sc::gotModel -events {
            ::cmscript <New>
            ::cmscript <Open>
            ::cmscript <Check>
        } -condition {
            [::cmscript checkstate] ni {unchecked syntax}
        }

        # NEXT, initialize the appserver
        appserver init
        myagent register app ::appserver

        # NEXT, create the real main window.
        appwin .main

        # NEXT, if there's a cellmodel(5) file on the command line, open it.
        if {[llength $argv] == 1} {
            cmscript open [file normalize [lindex $argv 0]]
        }
    }

    # exit ?text?
    #
    # text - Optional error message, tsubst'd
    #
    # Exits the program,writing the text (if any) to standard output.

    typemethod exit {{text ""}} {
        if {$text ne ""} {
            puts $text
            exit 1
        } else {
            exit
        }
    }

    # puts text
    #
    # text - A text string
    #
    # Writes the text to the message line of the topmost appwin.

    typemethod puts {text} {
        set topwin [app topwin]

        if {$topwin ne ""} {
            $topwin puts $text
        }
    }

    # error text
    #
    # text - A tsubst'd text string
    #
    # Normally, displays the error text in a message box.

    typemethod error {text} {
        set topwin [app topwin]

        if {$topwin ne ""} {
            uplevel 1 [list [app topwin] error $text]
        } else {
            error $text
        }
    }

    # topwin ?subcommand?
    #
    # subcommand - A subcommand of the topwin, as one argument or many
    #
    # If there's no subcommand, returns the name of the topmost appwin.
    # Otherwise, delegates the subcommand to the top win.  If there is
    # no top win, this is a noop.

    typemethod topwin {args} {
        # FIRST, determine the topwin
        set topwin ""

        foreach w [lreverse [wm stackorder .]] {
            if {[winfo class $w] eq "Appwin"} {
                set topwin $w
                break
            }
        }

        if {[llength $args] == 0} {
            return $topwin
        } elseif {[llength $args] == 1} {
            set args [lindex $args 0]
        }

        return [$topwin {*}$args]
    }

    # show uri
    #
    # uri - A URI for some application resource
    #
    # Shows the URI in some way.  If it's a "gui:" URI, tries to
    # handle it locally.  Otherwise, it passes it
    # to the Detail browser.

    typemethod show {uri} {
        # FIRST, get the scheme.  If it's not a gui:, punt to 
        # the Detail browser.

        if {[catch {
            array set parts [uri::split $uri]
        }]} {
            # Punt to normal error handling
            $type ShowInDetailBrowser $uri
            return
        }

        # NEXT, if the scheme isn't "gui", show in detail browser.
        if {$parts(scheme) ne "gui"} {
            $type ShowInDetailBrowser $uri
            return
        }

        # NEXT, what kind of "gui" url is it?

        if {$parts(host) eq "editor"} {
            if {[regexp {^(\d+)$} $parts(path) dummy line]} {
                .main gotoline $line
                return
            }
        }

        # NEXT, unknown kind of win; punt to normal error handling.
        $type GuiUrlError $uri "No such window"
    }

    # ShowInDetailBrowser uri
    #
    # uri - A URI for some application resource
    #
    # Shows the URI in the Detail browser.

    typemethod ShowInDetailBrowser {uri} {
        .main show $uri
        return
    }

    # GuiUrlError uri message
    #
    # uri     - A URI for a window we don't have.
    # message - A specific error message
    #
    # Shows an error.

    typemethod GuiUrlError {uri message} {
        app error {
            |<--
            Error in URI:
            
            $uri

            The requested gui:// URL cannot be displayed by the application:

            $message
        }
    }
}

proc version {} {
    return [kiteinfo version]
}
