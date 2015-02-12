#-----------------------------------------------------------------------
# TITLE:
#    coffer.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Coffer Class
#
#    A coffer contains the levels of all of an agent's resources, and tracks
#    them during strategy execution.  Its purpose is solely to support
#    tactic obligation; resources are actually expended during tactic
#    execution, which happens only if obligation succeeds.
#
#    A coffer can initialize itself from the "working_" tables or from 
#    another coffer.
#
#    Coffers are transient; a strategies and blocks will create coffers
#    and destroy them as needed.  They are not checkpointed as part of the
#    scenario.
#
# CASH RESERVE:
#    An actor's cash-reserve is allowed to be negative: any amount
#    of reserve is available.  Consequently, it's not clear that we need
#    to track the cash-reserve in the coffer, as it will never be a
#    binding constraint; unless, of course, we add a mode to pull all
#    remaining cash out of the reserve.
#
# SCENARIO LOCK:
#    On lock, we assume that the actors get whatever resources they 
#    ask for; however, we still need to track them because of tactics
#    like DEPLOY ALL and SPEND ALL.  Thus, the methods that draw down
#    personnel and cash-on-hand need to allow any amount on-lock, but
#    not actually draw down the amount below 0.
#
# TBD: Global refs: strategy
#
#-----------------------------------------------------------------------

