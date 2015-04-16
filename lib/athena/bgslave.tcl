#-----------------------------------------------------------------------
# TITLE:
#    bgslave.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Background Slave Module
#
#    This module wraps a single instance of athenadb(n) in the context 
#    of a background thread.  It:
#
#    * Configures athenadb(n) for speed, e.g., RDB monitoring is disabled.
#    * Implements as subcommands all activities we want to do in a 
#      background thread; the master thread calls these using 
#      thread::send.
#    * Manages all communications with the master thread.
#    * Log messages and other results are sent to the master thread 
#      for processing by athenadb(n)'s "master" component.
#
#    A scenario contains too much data to send it all to the child thread
#    via thread::send.  Instead, the master thread creates a "syncfile",
#    an .adb file containing the data the slave needs.  The slave opens
#    this syncfile, and later saves its results to it.
# 
#-----------------------------------------------------------------------

snit::type ::athena::bgslave {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # info array
    #
    # master   - The thread ID of the master (i.e., foreground) thread.
    # fgadb    - The name of the foreground athenadb(n) object.
    # syncfile - The name of the synchronization .adb file.

    typevariable info -array {
        master   ""
        fgadb    ""
        syncfile ""
    }

    #-------------------------------------------------------------------
    # Initialize and Termination

    # init master fgadb syncfile
    #
    # master   - The thread ID of the master thread.
    # fgadb    - The name of the relevant athenadb(n) instance in the 
    #            master thread.
    # syncfile - The name of the .adb file to use for synchronization
    #            with the master thread.
    #
    # Saves the data, and initializes the thread's athenadb(n) instance.

    typemethod init {master fgadb syncfile} {
        # FIRST, save the data.
        set info(master)   $master
        set info(fgadb)    $fgadb
        set info(syncfile) $syncfile

        # NEXT, create the athenadb instance.
        try {
            workdir init
            athenadb create ::sdb \
                -logcmd  [mytypemethod log] \
                -adbfile $info(syncfile)

            # NEXT, turn off all RDB monitoring and transactions on
            # orders.  We'll explicitly run important operations in 
            # a single RDB transaction for maximum speed.
            sdb order monitor off
            sdb order transactions off
        } on error {result eopts} {
            $type error $result $eopts
        }

        $type log normal slave "Initialized."
    }

    # shutdown
    #
    # Tells the slave to release the thread.

    typemethod shutdown {} {
        $type log normal slave "Shutting down."
        thread::release
    }

    #-------------------------------------------------------------------
    # Operation: Advancing Time for Locked Scenario

    # advance weeks
    #
    # weeks - Number of weeks to advance time.
    #
    # Advances time by the requested number of weeks, notifying the
    # master of progress.

    typemethod advance {weeks} {
        # No transaction is needed, as sim.tcl already wraps the run
        # in a transaction

        try {
            sdb advance -ticks $weeks -tickcmd [mytypemethod TickCmd]
            sdb save
            $type progress COMPLETE $weeks $weeks
        } on error {result eopts} {
            $type error $result $eopts
        }
    }

    # TickCmd tag i n
    #
    # Notifies the master of our progress.  Skip COMPLETE; we aren't
    # complete until we've saved the results.

    typemethod TickCmd {tag i n} {
        if {$tag ne "COMPLETE"} {
            $type progress $tag $i $n
        }
    }
    
    #-------------------------------------------------------------------
    # Utility Type Methods
    
    # log level comp message
    #
    # level     - The log level
    # comp      - The component name
    # message   - The log message
    #
    # Sends the log message to the master thread.  The string "bg." will
    # be added to the component name.

    typemethod log {level comp message} {
        # TBD: Sending the log to the master makes no sense.
        # $type master _log $level $comp $message
    }

    # progress tag ?i n?
    #
    # tag       - The progress tag, e.g., PAUSED, RUNNING, COMPLETE
    # i         - The progress counter, 0 to n
    # n         - The progress limit
    #
    # Sends the progress data to the master thread.

    typemethod progress {tag {i 0} {n 0}} {
        $type master _progress $tag $i $n
    }

    # error msg eopts
    #
    # msg   - The error message
    # eopts - The error options from catch/try
    #
    # Passes the error along to the master.

    typemethod error {msg eopts} {
        $type master _error $msg [dict get $eopts -errorinfo]
    } 

    # master subcommand ?args...?
    #
    # subcommand  - A subcommand of the "master" component
    # args        - Subcommand arguments.
    #
    # Sends the subcommand to the master thread's "master" component.

    typemethod master {subcommand args} {
        thread::send $info(master) \
            [list $info(fgadb) background $subcommand {*}$args]
    }

    #-------------------------------------------------------------------
    # Private Helper Type Methods



    
}