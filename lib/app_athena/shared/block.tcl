#-----------------------------------------------------------------------
# TITLE:
#    block.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Strategy Blocks
#
#    An agent's strategy determines his actions.  It consists of a number
#    of blocks, each of which contains zero or more conditions and tactics.
#
#-----------------------------------------------------------------------

# FIRST, create the class
beanclass create block 

# NEXT, define class methods
oo::objdefine block {
    #-------------------------------------------------------------------
    # Pasting of blocks

    # paste agent copysets
    #
    # agent     - The agent whose strategy will receive the blocks
    # copysets  - A list of block copysets from [$bean copydata].
    #
    # Pastes the blocks into the given strategy, pasting tactics and
    # conditions recursively.  This call should be
    # wrapped by [cif startblock]/[cif endblock] calls.  These are
    # not included in [paste] itself, because pasting blocks could be
    # done as part of a larger paste.

    method paste {agent copysets} {
        # FIRST, paste the copied blocks into the agent's strategy
        foreach copyset $copysets {
            # FIRST, get the block data
            set bdict [my GetOrderParmsFromCopySet $copyset]

            # NEXT, create the block with default settings
            set block_id [order send gui STRATEGY:BLOCK:ADD agent $agent]

            # NEXT, update the block with the right data.
            order send gui BLOCK:UPDATE block_id $block_id {*}$bdict

            # NEXT, paste the conditions and tactics
            condition paste $block_id [dict get $copyset conditions]
            tactic paste    $block_id [dict get $copyset tactics]
        }
    }

    # GetOrderParmsFromCopySet copyset
    #
    # copyset - The copyset from [$bean copydata]
    #
    # Pulls out the required parameters from the copyset.

    method GetOrderParmsFromCopySet {copyset} {
        set pdict [dict create]

        foreach parm [order parms BLOCK:UPDATE] {
            if {$parm eq "block_id"} {
                continue
            }

            dict set pdict $parm [dict get $copyset $parm]
        }

        return $pdict
    }

}


