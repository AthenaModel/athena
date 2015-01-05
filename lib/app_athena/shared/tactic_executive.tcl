#-----------------------------------------------------------------------
# TITLE:
#    tactic_executive.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Mark II Tactic, EXECUTIVE
#
#    An EXECUTIVE tactic executes a single Athena executive command.
#
#-----------------------------------------------------------------------

# FIRST, create the class.
tactic define EXECUTIVE "Executive Command" {actor system} -onlock {
    #-------------------------------------------------------------------
    # Instance Variables

    variable command    ;# The command to execute
    
    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Initialize as a tactic bean.
        next

        # NEXT, Initialize state variables
        set command ""
        my set state invalid   ;# command is still unknown.

        # NEXT, Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    
    method SanityCheck {errdict} {
        if {[normalize $command] eq ""} {
            dict set errdict command "No executive command has been specified."   
        }

        return [next $errdict]
    }

    # No special obligation is required, as Athena has no way of knowing
    # what resources the command might require.

    method narrative {} {
        if {[normalize $command] eq ""} {
            return "Executive command: ???"
        } else {
            return "Executive command: $command"
        }
    }

    method execute {} {
        # FIRST, set the order state to TACTIC, so that
        # relevant orders can be executed.

        set oldState [order state]
        order state TACTIC
            
        # NEXT, create a savepoint, so that we can back out
        # the command's changes on error.
        rdb eval {SAVEPOINT executive}  

        # NEXT, attempt to run the user's command.
        if {[catch {
            executive eval $command
        } result eopts]} {
            # FAILURE 

            # FIRST, roll back any changes made by the script; 
            # it threw an error, and we don't want any garbage
            # left behind.
            rdb eval {ROLLBACK TO executive}

            # NEXT, restore the old order state
            order state $oldState

            # NEXT, log failure.
            sigevent log error tactic "
                EXECUTIVE: Failed to execute command {$command}: $result
            " [my agent]

            executive errtrace

            # TBD: Report as sanity check failure
            return
        }

        # SUCCESS

        # NEXT, release the savepoint; the script ran without
        # error.
        rdb eval {RELEASE executive}

        # NEXT, restore the old order state
        order state $oldState

        # NEXT, log success
        sigevent log 1 tactic "
            EXECUTIVE: $command
        " [my agent]
    }
}

#-----------------------------------------------------------------------
# TACTIC:* orders

# TACTIC:EXECUTIVE
#
# Updates the tactic's parameters

order define TACTIC:EXECUTIVE {
    title "Tactic: Executive Command"

    options -sendstates PREP

    form {
        rcc "Tactic ID:" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Command:" -for command
        text command -width 80
    }
} {
    # FIRST, prepare and validate the parameters
    prepare tactic_id -required -with {::pot valclass tactic::EXECUTIVE}
    prepare command             -type tclscript
    returnOnError -final

    set tactic [pot get $parms(tactic_id)]

    prepare name  -toupper  -with [list $tactic valName]

    # NEXT, update the block
    setundo [$tactic update_ {name command} [array get parms]]
}




