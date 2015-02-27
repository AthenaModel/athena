#-----------------------------------------------------------------------
# TITLE:
#    tactic_build.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena(n): Mark II Tactic, BUILD
#
#    A BUILD tactic spends cash-on-hand to build new goods sector
#    production infrastructure
#
#-----------------------------------------------------------------------

# FIRST, create the class.
::athena::tactic define BUILD "Build Infrastructure" {actor} {
    #-------------------------------------------------------------------
    # Instance Variables

    variable mode    ;# Spending mode: CASH or EFFORT
    variable num     ;# Number of plants to build
    variable amount  ;# Amount of money to spend depending on mode
    variable n       ;# Nbhood in which to build plants
    variable done    ;# A flag indicating the build is complete

    # Transient Data
    variable trans
    
    #-------------------------------------------------------------------
    # Constructor

    constructor {pot_ args} {
        next $pot_

        # Initialize state variables
        set mode    CASH
        set amount  0
        set num     1
        set n       {}  
        set done    0

        my set state invalid

        set trans(amount)   0.0

        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    method SanityCheck {errdict} {
        # Neighborhood
        if {$n eq ""} {
            dict set errdict n "No neighborhood selected."
        } elseif {$n ni [[my adb] nbhood names]} {
            dict set errdict n "No such neighborhood: \"$n\"."
        } elseif {$n ni [[my adb] nbhood local names]} {
            dict set errdict n "Neighborhood \"$n\" is not local, should be."
        }

        # Non-zero work-weeks if mode is effort
        if {$mode eq "EFFORT" && $num == 0} {
            dict set errdict num "Must specify > 0 plants to build."
        }

        return [next $errdict]
    }

    method narrative {} {
        set s(n)       [::athena::link make nbhood $n]
        set s(amount)  "\$[commafmt $amount]"
        set s(num)     [expr {$num == 1 ? "1 plant" : "$num plants"}]

        switch -exact -- $mode {
            EFFORT {
                return \
                  "Use up to all remaining cash-on-hand each week to fund $num work-weeks each week in $s(n)."
            }

            CASH {
                return \
                    "Use at most $s(amount)/week to build infrastructure in $s(n)."
            }

            default {
                error "Invalid mode: \"$mode\"."
            }
        }
    }

    # ObligateResources coffer
    #
    # coffer  - A coffer object with the owning agent's current
    #           resourcemaxAmts
    #
    # Obligates the money to be spent.

    method ObligateResources {coffer} {
        set cash [$coffer cash]
        if {$cash == 0.0} {
            my Fail CASH "Need money to build, have none."
            return 0
        }

        set owner [my agent]
        set spend 0.0

        switch -exact -- $mode {
            EFFORT {
                set cost [[my adb] plant buildcost $n $owner $num]
                let spend {min($cost, $cash)}
            }

            CASH {
                let spend {min($amount, $cash)}
            }

            default {
                error "Invalid mode: \"$mode\"."
            }
        }

        $coffer spend $spend
        set trans(amount) $spend

        return 1

    }
 
    method execute {} {
        set owner [my agent]

        [my adb] cash spend $owner BUILD $trans(amount)

        lassign [[my adb] plant build $n $owner $trans(amount)] old new

        if {$mode eq "EFFORT"} {
            [my adb] sigevent log 2 tactic "
                BUILD: Actor {actor:$owner} spends
                \$[moneyfmt $trans(amount)] in an effort to 
                construct $num infrastructure plant(s) in $n. 
                $old plant(s) were worked on, $new plant(s) started.
            " $owner $n
        } elseif {$mode eq "CASH"} {
            [my adb] sigevent log 2 tactic "
                BUILD: Actor {actor:$owner} spends
                \$[moneyfmt $trans(amount)] in an effort to 
                construct as much infrastructure plant(s) in $n as possible. 
                $old plant(s) were worked on, $new plant(s) started.
            " $owner $n
        }
    
    }
}

#-----------------------------------------------------------------------
# TACTIC:* orders

# TACTIC:BUILD
#
# Updates existing BUILD tactic.

::athena::orders define TACTIC:BUILD {
    meta title      "Tactic: Build Infrastructure"
    meta sendstates PREP
    meta parmlist   {tactic_id name n mode num amount}

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Nbhood:" -for n 
        localn n

        rcc "Construction Mode:" -for mode
        selector mode {
            case EFFORT "Use as much cash-on-hand it takes to work up to" {
                rcc "Number:" -for num
                text num 
                label "work weeks each week."
            }

            case CASH "Use up to this amount of cash-on-hand" {
               rcc "Amount:" -for amount
               text amount
               label "dollars"
            }
        }
    }


    method _validate {} {
        # FIRST, prepare the parameters
        my prepare tactic_id  -required \
            -with [list $adb strategy valclass ::athena::tactic::BUILD]
        my returnOnError

        set tactic [$adb pot get $parms(tactic_id)]

        my prepare name    -toupper  -with [list $tactic valName]
        my prepare n
        my prepare mode    -toupper  -selector
        my prepare amount  -type money
        my prepare num     -type iquantity

        my returnOnError

        # NEXT, check cross-constraints
        fillparms parms [$tactic view]

        if {$parms(num) == 0} {
            my reject num "You must specify a number of plants > 0."
        }
    }

    method _execute {{flunky ""}} {
        set tactic [$adb pot get $parms(tactic_id)]
        my setundo [$tactic update_ {
            name n mode amount num
        } [array get parms]]
    }
}







