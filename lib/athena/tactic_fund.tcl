#-----------------------------------------------------------------------
# TITLE:
#    tactic_fund.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena(n): Mark II Tactic, FUND
#
#    A FUND tactic gives some amount of funds to another actor.
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# Tactic: FUND

::athena::tactic define FUND "Fund Another Actor" {actor} {
    #-------------------------------------------------------------------
    # Instance Variables

    variable mode    ;# ALL, EXACT, UPTO, PERCENT or EXCESS
    variable a       ;# The actor to fund
    variable amount  ;# Amount of money to fund the other actor
    variable percent ;# Percentage of money to use to fund the other actor

    # Transient data
    variable trans

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # Initialize as tactic bean
        next

        # Initialize state variables
        set mode    ALL
        set a       ""
        set amount  0.0
        set percent 0.0

        # Initial state is invalid (no a)
        my set state invalid

        set trans(amount) 0.0

        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    method SanityCheck {errdict} {
        # FIRST, check that the actor exists
        if {$a eq ""} {
            dict set errdict a "No actor selected."
        } elseif {$a ni [[my adb] actor names]} {
            dict set errdict a "No such actor: \"$a\"."
        }

        return [next $errdict]
    }

    method narrative {} {
        set s(a)       [link make actor $a]
        set s(amount)  "\$[commafmt $amount]"
        set s(percent) [format %.1f%% $percent]

        switch -exact -- $mode {
            ALL {
                return \
                    "Fund actor $s(a) with all remaining cash-on-hand each week."
            }

            EXACT {
                return "Fund actor $s(a) with $s(amount) each week."
            }

            UPTO {
                return "Fund actor $s(a) with up to $s(amount) each week."
            }

            PERCENT {
                return "Fund actor $s(a) with $s(percent) of cash-on-hand each week."
            }

            EXCESS {
                return \
                    "Fund actor $s(a) with any cash-on-hand over $s(amount) each week."
            }

            default {
                error "Invalid mode: \"$mode\""
            }
        }
    }

    # ObligateResources coffer
    #
    # coffer  - A coffer object with the owning agent's current
    #           resources
    #
    # Obligates the money to be funded based on mode 
    #
    # NOTE: FUND never executes on lock.

    method ObligateResources {coffer} {
        assert {[strategy ontick]}

        # FIRST, retrieve relevant data.
        set cash [$coffer cash]
        set funds 0.0

        # NEXT, depending on mode, try to obligate money
        switch -exact -- $mode {
            ALL {
                if {$cash > 0.0} {
                    set funds $cash
                }
            }

            EXACT {
                # This is the only one than could give rise to an error
                if {[my InsufficientCash $cash $amount]} {
                    return
                }
                set funds $amount
            }

            UPTO {
                let funds {max(0.0, min($cash, $amount))}
            }

            PERCENT {
                if {$cash > 0.0} {
                    let funds {double($percent/100.0) * $cash}
                }
            }

            EXCESS {
                let funds {max(0.0, $cash-$amount)}
            }

            default {
                error "Invalid mode: \"$mode\""
            }

        }

        # NEXT, get the actual amount to deposit.
        set trans(amount) $funds

        # NEXT, obligate it.
        $coffer spend $trans(amount)
    }

    method execute {} {
        # FIRST, Consume the money, if we can.
        [my adb] cash spend [my agent] NONE $trans(amount)

        # NEXT, give the money to the other actor.
        [my adb] cash give [my agent] $a $trans(amount)
           
        sigevent log 2 tactic "
            FUND: Actor {actor: [my agent]} funds {actor:$a}
            with \$[moneyfmt $trans(amount)]/week.
        " [my agent] $a
    }
}

# TACTIC:FUND
#
# Updates existing FUND tactic.

::athena::orders define TACTIC:FUND {
    meta title      "Tactic: Fund Actor"
    meta sendstates PREP
    meta parmlist {tactic_id name a mode amount percent}

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Actor:" -for a
        enum a -listcmd {$order_ allAgentsBut $tactic_id}

        rcc "Mode:"   -for mode
        selector mode {
            case ALL "Fund using all remaining cash-on-hand" {}

            case EXACT "Fund exactly this much cash-on-hand" {
                rcc "Amount:" -for amount
                text amount
            }

            case UPTO "Fund up to this much of cash-on-hand" {
                rcc "Amount:" -for amount
                text amount
            }

            case PERCENT "Fund this percentage of cash-on-hand" {
                rcc "Percent:" -for percent
                text percent
                label "%"
            }

            case EXCESS "Fund cash-on-hand in excess of given amount" {
                rcc "Amount:" -for amount
                text amount
            }
        }
    }


    method _validate {} {
        my prepare tactic_id -required -with {::strategy valclass ::athena::tactic::FUND}
        my returnOnError

        set tactic [$adb pot get $parms(tactic_id)]

        # FIRST, prepare and validate the parameters
        my prepare name     -toupper   -with [list $tactic valName]
        my prepare a        -toupper 
        my prepare amount   -toupper   -type   money
        my prepare percent  -toupper   -type   rpercent

        my returnOnError

        fillparms parms [$tactic view]

        if {$parms(mode) ne "PERCENT" && 
            $parms(mode) ne "ALL"     &&
            $parms(amount) == 0.0} {
                my reject amount "You must specify an amount > 0.0"
        }

        if {$parms(mode) eq "PERCENT" && $parms(percent) == 0.0} {
            my reject percent "You must specify a percent > 0.0"
        }
    }

    method _execute {{flunky ""}} {
        set tactic [$adb pot get $parms(tactic_id)]
        my setundo [$tactic update_ {
            name a mode amount percent
        } [array get parms]]
    }
}