# NEXT, define instance methods
oo::define block {
    #-------------------------------------------------------------------
    # Instance Variables

    variable parent     ;# Name of the owning strategy
    variable intent     ;# Intent of the analyst for this block
    variable state      ;# normal, disabled
    variable once       ;# Flag; if true, the block will be disabled
                         # after being executed once.
    variable onlock     ;# Flag; if true, the block is always executed
                         # on scenario lock.
    variable tmode      ;# Time constraint mode: ALWAYS, AT, BEFORE,
                         # AFTER, DURING
    variable t1         ;# Time tick for tmode={AT,BEFORE,AFTER,DURING}
    variable t2         ;# Ending time tick for tmode=DURING
    variable cmode      ;# Which conditions must be met: ANY | ALL
    beanslot conditions ;# List of condition beans
    variable emode      ;# Execution mode, ALL | SOME
    beanslot tactics    ;# List of tactics
    variable execstatus ;# eexecstatus value: result of last execution attempt
    variable exectime   ;# Sim time at which the block last executed, or ""

    #-------------------------------------------------------------------
    # Constructor/Destructor

    # constructor ?option value...?
    #
    # option  - An instance variable in option form, e.g., -tmode.
    #
    # Creates the object, and assigns values to instance variables.
    #
    # Note: bean constructors must not have required arguments.

    constructor {args} {
        next
        set parent     ""
        set intent     ""
        set state      "normal"
        set once       0
        set onlock     0
        set tmode      ALWAYS
        set t1         ""
        set t2         ""
        set cmode      ALL
        set conditions [list]
        set emode      ALL
        set tactics    [list]
        set execstatus NONE
        set exectime   ""

        # Configure any option values.
        my configure {*}$args
    }
    
    #-------------------------------------------------------------------
    # Queries

    # subject
    #
    # Set subject for notifier events.

    method subject {} {
        return "::block"
    }

    # agent
    #
    # Returns the strategy's agent

    method agent {} {
        return [$parent agent]
    }

    # strategy
    #
    # Return the block's owning strategy

    method strategy {} {
        return $parent
    }

    # state
    #
    # Returns the bean's state

    method state {} {
        return $state
    }

    # execstatus 
    #
    # Returns the execution status, an eexecstatus value

    method execstatus {} {
        return $execstatus
    }

    # execflag
    #
    # Returns 1 if the tactic executed successfully during the last time
    # tick.

    method execflag {} {
        return [expr {$execstatus eq "SUCCESS"}]
    }

    # statusicon
    #
    # Returns the block's execution status icon.

    method statusicon {} {
        # FIRST, if it's a resource failure return the icon
        # for the first failed tactic.
        if {$execstatus eq "FAIL_RESOURCES"} {
            foreach tactic [my tactics] {
                if {[$tactic failicon] ne ""} {
                    return [$tactic failicon]
                }
            }
        }

        # OTHERWISE, use the icon for the block's own status.
        return [eexecstatus as icon $execstatus]
    }

    # timestring
    #
    # Returns a narrative for the time variables.

    method timestring {} {
        switch -exact -- $tmode {
            ALWAYS { 
                return "every week" 
            }
            AT { 
                return "at week [simclock toString $t1] ($t1)"
            }
            BEFORE { 
                return "every week before [simclock toString $t1] ($t1)"
            }
            AFTER { 
                return "every week after [simclock toString $t1] ($t1)"
            }
            DURING {
                set w1 "[simclock toString $t1] ($t1)"
                set w2 "[simclock toString $t2] ($t2)"
                return "every week from $w1 to $w2"
            }
            default {
                error "None tmode: \"$tmode\""
            }
        }
    }

    # istime ?tick?
    #
    # tick  - A time tick; defaults to now
    #
    # Returns 1 if tick is accepted by the constraint.

    method istime {{tick ""}} {
        if {$tick eq ""} {
            set tick [simclock now]
        }

        switch -exact -- $tmode {
            ALWAYS  { return 1                            }
            AT      { expr {$t1 == $tick}                 } 
            BEFORE  { expr {$tick < $t1}                  }
            AFTER   { expr {$tick > $t1}                  }
            DURING  { expr {$t1 <= $tick && $tick <= $t2} }
            default { error "None tmode: \"$tmode\""   }
        }
    }

    # condition_ids
    #
    # Returns a list of the block's condition IDs

    method condition_ids {} {
        return $conditions
    }

    # tactic_ids
    #
    # Returns a list of the block's tactic IDs

    method tactic_ids {} {
        return $tactics
    }

    #-------------------------------------------------------------------
    # Block Reset

    # reset
    #
    # Resets the execution status of the block and its tactics.

    method reset {} {
        my set execstatus NONE
        my set exectime   ""

        foreach tactic [my tactics] {
            $tactic reset
        }
    }
    

    #-------------------------------------------------------------------
    # Views

    # view ?view?
    #
    # view   - A view name (ignored at present)
    #
    # Returns a view dictionary, for display.
    #
    # Standard views:
    #
    #     text    - Everything, links converted to text.
    #     html    - Everything, links converted to HTML <a> links
    #     cget    - Data for [block cget] executive command
    #
    # Note that for blocks, text and html are the same, as blocks
    # have no links.

    method view {{view ""}} {
        # FIRST, set up the basic text/html view
        set vdict [next $view]

        dict set vdict agent         [my agent]
        dict set vdict pretty_once   [expr {$once ? "Yes" : "No"}]
        dict set vdict pretty_onlock [expr {$onlock ? "Yes" : "No"}]
        dict set vdict timestring    [my timestring]
        dict set vdict statusicon    [my statusicon]

        if {$exectime ne ""} {
            dict set vdict pretty_exectime [simclock toString $exectime]
        } else {
            dict set vdict pretty_exectime "-"
        }

        # NEXT, handle cget view differences
        if {$view eq "cget"} {
            # FIRST, define or translate needed keys
            dict set vdict block_id   [my id]
            dict set vdict conditions $conditions
            dict set vdict tactics    $tactics

            # NEXT, remove extraneous keys
            set vdict [dict remove $vdict {*}{
                execstatus
                exectime
                id
                parent
                pretty_exectime
                pretty_once 
                pretty_onlock
                statusicon
                timestring
            }]
        }

        return $vdict
    }

    #-------------------------------------------------------------------
    # HTML Output

    # htmlpage ht
    #
    # ht - An htools(n) buffer
    #
    # Produces a complete HTML page describing this block in the
    # ht buffer.

    method htmlpage {ht} {
        $ht page "Agent [my agent], Detail for Strategy Block [my id]"
        $ht putln "<b>Agent "
        $ht link my://app/agent/[my agent] [my agent]
        $ht put ", Strategy Block [my id]: Detail</b>"
        $ht hr
        $ht para
        my html $ht
        $ht /page
    }

    # html ht
    #
    # ht   - An htools(n) buffer
    #
    # Produces an HTML description of the block, in the buffer, for
    # inclusion in another page or for use in a myhtmlpane.

    method html {ht} {
        # FIRST, add the header.  Its color and font should indicate
        # the state.
        $ht putln "<a name=\"block[my id]\"><span class=\"[my state]\">"
        $ht put "<b>Block [my id]:</b> "

        if {[my state] eq "disabled"} {
            $ht putln "<b>(Disabled)</b> "
        } elseif {[my state] eq "invalid"} {
            $ht putln "<b>(Invalid)</b> "
        }

        if {[my get intent] ne ""} {
            $ht put "<b>[my get intent]</b>"
        } else {
            $ht put "<i>The analyst has not entered the block's intent</i>"
        }
        $ht put "</span></a>"

        $ht para

        # NEXT, if we are locked show the execution status of this block.
        if {[sim locked]} {
            $ht putln "<b>Execution Status:</b> "
            $ht put [eexecstatus as btext [my execstatus]]

            $ht para
        }

        # NEXT, major sections
        my HtmlExecConstraints $ht
        my HtmlConditions $ht
        my HtmlTactics $ht

        set etime [my get exectime]

        if {$etime ne ""} {
            set week [simclock toString $etime]

            if {$etime == [simclock cget -tick0]} {
                set tick "on lock"
            } else {
                set tick "tick $etime"
            }
            $ht tiny "Last executed: $week ($tick)"
        }
    }
    
    # HtmlExecConstraints ht
    #
    # ht   - An htools(n) buffer
    #
    # Adds the block's execution constraints to the buffer.

    method HtmlExecConstraints {ht} {
        $ht putln "<b>Execution Constraints:</b> "

        $ht ul

        if {[my get onlock]} {
            $ht li-text {
                The block will execute <b>on scenario lock</b>.
            }
        }

        $ht li {
            set tstring [my timestring]

            $ht putln "The block is eligible to execute <b>$tstring</b>"

            if {[llength [my conditions]] > 0} {
                $ht put ", provided that <b>"
                $ht putln [string tolower [eanyall longname [my get cmode]]]
                $ht putln "</b> the conditions are met"
            }

            $ht put "."
        }

        if {[my get once]} {
            $ht li-text {
                The block can execute <b>at most once</b>, and will then 
                be disabled.
            }
        }

        if {[my get emode] eq "ALL"} {
            $ht li-text {
                The block will fail to execute if there are 
                insufficient resources available for <b>all</b> 
                of the block's tactics.
            }
        } else {
            $ht li-text {
                The block will execute as many of its tactics as
                it can, in priority order, given current resources.
            }
        }

        $ht /ul

        $ht para
    }

    # HtmlConditions ht
    #
    # ht   - An htools(n) buffer
    #
    # Adds the block's conditions to the buffer.

    method HtmlConditions {ht} {
        # FIRST, handle the empty case.
        if {[llength [my conditions]] == 0} {
            $ht putln "No conditions have been added to this block."
            $ht para
            return
        }


        # NEXT, include a block of the conditions:
        $ht putln "The conditions are as follows:"
        $ht para

        # TBD: Add state
        $ht table {
            "Status" "ID" "Type" "State" "Narrative"
        } {
            set count 0
            foreach bean [my conditions] {
                array set data [$bean view html]

                if {[incr count] % 2 == 1} {
                    set cls oddrow
                } else {
                    set cls evenrow
                }

                $ht tr class $cls valign top {
                    $ht td center { $ht image $data(statusicon) }
                    $ht td center { $ht put $data(id)           }
                    $ht td left   { $ht put $data(typename)     }
                    $ht td left   { $ht put $data(state)        }
                    $ht td left {
                        $ht span $data(state) {
                            $ht put $data(narrative)
                        }

                        if {$data(state) eq "invalid"} {
                            $ht para
                            $ht putln "Sanity Check Failures:"
    
                            dict for {var msg} [$bean check] {
                                $ht br
                                $ht putln "==> <tt>$var</tt>: "
                                $ht span error {
                                    $ht putln $msg
                                }
                            }
                        }

                    }
                }
            }
        }

        $ht para
    }

    # HtmlTactics ht
    #
    # ht   - An htools(n) buffer
    #
    # Adds the block's tactics to the buffer.

    method HtmlTactics {ht} {
        # FIRST, handle the empty case.
        if {[llength [my tactics]] == 0} {
            $ht putln "No tactics have been added to this block."
            $ht para
            return
        }


        # NEXT, include a block of the tactics:
        $ht putln "The tactics are as follows:"
        $ht para

        $ht table {
            "Status" "ID" "Type" "State" "Narrative"
        } {
            set count 0
            foreach bean [my tactics] {
                array set data [$bean view html]

                if {[incr count] % 2 == 1} {
                    set cls oddrow
                } else {
                    set cls evenrow
                }

                $ht tr class $cls valign top {
                    $ht td center { $ht image $data(statusicon) }
                    $ht td center { $ht put $data(id)           }
                    $ht td left   { $ht put $data(typename)     }
                    $ht td left   { $ht put $data(state)        }
                    $ht td left {
                        $ht span $data(state) {
                            $ht put $data(narrative)
                        }

                        if {$data(failures) ne ""} {
                            $ht span error {
                                $ht putln $data(failures)
                            }
                        }

                        if {$data(state) eq "invalid"} {
                            $ht para
                            $ht putln "Sanity Check Failures:"
    
                            dict for {var msg} [$bean check] {
                                $ht br
                                $ht putln "==> <tt>$var</tt>: "
                                $ht span error {
                                    $ht putln $msg
                                }
                            }
                        }
                    }
                }
            }
        }
        $ht para
    }


    #-------------------------------------------------------------------
    # Operations

    # check
    #
    # Sanity checks the block's conditions and tactics, returning a 
    # nested dictionary of error messages.  Skips disabled conditions
    # and tactics.
    #
    # The dictionary has the following keys:
    #
    #   conditions -> $condition -> $var -> $errmsg
    #   tactics    -> $tactic    -> $var -> $errmsg
    #
    # If the block's contents is entirely sane, the dictionary will be
    # empty.
    #
    # If the block's state is not "disabled", it will be set to 
    # normal or invalid.

    method check {} {
        set result [dict create]

        foreach cond [my conditions] {
            if {[$cond state] eq "disabled"} {
                continue
            }

            set errdict [$cond check]
            if {[dict size $errdict] > 0} {
                dict set result conditions $cond $errdict
            }
        }

        foreach tactic [my tactics] {
            if {[$tactic state] eq "disabled"} {
                continue
            }

            set errdict [$tactic check]
            if {[dict size $errdict] > 0} {
                dict set result tactics $tactic $errdict
            }
        }

        if {[my state] ne "disabled"} {
            if {[dict size $result] == 0} {
                my set state normal
            } else {
                my set state invalid
            }
        }

        return $result
    }

    # execute coffer
    #
    # coffer   - A coffer containing the actor's available resources
    #            at this point in strategy execution.
    #
    # Attempts to execute the block given the resources in the coffer.
    # On success, expended resources are deducted from the coffer.
    # The execstatus method returns an eexecstatus value indicating
    # what happened; see eexecstatus in apptypes(sim) for details.

    method execute {coffer} {
        # FIRST, we don't know what the current execution status is.  Set
        # it to none so that if we don't set it properly later we'll have
        # a clue.
        my set execstatus NONE

        # NEXT, mark all tactics as SKIP_BLOCK.  We'll update that later
        # if need be.
        foreach tactic [my tactics] {
            $tactic set execstatus SKIP_BLOCK
        }

        # NEXT, skip if disabled
        if {[my state] ne "normal"} {
            my set execstatus SKIP_STATE
            return
        }

        # NEXT, block eligibility is different on lock than on tick.
        if {[strategy locking]} {
            # FIRST, skip if the block's not done on lock.
            if {!$onlock} {
                my set execstatus SKIP_LOCK
                return
            }
        } else {
            # FIRST, check whether it's time.
            if {![my istime]} {
                my set execstatus SKIP_TIME
                return
            }

            # NEXT, are the conditions met according to the cmode?
            if {![my AreConditionsMet]} {
                my set execstatus SKIP_CONDITIONS
                return
            }
        }

        # NEXT, get the tactics to execute
        set tacticsToExecute [my GetTactics $coffer]

        # NEXT, if there are no tactics to execute, we've failed;
        # the execstatus was set in GetTactics.
        if {[llength $tacticsToExecute] == 0} {
            return
        }

        # NEXT, Execute the tactics.
        foreach tactic $tacticsToExecute {
            $tactic set execstatus SUCCESS
            $tactic execute
        }

        my set execstatus SUCCESS
        my set exectime   [simclock now]

        # NEXT, disable the block if it should only be executed once.
        if {$once} {
            my set state disabled
        }
    }

    # AreConditionsMet
    #
    # Determines whether the block's conditions are met, according to
    # the cmode.  Returns 1 if they are, and 0 otherwise.

    method AreConditionsMet {} {
        # FIRST, get the conditions whose state is normal.
        set normals [list]

        foreach cond [my conditions] {
            if {[$cond get state] eq "normal"} {
                lappend normals $cond
            }
        }

        # NEXT, if there are none, we've succeeded.
        if {[llength $normals] == 0} {
            return 1
        }

        # NEXT, count the conditions that are met.
        set count 0
        foreach cond $normals {
            if {[$cond eval]} {
                incr count
            }
        }

        # NEXT, compute the flag given the cmode.
        switch -exact -- $cmode {
            ALL     { set cflag [expr {$count == [llength $normals]}] }
            ANY     { set cflag [expr {$count > 0}]                   }
            default { error "None cmode: \"$cmode\""                  }
        }

        return $cflag
    }

    # GetTactics coffer
    #
    # coffer   - A coffer containing the actor's available resources
    #            at this point in strategy execution.
    #
    # Given that the block is eligible for execution, determines which
    # tactics are to be executed, and returns them in order.

    method GetTactics {coffer} {
        # FIRST, obligate the required assets
        set tacticsToExecute [list]

        my set execstatus SKIP_EMPTY

        foreach tactic [my tactics] {
            # FIRST, skip disabled and invalid tactics
            if {[$tactic get state] ne "normal"} {
                $tactic set execstatus SKIP_STATE
                continue
            }

            # NEXT, skip tactics that don't execute on lock.
            if {[strategy locking]} {
                set ttype [info object class $tactic]
                if {![$ttype onlock]} {
                    $tactic set execstatus SKIP_LOCK
                    continue
                }
            }

            # NEXT, obligate required assets.  Save the coffer state,
            # so that we can restore it.
            set cofferState [$coffer getdict]

            if {[$tactic obligate $coffer]} {
                lappend tacticsToExecute $tactic
            } else {
                # Insufficient assets; restore old coffer state, and
                # return.
                $tactic set execstatus FAIL_RESOURCES
                my set execstatus FAIL_RESOURCES
                $coffer setdict $cofferState

                if {$emode eq "ALL"} {
                    return [list]
                }
            }
        }

        # NEXT, if there are no tactics to execute, we have an empty
        # block.  Either there we are skipping the block because there
        # were no tactics with state=normal, or emode is SOME but none
        # of the tactics could be obligated.  Either way, the execstatus
        # is already set.
        if {[llength $tacticsToExecute] == 0} {
            return [list]
        }

        # NEXT, return the tactics to execute.
        return $tacticsToExecute
    }

    #-------------------------------------------------------------------
    # Event Handlers and Order Mutators

    # onUpdate_
    #
    # Additional stuff to do on update, including sending
    # notifications.

    method onUpdate_ {} {
        # FIRST, clear the execution status; things are different.
        my set execstatus NONE
        my set exectime   ""

        # NEXT, if we've just set the state to "normal", make sure 
        # that that's OK.
        if {$state eq "normal"} {
            my check
        }

        # NEXT, send notifications
        next
    }

    # onAddBean_
    #
    # Clear the execution status when beans are added.

    method onAddBean_ {slot bean_id} {
        my set execstatus NONE
        my set exectime   ""

        next $slot $bean_id   ;# Do notifications
    }

    # onDeleteBean_
    #
    # Clear the execution status when beans are deleted.

    method onDeleteBean_ {slot bean_id} {
        my set execstatus NONE
        my set exectime   ""

        next $slot $bean_id   ;# Do notifications
    }

    # addcondition_ typename
    #
    # typename   - The condition typename
    #
    # Adds an "empty" condition of the given type, and clears the
    # execution data.

    method addcondition_ {typename} {
        return [my addbean_ conditions [condition type $typename]]
    }

    # deletecondition_ condition_id 
    #
    # condition_id   - Bean ID of a condition owned by this strategy
    #
    # Deletes the condition from the conditions list and from memory, 
    # and clears the execution data.

    method deletecondition_ {condition_id} {
        return [my deletebean_ conditions $condition_id]
    }

    # addtactic_ typename
    #
    # typename   - The tactic typename
    #
    # Adds an "empty" tactic of the given type, and clears the
    # execution data.

    method addtactic_ {typename} {
        return [my addbean_ tactics [tactic type $typename]]
    }

    # deletetactic_ tactic_id 
    #
    # tactic_id   - Bean ID of a tactic owned by this strategy
    #
    # Deletes the tactic from the tactics list and from memory, and clears the
    # execution data.

    method deletetactic_ {tactic_id} {
        return [my deletebean_ tactics $tactic_id]
    }

    # movetactic_ tactic_id where
    #
    # tactic_id  - a tactic ID contained with this block.
    # where      - emoveitem value
    #
    # Moves the tactic in the given way.

    method movetactic_ {tactic_id where} {
        return [my movebean_ tactics $tactic_id $where]
    }
}

