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
    # port   - The port on which to listen to http requests.
    # web    - 1 if Arachne should start the web server, and 0 otherwise.

    typevariable info -array {
        port    8080
        web     0
    }

    # cases array: tracks scenarios
    #
    # names      - The names of the different cases.
    # sdb-$case  - The scenario object for $case 

    typevariable cases -array {
        names {}
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
        set result ""

        # FIRST, get the command line options.
        set adbfile ""
        set script ""
        set scratchdir ""

        foroption opt argv -all {
            -port {
                set info(port) [lshift argv]
            }
            -scenario { 
                set adbfile [lshift argv]

                if {![file isfile $adbfile]} {
                    throw FATAL "-scenario does not exist: \"$adbfile\""
                }
            }
            -scratchdir {
                set scratchdir [lshift argv]
            }
            -script { 
                set script [lshift argv] 

                if {![file isfile $script]} {
                    throw fatal "-script does no exist: \"$script\""
                }
            }
            -web {
                set info(web) 1
            }
        }

        # NEXT, initialize the scratch directory
        scratchdir init $scratchdir
        scratchdir clear

        # NEXT, add the base case scenario.
        $type AddBaseCase $adbfile $script

        # NEXT, start the server if desired.
        if {$info(web)} {
            $type StartServer
            set result vwait
        }

        return $result
    }

    #-------------------------------------------------------------------
    # Case Management

    # case names
    #
    # Returns the list of case names.

    typemethod {case names} {} {
        return $cases(names)
    }


    # sdb case ?subcommand ...?
    #
    # case - A case name
    #
    # By default, returns the sdb for the case.  If a subcommand is
    # given, executes the subcommand.

    typemethod sdb {case args} {
        if {[llength $args] == 0} {
            return cases(sdb-$case)
        }

        tailcall $cases(sdb-$case) {*}$args
    }

    # AddBaseCase adbfile script
    #
    # adbfile  - A scenario file, or ""
    # script   - A script file or ""
    #
    # Adds the case to the data structure.

    typemethod AddBaseCase {adbfile script} {
        puts "Loading base case: $adbfile $script"
        set sdb [athena new \
                    -logcmd [$type MakeLog sdb-base] \
                    -subject base]

        lappend cases(names) base
        set cases(sdb-base) $sdb

        $logs(sdb-base) normal base "Initialization scenario"
        try {
            if {$adbfile ne ""} {
                $sdb load $adbfile                
            }
        } trap {SCENARIO OPEN} {result} {
            throw FATAL "Could not load $adbfile:\n$result"
        }

        try {
            if {$script ne ""} {
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

        # FIRST, create a web server log
        ahttpd init \
            -port       $info(port)             \
            -secureport ""                      \
            -debug                              \
            -logcmd     [$type MakeLog ahttpd]  \
            -docroot    [appdir join htdocs]

        # NEXT, Add content
        [scenario_domain new] ahttpd
    }


    #-------------------------------------------------------------------
    # Application Log

    # MakeLog name 
    #
    # Creates a log for the given name.

    typemethod MakeLog {name} {
        set logdir [scratchdir join log $name]
        file mkdir $logdir ;# TBD: Neede?

        set logs($name) [logger %AUTO% -logdir $logdir]

        return $logs($name)
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
}

