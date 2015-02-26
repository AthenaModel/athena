#-----------------------------------------------------------------------
# FILE: log.tcl
#
#   Logger manager
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

#-----------------------------------------------------------------------

snit::type log {
    #-------------------------------------------------------------------
    # Type Components

    typecomponent logger   ;# logger(n)
    
    #-------------------------------------------------------------------
    # Initialization

    # init
    #
    # Creates and initializes the Logger.

    typemethod init {} {
        # FIRST, get the log directory.
        set logDir [workdir join log app_sim]

        # NEXT, create a logger.
        set logger [logger %AUTO% \
                        -simclock   ::simclock               \
                        -logdir     $logDir                  \
                        -newlogcmd  [mytypemethod OnNewLog]]

        # NEXT, create new log files when appropriate
        notifier bind ::adb <Unlocked> $type [mytypemethod newlog prep]
    }

    #-------------------------------------------------------------------
    # Event Handlers

    # OnNewLog filename
    #
    # filename  - The new log file name.
    #
    # Notifies the App thread of a new log file name in response to
    # a call from the Logger thread, or from the logger in this thread.
    # This is used by the 
    # Log tab to display the latest log.

    typemethod OnNewLog {filename} {
        notifier send ::log <NewLog> $filename
    }

    #-------------------------------------------------------------------
    # logger(n) Subcommands

    delegate typemethod * to logger
}