#-----------------------------------------------------------------------
# Orders: BLOCK:*

# BLOCK:UPDATE
#
# Updates a block's own data.

order define BLOCK:UPDATE {
    title "Update Strategy Block"

    options -sendstates PREP

    form {
        rc "Block ID:" -for block_id
        text block_id -context yes \
            -loadcmd {beanload}

        label "&nbsp;&nbsp;"
        check onlock -text "On Lock?"

        label "&nbsp;&nbsp;"
        check once -text "Once Only?"

        rc "Intent:" -for intent
        text intent -width 70

        rc "Time Constraint:" -for tmode
        selector tmode {
            case ALWAYS "Always" {}

            case AT "At" {
                label "week:" -for t1
                text t1 -width 12
            }

            case BEFORE "Before" {
                label "week:" -for t1
                text t1 -width 12
            }

            case AFTER "After" {
                label "week:" -for t1
                text t1 -width 12
            }

            case DURING "From" {
                label "week:" -for t1
                text t1 -width 12
                label "to week:" -for t2
                text t2 -width 12
            }
        }

        rc "Execute the block when " -for cmode
        enumlong cmode -dictcmd {eanyall deflist}
        label "the conditions are met."

        rc "Given available resources, execute " -for emode
        enumlong emode -dictcmd {eexecmode asdict longname}
    }
} {
    # FIRST, prepare and validate the parameters
    prepare block_id -required -type ::block
    prepare intent
    prepare tmode    -toupper  -selector
    prepare t1       -toupper  -type {simclock timespec}
    prepare t2       -toupper  -type {simclock timespec}
    prepare cmode    -toupper  -type eanyall
    prepare emode    -toupper  -type eexecmode
    prepare once               -type boolean
    prepare onlock             -type boolean

    returnOnError

    # NEXT, get the block.
    set block [block get $parms(block_id)]


    # NEXT, do cross-checks
    fillparms parms [$block view]

    if {$parms(tmode) ne "ALWAYS" && $parms(t1) eq ""} {
        reject t1 "Week not specified."
    }

    returnOnError -final

    if {$parms(tmode) eq "DURING"} {
        if {$parms(t2) eq ""} {
            reject t2 "Week not specified."
        } elseif {$parms(t2) < $parms(t1)} {
            reject t1 "End week must be no earlier than start week."
        }
    }

    returnOnError -final

    # NEXT, update the block.
    set undo [$block update_ {
        intent tmode t1 t2 cmode emode once onlock
    } [array get parms]]

    # NEXT, save the undo script; we're successful.
    setundo $undo
}

