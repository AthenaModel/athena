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
    # Type Variable

    typevariable logdir  ;# The parent log directory.
    
    
    #-------------------------------------------------------------------
    # Initialization

    # init
    #
    # Creates and initializes the Logger.

    typemethod init {} {
        # FIRST, get the log directory.
        set logdir [workdir join log]
        set mydir [file join $logdir application]

        # NEXT, create a logger.
        set logger [logger %AUTO% \
                        -logdir     $mydir                  \
                        -newlogcmd  [mytypemethod OnNewLog]]
    }

    # logdir
    #
    # Returns the log directory name.

    typemethod logdir {} {
        return $logdir
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


