#-----------------------------------------------------------------------
# TITLE:
#   app.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# PACKAGE:
#   app_arachne(n): Arachne Implementation Package
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Arachne main application object.
#
#-----------------------------------------------------------------------

snit::type app {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # info array - configuration
    #
    # port        - The port on which to listen to http requests.
    # secureport  - The port on which to listen to https requests.
    # web         - 1 if Arachne should start the web server, and 0 
    #               otherwise.

    typevariable info -array {
        port         8080
        secureport   8081
        test         0
    }

    # logs array: Logs by log name
    typevariable logs -array {}

    #-------------------------------------------------------------------
    # Initialization

    # init argv
    #
    # argv - The command line options
    #
    # Processes the command line and initiates the program's actions.
    # If it returns "vwait", the application loader will vwait forever.

    typemethod init {argv} {
        appdir init
        set result ""

        # FIRST, load the mods
        try {
            mod load
            mod apply
        } trap {MODERROR LOAD} {result} {
            throw FATAL "Could not load mods: $result"
        } trap {MODERROR APPLY} {result} {
            throw FATAL "Could not apply mods: $result"
        }

        # NEXT, get the command line options.
        set scenariodir [appdir join scenarios]
        set adbfile ""
        set script ""
        set scratchdir ""

        foroption opt argv -all {
            -scenariodir {
                set scenariodir [file normalize [lshift argv]]
            }
            -port {
                set info(port) [lshift argv]
            }
            -scenario { 
                set adbfile [file normalize [lshift argv]]

                if {![file isfile $adbfile]} {
                    throw FATAL "-scenario does not exist: \"$adbfile\""
                }
            }
            -scratchdir {
                set scratchdir [file normalize [lshift argv]]
            }
            -script { 
                set script [file normalize [lshift argv]] 

                if {![file isfile $script]} {
                    throw fatal "-script does not exist: \"$script\""
                }
            }
            -test {
                set info(test) 1
            }
        }

        # NEXT, initialize the scratch directory
        scratchdir init $scratchdir
        scratchdir clear

        # NEXT, initialize the application log
        $type newlog app

        # NEXT, add the base case scenario.
        case init $scenariodir

        $type InitializeBaseCase $adbfile $script

        # NEXT, start the server if desired.
        if {!$info(test)} {
            $type StartServer
            set result vwait
        }

        return $result
    }

    # InitializeBaseCase adbfile script
    #
    # adbfile  - A scenario file, or ""
    # script   - A script file or ""
    #
    # Initializes the base case using the file and script.

    typemethod InitializeBaseCase {adbfile script} {
        app log normal app "Initializing case00: adbfile=$adbfile script=$script"

        try {
            if {$adbfile ne ""} {
                case import case00 $adbfile                
            }
        } trap {SCENARIO OPEN} {result} {
            throw FATAL "Could not import $adbfile:\n$result"
        }

        try {
            if {$script ne ""} {
                set sdb [case get case00]
                $sdb executive call $script
            }
        } on error {result eopts} {
            puts [dict get $eopts -errorinfo]
            throw FATAL "Error in $script:\n$result"
        }
    }

    #-------------------------------------------------------------------
    # Web Server

    # StartServer
    #
    # Invokes the ahttpd web server, which is a global resource.
    #
    # TBD: Ultimately, should start only -secureport

    typemethod StartServer {} {
        puts "Starting server on port $info(port)"
        app log normal app "Starting server on port $info(port)"

        # ::tls::init -tls1 1 -tls1.1 0 -tls1.2 0 -ssl2 0 -ssl3 0

        # FIRST, create a web server log
        ahttpd init \
            -port       $info(port)             \
            -secureport ""                      \
            -logcmd     [$type newlog ahttpd]   \
            -docroot    [appdir join htdocs]

        # NEXT, Add content
        [scenario_domain new] ahttpd
        [debug_domain new] ahttpd     ;# TBD: enable this on -debug.

    }


    #-------------------------------------------------------------------
    # Application Logs

    # newlog name 
    #
    # Creates a log for the given name.

    typemethod newlog {name} {
        if {$info(test)} {
            set logs($name) [myproc Swallow]
        } else {
            set logdir [scratchdir join log $name]
            set logs($name) [logger %AUTO% -logdir $logdir]
        }


        return $logs($name)
    }

    # log level comp message
    #
    # Logs to the main application log.

    typemethod log {level comp message} {
        $logs(app) $level $comp $message
    }

    #-------------------------------------------------------------------
    # Utility Commands
    
    # dumpstack

    typemethod dumpstack {} {
        set i [info frame]

        puts "Stack Frames:"
        for {set i [info frame]} {$i > 0} {incr i -1} {
            array set frm [info frame $i]
            puts "$i: $frm(cmd)"
        }
    }

    # version
    #
    # Returns the application version

    typemethod version {} {
        return [kiteinfo version]
    }

    # Swallow args
    proc Swallow {args} {}
}

