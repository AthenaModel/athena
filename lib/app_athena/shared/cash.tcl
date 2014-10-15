#-----------------------------------------------------------------------
# TITLE:
#    cash.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Cash Management
#
#    This module is responsible for managing an actor's cash during
#    strategy execution.  It should only be used during the duration
#    of [strategy tock], or to set up for tactic tests in the test suite.
#
#-----------------------------------------------------------------------

snit::type cash {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # Total expenditures on the various sectors, to be given to the
    # Economics model
    typevariable allocations -array {
        goods  0.0
        black  0.0
        pop    0.0
        region 0.0
        world  0.0
    }

    #-------------------------------------------------------------------
    # Public Methods


    # start
    #
    # Sets up the expenditures table in preparation for on-lock strategy 
    # execution 

    typemethod start {} {
        # FIRST, initialize expenditures table
        rdb eval {
            DELETE FROM expenditures;
            INSERT INTO expenditures(a) SELECT a FROM actors;
        }
    }

    # load
    #
    # Loads every actor's cash balances into working_cash for use during
    # strategy execution, and (except on lock) gives the actor his income.

    typemethod load {} {
        # FIRST, clear expenditures
        $type reset
        
        # NEXT, load up the working cash table, giving the actor his income.
        # Note that for BUDGET actors, actors_view.income IS the actor's
        # budget.
        rdb eval {
            DELETE FROM working_cash;
        }

        rdb eval {
            SELECT a, 
                   cash_reserve, 
                   income, 
                   cash_on_hand
            FROM actors_view;
        } {
            let cash_on_hand { $cash_on_hand + $income }

            rdb eval {
                INSERT INTO working_cash(a, cash_reserve, income, cash_on_hand)
                VALUES($a, $cash_reserve, $income, $cash_on_hand)
            }
            
        }
    }

    # save
    #
    # Save every actors' cash balances back into the actors table.
    #
    # Note that budget actors don't get to keep their unspent cash.
    # They won't usually touch their cash_reserve, but if they do we
    # preserve it.

    typemethod save {} {
        # FIRST, we should not be locking the scenario
        assert {![strategy locking]}

        rdb eval {
            SELECT a, cash_reserve, cash_on_hand, gifts FROM working_cash
        } {
            rdb eval {
                UPDATE actors
                SET cash_reserve = $cash_reserve,
                    cash_on_hand = $cash_on_hand + $gifts
                WHERE a=$a AND atype='INCOME';
                
                -- Budget actors don't get to keep unspent cash.
                UPDATE actors
                SET cash_reserve = $cash_reserve,
                    cash_on_hand = 0
                WHERE a=$a AND atype='BUDGET';
            }
        }

        rdb eval {
            DELETE FROM working_cash
        }
    }

    # reset
    #
    # Clear cash expenditures 

    typemethod reset {} {
        # FIRST, clear the sector allocations
        foreach sector [array names allocations] {
            set allocations($sector) 0.0
        }
        
        # NEXT, initialize the actors' expenditures table.
        rdb eval {
            UPDATE expenditures 
            SET goods = 0, black  = 0, pop   = 0,
                actor = 0, region = 0, world = 0;
        }
    }

    #-------------------------------------------------------------------
    # Queries
    

    # get a parm
    #
    # a    - An actor
    # parm - A column name
    #
    # Retrieves a row dictionary, or a particular column value, from
    # working_cash

    typemethod get {a {parm ""}} {
        # FIRST, get the data
        rdb eval {SELECT * FROM working_cash WHERE a=$a} row {
            if {$parm ne ""} {
                return $row($parm)
            } else {
                unset row(*)
                return [array get row]
            }
        }

        return ""
    }

    # onhand a
    #
    # a  - An actor
    #
    # Returns the actor's cash-on-hand.  If the actor is the acting
    # actor, then it's the working cash-on-hand; otherwise, it's the
    # actor's cash-on-hand prior to strategy execution.

    typemethod onhand {a} {
        if {$a eq [strategy acting]} {
            return [cash get $a cash_on_hand]
        } else {
            return [actor get $a cash_on_hand]
        }
    }

    # reserve a
    #
    # a  - An actor
    #
    # Returns the actor's cash-reserve.  If the actor is the acting
    # actor, then it's the working cash-reserve; otherwise, it's the
    # actor's cash-reserve prior to strategy execution.

    typemethod reserve {a} {
        if {$a eq [strategy acting]} {
            return [cash get $a cash_reserve]
        } else {
            return [actor get $a cash_reserve]
        }
    }

    #-------------------------------------------------------------------
    # Strategy Execution Commands
    

    # spend a eclass dollars
    #
    # a         - An actor
    # eclass    - An expenditure class, or NONE.
    # dollars   - Some number of dollars
    #
    # Deducts dollars from cash_on_hand if there are sufficient funds;
    # returns 1 on success and 0 on failure.  If strategy is locking then
    # only the allocation of funds is made as a baseline, no money is
    # actually deducted.  If the eclass is not NONE, then the expenditure 
    # is allocated to the sectors.

    typemethod spend {a eclass dollars} {
        # FIRST, if strategy is locking only allocate the money to
        # the expenditure class as a baseline, and then we are done.
        if {[strategy locking]} {

            # NEXT, if dollars is negative, which can happen on lock,
            # then nothing is expended from working cash. But the tactic 
            # still executes and the money is allocated to sectors
            # as if the full amount had been spent
            if {$dollars < 0.0} {
                set dollars 0.0
            }

            rdb eval {
                UPDATE working_cash
                SET cash_on_hand = cash_on_hand - $dollars
                WHERE a=$a
            }

            $type AllocateByClass $a $eclass $dollars

            return 1
        }

        # NEXT, can he afford it
        set cash_on_hand [cash get $a cash_on_hand]

        if {$dollars > $cash_on_hand} {
            return 0
        }

        # NEXT, expend it.
        rdb eval {
            UPDATE working_cash 
            SET cash_on_hand = cash_on_hand - $dollars
            WHERE a=$a
        }

        # NEXT, allocate the money to the expenditure class
        $type AllocateByClass $a $eclass $dollars

        return 1
    }

    # spendon a dollars profile
    #
    # a         - An actor
    # dollars   - Some number of dollars
    # profile   - A spending profile
    #
    # Deducts dollars from cash_on_hand if there are sufficient funds;
    # returns 1 on success and 0 on failure.  If strategy is locking then
    # only the allocation of funds is made as a baseline, no money is
    # actually deducted.  The expenditure is allocated to the sectors
    # according to the profile, which is a dictionary of sectors and
    # fractions.

    typemethod spendon {a dollars profile} {
        # FIRST, if strategy is locking, then the tactic needs to
        # execute.
        if {[strategy locking]} {

            # NEXT, if dollars is negative, which can happen on lock,
            # then nothing is expended from working cash. But the tactic 
            # still executes and the money is allocated to sectors
            # as if the full amount had been spent
            if {$dollars < 0} {
                set dollars 0
            }

            rdb eval {
                UPDATE working_cash
                SET cash_on_hand = cash_on_hand - $dollars
                WHERE a=$a
            }

            $type Allocate $a $profile $dollars

            return 1
        }

        # NEXT, can he afford it
        set cash_on_hand [cash get $a cash_on_hand]
    
        if {$dollars > $cash_on_hand} {
            return 0
        }
    
        # NEXT, expend it.
        rdb eval {
            UPDATE working_cash 
            SET cash_on_hand = cash_on_hand - $dollars
            WHERE a=$a
         }

        # NEXT, allocate the money to the expenditure class
        $type Allocate $a $profile $dollars

        return 1
    }

    # refund a eclass dollars
    #
    # a         - An actor
    # eclass    - An expenditure class, or NONE.
    # dollars   - Some number of dollars
    #
    # Refunds dollars to the actor's cash on hand.  If the eclass is
    # not NONE, then the dollars are removed from the sector allocations.

    typemethod refund {a eclass dollars} {
        # FIRST, give him the money back.
        rdb eval {
            UPDATE working_cash 
            SET cash_on_hand = cash_on_hand + $dollars
            WHERE a=$a
        }

        # NEXT, the money no longer flows into the other sectors.
        $type AllocateByClass $a $eclass [expr {-1.0*$dollars}]
    }

    # Allocate a profile dollars
    #
    # eclass   - An expenditure class, or NONE
    # profile  - An expenditure profile dictionary (shares by sector)
    # dollars  - Some number of dollars.
    #
    # Allocates an expenditure of dollars to the CGE sectors.  If
    # the number of dollars is negative, the dollars are removed from
    # the sectors.  In any case, the dollars are allocated according
    # to the profile.

    typemethod Allocate {a profile dollars} {
        # FIRST, determine the total number of shares for this expenditure
        # profile
        set denom 0.0
        dict for {sector share} $profile {
            let denom {$denom + $share}
        }

        # NEXT, if there are no shares to allocate then we are done
        if {$denom == 0.0} {
            return
        }

        # NEXT, allocate fractions of the expenditure to each
        # sector
        dict for {sector share} $profile {
            let frac {$share/$denom}
            let amount {$frac*$dollars}
            let allocations($sector) {$allocations($sector) + $amount}
            
            rdb eval "
                UPDATE expenditures
                SET $sector = $sector + \$amount,
                    tot_$sector = tot_$sector + \$amount
                WHERE a = \$a
            "
        }
    }

    # AllocateByClass a eclass dollars
    #
    # a        - The actor spending the money
    # eclass   - An expenditure class, or NONE
    # dollars  - Some number of dollars.
    #
    # Allocates an expenditure of dollars to the CGE sectors.  If
    # the number of dollars is negative, the dollars are removed from
    # the sectors.  In any case, the dollars are allocated according
    # to the econ.shares.<class>.* parameter values.
    # 
    # If the eclass is NONE, this call is a no-op.

    typemethod AllocateByClass {a eclass dollars} {
        # FIRST, if we don't care we don't care.
        if {$eclass eq "NONE"} {
            return
        }

        # NEXT, retrieve the profile.
        set profile [dict create]
        foreach sector [array names allocations] {
            dict set profile $sector [parm get econ.shares.$eclass.$sector]
        }

        # NEXT, allocate it.
        $type Allocate $a $profile $dollars
    }

    # allocations
    #
    # Returns a dictionary of the expenditures by sector.

    typemethod allocations {} {
        return [array get allocations]
    }

    # deposit a dollars
    #
    # a       - An actor
    # dollars - A positive number of dollars
    #
    # Moves dollars from cash_on_hand to cash_reserve, if there's
    # sufficient funds.  Returns 1 on success and 0 on failure.

    typemethod deposit {a dollars} {
        set cash_on_hand [cash get $a cash_on_hand]

        if {$dollars > $cash_on_hand} {
            return 0
        }

        rdb eval {
            UPDATE working_cash
            SET cash_reserve = cash_reserve + $dollars,
                cash_on_hand = cash_on_hand - $dollars
            WHERE a=$a;
        }

        return 1
    }

    # withdraw a dollars
    #
    # a       - An actor
    # dollars - A positive number of dollars
    #
    # Moves dollars from cash_reserve to cash_on_hand.  We do not
    # worry about whether there are sufficient funds or not;
    # cash_reserve is allowed to go negative.

    typemethod withdraw {a dollars} {
        set cash_reserve [cash get $a cash_reserve]

        rdb eval {
            UPDATE working_cash 
            SET cash_reserve = cash_reserve - $dollars,
                cash_on_hand = cash_on_hand + $dollars
            WHERE a=$a;
        }

        return 1
    }

    # give a dollars
    #
    # owner     - The funding actor
    # a         - The funded actor
    # dollars   - Some number of dollars
    #
    # Adds dollars to the actor's "gifts" balance; this will
    # be added to the actor's cash-on-hand when the working cash
    # is saved.  This allows us to give money to the actor that 
    # should only be available after this strategy execution is
    # complete.
    # If the fuding actor is a BUDGET actor and the funded actor
    # an INCOME actor, then the money is entering the economy and
    # must appear as an expenditure to the actor sector by the 
    # funding actor.

    typemethod give {owner a dollars} {
        rdb eval {
            UPDATE working_cash 
            SET gifts = gifts + $dollars
            WHERE a=$a
        }
        
        if {[actor get $owner atype] eq "BUDGET" &&
            [actor get $a     atype] eq "INCOME"} {
                rdb eval {
                    UPDATE expenditures
                    SET actor=actor+$dollars,
                        tot_actor=tot_actor+$dollars
                    WHERE a=$owner
                }
        }
    }
}

