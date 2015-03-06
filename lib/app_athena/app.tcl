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
    # -url url         - A URL to load into the detail browser.
    #                    "%" is replaced with "/", to work around MSys
    #                    path-munging.

    typevariable opts -array {
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
                    # Generate error message for users that are accustomed
                    # to the -batch option in previous versions of Athena
                    if {$opt eq "-batch"} {
                        set errmsg "\"-batch\" is invalid, use athena_batch "
                        append errmsg "instead.\nSee the athena_batch(1) "
                        append errmsg "documentation for more information."
                    } else {
                        set errmsg "Unknown option: \"$opt\"\n[app usage]"
                    }
                    app exit $errmsg
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
        if {[app tkloaded] && !$opts(-ignoreuser)} {
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
        log init

        # NEXT, log any loaded mods
        mod logmods

        # NEXT, initialize and load the user preferences
        prefs init
        
        if {[app tkloaded] && !$opts(-ignoreuser)} {
            prefs load
        }

        prefs configure -notifycmd \
            [list notifier send ::app <Prefs>]

        # NEXT, enable notifier(n) tracing
        notifier trace [myproc NotifierTrace]

        # NEXT, Create the working scenario RDB and initialize simulation
        # components
        view      init
        MakeAthena ::adb

        # NEXT, register my:// servers with myagent.
        appserver init

        myagent register app ::appserver
        myagent register help \
            [helpserver %AUTO% \
                 -helpdb    [appdir join docs athena.helpdb] \
                 -headercmd [mytypemethod HelpHeader]]
        myagent register rdb \
            [rdbserver %AUTO% -rdb ::adb]


        # NEXT, bind components together
        notifier bind ::app <Puck>          ::order_dialog {::order_dialog puck}
        notifier bind ::adb <InsaneOnTick>  ::app [mytypemethod InsaneOnTick]
        notifier bind ::adb.econ <SamError> ::app [mytypemethod EconError]
        notifier bind ::adb.econ <CgeError> ::app [mytypemethod EconError]

        # NEXT, create state controllers, to enable and disable
        # GUI components as application state changes.
        $type CreateStateControllers
        
        # NEXT, Create the main window.

        if {[app tkloaded]} {
            wm withdraw .
            appwin .main
        }

        # NEXT, log that we're up.
        log normal app "Athena [kiteinfo version]"
        
        # NEXT, if we're in non-GUI mode print that we are up
        if {![app tkloaded]} {
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
            adb dbsync
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
                adb executive call $opts(-script)
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

        # NEXT, if there's a URL and we're in GUI mode, load it.
        if {$opts(-url) ne "" && [app tkloaded]} {
            app show [string map {% /} $opts(-url)]
        }
    }

    # tkloaded
    #
    # Returns the value of the tkLoaded flag for other modules to use

    typemethod tkloaded {} {
        return $::tkLoaded
    }

    
    # CreateStateControllers
    #
    # Creates a family of statecontroller(n) objects to manage
    # the state of GUI components as the application state changes.

    typemethod CreateStateControllers {} {
        namespace eval ::cond { }

        # Simulation state is PREP.

        statecontroller ::cond::simIsPrep -events {
            ::adb <State>
        } -condition {
            [::adb state] eq "PREP"
        }

        # browser predicate

        statecontroller ::cond::predicate -condition {
            [$browser {*}$predicate]
        }


        statecontroller ::cond::simPrepPredicate -events {
            ::adb <State>
        } -condition {
            [::adb state] eq "PREP" &&
            [$browser {*}$predicate]
        }

        # Simulation state is not RUNNING or WIZARD

        statecontroller ::cond::simIsStable -events {
            ::adb <State>
        } -condition {
            [::adb stable]
        }

        # Simulation state is PREP or PAUSED
        #
        # Equivalent to simIsStable, but appropriate for controls
        # that send orders valid in PREP and PAUSED.

        statecontroller ::cond::simPrepPaused -events {
            ::adb <State>
        } -condition {
            [::adb state] in {PREP PAUSED}
        }

        # Simulation state is PREP or PAUSED, plus browser predicate

        statecontroller ::cond::simPP_predicate -events {
            ::adb <State>
        } -condition {
            [::adb state] in {PREP PAUSED} &&
            [$browser {*}$predicate]
        }

        # Order is available in the current state.
        #
        # Objdict:   order   THE:ORDER:NAME

        statecontroller ::cond::available -events {
            ::adb.order <Sync>
        } -condition {
            [::adb order available $order]
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
            ::adb.order <Sync>
        } -condition {
            [::adb order available $order]                &&
            [llength [$browser curselection]] == 1
        }

        # Order is available, one or more browser entries are selected.  The
        # browser should call update for its widgets.
        #
        # Objdict:   order     THE:ORDER:NAME
        #            browser   The browser window

        statecontroller ::cond::availableMulti -events {
            ::adb.order <Sync>
        } -condition {
            [::adb order available $order]              &&
            [llength [$browser curselection]] > 0
        }

        # Order is available, and the selection is deletable.
        # The browser should call update for its widgets.
        #
        # Objdict:   order     THE:ORDER:NAME
        #            browser   The browser window

        statecontroller ::cond::availableCanDelete -events {
            ::adb.order <Sync>
        } -condition {
            [::adb order available $order] &&
            [$browser candelete]
        }

        # Order is available, and the selection is updateable.
        # The browser should call update for its widgets.
        #
        # Objdict:   order     THE:ORDER:NAME
        #            browser   The browser window

        statecontroller ::cond::availableCanUpdate -events {
            ::adb.order <Sync>
        } -condition {
            [::adb order available $order] &&
            [$browser canupdate]
        }

        # Order is available, and the selection can be resolved.
        # The browser should call update for its widgets.
        #
        # Objdict:   order     THE:ORDER:NAME
        #            browser   The browser window

        statecontroller ::cond::availableCanResolve -events {
            ::adb.order <Sync>
        } -condition {
            [::adb order available $order] &&
            [$browser canresolve]
        }
    }

    # usage
    #
    # Returns the application's command-line syntax based on whether
    # in GUI mode or non-GUI mode
    
    typemethod usage {} {
        if {![app tkloaded]} {
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

        if {![app tkloaded]} {
            append usage \
                "\nSee athena_batch(1) for more information.\n"
        } else {
            append usage \
            "-url url            Load the URL in the detail browser.\n" \
            "                    '%' is replaced with '/'.\n"           \
            "\nSee athena(1) for more information.\n"
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

    # delete order parmdict message
    #
    # order    - The delete order name
    # parmdict - The deletion parameters
    # message  - "Are you sure" message
    #
    # Normalizes the message and asks the user if he is sure.  If so,
    # deletes sends the delete order.  This is for use by browsers.

    typemethod delete {order parmdict message} {
        set answer [messagebox popup \
                        -title         "Are you sure?"                  \
                        -icon          warning                          \
                        -buttons       {ok "Delete it" cancel "Cancel"} \
                        -default       cancel                           \
                        -onclose       cancel                           \
                        -ignoretag     $order                           \
                        -ignoredefault ok                               \
                        -parent        [app topwin]                     \
                        -message       [normalize $message]]

        if {$answer eq "cancel"} {
            return
        }

        # NEXT, Send the delete order.
        adb order senddict gui $order $parmdict

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

        if {![app tkloaded]} {
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

            if {[app tkloaded]} {
                app DisplayExitText $text
            } else {
                set f [open "error.log" w]
                puts $f $text
                close $f
                app DisplayExitText \
                    "Error; see [file join [pwd] error.log] for details."
            }
        }

        # NEXT, save the main window prefs, if any.
        if {!$opts(-ignoreuser) && [app tkloaded] && [winfo exists .main]} {
            .main saveprefs
        }

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

    # enter order ?parm value...?
    # enter order ?parmdict?
    #
    # order     - The name of an order
    # parmdict  - Initial parameter settings
    #
    # Pops up the order dialog for the named order given the parameters.

    typemethod enter {order args} {
        if {[llength $args] == 1} {
            set parmdict [lindex $args 0]
        } else {
            set parmdict $args
        }

        set order [string toupper $order]

        adb enter \
            -order     $order                      \
            -parmdict  $parmdict                   \
            -appname   "Athena [kiteinfo version]" \
            -master    [app topwin]                \
            -helpcmd   [list app help]
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

            if {[::athena::orders exists $order]} {
                set parms [split $parts(query) "=+"]
                if {[catch {
                    app enter $order $parms
                } result]} {
                    puts $::errorInfo
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

    # InsaneOnTick
    #
    # This is called when the scenario's on-tick sanity check fails.
    # The run stops automatically.

    typemethod InsaneOnTick {} {
        # FIRST, direct the user to the appropriate appserver page
        # if we are in GUI mode
        app show my://app/sanity/ontick

        if {[winfo exists .main]} {
            messagebox popup \
                -parent  [app topwin]         \
                -icon    error                \
                -title   "Simulation Stopped" \
                -message [normalize {
        On-tick sanity check failed; simulation stopped.
        Please see the On-Tick Sanity Check report for details.
                }]
        }
    }

    # EconError
    #
    # This is called when the econ model fails.

    typemethod EconError {} {
        append msg "Failure in the econ model caused it to be disabled."
        append msg "\nSee the detail browser for more information."

        if {[app tkloaded]} {
            set answer [messagebox popup              \
                            -icon warning             \
                            -message $msg             \
                            -parent [app topwin]      \
                            -title  $title            \
                            -buttons {ok "Ok" browser "Go To Detail Browser"}]

           if {$answer eq "browser"} {
               app show my://app/econ
           }
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
        # NEXT, create a new, blank scenario
        ::adb reset

        # NEXT, log it.
        log newlog new
        log normal scenario "New Scenario: Untitled"

        app puts "New scenario created"

        # NEXT, Resync the app with the RDB.
        adb dbsync
    }

    # open filename
    #
    # filename - The name of the .adb file to open.
    #
    # Opens and loads an existing scenario, throwing away unsaved 
    # changes.
    
    typemethod open {filename} {
        # FIRST, try to open the scenario.
        try {
            ::adb load $filename
        } trap {SCENARIO OPEN} {result} {
            # At least have an empty scenario.
            ::adb reset
            
            # Report the error
            app error {
                |<--
                Could not open scenario

                    $filename

                $result
            }
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
        adb dbsync
    }

    # save ?filename?
    #
    # filename - A new file name
    #
    # Saves the current scenario using the existing name.

    typemethod save {{filename ""}} {
        require {[adb stable]} "The scenario cannot be saved in this state."

        # FIRST, notify the simulation that we're saving, so other
        # modules can prepare.
        notifier send ::scenario <Saving>

        # NEXT, save the scenario to disk.
        try {
            adb save $filename
        } trap {SCENARIO SAVE} {result eopts} {
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

        log normal scenario "Save Scenario: [adb adbfile]"

        app puts "Saved Scenario [file tail [adb adbfile]]"

        notifier send $type <ScenarioSaved>

        return 1
    }

    # revert
    #
    # Revert the current scenario to its last save (or to the 
    # default initial scenario if there is none).

    typemethod revert {} {
        if {[adb adbfile] ne ""} {
            app open [adb adbfile]
        } else {
            app new
        }
    }

    # MakeAthena name ?filename?
    #
    # name     - The command name
    # filename - An .adb file name, or ""
    #
    # Creates the ::adb object.

    proc MakeAthena {name {filename ""}} {
        athena create $name \
            -adbfile $filename \
            -logcmd  ::log     \
            -subject ::adb

        log configure \
            -simclock [adb getclock]
    }

    # lock
    #
    # Locks the scenario by sending SIM:LOCK; displays sanity check
    # failures on rejection.

    typemethod lock {} {
        require {[adb state] eq "PREP"} \
            "The scenario cannot be locked in this state."

        set sev [adb sanity onlock check]
 
        if {$sev eq "WARNING" && [app tkloaded]} {
            app show my://app/sanity/onlock

            set answer \
                [messagebox popup \
                     -title         "On-lock Sanity Check Failed"    \
                     -icon          warning                          \
                     -buttons       {ok "Continue" cancel "Cancel"}  \
                     -default       my cancel                           \
                     -ignoretag     onlock_check_failed              \
                     -ignoredefault ok                               \
                     -parent        [app topwin]                     \
                     -message       [normalize {
                     The on-lock sanity check failed with warnings; 
                     one or more simulation objects are invalid.  See the 
                     Detail Browser for details.  Press "Cancel" and
                     fix the problems, or press "Continue" to 
                     go ahead and lock the scenario, in which 
                     case the invalid simulation objects will be 
                     ignored as the simulation runs.
                 }]]

            if {$answer eq "cancel"} {
                return
            }
        } elseif {$sev eq "ERROR"} {
            app show my://app/sanity/onlock
            return
        }

        adb lock
    }

    # unlock
    #
    # Unlocks the scenario.

    typemethod unlock {} {
        adb unlock
    }

    # rebase
    #
    # Rebases the app, unlocking it and returning it to the prep state.

    typemethod rebase {} {
        require {[adb state] eq "PAUSED"} \
            "The scenario cannot be rebased in this state."

        if {[app tkloaded]} {
            set answer \
                [messagebox popup \
                    -title         "Are you sure?"                  \
                    -icon          warning                          \
                    -buttons       {ok "Rebase" cancel "Cancel"}    \
                    -default       cancel                           \
                    -ignoretag     SIM:REBASE                       \
                    -ignoredefault ok                               \
                    -parent        [app topwin]                     \
                    -message       [normalize {
                        By pressing "Rebase" you will be creating a
                        new scenario based on the current simulation
                        state.  This action cannot be undone, so be
                        sure to save the old scenario before you do
                        this.
                    }]]

            if {$answer eq "cancel"} {
                return
            }
        }

        adb rebase
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

    adb halt

    # Gather any error context we may have
    set trace ""
    set level [info level]

    if {$level > 0} {
        set trace "bgerror context:\n"
        for {set lvl [expr {$level-1}]} {$lvl > 0} {incr lvl -1} {
            append trace "$lvl [info level $lvl]\n"
        }
    }

    if {![app tkloaded]} {
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



