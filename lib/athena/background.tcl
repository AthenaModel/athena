#-----------------------------------------------------------------------
# TITLE:
#    background.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Background Processing Master
#
#    This module manages all background processing for the foreground
#    thread for this scenario.  It is an athenadb(n) component.  When
#    the scenario needs to do work in the background, it requests it
#    through this module.  This module:
#
#    * Creates a background thread (if it hasn't already been created)
#    * Initializes the ::athena::bgslave module in the thread.
#    * Sends the request to the background slave.
#    * Uses the busy/progress API to notify the scenario of the progress
#      of the request.
#    * Manages all communication with the slave.
#
#-----------------------------------------------------------------------

snit::type ::athena::background {
    #-------------------------------------------------------------------
    # Components

    component adb       ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Instance Variables

    # info array
    #
    # slave         - The slave's thread ID
    # syncfile      - The name of the synchronization .adb file.
    # completionCB  - The name of the method to call when the request
    #                 is complete.
    # tickCmd       - TickCmd for advance request.

    variable info -array {
        slave        ""
        syncfile     ""
        completionCB ""
        tickCmd      ""
    }
    

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        # FIRST, save athenadb(n) handle and options.
        set adb $adb_

        # NEXT, create and remember the syncfile name.
        set info(syncfile) [workdir join slave.adb]
    }


    # destructor 
    #
    # Shutdown the slave, if we have one.

    destructor {
        catch {$self shutdown}
    }

    #-------------------------------------------------------------------
    # Queries

    # busy
    #
    # This is just the scenario's busy flag; but it's convenient to
    # be able to ask the master directly.

    delegate method busy to adb

    #-------------------------------------------------------------------
    # Request: Shutdown

    # shutdown
    #
    # Shuts down the slave, if it's active.

    method shutdown {} {
        if {$info(slave) ne ""} {
            $self Slave shutdown
            set info(slave) ""
        }
    }
    
    

    #-------------------------------------------------------------------
    # Request: Time Advance

    # advance ticks ?tickcmd?
    #
    # ticks    - Number of ticks to advance time.
    # tickcmd  - Command to call on each tick and at end.
    #
    # Causes the simulation to advance time in a background thread.
    # The thread runs until the requested run time is complete or we
    # get an error.  Assumes that the scenario is locked.

    method advance {ticks {tickcmd ""}} {
        assert {[$adb locked] && [$adb idle]}

        $adb log normal background "advance $ticks $tickcmd"

        # FIRST, save this instance to the syncfile.
        #
        # TBD: Could track orders to see when things have changed since
        # last sync.

        $adb savetemp $info(syncfile)

        # NEXT, set the busy lock; this is not currently interruptible.
        let stoptime {[$adb clock now] + $ticks}
        $adb busy set "Running until [$adb clock toString $stoptime]"
        $adb progress 0.0

        # NEXT, if the thread doesn't exist, create it.
        if {$info(slave) eq ""} {
            $self SlaveInit
        }

        # NEXT, request a time advance.
        set info(tickCmd)      $tickcmd
        set info(completionCB) AdvanceComplete
        $self Slave advance $ticks
    }

    # AdvanceComplete tag
    #
    # tag   - COMPLETE | ERROR
    #
    # This method is called when the time advance is complete.

    method AdvanceComplete {tag} {
        set info(tickCmd) ""

        if {$tag eq "COMPLETE"} {
            $adb loadtemp $info(syncfile)
            $adb busy clear
            $adb dbsync
        } else {
            $adb busy clear
        }
    }

    #-------------------------------------------------------------------
    # Slave Callbacks
    #
    # The slave calls these commands when communicating with the master
    # thread.

    # _newlog filename
    #
    # Logs the slave's new log file name.
    
    method _newlog {filename} {
        set logfile [file tail $filename]
        set logdir  [file tail $logfile]
        $adb log normal background "newlog $logdir/$logfile"
    }

    # _progress tag i n
    #
    # tag   - A progress tag, or COMPLETE when the request is finished.
    # i     - Progress counter
    # n     - Progress limit
    #
    # Updates the busy progress, and terminates it when done.

    method _progress {tag i n} {
        set progflag ""
        if {$info(tickCmd) ne ""} {
            set progflag [{*}$info(tickCmd) [$adb state] $i $n]
        }

        # Report progress if the tickcmd didn't handle it.
        if {$progflag ne "no_progress"} {
            $adb progress [expr {double($i)/double($n)}] 
        }

        if {$tag eq "COMPLETE"} {
            $self $info(completionCB) $tag
            set info(completionCB) ""
        }
    }

    # _error msg errinfo
    #
    # msg      - Error message
    # errinfo  - Stack trace
    #
    # Handles errors from the slave.

    method _error {msg errinfo} {
        $self $info(completionCB) ERROR
        set info(completionCB) ""
        return -code error -errorinfo $errinfo \
            "Error in background thread: $msg"
    }
    
    #-------------------------------------------------------------------
    # Utility Methods

    # SlaveInit
    #
    # Initializes the slave.

    method SlaveInit {} {
        assert {$info(slave) eq ""}

        # FIRST, create the thread.
        set info(slave) [thread::create]

        # NEXT, set the auto_path, so that it can find packages.
        thread::send $info(slave) [list set auto_path $::auto_path]

        # NEXT, initialize the starkit library, so that we can load
        # binary extensions.  Note: this is a bit fraught; we may
        # find that we need to prevent some from loading.
        if {[info exists ::starkit::topdir]} {
            thread::send $info(slave) [list package require starkit]
            thread::send $info(slave) \
                [list set ::starkit::topdir $::starkit::topdir]
        }

        # NEXT, load the athena(n) library.
        thread::send $info(slave) {
            package require athena
            namespace import ::projectlib::* ::athena::*
        }

        # NEXT, ask the bgslave module to initialize itself.
        $self Slave init [thread::id] $adb $info(syncfile) \
            [$adb cget -logdir].bg
    }

    # Slave subcommand ?args?
    #
    # subcommand  - A subcommand of the slave module
    # args        - Arguments to the subcommand.
    # 
    # Sends an asynchronous command to the slave.

    method Slave {subcommand args} {
        thread::send -async $info(slave) \
            [list ::athena::bgslave $subcommand {*}$args]
    }
}




