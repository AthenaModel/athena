#-----------------------------------------------------------------------
# TITLE:
#    tactic_damage.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena_sim(1): Mark II Tactic, DAMAGE
#
#    A DAMAGE tactic, available only to the SYSTEM agent, sets
#    the average repair level of goods production infrastructure owned
#    by an actor in a neighborhood
#
#-----------------------------------------------------------------------

# FIRST, create the class.
tactic define DAMAGE "Damage Infrastructure" {system} {
    #-------------------------------------------------------------------
    # Instance Variables

    variable percent ;# The new repair level, as a percentage
    variable n       ;# Nbhood in which to damage plants
    variable a       ;# An agent owning infrastructure

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # Initialize as tactic bean.
        next

        # Initialize state variables
        set percent 0
        set n       {}  
        set a       {}

        my set state invalid

        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    method SanityCheck {errdict} {
        # Actor
        if {$a eq ""} {
            dict set errdict a "No actor selected."
        } elseif {$a ni [agent names]} {
            dict set errdict a "No such actor: \"$a\"."
        }

        # Neighborhood
        if {$n eq ""} {
            dict set errdict n "No neighborhood selected."
        } elseif {$n ni [nbhood names]} {
            dict set errdict n "No such neighborhood: \"$n\"."
        } elseif {$n ni [nbhood local names]} {
            dict set errdict n "Neighborhood \"$n\" is not local, should be."
        }

        return [next $errdict]
    }

    method narrative {} {
        set s(n)       [link make nbhood $n]
        set s(a)       [link make actor $a]
        set s(percent) [format %.1f%% $percent]

        return \
            "Set average repair level of any infrastructure owned by $s(a) in $s(n) to $s(percent) of full capacity."
    }

    method execute {} {
        # FIRST, if no infrastructure to damage trivially exit
        if {![plant exists [list $n $a]]} {
            sigevent log 2 tactic "
                DAMAGE: No infrastructure is affected since {actor:$a} does
                not own any infrastructure in {nbhood:$n}
            "

            return
        }

        # NEXT, get current repair level
        let current {100.0 * [plant get [list $n $a] rho]}

        set s(current) [format %.1f%% $current]
        set s(percent) [format %.1f%% $percent]

        if {$percent < $current} {
            sigevent log 2 tactic "
                DAMAGE: Infrastructure owned by {actor:$a} in {nbhood:$n} 
                repair level reduced from $s(current) to $s(percent).
            " $a $n
        } else {
            sigevent log 2 tactic "
                DAMAGE: Infrastructure owned by {actor:$a} in {nbhood:$n} 
                repair level increased from $s(current) to $s(percent).
            " $a $n
        }

        let newRho {$percent/100.0}

        # NEXT, update average repair level in the plants_na table
        rdb eval {
            UPDATE plants_na
            SET rho=$newRho
            WHERE n=$n AND a=$a
        }
    }
}

#-----------------------------------------------------------------------
# TACTIC:* orders

# TACTIC:DAMAGE
#
# Updates existing DAMAGE tactic.

order define TACTIC:DAMAGE {
    title "Tactic: Damage Infrastructure"
    options -sendstates PREP

    form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {beanload}

        rcc "Actor:" -for a
        actor a

        rcc "Nbhood:" -for n 
        localn n

        rcc "Repair Level:" -for percent
        percent percent
    }
} {
    # FIRST, prepare the parameters
    prepare tactic_id  -required -type tactic::DAMAGE
    returnOnError

    set tactic [tactic get $parms(tactic_id)]

    prepare n
    prepare a
    prepare percent -type ipercent

    returnOnError -final

    # NEXT, update the tactic, saving the undo script
    setundo [$tactic update_ {n a percent} [array get parms]]
}






