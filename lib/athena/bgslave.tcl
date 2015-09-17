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
    # logdir   - The log directory for the scenario log.
    #
    # Saves the data, and initializes the thread's athenadb(n) instance.

    typemethod init {master fgadb syncfile logdir} {
        # FIRST, save the data.
        set info(master)   $master
        set info(fgadb)    $fgadb
        set info(syncfile) $syncfile

        # NEXT, create the athenadb instance.
        try {
            workdir init
            athenadb create ::sdb \
                -logdir  $logdir

            notifier bind ::sdb <NewLog> $type [mytypemethod newlog]

            # NEXT, turn off all RDB monitoring and transactions on
            # orders.  We'll explicitly run important operations in 
            # a single RDB transaction for maximum speed.
            sdb order monitor off
            sdb order transactions off
        } on error {result eopts} {
            $type error $result $eopts
        }

        set modlist [mod list]
        if {[llength $modlist] > 0} {
            sdb log normal app "Loaded Mods:\n[dictab format $modlist -headers]"
        } else {
            sdb log normal app "No mods loaded."
        }


        sdb log normal slave "Initialized."
    }

    # shutdown
    #
    # Tells the slave to release the thread.

    typemethod shutdown {} {
        sdb log normal slave "Shutting down."
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
            sdb loadtemp $info(syncfile)
            sdb log newlog advance
            sdb advance -ticks $weeks -tickcmd [mytypemethod TickCmd]
            sdb savetemp $info(syncfile)
            $type progress [sdb sim stopreason] $weeks $weeks
        } on error {result eopts} {
            $type error $result $eopts
        }
    }

    # TickCmd tag i n
    #
    # Notifies the master of our progress.  Skip COMPLETE; we aren't
    # complete until we've saved the results.

    typemethod TickCmd {tag i n} {
        if {$tag ni {"COMPLETE" "FAILURE"}} {
            $type progress $tag $i $n
        }
    }
    
    #-------------------------------------------------------------------
    # Utility Type Methods
    
    # newlog filename
    #
    # filename - The new log file name.
    #
    # Sends the new log file name to the master thread.

    typemethod newlog {filename} {
        $type master _newlog $filename
    }

    # progress tag ?i n?
    #
    # tag       - The progress tag, e.g., PAUSED, BUSY, RUNNING, COMPLETE
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
        set errinfo [dict get $eopts -errorinfo]
        sdb log error slave $errinfo

        $type master _error $msg $errinfo
    } 

    # master subcommand ?args...?
    #
    # subcommand  - A subcommand of the "master" component
    # args        - Subcommand arguments.
    #
    # Sends the subcommand asynchronously to the master thread's 
    # "background" component.

    typemethod master {subcommand args} {
        thread::send -async $info(master) \
            [list $info(fgadb) background $subcommand {*}$args]
    }

    #-------------------------------------------------------------------
    # Private Helper Type Methods



    
}