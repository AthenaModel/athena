#-----------------------------------------------------------------------
# TITLE:
#   worker.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Event loop work proc manager.  It executes a command repeatedly in
#   the context of the event loop, waiting -delay milliseconds between 
#   calls, until the command returns true or the worker object is
#   destroyed.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export worker
}

#-----------------------------------------------------------------------
# worker

snit::type ::projectlib::worker {
    #-------------------------------------------------------------------
    # Components

    component timeout ;# Timeout used for callbacks
    

    #-------------------------------------------------------------------
    # Options

    delegate option -delay to timeout as -interval

    # -command cmd
    #
    # Command to be called to do work.  It should return true when
    # the work is complete, and false otherwise.

    option -command

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        install timeout using timeout ${selfns}::timeout \
            -interval   100                              \
            -repetition off                              \
            -command    [mymethod WorkStep]

        $self configurelist $args
    }

    destructor {
        catch {$timeout destroy}
    }

    #-------------------------------------------------------------------
    # Event Handlers

    # WorkStep
    #
    # Calls the user's work command once.  If the command returns 
    # true, it is rescheduled; if false, not.
    #
    # NOTE: if the command throws an error, it will not be rescheduled.

    method WorkStep {} {
        set flag [{*}$options(-command)]

        if {!$flag} {
            $timeout schedule
        }
    }
    

    #-------------------------------------------------------------------
    # User API

    # start
    #
    # Starts the worker going.  It's an error if the worker is already
    # going.

    method start {} {
        $self WorkStep

        return
    }
}
