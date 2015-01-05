#-----------------------------------------------------------------------
# TITLE:
#    tactic_deposit.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Mark II Tactic, DEPOSIT
#
#    A DEPOSIT tactic deposits money from cash-on-hand to cash-reserve.
#
#-----------------------------------------------------------------------

# FIRST, create the class.
tactic define DEPOSIT "Deposit Money" {actor} {
    #-------------------------------------------------------------------
    # Instance Variables

    variable mode    ;# ALL, EXACT, UPTO, PERCENT or EXCESS
    variable amount  ;# Amount of money to deposit, based on mode
    variable percent ;# Percent of money to deposit if mode is PERCENT

    # Transient Data
    variable trans

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # Initialize as tactic bean.
        next

        # Initialize state variables
        set mode    ALL
        set amount  0.0
        set percent 0.0

        set trans(amount) 0.0

        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    # No special SanityCheck is required.

    method narrative {} {
        set amt [moneyfmt $amount]

        switch -exact -- $mode {
            ALL {
                return "Deposit all cash-on-hand to cash reserve."
            }

            EXACT {
                return "Deposit \$$amt to cash reserve."
            }

            UPTO {
                return "Deposit up to \$$amt of cash-on-hand to cash reserve."
            }

            PERCENT {
                return "Deposit $percent% of cash-on-hand to cash reserve."
            }

            EXCESS {
                return "Deposit any cash-on-hand over \$$amt to cash reserve."
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
    # Obligates the money to be deposited based on mode 
    #
    # NOTE: DEPOSIT never executes on lock.

    method ObligateResources {coffer} {
        assert {[strategy ontick]}
        
        # FIRST, retrieve relevant data.
        set cash [$coffer cash]
        set deposit 0.0

        # NEXT, depending on mode, try to obligate money
        switch -exact -- $mode {
            ALL {
                if {$cash > 0.0} {
                    set deposit $cash
                }
            }

            EXACT {
                # This is the only one than could give rise to an error
                if {[my InsufficientCash $cash $amount]} {
                    return
                }
                set deposit $amount
            }

            UPTO {
                let deposit {max(0.0, min($cash, $amount))}
            }

            PERCENT {
                if {$cash > 0.0} {
                    let deposit {double($percent/100.0) * $cash}
                }
            }

            EXCESS {
                let deposit {max(0.0, $cash-$amount)}
            }

            default {
                error "Invalid mode: \"$mode\""
            }

        }

        # NEXT, get the actual amount to deposit.
        set trans(amount) $deposit

        # NEXT, obligate it.
        $coffer deposit $trans(amount)
    }

    method execute {} {
        cash deposit [my agent] $trans(amount)

        sigevent log 2 tactic "
            DEPOSIT: [my agent] deposits \$[moneyfmt $trans(amount)] to reserve.
        " [my agent]
    }
}

#-----------------------------------------------------------------------
# TACTIC:DEPOSIT order

# TACTIC:DEPOSIT
#
# Updates existing DEPOSIT tactic.

order define TACTIC:DEPOSIT {
    title "Tactic: Deposit Money"
    options -sendstates PREP

    form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Mode:"   -for mode
        selector mode {
            case ALL "Deposit all remaining cash-on-hand" {}

            case EXACT "Deposit exactly this much cash-on-hand" {
                rcc "Amount:" -for amount
                text amount
            }

            case UPTO "Deposit up to this much of cash-on-hand" {
                rcc "Amount:" -for amount
                text amount
            }

            case PERCENT "Deposit this percentage of cash-on-hand" {
                rcc "Percent:" -for percent
                text percent
                label "%"
            }

            case EXCESS "Deposit cash-on-hand in excess of given amount" {
                rcc "Amount:" -for amount
                text amount
            }
        }
    }
} {
    # FIRST, prepare the parameters
    prepare tactic_id  -required -with {::pot valclass tactic::DEPOSIT}
    returnOnError 
    
    set tactic [pot get $parms(tactic_id)]

    prepare name       -toupper  -with [list $tactic valName]
    prepare mode       -toupper  -selector
    prepare amount     -toupper  -type money
    prepare percent    -toupper  -type rpercent

    returnOnError 

    # NEXT, do the cross checks
    fillparms parms [$tactic view]

    if {$parms(mode) ne "PERCENT" && 
        $parms(mode) ne "ALL"     &&
        $parms(amount) == 0.0} {
            reject amount "You must specify an amount > 0.0"
    }

    if {$parms(mode) eq "PERCENT" && $parms(percent) == 0.0} {
        reject percent "You must specify a percent > 0.0"
    }

    returnOnError -final

    # NEXT, update the tactic, saving the undo script
    set undo [$tactic update_ {
        name mode amount percent
    } [array get parms]]

    # NEXT, modify the tactic
    setundo $undo
}






