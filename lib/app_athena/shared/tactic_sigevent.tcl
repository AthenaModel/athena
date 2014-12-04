#-----------------------------------------------------------------------
# TITLE:
#    tactic.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Mark II Tactic, SIGEVENT
#
#    A SIGEVENT tactic writes a message to the sigevents log.
#
#-----------------------------------------------------------------------

# FIRST, create the class.
tactic define SIGEVENT "Log Significant Event" {system actor} {
    #-------------------------------------------------------------------
    # Instance Variables

    variable msg        ;# The message to log.
    
    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Initialize as tactic bean.
        next

        # NEXT, Initialize state variables
        set msg ""

        # NEXT, Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    # No special SanityCheck is required; any message is OK.

    # No special obligation is required; SIGEVENT takes no resources.

    method narrative {} {
        if {$msg ne ""} {
            return "Logs \"$msg\" to the sigevents log"
        } else {
            return "Logs \"???\" to the sigevents log"
        }
    }

    method execute {} {
        if {$msg ne ""} {
            set output $msg
        } else {
            set output "*NULL*"
        }
        sigevent log 1 tactic "SIGEVENT: $output" [my agent]
    }
}

#-----------------------------------------------------------------------
# TACTIC:* orders

# TACTIC:SIGEVENT
#
# Updates the tactic's parameters

order define TACTIC:SIGEVENT {
    title "Tactic: Log Significant Event"

    options -sendstates PREP

    form {
        rcc "Tactic ID:" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {beanload}

        rcc "Message:" -for msg
        text msg -width 40
    }
} {
    # FIRST, prepare and validate the parameters
    prepare tactic_id -required -with {::pot valclass tactic::SIGEVENT}
    prepare msg        
    returnOnError -final

    set tactic [pot get $parms(tactic_id)]

    # NEXT, update the block
    setundo [$tactic update_ {msg} [array get parms]]
}




