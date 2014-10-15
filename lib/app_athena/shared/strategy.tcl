#-----------------------------------------------------------------------
# TITLE:
#    strategy.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Strategy Class
#
#    An agent's strategy determines his actions.  It consists of a number
#    of blocks, each of which contains zero or more conditions and tactics.
#
#    Strategy objects are typically named after their owning agents,
#    i.e., ::strategy::<agent>; however, this is not required.  The
#    SYSTEM agent's strategy is created as part of the scenario; actor
#    strategies are created and destroyed with the actor.
#
#-----------------------------------------------------------------------

# FIRST, create the class
beanclass create strategy

# NEXT, define class members
oo::objdefine strategy {
    #-------------------------------------------------------------------
    # Transient Class Variables

    variable locking   ;# Flag: 1 if locking the scenario, 0 otherwise.
    variable acting    ;# Name of the acting agent, or "" if none.
    
    #-------------------------------------------------------------------
    # Initialization
    
    # init
    #
    # Initializes strategy execution on new scenario.

    method init {} {
        # FIRST, create strategies for predefined agents.
        foreach agent [agent system names] {
            log normal strategy "Creating strategy for agent $agent"
            my create_ $agent
        }

        # NEXT, initialize class data.
        set locking 0
    }

    # rebase
    #
    # Mark blocks "onlock" if they executed at the last tick.
    # Clear block and tactic execution data.

    method rebase {} {
        foreach a [agent names] {
            set s [strategy getname $a]

            foreach block [$s blocks] {
                if {[$block execstatus] eq "SUCCESS"} {
                    $block set onlock 1
                } else {
                    $block set onlock 0
                }

                $block reset
            }
        }
    }

    #-------------------------------------------------------------------
    # Strategy Execution

    # start
    #
    # This method is called on scenario lock, when the simulation is
    # moving from PREP to PAUSED.
    # the paused state

    method start {} {
        my locking 1
        my DoTock $locking
        my locking 0
    }

    # tock
    #
    # This method is called when the simulation is running forward in
    # time

    method tock {} {
        my locking 0
        my DoTock $locking
    }

    # locking ?flag?
    #
    # flag   - Optionally, the new value of the flag.
    #
    # This method sets and returns the locking flag. This is called by 
    # strategy elements (e.g., blocks and tactics) whose behavior depends on
    # whether this is "on lock" or "on tick".

    method locking {{flag ""}} {
        if {$flag ne ""} {
            set locking $flag
        }
        return $locking
    }

    # ontick
    #
    # Returns 1 if we are not currently locking the scenario.  This is for
    # use by tactics who behave differently on tick.

    method ontick {} {
        return [expr {!$locking}]
    }

    # acting ?a?
    #
    # Returns the name of the acting agent, or "" if we aren't in
    # the middle of strategy execution.
    #
    # If a is given, sets the acting agent to $a.  NOTE: This for use
    # by the test suite only.

    method acting {{a "-"}} {
        if {$a ne "-"} {
            set acting $a
        } 
        return $acting
    }

    # DoTock
    #
    # Executes agent strategies on lock and on normal ticks.  In either
    # case we load working tables that might affect or be affected by
    # tactic execution.  Then, for each agent we execute all eligible
    # blocks.  Finally, we save the working tables back into the scenario,
    # to reflect the agents' decisions.
    #
    # A block is eligible for execution on lock if its onlock flag is set.
    #
    # A block is eligible for execution on tick if:
    #
    # * Its time constraints are met
    # * Its attached conditions (if any) are met according to its "cmode".
    #
    # An eligible tactic might not be able to execute on tick due to lack
    # of resources.

    method DoTock {onlock} {
        # FIRST, Set up working tables.  This includes giving
        # the actors their incomes, unless we are locking, in which
        # case no cash moves
        profile 1 control load
        profile 1 cash load
        profile 1 personnel load
        profile 1 service_eni load
        profile 1 plant load
        profile 1 cap access load

        # TBD: Replace these as appropriate as the tactic types are defined.
        profile 1 driver::abevent reset
        profile 1 tactic::BROADCAST reset
        profile 1 tactic::FLOW reset
        profile 1 tactic::STANCE reset

        profile 1 unit reset

        # NEXT, execute each agent's strategy.

        foreach acting [agent names] {
            [my getname $acting] execute
        } 

        set acting ""

        # NEXT, save working data. If we are on lock, no cash has been used
        # so we don't want to save it
        profile 1 control save

        if {!$onlock} {
            profile 1 cash save
        }

        profile 1 personnel save
        profile 1 tactic::FLOW save
        profile 1 service_eni save
        profile 1 plant save
        profile 1 cap access save

        # NEXT, populate base units for all groups.
        profile 1 unit makebase

        # NEXT, assess all requested IOM broadcasts
        profile 1 tactic::BROADCAST assess
    }


    #-------------------------------------------------------------------
    # Strategy Sanity Check

    # check
    #
    # Performs the sanity check for all strategies, marking failing
    # blocks, tactics, and conditions as "invalid".
    #
    # Returns 1 if problems were found, and 0 otherwise.
    
    method check {} {
        set flag 0

        foreach agent [agent names] {
            set s [strategy getname $agent]

            if {[dict size [$s check]] > 0} {
                set flag 1
            }
        }

        # NEXT, notify the application that a check has been done.
        notifier send ::strategy <Check>

        return $flag
    }

    # checker ?ht?
    #
    # ht - An htools buffer
    #
    # Computes the sanity check, and formats the results into the buffer
    # for inclusion into an HTML page.  Returns an esanity value, either
    # OK or WARNING.

    method checker {{ht ""}} {
        # FIRST, check each strategy, saving results into a dictionary
        # by strategy name.

        set result [dict create]

        foreach agent [agent names] {
            set s [strategy getname $agent]

            set scheck [$s check]

            if {[dict size $scheck] > 0} {
                dict set result $s $scheck
            }
        }

        # NEXT, notify the application that a check has been done.
        notifier send ::strategy <Check>

        # NEXT, if no problems were found, we're OK.
        if {[dict size $result] == 0} {
            return OK
        }

        # NEXT, create a report if request.
        if {$ht ne ""} {
            my DoSanityReport $ht $result
        }

        # NEXT, strategy sanity check failures are now errors; the
        # user needs to either fix or disable any problem entities.
        return ERROR
    }

    # DoSanityReport ht errdict
    #
    # ht        - An htools buffer to receive a report.
    # errdict   - A dictionary of errors by strategy.
    #
    # The sdict has this structure:
    #
    # $strategy -> $block -> conditions -> $condition -> $var -> $errmsg
    #                     -> tactics    -> $tactic    -> $var -> $errmsg
    #
    # Writes HTML text of the results of the sanity check to the ht
    # buffer.

    method DoSanityReport {ht errdict} {
        # FIRST, a header
        $ht putln {
            The following conditions and tactics have failed their 
            sanity checks and have been marked invalid.  You must fix 
            them or disable them (or their containing block) 
            in order to lock the scenario.
        }
        $ht para

        # NEXT, show errors by agent and block
        foreach a [lsort [dict keys $errdict]] {
            set sdict [dict get $errdict $a] 
            dict for {block bdict} $sdict {
                $ht subtitle "Agent [$a agent], Block [$block id]: [$block get intent]"

                $ht ul {
                    if {[dict exists $bdict conditions]} {
                        my DoReportEntry $ht "Condition" \
                            [dict get $bdict conditions]
                    }

                    if {[dict exists $bdict tactics]} {
                        my DoReportEntry $ht "Tactic" \
                            [dict get $bdict tactics]
                    }
                }
                $ht para
            }
        }
    }

    # DoReportEntry ht label ctdict
    #
    # ht     - An htools buffer to receive a report
    # label  - Label for the kind of entity
    # ctdict - A dictionary of errors by condition or tactic
    #
    # The ctdict has this structure:
    #
    #   $condition/$tactic -> $var -> $errmsg

    method DoReportEntry {ht label ctdict} {
        dict for {bean vdict} $ctdict {
            $ht li 
            $ht put "$label: [$bean id], [$bean narrative]"

            dict for {var msg} $vdict {
                $ht br
                $ht putln "==> <font color=red><tt>$var</tt>: $msg</font>"
            }
            $ht para
        }
    }

    #-------------------------------------------------------------------
    # Queries

    # getname agent
    #
    # Gets the name of the strategy object for the given agent.

    method getname {agent} {
        return "::strategy::$agent"
    }
    

    #-------------------------------------------------------------------
    # Mutators
    

    # create_ agent
    # 
    # agent - An agent name
    #
    # Add a strategy for the agent, returning an undo script.  This
    # mutator is used on creation of an agent entity (i.e., an actor).

    method create_ {agent} {
        set s [my getname $agent]
        strategy create $s $agent

        return [list bean delete [$s id]]
    }

    # delete_ agent
    #
    # agent - An agent name
    #
    # Delete the strategy for the agent, returning an undo script.
    # This mutator is used on deletion of an agent entity (i.e., an actor).

    method delete_ {agent} {
        set s [my getname $agent]

        return [list bean undelete [bean delete [$s id]]]        
    }
}

