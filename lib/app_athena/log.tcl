#-----------------------------------------------------------------------
# FILE: log.tcl
#
#   Logger thread manager
#
# PACKAGE:
#   app_sim(n) -- athena(1) implementation package
#
# PROJECT:
#   Athena S&RO Simulation
#
# AUTHOR:
#    Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Type Definition
#
# The log type creates and manages a Logger thread, and serves as a 
# proxy for the logger(n) object in that thread.


#-----------------------------------------------------------------------

snit::type log {
    #-------------------------------------------------------------------
    # Type Components

    typecomponent logger   ;# logger(n), unless threads.
    
    #-------------------------------------------------------------------
    # Type Variables

    typevariable tid ""    ;# The thread ID of the Logger thread.

    #-------------------------------------------------------------------
    # Initialization

    # init threads
    #
    # threads - Flag; if 0, do logging in this thread.  If 1, do 
    #           logging in the Logger thread.
    #
    # Creates and initializes the Logger.

    typemethod init {threads} {
        # FIRST, get the log directory.
        set logDir [workdir join log app_sim]

        # NEXT, either create the Logger thread, or just a normal logger.
        if {$threads} {
            set marsDir   [file normalize [file join $::marsutil::library ..]]
            set athenaDir [file normalize [file join $::app_athena::library ..]]
            set clockdata [simclock cget -clockdata]

            set tid [thread::create [format {
                lappend auto_path %s %s
                package require app_sim_logger

                app init          \
                    -clockdata %s \
                    -appthread %s \
                    -logdir    %s \
                    -newlogcmd [list ::log NewLog]
                thread::wait
            } $marsDir $athenaDir $clockdata [thread::id] $logDir]]

            # NEXT, prepare to keep time synchronized.
            notifier bind ::sim <Time>    $type [mytypemethod SimTime]
            notifier bind ::sim <DbSyncA> $type [mytypemethod SimTime]
        } else {
            set logger [logger %AUTO% \
                            -simclock   ::simclock               \
                            -logdir     $logDir                  \
                            -newlogcmd  [mytypemethod NewLog]]
        }
    }

    #-------------------------------------------------------------------
    # Event Handlers

    # NewLog filename
    #
    # filename  - The new log file name.
    #
    # Notifies the App thread of a new log file name in response to
    # a call from the Logger thread, or from the logger in this thread.
    # This is used by the 
    # Log tab to display the latest log.

    typemethod NewLog {filename} {
        notifier send ::log <NewLog> $filename
    }


    # SimTime
    #
    # Synchronizes the Logger thread's simclock with the App thread's
    # simclock when time or startdate changes.

    typemethod SimTime {} {
        thread::send -async $tid [list app simtime [simclock checkpoint]]
    }

    #-------------------------------------------------------------------
    # Termination

    # release
    #
    # Releases the logger thread, which should then shut down.

    typemethod release {} {
        if {$tid ne ""} {
            thread::release $tid
        }
    }

    #-------------------------------------------------------------------
    # logger(n) Subcommands

    delegate typemethod * using {%t Forward %m}

    # Forward subcommand args...
    #
    # Forwards the subcommand to the Logger.

    typemethod Forward {args} {
        if {$tid ne ""} {
            thread::send -async $tid [list log {*}$args]
        } else {
            $logger {*}$args
        }
    }
}