# FIRST, create the class
oo::class create ::athena::coffer {
    #-------------------------------------------------------------------
    # Instance variables
    
    variable adb        ;# The athenadb(n) handle
    variable cash       ;# Cash-on-hand
    variable reserve    ;# Cash-reserve
    variable troops     ;# dict $g -> {mobilized, undeployed, $n} -> $troops
    variable plants     ;# dict $n -> repair level

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb ?agent?
    #
    # adb   - The athenadb(n) handle
    # agent - The agent whose coffer this is.
    #
    # Initializes the instance variables; if agent is given, loads the
    # agent's resources into the coffer.
    #
    # NOTE: We assume that the coffer is created at the beginning of
    # the agent's strategy execution, before any mobilization or deployment
    # changes and before any infrastructure maintenance are done.

    constructor {adb_ {agent ""}} {
        # FIRST, initialize the instance variables
        set adb     $adb_
        set cash    0.0
        set reserve 0.0
        set troops  [dict create]
        set plants  [dict create]

        if {$agent eq ""} {
            return
        }

        # NEXT, load the agent's cash resources.
        # NOTE: Apparently cash_on_hand can be zero on-lock, according
        # to a comment by DRH.
        $adb eval {
            SELECT max(0.0,cash_on_hand) AS cash,
                   max(0.0,cash_reserve) AS reserve
            FROM working_cash
            WHERE a = $agent
        } row {
            set cash    $row(cash)
            set reserve $row(reserve)
        }

        # NEXT, load the agent's undeployed personnel
        $adb eval {
            SELECT g, 
                   personnel AS mobilized, 
                   available
            FROM working_personnel
            JOIN agroups USING (g)
            WHERE a = $agent
        } {
            dict set troops $g mobilized  $mobilized
            dict set troops $g undeployed $available
        }

        # NEXT, initialize agent's infrastructure repair levels
        $adb eval {
            SELECT n, rho
            FROM plants_na
            WHERE a = $agent
        } {
            dict set plants $n $rho
        }
    }

    #-------------------------------------------------------------------
    # State Methods

    # getdict 
    #
    # Returns object state as a dictionary.

    method getdict {} {
        return [dict create cash $cash reserve $reserve troops $troops plants $plants]    
    }

    # setdict dict
    #
    # dict   - A [$coffer getdict] dictionary
    #
    # Restores the object's state

    method setdict {dict} {
        set cash    [dict get $dict cash]
        set reserve [dict get $dict reserve]
        set troops  [dict get $dict troops]
        set plants  [dict get $dict plants]
    }

    #-------------------------------------------------------------------
    # Queries
    
    # cash
    #
    # Returns current cash-on-hand

    method cash {} {
        return $cash
    }

    # reserve
    #
    # Returns current cash-reserve

    method reserve {} {
        return $reserve
    }

    # troops g location
    #
    # g        - Group name
    # location - "mobilized", "undeployed" or neighborhood
    #
    # Returns the number of troops in the specified location.
    # All troops in the playbox are counted as "mobilized".
    # Troops not yet deployed to neighborhoods are in the "undeployed"
    # location; troops deployed to neighborhood $n and not yet assigned
    # are in the "$n" location.

    method troops {g location} {
        if {[dict exists $troops $g $location]} {
            return [dict get $troops $g $location]
        }

        return 0
    }

    # plants n
    #
    # n     - A neighborhood
    #
    # Returns the average level of repair of the plants in n.

    method plants {n} {
        if {[dict exists $plants $n]} {
            return [dict get $plants $n]
        }

        return 0.0
    }

    #-------------------------------------------------------------------
    # Obligation Methods

    # spend amount
    #
    # amount  - Some amount of cash.
    #
    # Deducts the amount from the cash-on-hand.  On tick, requires that
    # the cash be available.

    method spend {amount} {
        if {[strategy ontick]} {
            require {$amount <= $cash} "insufficient cash"
        }

        let cash {max(0.0,$cash - $amount)}

        return
    }

    # deposit amount
    #
    # amount - Some amount of cash
    #
    # Deducts the amount from the cash-on-hand, and puts it in the
    # cash-reserve.

    method deposit {amount} {
        assert {[strategy ontick]}

        my spend $amount
        let reserve {$reserve + $amount}
    }
    
    # withdraw amount
    #
    # amount - Some amount of cash
    #
    # Deducts the amount from the cash-reserve, and puts it in the
    # cash-on-hand.  Per cash(sim), cash-reserve is allowed to go 
    # negative.

    method withdraw {amount} {
        assert {[strategy ontick]}

        let cash {$cash + $amount}
        let reserve {$reserve - $amount}
    }
    
    # demobilize g personnel
    #
    # g          - A group with personnel
    # personnel  - Personnel to remove from the playbox.
    #
    # Deducts the specified number of personnel from the group's 
    # undeployed personnel.

    method demobilize {g personnel} {
        assert {[strategy ontick]}

        set undeployed [my troops $g undeployed]
        require {$personnel <= $undeployed} "insufficient personnel"

        let undeployed {$undeployed - $personnel}
        dict set troops $g undeployed $undeployed

        let mobilized {[my troops $g mobilized] - $personnel}
        dict set troops $g mobilized $mobilized
    }

    # mobilize g personnel
    #
    # g          - A group with personnel
    # personnel  - Personnel to remove from the playbox.
    #
    # Adds the specified number of personnel to the group's 
    # undeployed personnel.

    method mobilize {g personnel} {
        assert {[strategy ontick]}

        set undeployed [my troops $g undeployed]

        let undeployed {$undeployed + $personnel}
        dict set troops $g undeployed $undeployed

        let mobilized {[my troops $g mobilized] + $personnel}
        dict set troops $g mobilized $mobilized
    }

    # deploy g n personnel
    #
    # g         - A force or organization group
    # n         - A neighborhood to which troops will be deployed
    # personnel - The number of troops to deploy
    #
    # Obligates the personnel as being unassigned in the neighborhood.

    method deploy {g n personnel} {
        set undeployed [my troops $g undeployed]
        set deployed   [my troops $g $n]

        if {[strategy ontick]} {
            require {$personnel <= $undeployed} "insufficient personnel"
        }

        let undeployed {max(0,$undeployed - $personnel)}
        let deployed   {$deployed + $personnel}

        dict set troops $g undeployed $undeployed
        dict set troops $g $n         $deployed
    }

    # assign g n personnel
    #
    # g         - A force or organization group
    # n         - A neighborhood in which g's troops might be be deployed
    # personnel - The number of troops to assign
    #
    # Deducts the specified number of g personnel from those deployed but 
    # unassigned in n.
    #
    # We don't worry about what they have been assigned to do; all that
    # matters is that they are no longer available for assignment.

    method assign {g n personnel} {
        set unassigned [my troops $g $n]

        if {[strategy ontick]} {
            require {$personnel <= $unassigned} "insufficient personnel"
        }

        let unassigned {max(0,$unassigned - $personnel)}
        dict set troops $g $n $unassigned
    }

    # repair n rho
    #
    # n        - A neighborhood that contains GOODS production infrastructure
    # rho      - The repair level of that infrastructure
    #
    # This keeps track of the level of repair of the infrastructure in n.
    # The level goes up each time a MAINTAIN tactic is obligated.

    method repair {n dRho} {
        set rho [my plants $n]

        let newRho {$rho + $dRho}

        dict set plants $n $newRho
    }
}

