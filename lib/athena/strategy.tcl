#-----------------------------------------------------------------------
# TITLE:
#    strategy.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Strategy Class
#
#    An agent's strategy determines his actions.  It consists of a number
#    of blocks, each of which contains zero or more conditions and tactics.
#
#    Strategy objects are typically named after their owning agents,
#    i.e., ...::<agent>; however, this is not required.  The
#    SYSTEM agent's strategy is created as part of the scenario; actor
#    strategies are created and destroyed with the actor.
#
#    This module defines the following objects:
#
#    * strategy_manager, used to manage strategy execution; it is 
#      exposed by athenadb(n) as its "strategy" subcommand.
#    * ::athena::strategy, the strategy bean.
#    * The various ::strategy::* orders.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Strategy Manager

snit::type ::athena::strategy_manager {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Transient Instance Variables

    variable locking  0          ;# Flag: 1 if locking the scenario, 0 otherwise.
    variable acting   ""         ;# Name of the acting agent, or "" if none.
    variable cache    -array {}  ;# Array, strategy bean ID by agent name.

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        # FIRST, save the adb.
        set adb $adb_

        # NEXT, initialize variables and create predefined
        # agents.
        $self reset
    }

    destructor {
        notifier forget $self
    }

    # reset
    #
    # Resets transient strategy variables.

    method reset {} {
        # FIRST, initialize variables
        set locking  0   
        set acting   ""  
        array unset cache

        # NEXT, create strategies for predefined agents.
        foreach agent [$adb agent system names] {
            $adb log normal strategy "Creating strategy for agent $agent"
            $self create_ $agent
        }
    }

    # dbsync
    #
    # Recache strategies by agent name on dbsync.

    method dbsync {} {
        array unset cache

        foreach id [$adb bean ids ::athena::strategy] {
            set s [$adb bean get $id]
            set cache([$s agent]) $id 
        }
    }

    # rebase
    #
    # Mark blocks "onlock" if they executed at the last tick.
    # Clear block and tactic execution data.

    method rebase {} {
        foreach a [$adb agent names] {
            set s [$self getname $a]

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

    #----------------------------------------------------------------------
    # Validators

    # valclass cls id
    #
    # cls   - A block, tactic or condition class or subclass
    # id    - Possibly, an id in the beanpot(n) or a full name of an
    #         existing strategy bean
    #
    # Throws an error with an errorcode of INVALID if this is not either
    # a numeric id belonging to a bean of the given class or the full
    # name of a strategy bean.

    method valclass {cls id} {
        # FIRST, grab the short name of the class
        set short [namespace tail $cls]

        # NEXT, check id against bean IDs of this class
        set bean_ids [$adb bean ids $cls]
        if {$id in $bean_ids} {
            return $id
        }

        set retval [$self nameToId $id]

        # NEXT, if there is no mapping from name to id, throw INVALID
        if {$retval eq ""} {
            throw INVALID "Invalid $short ID: \"$id\""
        }

        # NEXT, if the ID belongs to a bean of the wrong class, throw 
        # INVALID
        if {![$adb bean hasa $cls $retval]} {
            throw INVALID "Invalid $short ID: \"$id\""
        }

        return $retval
    }

    #-------------------------------------------------------------------
    # Helper methods

    # nameToId name
    #
    # name    - Possibly a full name for a strategy bean
    #
    # This method traverses the supplied full name and tries to find
    # the appropriate ID that corresponds to the name. For example, a full
    # name of the form:
    #
    #     GOV/B1/T1
    #
    # will find the bean ID of the first tactic in the first block owned
    # by the GOV agent and return it (assuming default names are used).
    # If a bean ID cannot be found, the empty string is returned.

    method nameToId {name} {
        # FIRST, no name then no id
        if {$name eq ""} {
            return ""
        }

        # NEXT, get individual names, expect <= 3 path elements
        set path [split $name "/"]
        if {[llength $path] > 3} {
            return ""
        }

        # NEXT, assign names to specific variable. Variable may be
        # empty
        lassign $path agent bname tcname

        # NEXT, make sure agent exists
        if {$agent ni [$adb agent names]} {
            return ""
        }

        # NEXT, no block name, return agent name
        if {$bname eq ""} {
            return $agent
        }

        set s [$self getname $agent]
        set block_id ""

        # NEXT, look for a match on block name
        foreach block [$s blocks] {
            if {[$block get name] eq $bname} {
                set block_id [$block id]
                break
            }
        }

        # NEXT, no block found, no id
        if {$block_id eq ""} {
            return ""
        }

        # NEXT, if only block specified, return block ID
        if {$tcname eq ""} {
            return $block_id
        }

        set block [$adb bean get $block_id]

        # NEXT, see if the name is a tactic, return ID of first match
        foreach tactic [$block tactics] {
            if {[$tactic get name] eq $tcname} {
                return [$tactic get id]
            }
        }

        # NEXT, see if the name is a condition, return ID of first match
        foreach cond [$block conditions] {
            if {[$cond get name] eq $tcname} {
                return [$cond get id]
            }
        }

        # NEXT, if we get here there's no matches, no ID
        return ""
    }

    #-------------------------------------------------------------------
    # Strategy Execution

    # start
    #
    # This method is called on scenario lock, when the simulation is
    # moving from PREP to PAUSED.
    # the paused state

    method start {} {
        $self locking 1
        $self DoTock $locking
        $self locking 0
    }

    # tock
    #
    # This method is called when the simulation is running forward in
    # time

    method tock {} {
        $self locking 0
        $self DoTock $locking
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
        $adb profile 1 $adb control load
        $adb profile 1 $adb cash load
        $adb profile 1 $adb personnel load
        $adb profile 1 $adb service load
        $adb profile 1 $adb plant load
        $adb profile 1 $adb cap access load
        $adb profile 1 $adb abevent reset
        $adb profile 1 $adb broadcast reset
        $adb profile 1 $adb stance reset
        $adb profile 1 $adb unit reset
        $adb profile 1 $adb service reset

        # NEXT, execute each agent's strategy.

        foreach acting [$adb agent names] {
            [$self getname $acting] execute
        } 

        set acting ""

        # NEXT, save working data. If we are on lock, no cash has been used
        # so we don't want to save it
        $adb profile 1 $adb control save

        if {!$onlock} {
            $adb profile 1 $adb cash save
        }

        $adb profile 1 $adb personnel save
        $adb profile 1 $adb service save
        $adb profile 1 $adb plant save
        $adb profile 1 $adb cap access save

        # NEXT, populate base units for all groups.
        $adb profile 1 $adb unit makebase

        # NEXT, assess all requested IOM broadcasts
        $adb profile 1 $adb broadcast assess
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

        foreach agent [$adb agent names] {
            set s [$self getname $agent]

            if {[dict size [$s check]] > 0} {
                set flag 1
            }
        }

        # NEXT, notify the application that a check has been done.
        $adb notify strategy <Check>

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

        foreach agent [$adb agent names] {
            set s [$self getname $agent]

            set scheck [$s check]

            if {[dict size $scheck] > 0} {
                dict set result $s $scheck
            }
        }

        # NEXT, notify the application that a check has been done.
        $adb notify strategy <Check>

        # NEXT, if no problems were found, we're OK.
        if {[dict size $result] == 0} {
            return OK
        }

        # NEXT, create a report if request.
        if {$ht ne ""} {
            $self DoSanityReport $ht $result
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
                        $self DoReportEntry $ht "Condition" \
                            [dict get $bdict conditions]
                    }

                    if {[dict exists $bdict tactics]} {
                        $self DoReportEntry $ht "Tactic" \
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
        if {![info exists cache($agent)]} {
            return ""
        }
        
        return [$adb bean get $cache($agent)]
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
        set s [$adb bean new ::athena::strategy $agent]
        set cache($agent) [$s id]

        return [list $adb bean delete [$s id]]
    }

    # delete_ agent
    #
    # agent - An agent name
    #
    # Delete the strategy for the agent, returning an undo script.
    # This mutator is used on deletion of an agent entity (i.e., an actor).

    method delete_ {agent} {
        set s [$self getname $agent]

        return [list $adb bean undelete [$adb bean delete [$s id]]]        
    }
}

#-----------------------------------------------------------------------
# Bean Class

oo::class create ::athena::strategy {
    superclass ::projectlib::bean

    #-------------------------------------------------------------------
    # Instance Variables

    variable agent   ;# Name of the owning agent
    beanslot blocks  ;# List of owned strategy blocks
    
    #-------------------------------------------------------------------
    # Constructor/Destructor

    # Note: bean constructors must not have required arguments other
    # than pot_.
    constructor {pot_ {agent_ ""}} {
        next $pot_
        set agent $agent_
        set blocks [list]
    }

    #-------------------------------------------------------------------
    # Public Methods

    # adb
    #
    # Returns the scenario athenadb(n) handle.

    method adb {} {
        return [[my pot] cget -rdb]
    }

    # subject
    #
    # Set subject for notifier events.  It's the athenadb(n) subject
    # plus ".strategy".

    method subject {} {
        set adb [[my pot] cget -rdb]
        return "[$adb cget -subject].strategy"
    }

    # agent
    #
    # Returns the strategy's agent

    method agent {} {
        return $agent
    }

    # block_ids
    #
    # Returns a list of the IDs of the blocks owned by this strategy,
    # in priority order.

    method block_ids {} {
        return $blocks
    }

    # next_block_name
    #
    # Returns the next default block name based upon existing names.
    # If blocks of the form 'Bn' already exist, where 'n' is an integer, 
    # then 'Bn+1' is returned, otherwise 'B1' is returned.

    method next_block_name {} {
        # FIRST, default n is 1
        set n 1
        set bnum ""

        # NEXT, go through the blocks in this strategy and pull
        # out the ones that have the pattern "Bn".
        foreach block [my blocks] {
            set bname [$block get name]
            if {[regexp {^B(\d+)$} $bname dummy bnum]} {
               let n {max($bnum+1, $n)}
            }
        }

        return "B$n"
    }

    # state
    #
    # Returns the strategy's state.
    #
    # A strategy's state is normal or invalid; and it is invalid
    # only if it contains invalid blocks.
    
    method state {} {
        foreach block [my blocks] {
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

        foreach block [my blocks] {
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
        set coffer [::athena::coffer new [my adb] [my agent]]

        # NEXT, try to execute each block.  The coffer will
        # keep track of resources as execution proceeds.  Each block
        # will remember its execution status.
        foreach block [my blocks] {
            $block execute $coffer
        }
    }

    # onAddBean_ slot bean_id
    #
    # Figures out the next default name to use for a new block
    # and sets it

    method onAddBean_ {slot bean_id} {
        set block [[my pot] get $bean_id]
        $block configure -name [my next_block_name]
        next $slot $bean_id
    }

    #-------------------------------------------------------------------
    # Order Mutators

    # addblock_
    #
    # Adds a new block to the strategy, placing it at the end of the
    # list.

    method addblock_ {} {
        return [my addbean_ blocks ::athena::block]
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

::athena::orders define STRATEGY:BLOCK:ADD {
    variable block_id  ;# Saved on first execution for redo

    meta title      "Add Block to Strategy"
    meta sendstates PREP
    meta parmlist  {agent}

    method _validate {} {
        my prepare agent  -toupper -required -type [list $adb agent]
    }

    method _execute {{flunky ""}} {
        set s [$adb strategy getname $parms(agent)]

        if {[info exists block_id]} {
            $adb bean setnextid $block_id
        }

        my setundo [$s addblock_]

        # NEXT, return the new block's ID
        set block_id [lindex [$s block_ids] end]

        return $block_id
    }
}

# STRATEGY:BLOCK:DELETE
#
# Deletes a strategy block from an agent's strategy.

::athena::orders define STRATEGY:BLOCK:DELETE {
    meta title      "Delete Block from Strategy"
    meta sendstates PREP
    meta parmlist   {ids}

    method _validate {} {
        my prepare ids -required -listwith [list $adb strategy valclass ::athena::block]
    }

    method _execute {{flunky ""}} {
        set undo [list]
        foreach bid $parms(ids) {
            set block [$adb bean get $bid]
            set s [$block strategy]
            lappend undo [$s deleteblock_ $bid]
        }
    
        my setundo [join [lreverse $undo] "\n"]
    }
}

# STRATEGY:BLOCK:MOVE
#
# Moves a strategy block in an agent's strategy.

::athena::orders define STRATEGY:BLOCK:MOVE {
    meta title      "Move Block in Strategy"
    meta sendstates PREP
    meta parmlist   {block_id where}

    method _validate {} {
        my prepare block_id -required -with [list $adb strategy valclass ::athena::block]
        my prepare where    -required -type emoveitem
    }

    method _execute {{flunky ""}} {
        set block [$adb bean get $parms(block_id)]
        set s [$block strategy]
        my setundo [$s moveblock_ $parms(block_id) $parms(where)]
    }
}


