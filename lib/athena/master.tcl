#-----------------------------------------------------------------------
# TITLE:
#    master.tcl
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
#    * Initializes the ::athena::slave module in the thread.
#    * Sends the request to the background slave.
#    * Uses the busy/progress API to notify the scenario of the progress
#      of the request.
#    * Manages all communication with the slave.
#
#-----------------------------------------------------------------------

snit::type ::athena::master {
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

    variable info -array {
        slave        ""
        syncfile     ""
        completionCB ""
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

    # advance ?options...?
    #
    # -ticks ticks       Run until now + ticks
    # -until tick        Run until tick
    #
    # Causes the simulation to advance time in a background thread.
    # The thread runs until the requested run time is complete or we
    # get an error.  Assumes (for now) that the scenario is locked.

    method advance {args} {
        assert {[$adb locked] && [$adb idle]}

        # FIRST, get the number of weeks.  By default, run for one week.
        set ticks 1

        foroption opt args -all {
            -ticks {
                set ticks [lshift args]
                let stoptime {$ticks + [$adb clock now]}
            }

            -until {
                set stoptime [lshift args]
                let ticks {$stoptime - [$adb clock now]}
            }
        }

        # NEXT, Make sure it's in the future.
        assert {$ticks > 0}

        # NEXT, save this instance to the syncfile.
        #
        # TBD: Could track orders to see when things have changed since
        # last sync.
        #
        # TBD: Need to be able to save without setting unchanged flag!
        $adb save $info(syncfile)

        # NEXT, set the busy lock.
        $adb busy set "Running until [$adb clock toString $stoptime]"
        $adb progress 0.0

        # NEXT, if the thread doesn't exist, create it.
        if {$info(slave) eq ""} {
            $self SlaveInit
        }

        # NEXT, request a time advance.
        set info(completionCB) AdvanceComplete
        $self Slave advance $ticks
    }

    # AdvanceComplete tag
    #
    # tag   - COMPLETE | ERROR
    #
    # This method is called when the time advance is complete.

    method AdvanceComplete {tag} {
        $adb busy clear

        if {$tag eq "COMPLETE"} {
            $adb load $info(syncfile)
            $adb dbsync
        }
    }

    #-------------------------------------------------------------------
    # Slave Callbacks
    #
    # The slave calls these commands when communicating with the master
    # thread.

    # _log level comp message
    #
    # Passes the slave's log messages along to the main log.
    
    method _log {level comp message} {
        $adb log $level bg.$comp $message
    }

    # _progress tag i n
    #
    # tag   - A progress tag, or COMPLETE when the request is finished.
    # i     - Progress counter
    # n     - Progress limit
    #
    # Updates the busy progress, and terminates it when done.

    method _progress {tag i n} {
        # FIRST, notify app of progress.
        if {$n != 0} {
            $adb progress [expr {double($i)/double($n)}]
        } else {
            $adb progress wait
        }

        # NEXT, if we're done, clean up.
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
        set info(slave) [thread::create]

        thread::send $info(slave) [list set auto_path $::auto_path]

        thread::send $info(slave) {
            package require athena
            namespace import ::projectlib::* ::athena::*
        }

        $self Slave init [thread::id] $adb $info(syncfile)
    }

    # Slave subcommand ?args?
    #
    # subcommand  - A subcommand of the slave module
    # args        - Arguments to the subcommand.
    # 
    # Sends an asynchronous command to the slave.

    method Slave {subcommand args} {
        thread::send -async $info(slave) \
            [list ::athena::slave $subcommand {*}$args]
    }
}