# NEXT, define instance members
oo::define strategy {
    #-------------------------------------------------------------------
    # Instance Variables

    variable agent   ;# Name of the owning agent
    beanslot blocks  ;# List of owned strategy blocks
    
    #-------------------------------------------------------------------
    # Constructor/Destructor

    # Note: bean constructors must not have required arguments.
    constructor {{agent_ ""}} {
        next
        set agent $agent_
        set blocks [list]
    }

    #-------------------------------------------------------------------
    # Public Methods

    # subject
    #
    # Set the subject, so that notifications are sent.

    method subject {} {
        return "::strategy"
    }

    # agent
    #
    # Returns the strategy's agent

    method agent {} {
        return $agent
    }

    # blocks ?idx?
    #
    # idx   - Optionally, a lindex index
    #
    # Returns a list of the strategy's blocks in priority order.
    # If the idx is given, returns the selected block.

    method blocks {{idx ""}} {
        if {$idx eq ""} {
            return $blocks
        } else {
            return [lindex $blocks $idx]
        }
    }

    # block_ids
    #
    # Returns a list of the IDs of the blocks owned by this strategy,
    # in priority order.
    #
    # TBD: Should probably be a [bean] command for this.

    method block_ids {} {
        set result [list]

        foreach block $blocks {
            lappend result [$block id]
        }

        return $result
    }

    # state
    #
    # Returns the strategy's state.
    #
    # A strategy's state is normal or invalid; and it is invalid
    # only if it contains invalid blocks.
    
    method state {} {
        foreach block $blocks {
            if {[$block state] eq "invalid"} {
                return "invalid"
            }
        }

        return "normal"
    }


    # check
    #
    # Sanity checks the strategy's blocks.  Returns a dictionary
    #
    # $block -> conditions -> $condition -> $var -> $errmsg
    #        -> tactics    -> $tactic    -> $var -> $errmsg
    #
    # The dictionary will be empty if there are no sanity check failures.
    # Blocks that are disabled are skipped.

    method check {} {
        set result [dict create]

        foreach block $blocks {
            if {[$block state] eq "disabled"} {
                continue
            }

            set bcheck [$block check]

            if {[dict size $bcheck] > 0} {
                dict set result $block $bcheck
            }
        }

        return $result
    }

    # execute
    #
    # Executes the strategy, which has whatever effect it has.

    method execute {} {
        # FIRST, get a coffer of this agent's resources.
        set coffer [coffer new [my agent]]

        # NEXT, try to execute each block.  The coffer will
        # keep track of resources as execution proceeds.  Each block
        # will remember its execution status.
        foreach block $blocks {
            $block execute $coffer
        }
    }

    #-------------------------------------------------------------------
    # Order Mutators

    # addblock_
    #
    # Adds a new block to the strategy, placing it at the end of the
    # list.

    method addblock_ {} {
        return [my addbean_ blocks ::block]
    }

    # deleteblock_ block_id
    #
    # block_id   - Bean ID of a block owned by this strategy
    #
    # Deletes the block from the strategy.

    method deleteblock_ {block_id} {
        return [my deletebean_ blocks $block_id]
    }

    # moveblock_ block_id where
    #
    # block_id  - a block
    # where     - emoveitem value
    #
    # Moves the block in the given way.

    method moveblock_ {block_id where} {
        return [my movebean_ blocks $block_id $where]
    }
}

