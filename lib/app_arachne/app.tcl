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

    # domains
    #
    # Array of domains by prefix, e.g., "/scenario"

    typevariable domains -array {}

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
                set adbfile [lshift argv]

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

        # NEXT, purge any JSON files from htdocs/temp
        set filenames [glob \
                        -nocomplain \
                        -directory [appdir join htdocs temp] \
                        *.json]

        foreach f $filenames {
            file delete -force -- $f
        }  

        # NEXT, initialize the application log
        $type newlog app

        # NEXT, add the base case scenario.
        case init $scenariodir

        $type InitializeBaseCase $adbfile $script

        # NEXT, define the domains.
        set domains(/scenario) [/scenario new]
        set domains(/debug)    [/debug new]     ;# TBD: If -debug

        set helpdb [appdir join docs athena.helpdb]
        set domains(/help)     \
            [::projectlib::helpdomain new /help "Athena Help" $helpdb]

        # NEXT, start the server if desired.
        if {!$info(test)} {
            $type StartServer
            set result vwait
        } else {
            set result ""
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
                case import $adbfile case00                
            }
        } trap ATHENA {result} {
            throw FATAL "Could not import $adbfile:\n$result"
        } trap ARACHNE {result} {
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
        ahttpd init -allowtml \
            -port       $info(port)             \
            -secureport ""                      \
            -logcmd     [$type newlog ahttpd]   \
            -docroot    [appdir join htdocs]

        # NEXT, Add content
        tempdomain create ::/temp /temp
        puts "Temp Directory: [/temp tempdir]"
        app log normal app "Temp Directory: [/temp tempdir]"

        foreach domain [array names domains] {
            $domains($domain) ahttpd
        }
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

    # profile ?depth? command ?args...?
    #
    # Calls the command once using [time], in the caller's context,
    # and logs the outcome, returning the command's return value.
    # In other words, you can stick "$self profile" before any command name
    # and profile that call without changing code or adding new routines.
    #
    # If the depth is given, it must be an integer; that many "*" characters
    # are added to the beginning of the log message.

    typemethod profile {args} {
        if {[string is integer -strict [lindex $args 0]]} {
            set prefix "[string repeat * [lshift args]] "
        } else {
            set prefix ""
        }

        set msec [lindex [time {
            set result [uplevel 1 $args]
        } 1] 0]

        puts "${prefix}profile [list $args] $msec"

        return $result
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