# BLOCK:STATE
#
# Sets a block's state to normal or disabled.  The order dialog
# is not generally used.

order define BLOCK:STATE {
    title "Set Strategy Block State"

    options -sendstates PREP

    form {
        label "Block ID:" -for block_id
        text block_id -context yes

        rc "State:" -for state
        text state
    }
} {
    # FIRST, prepare and validate the parameters
    prepare block_id -required          -type ::block
    prepare state    -required -tolower -type ebeanstate
    returnOnError -final

    set block [block get $parms(block_id)]

    # NEXT, update the block
    setundo [$block update_ {state} [array get parms]]
}

# BLOCK:TACTIC:ADD
#
# Adds a tactic of a given type to the block.  The tactic is empty, and
# needs to be initialized by the analyst.
#
# The order dialog is not generally used.

order define BLOCK:TACTIC:ADD {
    title "Add Tactic to Block"

    options -sendstates PREP

    form {
        label "Block ID:" -for block_id
        text block_id -context yes

        rcc "Tactic Type:" -for typename
        text typename
    }
} {
    # FIRST, prepare and validate the parameters
    prepare block_id -required          -type  ::block
    prepare typename -required -toupper -oneof [tactic typenames]

    returnOnError -final

    # NEXT, add the tactic
    set block [block get $parms(block_id)]

    setundo [$block addtactic_ $parms(typename)]

    set tactic [$block tactics end]

    setredo [list bean setnextid [$tactic id]]

    return [$tactic id]
}