#-------------------------------------------------------------------
# Orders: STRATEGY:*

# STRATEGY:BLOCK:ADD
#
# Adds a new strategy block to an agent's strategy.

order define STRATEGY:BLOCK:ADD {
    title "Add Block to Strategy"

    options -sendstates PREP

    form {
        rcc "Agent:" -for agent
        text agent -context yes
    }
} {
    # FIRST, prepare and validate the parameters
    prepare agent  -toupper -required -type agent

    returnOnError -final

    # NEXT, create the block
    set s [strategy getname $parms(agent)]

    setundo [$s addblock_]

    # NEXT, return the new block's ID
    set block [lindex [$s blocks] end]

    setredo [list bean setnextid [$block id]]
    return [$block id]
}

# STRATEGY:BLOCK:DELETE
#
# Deletes a strategy block from an agent's strategy.

order define STRATEGY:BLOCK:DELETE {
    title "Delete Block from Strategy"

    options -sendstates PREP

    form {
        text ids -context yes
    }
} {
    # FIRST, prepare and validate the parameters
    prepare ids -required -listof ::block

    returnOnError -final

    # NEXT, delete the block(s)
    set undo [list]
    foreach bid $parms(ids) {
        set block [block get $bid]
        set s [$block strategy]
        lappend undo [$s deleteblock_ $bid]
    }
    
    setundo [join [lreverse $undo] "\n"]
}

# STRATEGY:BLOCK:MOVE
#
# Moves a strategy block in an agent's strategy.

order define STRATEGY:BLOCK:MOVE {
    title "Move Block in Strategy"

    options -sendstates PREP

    form {
        rcc "Block ID:" -for block_id
        text block_id -context yes

        rcc "Where:" -for where
        enumlong where -dict {emoveitem asdict longname}
    }
} {
    # FIRST, prepare and validate the parameters
    prepare block_id -required -type ::block
    prepare where    -required -type emoveitem

    returnOnError -final

    # NEXT, move the block
    set block [block get $parms(block_id)]
    set s [$block strategy]

    setundo [$s moveblock_ $parms(block_id) $parms(where)]
}

