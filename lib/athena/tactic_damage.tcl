#-----------------------------------------------------------------------
# TITLE:
#    tactic_damage.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena(n): Mark II Tactic, DAMAGE
#
#    A DAMAGE tactic, available only to the SYSTEM agent, sets
#    the average repair level of goods production infrastructure owned
#    by an actor in a neighborhood
#
#-----------------------------------------------------------------------

# FIRST, create the class.
::athena::tactic define DAMAGE "Damage Infrastructure" {system} {
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
        } elseif {$a ni [[my adb] agent names]} {
            dict set errdict a "No such actor: \"$a\"."
        }

        # Neighborhood
        if {$n eq ""} {
            dict set errdict n "No neighborhood selected."
        } elseif {$n ni [[my adb] nbhood names]} {
            dict set errdict n "No such neighborhood: \"$n\"."
        } elseif {$n ni [[my adb] nbhood local names]} {
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
        [my adb] eval {
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

::athena::orders define TACTIC:DAMAGE {
    meta title      "Tactic: Damage Infrastructure"
    meta sendstates PREP
    meta parmlist   {tactic_id name a n percent}

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Actor:" -for a
        actor a

        rcc "Nbhood:" -for n 
        localn n

        rcc "Repair Level:" -for percent
        percent percent
    }


    method _validate {} {
        # FIRST, prepare the parameters
        my prepare tactic_id  -required \
            -with [list $adb strategy valclass ::athena::tactic::DAMAGE]
        my returnOnError

        set tactic [$adb pot get $parms(tactic_id)]

        my prepare name    -toupper  -with [list $tactic valName]
        my prepare n
        my prepare a
        my prepare percent -type ipercent
    }

    method _execute {{flunky ""}} {
        set tactic [$adb pot get $parms(tactic_id)]
        my setundo [$tactic update_ {name n a percent} [array get parms]]
    }
}