# BLOCK:TACTIC:DELETE
#
# Deletes a tactic or tactics from a block. 
#
# The order dialog is not generally used.

order define BLOCK:TACTIC:DELETE {
    title "Delete Tactic(s) from Block"

    options -sendstates PREP

    form {
        text ids
    }
} {
    # FIRST, prepare and validate the parameters
    prepare ids   -required -listof tactic
    returnOnError -final

    # NEXT, delete the tactics
    set undo [list]
    foreach tid $parms(ids) {
        set tactic [tactic get $tid]
        set block [$tactic block]
        lappend undo [$block deletetactic_ $tid]
    }
    
    setundo [join [lreverse $undo] "\n"]
}

# BLOCK:TACTIC:MOVE
#
# Moves a tactic within a strategy block.
#
# The order dialog is not usually used.

order define BLOCK:TACTIC:MOVE {
    title "Move Tactic Within Block"

    options -sendstates PREP

    form {
        rcc "Tactic ID:" -for tactic_id
        text tactic_id -context yes

        rcc "Where:" -for where
        enumlong where -dict {emoveitem asdict longname}
    }
} {
    # FIRST, prepare and validate the parameters
    prepare tactic_id -required -type tactic
    prepare where     -required -type emoveitem

    returnOnError -final

    # NEXT, move the block
    set tactic [tactic get $parms(tactic_id)]
    set block [$tactic block]

    setundo [$block movetactic_ $parms(tactic_id) $parms(where)]
}


