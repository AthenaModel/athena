#-----------------------------------------------------------------------
# FILE: app.tcl
#
#   Application Ensemble.
#
# PACKAGE:
#   app_sim(n) -- athena_sim(1) implementation package
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

# All needed packages are required in app_sim.tcl.
 
#-----------------------------------------------------------------------
# Module: app
#
# app_sim(n) Application Ensemble
#
# This module defines app, the application ensemble.  app encapsulates 
# all of the functionality of athena_sim(1), including the application's 
# start-up behavior.  To invoke the  application,
#
# > package require app_sim
# > app init $argv
#
# The app_sim(n) package can be invoked by athena(1) and by 
# athena_test(1).

snit::type app {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Group: Global Lookup Variables

    # Type Variable: derivedfg
    #
    # The foreground color for derived data (as opposed to input data).
    # This color is used by a variety of data browsers throughout the
    # application.  TBD: Consider making this a preference.

    typevariable derivedfg "#008800"

    #-------------------------------------------------------------------
    # Group: Type Variables

    # Type Variable: opts
    #
    # Application options.  These are set in a variety of ways.
    #
    # -batch           - If 1, athena_batch(1) is running; otherwise,
    #                    athena(1) is running.
    #
    # -ignoreuser      - If 1, ignore user preferences, etc.
    #                    Used for testing.
    #
    # -script filename - The name of a script to execute at start-up,
    #                    after loading the scenario file (if any).
    # -scratch dir     - The name of a directory to use for writing
    #                    log and working rdb files.
    #
    # athena(1) only:
    #
    # -dev             - If 1, run in development mode (e.g., include 
    #                    debugging log in appwin)
    #
    # -url url         - A URL to load into the detail browser.
    #                    "%" is replaced with "/", to work around MSys
    #                    path-munging.

    typevariable opts -array {
        -batch      0
        -dev        0
        -ignoreuser 0
        -script     {}
        -scratch    {}
        -url        {}
    }


    #-------------------------------------------------------------------
    # Group: Application Initialization

    # init argv
    #
    # argv - Command line arguments from main.
    #
    # Initializes the application.  This routine should be called once
    # at application start-up, and passed the arguments from the
    # shell command line.  In particular, it:
    #
    # * Determines where the application is installed.
    # * Creates a working directory.
    # * Opens the debugging log.
    # * Logs any loaded mods.
    # * Loads the user preferences, unless -ignoreuser is specified.
    # * Purges old working directories.
    # * Initializes the various application modules.
    # * Creates a number of statecontroller(n) objects to enable and
    #   disable various GUI components as application state changes.
    # * Sets the application icon.
    # * Opens the scenario specified on the command line, if any.
    #
    # Syntax:
    #   init _argv_
    #
    #   argv - Command line arguments (if any)
    #
    # See <usage> for the definition of the arguments.
    
    typemethod init {argv} {
        # FIRST, Process the command line.
        while {[string match "-*" [lindex $argv 0]]} {
            set opt [lshift argv]

            switch -exact -- $opt {
                -batch      -
                -dev        -
                -ignoreuser {
                    set opts($opt) 1
                }

                -script -
                -url    {
                    set opts($opt) [lshift argv]
                }

                -scratch {
                    set opts($opt) [lshift argv]
                }
                
                default {
                    app exit "Unknown option: \"$opt\"\n[app usage]"
                }
            }
        }

        if {[llength $argv] > 1} {
            app exit [app usage]
        }

        # NEXT, get the application directory
        appdir init

        # NEXT, validate that if -scrach is provided, it exists
        if {$opts(-scratch) ne ""} {
            if {![file exists $opts(-scratch)]} {
                app exit {
                    |<--
                    Error, scratch directory:

                        $opts(-scratch)

                    does not exist.
                }
            }
        }

        # NEXT, create the working directory.
        if {[catch {workdir init $opts(-scratch)} result]} {
            app exit {
                |<--
                Error, could not create working directory: 

                    [workdir join]

                Reason: $result
            }
        }

        # NEXT, create the preferences directory.
        if {!$opts(-batch) && !$opts(-ignoreuser)} {
            if {[catch {prefsdir init} result]} {
                app exit {
                    |<--
                    Error, could not create preferences directory: 

                        [prefsdir join]

                    Reason: $result
                }
            }
        }

        # NEXT, open the debugging log.
        log init 0

        # NEXT, log any loaded mods
        mod logmods

        # NEXT, initialize and load the user preferences
        prefs init
        
        if {!$opts(-ignoreuser) && !$opts(-batch)} {
            prefs load
        }

        prefs configure -notifycmd \
            [list notifier send ::app <Prefs>]

        # NEXT, enable notifier(n) tracing
        notifier trace [myproc NotifierTrace]

        # NEXT, create the weekclock, replacing the default Mars 
        # simclock(n) object.
        simclock destroy
        weekclock ::simclock

        # NEXT, Create the working scenario RDB and initialize simulation
        # components
        executive init
        parm      init master
        map       init
        view      init
        cif       init
        order     init \
            -subject      ::order                \
            -rdb          ::rdb                  \
            -usedtable    entities               \
            -logcmd       ::log                  \
            -ordercmd     [myproc AddOrderToCIF]
        bsys      init
        scenario ::sdb ""
        nbhood    init
        sim       init
        axdb      init
        strategy  init

        coverage_model init

        # NEXT, register other saveables
        scenario register ::projectlib::bean
        scenario register ::wintel::wizard

        # NEXT, register my:// servers with myagent.
        appserver init

        myagent register app ::appserver
        myagent register help \
            [helpserver %AUTO% \
                 -helpdb    [appdir join docs athena.helpdb] \
                 -headercmd [mytypemethod HelpHeader]]
        myagent register rdb \
            [rdbserver %AUTO% -rdb ::rdb]

        # NEXT, define order interfaces

        # app: For internal orders.  No tracing, and the app has to
        # do the error handling.
        order interface configure app

        # gui: For user orders from the GUI
        order interface configure gui \
            -checkstate  yes                           \
            -trace       yes                           \
            -errorcmd    [myproc UnexpectedOrderError]

        # cli: For user orders from the CLI
        order interface add cli \
            -checkstate  yes                            \
            -trace       yes                            \
            -rejectcmd   [myproc FormatRejectionForCLI] \
            -errorcmd    [myproc UnexpectedOrderError]

        # raw: Like CLI, but with no special rejection formatting.
        # Used by "send" executive command.
        order interface add raw \
            -checkstate  yes    \
            -trace       yes

        # tactic: Like raw, but does not trace; used by "send"
        # when the order state is TACTIC.
        order interface add tactic \
            -checkstate  yes

        # wizard: Orders from wizards, used for editing internal
        # wizard state.  Not traced, because they don't edit the
        # scenario.
        order interface add wizard \
            -checkstate  yes       \
            -trace       no        \
            -transaction no

        # test: For orders from the test suite.  No special handling
        # for unexpected errors, and no transactions, so that errors
        # remain in place.
        order interface add test \
            -checkstate  yes     \
            -trace       yes     \
            -transaction no

        # NEXT, initialize the order dialog manager if we are in
        # GUI mode
        if {[app tkloaded]} {
            orderdialog init \
                -parent    [list app topwin]           \
                -appname   "Athena [kiteinfo version]" \
                -helpcmd   [list app help]             \
                -refreshon {
                    ::cif <Update>
                    ::sim <Tick>
                    ::sim <DbSyncB>
                }
        }

        # NEXT, bind components together
        notifier bind ::sim <State> ::order {::order state [::sim state]}
        notifier bind ::app <Puck>  ::order {::order puck}

        # NEXT, create state controllers, to enable and disable
        # GUI components as application state changes.
        $type CreateStateControllers
        
        # NEXT, Create the main window, and register it as a saveable.
        # It does not, in fact, contain any scenario data; but this allows
        # us to capture the user's "session" as part of the scenario file.
        # No main window in batch mode.

        if {[app tkloaded]} {
            wm withdraw .
            appwin .main -dev $opts(-dev)
            scenario register .main
        }

        # NEXT, log that we're up.
        log normal app "Athena [kiteinfo version]"
        
        # NEXT, if we're in batch mode print that we are up
        if {$opts(-batch)} {
            puts [format "%-25s %s" "Athena version:"        [kiteinfo version]]
            puts [format "%-25s %s" "Application directory:" [appdir join]]
            puts [format "%-25s %s" "Working directory:"     [workdir join]]
        }

        # NEXT, if a scenario file is specified on the command line,
        # open it.
        if {[llength $argv] == 1} {
            app open [file normalize [lindex $argv 0]]
        } else {
            # This makes sure that the notifier events are sent that
            # initialize the user interface.
            sim dbsync
        }

        # NEXT, if there's a script, execute it.
        if {$opts(-script) ne ""} {
            set script [file normalize $opts(-script)]

            if {![file exists $script]} {
                set message {
                    |<--
                    -script $opts(-script) does not exist.
                    The full path is:

                    $script
                }

                app error $message
            } elseif {[catch {
                executive eval [list call $opts(-script)]
            } result eopts]} {
                if {[dict get $eopts -errorcode] eq "REJECT"} {
                    set message {
                        |<--
                        Order rejected in -script:

                        $result
                    }

                    if {![app tkloaded]} {
                        app exit $message
                    } else {
                        app error $message
                    }
                } elseif {![app tkloaded]} {
                    app exit {
                        |<--
                        Error in -script:
                        $result

                        Stack Trace:
                        [dict get $eopts -errorinfo]
                    }
                } else {
                    log error app "Unexpected error in -script:\n$result"
                    log error app "Stack Trace:\n[dict get $eopts -errorinfo]"
                    
                    after idle {app showlog}
                    
                    app error {
                        |<--
                        Unexpected error during the execution of
                        -script $opts(-script).  See the 
                        Log for details.
                    }
                }
            }
        }

        # NEXT, if we're in batch mode, exit; we're done.
        if {$opts(-batch)} {
            app exit
        }

        # NEXT, if there's a URL, load it.
        if {$opts(-url) ne ""} {
            app show [string map {% /} $opts(-url)]
        }
    }

    # tkloaded
    #
    # Returns the value of the -batch option for other modules to
    # use as needed.

    typemethod tkloaded {} {
        return $::tkLoaded
    }

    # AddOrderToCIF interface name parmdict undoScript ?redoScript?
    #
    # interface  - The interface by which the order was sent
    # name       - The order name
    # parmdict   - The order parameters
    # undoScript - The order's undo script, or "" if not undoable.
    # redoScript - The order's redo helper script, or "" if none.
    #
    # Adds accepted orders to the CIF.

    proc AddOrderToCIF {interface name parmdict undoScript {redoScript ""}} {
        cif add $name $parmdict $undoScript $redoScript
    }

    # UnexpectedOrderError name errmsg
    #
    # name    - The order name
    # errmsg  - The error message
    # einfo   - Error info (the stack trace)
    #
    # Handles unexpected order errors.

    proc UnexpectedOrderError {name errmsg einfo} {
        log error app "Unexpected error in $name:\n$errmsg"
        log error app "Stack Trace:\n$einfo"

        app showlog

        app error {
            |<--
            $name

            There was an unexpected error during the 
            handling of this order.  The scenario has 
            been rolled back to its previous state, so 
            the application data  should not be 
            corrupted.  However:

            * You should probably save the scenario under
              a new name, just in case.

            * The error has been logged in detail.  Please
              contact JPL to get the problem fixed.
        }

        if {[sim state] eq "RUNNING"} {
            sim mutate pause
        }

        sim dbsync

        return "Unexpected error while handling order."
    }

    # FormatRejectionForCLI errdict
    #
    # errdict     A REJECT error dictionary
    #
    # Formats the rejection error dictionary for display at the console.
    
    proc FormatRejectionForCLI {errdict} {
        if {[dict exists $errdict *]} {
            lappend out [dict get $errdict *]
        }

        dict for {parm msg} $errdict {
            if {$parm ne "*"} {
                lappend out "$parm: $msg"
            }
        }

        return [join $out \n]
    }

    # CreateStateControllers
    #
    # Creates a family of statecontroller(n) objects to manage
    # the state of GUI components as the application state changes.

    typemethod CreateStateControllers {} {
        namespace eval ::cond { }

        # Simulation state is PREP.

        statecontroller ::cond::simIsPrep -events {
            ::sim <State>
        } -condition {
            [::sim state] eq "PREP"
        }

        # browser predicate

        statecontroller ::cond::predicate -condition {
            [$browser {*}$predicate]
        }


        statecontroller ::cond::simPrepPredicate -events {
            ::sim <State>
        } -condition {
            [::sim state] eq "PREP" &&
            [$browser {*}$predicate]
        }

        # Simulation state is not RUNNING or WIZARD

        statecontroller ::cond::simIsStable -events {
            ::sim <State>
        } -condition {
            [::sim stable]
        }

        # Simulation state is PREP or PAUSED
        #
        # Equivalent to simIsStable, but appropriate for controls
        # that send orders valid in PREP and PAUSED.

        statecontroller ::cond::simPrepPaused -events {
            ::sim <State>
        } -condition {
            [::sim state] in {PREP PAUSED}
        }

        # Simulation state is PREP or PAUSED, plus browser predicate

        statecontroller ::cond::simPP_predicate -events {
            ::sim <State>
        } -condition {
            [::sim state] in {PREP PAUSED} &&
            [$browser {*}$predicate]
        }

        # Order is available in the current state.
        #
        # Objdict:   order   THE:ORDER:NAME

        statecontroller ::cond::available -events {
            ::order <State>
        } -condition {
            [::order available $order]
        }

        # One browser entry is selected.  The
        # browser should call update for its widgets.
        #
        # Objdict:   browser   The browser window

        statecontroller ::cond::single -condition {
            [llength [$browser curselection]] == 1
        }

        # Order is available, one browser entry is selected.  The
        # browser should call update for its widgets.
        #
        # Objdict:   order     THE:ORDER:NAME
        #            browser   The browser window

        statecontroller ::cond::availableSingle -events {
            ::order <State>
        } -condition {
            [::order available $order]                &&
            [llength [$browser curselection]] == 1
        }

        # Order is available, one or more browser entries are selected.  The
        # browser should call update for its widgets.
        #
        # Objdict:   order     THE:ORDER:NAME
        #            browser   The browser window

        statecontroller ::cond::availableMulti -events {
            ::order <State>
        } -condition {
            [::order available $order]              &&
            [llength [$browser curselection]] > 0
        }

        # Order is available, and the selection is deletable.
        # The browser should call update for its widgets.
        #
        # Objdict:   order     THE:ORDER:NAME
        #            browser   The browser window

        statecontroller ::cond::availableCanDelete -events {
            ::order <State>
        } -condition {
            [::order available $order] &&
            [$browser candelete]
        }

        # Order is available, and the selection is updateable.
        # The browser should call update for its widgets.
        #
        # Objdict:   order     THE:ORDER:NAME
        #            browser   The browser window

        statecontroller ::cond::availableCanUpdate -events {
            ::order <State>
        } -condition {
            [::order available $order] &&
            [$browser canupdate]
        }

        # Order is available, and the selection can be resolved.
        # The browser should call update for its widgets.
        #
        # Objdict:   order     THE:ORDER:NAME
        #            browser   The browser window

        statecontroller ::cond::availableCanResolve -events {
            ::order <State>
        } -condition {
            [::order available $order] &&
            [$browser canresolve]
        }
    }

    # usage
    #
    # Returns the application's command-line syntax.
    
    typemethod usage {} {
        if {$opts(-batch)} {
            set usage \
                "Usage: athena_batch ?options...? ?scenario.adb?\n\n"
        } else {
            set usage \
                "Usage: athena ?options...? ?scenario.adb?\n\n"
        }

        append usage \
            "-script filename    A script to execute after loading\n"   \
            "                    the scenario file (if any).\n"         \
            "-ignoreuser         Ignore preference settings.\n"

        if {!$opts(-batch)} {
            append usage \
            "-dev                Turns on all developer tools (e.g.,\n" \
            "                    the CLI and scrolling log)\n"          \
            "-url url            Load the URL in the detail browser.\n" \
            "                    '%' is replaced with '/'.\n"           \
            "\nSee athena(1) for more information.\n"
        } else {
            append usage \
                "\nSee athena_batch(1) for more information.\n"
        }

        return $usage
    }

    # Type Method: NotifierTrace
    #
    # A notifier(n) trace command that logs all notifier events.
    #
    # Syntax:
    #   NotifierTrace _subject event eargs objects_

    proc NotifierTrace {subject event eargs objects} {
        set objects [join $objects ", "]
        log detail notify "send $subject $event [list $eargs] to $objects"
    }

    # HelpHeader udict
    #
    # Formats a custom header for help pages.

    typemethod HelpHeader {udict} {
        set out "<b><font size=2>Athena [version] Help</b>"
        append out "<hr><p>\n"
        
        return $out
    }

    #-------------------------------------------------------------------
    # Group: Utility Type Methods
    #
    # This routines are application-specific utilities provided to the
    # rest of the application.

    # help title
    #
    # title  - A help page title
    #
    # Shows a page with the desired title, if any, in the Detail Browser.

    typemethod help {{title ""}} {
        app show "my://help/?[string trim $title]"
    }

    # Type Method: puts
    #
    # Writes the _text_ to the message line of the topmost appwin.
    # This is a no-op in batch mode.
    #
    # Syntax: 
    #   puts _text_
    #
    #   text - A text string

    typemethod puts {text} {
        if {[app tkloaded]} {
            set topwin [app topwin]

            if {$topwin ne ""} {
                $topwin puts $text
            }
        }
    }

    # Type Method: error
    #
    # Normally, displays the error _text_ in a message box.  In 
    # batchmode, calls [app exit].
    #
    # Syntax:
    #   error _text_
    #
    #   text - A tsubst'd text string

    typemethod error {text} {
        set text [uplevel 1 [list tsubst $text]]

        if {$opts(-batch)} {
            # Uplevel, so that [app exit] can expand the text.
            uplevel 1 [list app exit $text]
        } else {
            if {[winfo exists .main]} {
                wm deiconify .main
                raise .main
                .main error $text
            } else {
                error $text
            }
        }
    }

    # showlog
    #
    # Makes .main visible and shows the scrolling log.

    typemethod showlog {} {
        if {[winfo exists .main]} {
            wm deiconify .main
            raise .main
            .main tab view slog
        }
    }

    # Type Method: exit
    #
    # Exits the program,writing the text (if any) to standard output.
    # Saves the CLI's command history for the next session.
    #
    # Syntax:
    #   exit _?text?_
    #
    #   text - Optional error message, tsubst'd

    typemethod exit {{text ""}} {
        # FIRST, output the text.  In batch mode, write it to
        # error.log.
        if {$text ne ""} {
            set text [uplevel 1 [list tsubst $text]]

            if {!$opts(-batch)} {
                app DisplayExitText $text
            } else {
                set f [open "error.log" w]
                puts $f $text
                close $f
                app DisplayExitText \
                    "Error; see [file join [pwd] error.log] for details."
            }
        }

        # NEXT, save the CLI history, if any.
        if {!$opts(-ignoreuser) && !$opts(-batch) && [winfo exists .main]} {
            .main savehistory
        }

        # NEXT, release any threads
        log release

        # NEXT, exit
        if {$text ne ""} {
            exit 1
        } else {
            exit
        }
    }

    # DisplayExitText text...
    #
    # text - An exit message: multiple lines, each as a separate arg.
    #
    # Displays the [app exit] text appropriately.
    # 

    typemethod DisplayExitText {args} {
        set text [join $args \n]

        # FIRST, if this is not windows or if Tk is not loaded then
        # a simple puts will do.
        if {[os flavor] ne "windows" || ![app tkloaded]} {
            puts $text
        } else {
            wm withdraw .
            modaltextwin popup \
                -title   "Athena is shutting down" \
                -message $text
        }
    }

    # topwin ?subcommand...?
    #
    # If there's no subcommand, returns the name of the topmost "Topwin"
    # widget.  A "Topwin" is a widget in which the user does work, and
    # from which he can pop up dialogs.
    #
    # Otherwise, delegates the subcommand to the top win.  If there is
    # no top win, this is a noop.

    typemethod topwin {args} {
        # FIRST, if no Tk then nothing to do
        if {![app tkloaded]} {
            return ""
        }

        # NEXT, determine the topwin.  Note that [wm stackorder]
        # skips windows that are not mapped.
        set topwin ""

        foreach w [lreverse [wm stackorder .]] {
            if {[winfo class $w] eq "Topwin"} {
                set topwin $w
                break
            }
        }

        if {[llength $args] == 0} {
            return $topwin
        } elseif {[llength $args] == 1} {
            set args [lindex $args 0]
        }

        if {$topwin eq ""} {
            error "No topwin to execute command."
        }

        return [$topwin {*}$args]
    }

    # show uri
    #
    # uri - A URI for some application resource
    #
    # Shows the URI in some way.  If it's a "gui:" URI, tries to
    # display it as a tab or order dialog.  Otherwise, it passes it
    # to the Detail browser.

    typemethod show {uri} {
        # FIRST, if the app has not loaded Tk, there's nothing to show
        # (This happens in batchmode, or when athena_test(1) is 
        # explicitly told not to load Tk.)

        if {![app tkloaded]} {
            return
        }

        # NEXT, if there's no main window, just return.
        # (This happens when athena_test(1) runs the 
        # test suite with Tk loaded.)

        if {![winfo exists .main]} {
            return
        }

        # NEXT, get the scheme.  If it's not a gui:, punt to 
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

        if {[regexp {^tab/(\w+)$} $parts(path) dummy tab]} {
            if {[.main tab exists $tab]} {
                .main tab view $tab
            } else {
                # Punt
                $type GuiUrlError $uri "No such application tab"
            }
            return
        }

        if {[regexp {^order/([A-Za-z0-9:]+)$} $parts(path) dummy order]} {
            set order [string toupper $order]

            if {[order exists $order]} {
                set parms [split $parts(query) "=+"]
                if {[catch {
                    order enter $order {*}$parms
                } result]} {
                    $type GuiUrlError $uri $result
                }
            } else {
                # Punt
                $type GuiUrlError $uri "No such order"
            }
            return
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
        [.main tab win detail] show $uri
        .main tab view detail
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

    #-------------------------------------------------------------------
    # Scenario Management
    #
    # These are the routines to be used by the rest of the application
    # to manage the scenario as a whole.  They delegate the bulk of
    # the work to the scenario object, providing only the application's
    # policy and error handling glue.

    # new
    #
    # Creates a new scenario, throwing away unsaved changes.

    typemethod new {} {
        require {[sim stable]} "A new scenario cannot be created in this state."

        # FIRST, unlock the scenario if it is locked; this
        # will reinitialize modules like URAM.
        if {[sim state] ne "PREP"} {
            sim mutate unlock
        }

        # NEXT, create a new, blank scenario
        ::sdb destroy
        scenario ::sdb ""

        # NEXT, log it.
        log newlog new
        log normal scenario "New Scenario: Untitled"

        app puts "New scenario created"

        # NEXT, Resync the app with the RDB.
        sim dbsync
    }

    # open filename
    #
    # filename - The name of the .adb file to open.
    #
    # Opens and loads an existing scenario, throwing away unsaved 
    # changes.
    
    typemethod open {filename} {
        require {[sim stable]} "A new scenario cannot be opened in this state."

        # FIRST, try to open the scenario.
        try {
            ::sdb destroy
            scenario ::sdb $filename
        } trap {SCENARIO OPEN} {result} {

            app error {
                |<--
                Could not open scenario

                    $filename

                $result
            }

            # At least have an empty scenario.
            scenario ::sdb ""

            return
        }

        # NEXT, set the current working directory to the scenario
        # file location.
        catch {cd [file dirname [file normalize $filename]]}

        # NEXT, log it.
        log newlog open
        log normal scenario "Open Scenario: $filename"

        app puts "Opened Scenario [file tail $filename]"

        # NEXT, Resync the app with the RDB.
        sim dbsync
    }

    # save ?filename?
    #
    # filename - A new file name
    #
    # Saves the current scenario using the existing name.

    typemethod save {{filename ""}} {
        require {[sim stable]} "The scenario cannot be saved in this state."

        # FIRST, notify the simulation that we're saving, so other
        # modules can prepare.
        notifier send ::scenario <Saving>

        # NEXT, save the scenario to disk.
        try {
            scenario save $filename
        } on error {result eopts} {
            log warning scenario "Could not save: $result"
            log error scenario [dict get $eopts -errorinfo]
            app error {
                |<--
                Could not save as

                    $filename

                $result
            }
            return 0
        }

        # NEXT, set the current working directory to the scenario
        # file location.
        catch {cd [file dirname [file normalize $filename]]}

        # NEXT, log it.
        if {$filename ne ""} {
            log newlog saveas
        }

        log normal scenario "Save Scenario: [sdb dbfile]"

        app puts "Saved Scenario [file tail [sdb dbfile]]"

        notifier send $type <ScenarioSaved>

        return 1
    }

    # revert
    #
    # Revert the current scenario to its last save (or to the 
    # default initial scenario if there is none).

    typemethod revert {} {
        scenario revert
    }
}


#-----------------------------------------------------------------------
# Section: Miscellaneous Application Utility Procs

# version
#
# Returns the application version.

proc version {} {
    return [kiteinfo version]
}

# profile ?depth? command ?args...?
#
# Calls the command once using [time], in the caller's context,
# and logs the outcome, returning the command's return value.
# In other words, you can stick "profile" before any command name
# and profile that call without changing code or adding new routines.
#
# If the depth is given, it must be an integer; that many "*" characters
# are added to the beginning of the log message.

proc profile {args} {
    if {[string is integer -strict [lindex $args 0]]} {
        set prefix "[string repeat * [lshift args]] "
    } else {
        set prefix ""
    }

    set msec [lindex [time {
        set result [uplevel 1 $args]
    } 1] 0]

    log detail app "${prefix}profile [list $args] $msec"

    return $result
}


# Proc: bgerror
#
# Logs background errors; the errorInfo is stored in ::bgErrorInfo
#
# Syntax:
#   bgerror _msg_

proc bgerror {msg} {
    global errorInfo
    global bgErrorInfo

    set bgErrorInfo $errorInfo
    log error app "bgerror: $msg"
    log error app "Stack Trace:\n$bgErrorInfo"

    if {[sim state] eq "RUNNING"} {
        # TBD: might need to send order?
        sim mutate pause
    }

    # Gather any error context we may have
    set trace ""
    set level [info level]

    if {$level > 0} {
        set trace "bgerror context:\n"
        for {set lvl [expr {$level-1}]} {$lvl > 0} {incr lvl -1} {
            append trace "$lvl [info level $lvl]\n"
        }
    }

    if {$app::opts(-batch)} {
        # app exit subst's in the caller's context
        app exit {$msg\n\nStack Trace:\n$bgErrorInfo\n$trace}
    } elseif {[winfo exists .main]} {
        if {$trace ne ""} {
            log error app $trace
        }

        wm deiconify .main
        raise .main
        .main tab view slog

        app error {
            |<--
            An unexpected error has occurred;
            please see the log for details.
        }
    } else {
        puts "bgerror: $msg"
        puts "Stack Trace:\n$bgErrorInfo\n$trace"
    }
}