# BLOCK:CONDITION:ADD
#
# Adds a condition of a given type to the block.  The condition is empty, and
# needs to be initialized by the analyst.
#
# The order dialog is not generally used.

order define BLOCK:CONDITION:ADD {
    title "Add Condition to Block"

    options -sendstates PREP

    form {
        label "Block ID:" -for block_id
        text block_id -context yes

        rcc "Condition Type:" -for typename
        text typename
    }
} {
    # FIRST, prepare and validate the parameters
    prepare block_id -required          -type block
    prepare typename -required -toupper -oneof [condition typenames]

    returnOnError -final

    # NEXT, add the condition
    set block [block get $parms(block_id)]

    setundo [$block addcondition_ $parms(typename)]

    set cond [$block conditions end]

    setredo [list bean setnextid [$cond id]]

    return [$cond id]
}

# BLOCK:CONDITION:DELETE
#
# Deletes a condition from a block. 
#
# The order dialog is not generally used.

order define BLOCK:CONDITION:DELETE {
    title "Delete Condition from Block"

    options -sendstates PREP

    form {
        text ids
    }
} {
    prepare ids   -required -listof condition
    returnOnError -final

    # NEXT, delete the conditions
    set undo [list]
    foreach tid $parms(ids) {
        set condition [condition get $tid]
        set block [$condition block]
        lappend undo [$block deletecondition_ $tid]
    }
    
    setundo [join [lreverse $undo] "\n"]
}





