#-----------------------------------------------------------------------
# TITLE:
#    tactic.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Mark II Tactic, SIGEVENT
#
#    A tactic is a bean that represents an action taken by an agent.
#    Tactics consume assets (money, personnel), and are contained by
#    strategy blocks.
#
#    Athena uses many different kinds of tactic.  This module
#    defines a base class for tactic types.
#
# EXECSTATUS:
#    Each tactic has an "execstatus" variable, an eexecstatus value
#    that indicates whether or not it executed, and if not why not.  The
#    valid values are as follows:
#
#    NONE            - Set at creation and on update
#    SKIPPED         - The tactic wasn't supposed to execute, and didn't.
#    FAIL_RESOURCES  - The tactic couldn't obligate its required 
#                      resources. 
#    SUCCESS         - The tactic executed successfully.
#
#    The execstatus is set to NONE automatically when the tactic is created
#    and when it is updated.  The other status values are set by 
#    the owning block as it tries to execute (otherwise, they'd need to
#    be set by each individual tactic type).
#
#-----------------------------------------------------------------------

# FIRST, create the class.
oo::class create tactic {
    superclass ::projectlib::bean
}

# NEXT, define class methods
oo::objdefine tactic {
    # List of defined tactic types
    variable types

    # define typename title atypes ?options...? script
    #
    # typename - The tactic type name
    # title    - A tactic title
    # atypes   - The list of agent types this tactic type supports
    # options  - Other options
    # script   - The tactic's oo::define script
    #
    # The options are as follows:
    #
    # -onlock   - If present, the tactic executes on lock.  If not, not.
    #
    # Defines a new tactic type.

    method define {typename title atypes args} {
        # FIRST, get the options and script
        set optlist [lrange $args 0 end-1]
        set script  [lindex $args end]

        # NEXT, process the options
        array set opts {
            -onlock 0
        }

        while {[llength $optlist] > 0} {
            set opt [lshift optlist]

            switch -exact -- $opt {
                -onlock { 
                    set opts(-onlock) 1 
                }

                default {
                    error "Unknown option: \"$opt\""
                }
            }
        }

        # NEXT, create the new type
        set fullname ::tactic::$typename
        lappend types $fullname

        oo::class create $fullname {
            superclass ::tactic
        }

        # NEXT, define the instance members.
        oo::define $fullname $script

        # NEXT, define type commands

        oo::objdefine $fullname [format {
            method typename {} {
                return "%s"
            }

            method title {} {
                return "%s"
            }

            method atypes {} {
                return %s
            }

            method onlock {} {
                return %d
            }
        } $typename $title [list $atypes] $opts(-onlock)]
    }

    # types
    #
    # Returns a list of the available types.

    method types {} {
        return $types
    }

    # typenames ?agent_type?
    #
    # Returns a list of the names of the available types.  If 
    # agent_typeis given, it's limited to tactics available for
    # that type.

    method typenames {{agent_type ""}} {
        set result [list]

        foreach type [my types] {
            if {$agent_type ne ""} {
                if {$agent_type ni [$type atypes]} {
                    continue
                }
            }
            
            lappend result [$type typename]
        }

        return $result
    }

    # type typename
    #
    # name   A typename
    #
    # Returns the actual type object given the typename.

    method type {typename} {
        return ::tactic::$typename
    }

    # typedict ?agent_type?
    #
    # Returns a dictionary of type objects and titles.  If agent_type is
    # given, the result is limited to tactics applicable to that
    # agent type.

    method typedict {{agent_type ""}} {
        set result [dict create]

        foreach type [my types] {
            if {$agent_type ne ""} {
                if {$agent_type ni [$type atypes]} {
                    continue
                }
            }
            dict set result $type "[$type typename]: [$type title]"
        }

        return $result
    }

    # titledict ?agent_type?
    #
    # Returns a dictionary of titles and type names.  If agent_type is
    # given, the result is limited to tactics applicable to that
    # agent type.

    method titledict {{agent_type ""}} {
        set result [dict create]

        foreach type [my types] {
            if {$agent_type ne ""} {
                if {$agent_type ni [$type atypes]} {
                    continue
                }
            }
            dict set result "[$type typename]: [$type title]" [$type typename]
        }

        return $result
    }

    #-------------------------------------------------------------------
    # Pasting of Tactics

    # paste block copysets
    #
    # block_id  - The ID of the block to receive the tactics
    # copysets  - A list of tactic copysets from [$bean copydata].
    #
    # Pastes the tactics into the given block.  This call should be
    # wrapped by [flunky transaction] calls.  This is
    # not included in [paste] itself, because pasting tactics can be
    # done as part of a larger paste (i.e., pasting blocks).

    method paste {block_id copysets} {
        # FIRST, paste the copied tactics into the block
        foreach copyset $copysets {
            # FIRST, get the tactic data
            set cls   [dict get $copyset class_]
            set tname [$cls typename]
            set tdict [my GetOrderParmsFromCopySet $tname $copyset]

            # NEXT, create the tactic with default settings
            set tactic_id \
                [flunky senddict gui BLOCK:TACTIC:ADD \
                    [list block_id $block_id typename $tname]]

            # NEXT, update the tactic with the right data.
            flunky senddict gui TACTIC:$tname \
                [list tactic_id $tactic_id {*}$tdict]
        }
    }

    # GetOrderParmsFromCopySet tname copyset
    #
    # tname   - The tactic type name
    # copyset - The copyset from [$bean copydata]
    #
    # Pulls out the required parameters from the copyset.

    method GetOrderParmsFromCopySet {tname copyset} {
        set pdict [dict create]

        foreach parm [::athena::orders parms TACTIC:$tname] {
            if {$parm eq "tactic_id" || $parm eq "name"} {
                continue
            }

            dict set pdict $parm [dict get $copyset $parm]
        }

        return $pdict
    }
    

    #-------------------------------------------------------------------
    # Order Helpers

    # groupsOwnedByAgent id
    #
    # id   - A tactic ID
    #
    # Returns a list of force and organization groups owned by the 
    # agent who owns the given tactic.  This is for use in order
    # dynaforms where the user must choose an owned group.

    method groupsOwnedByAgent {id} {
        if {[pot has $id]} {
            set tactic [pot get $id]
            return [group ownedby [$tactic agent]]
        } else {
            return [list]
        }
    }

    # frcgroupsOwnedByAgent id
    #
    # id   - A tactic ID
    #
    # Returns a list of force groups owned by the 
    # agent who owns the given tactic.  This is for use in order
    # dynaforms where the user must choose an owned group.

    method frcgroupsOwnedByAgent {id} {
        if {[pot has $id]} {
            set tactic [pot get $id]
            return [frcgroup ownedby [$tactic agent]]
        } else {
            return [list]
        }
    }

    # allAgentsBut id
    #
    # id  - A tactic ID
    #
    # Returns a list of agents except the one that owns the 
    # given tactic.

    method allAgentsBut {id} {
        if {[pot has $id]} {
            set tactic [pot get $id]
            set alist [actor names]
            return [ldelete alist [$tactic agent]]
        } else {
            return [list]
        }
    }

}


# NEXT, define instance methods
oo::define tactic {
    #-------------------------------------------------------------------
    # Instance Variables

    # Every tactic has a "id", due to being a bean.

    variable parent      ;# The bean ID of the tactic's owning block
    variable state       ;# The tactic's state: normal, disabled, invalid
    variable execstatus  ;# An eexecstatus value: NONE, SKIPPED, 
                          # FAIL_RESOURCES, or SUCCESS.
    variable faildict    ;# Dictionary of resource failure detail messages
                          # by eresource symbol.
    variable name        ;# Tactic name; can be set by user

    # Tactic types will add their own variables.

    #-------------------------------------------------------------------
    # Constructor

    constructor {} {
        next
        set parent     ""
        set state      normal
        set execstatus NONE
        set faildict   [dict create]
        set name       ""
    }

    #-------------------------------------------------------------------
    # Queries
    #
    # These methods will rarely if ever be overridden by subclasses.

    # subject
    #
    # Set subject for notifier events.

    method subject {} {
        return "::tactic"
    }


    # fullname
    #
    # The fully qualified name of the tactic

    method fullname {} {
        return "[[pot get [my get parent]] fullname]/[my get name]"
    }

    # typename
    #
    # Returns the tactic's typename

    method typename {} {
        return [namespace tail [info object class [self]]]
    }

    # agent
    #
    # Returns the agent who owns the strategy that owns the block that
    # owns this condition.

    method agent {} {
        return [[[my pot] get $parent] agent]
    }
    
    # strategy 
    #
    # Returns the strategy that owns the block that owns this condition.

    method strategy {} {
        return [[[my pot] get $parent] strategy]
    }

    # block
    #
    # Returns the block that owns this condition.

    method block {} {
        return [[my pot] get $parent]
    }

    # state
    #
    # Returns the tactic's state: normal, disabled, invalid

    method state {} {
        return $state
    }

    # execstatus
    #
    # Returns the execution status.

    method execstatus {} {
        return $execstatus
    }

    # execflag
    #
    # Returns 1 if the tactic executed successfully, and 0 otherwise.

    method execflag {} {
        return [expr {$execstatus eq "SUCCESS"}]
    }

    # statusicon
    #
    # Returns the appropriate status icon for this tactic.  If the
    # execstatus is FAIL_RESOURCES, then it returns the failicon.
    # Otherwise it returns the execstatus icon.

    method statusicon {} {
        if {$execstatus eq "FAIL_RESOURCES"} {
            return [my failicon]
        } else {
            return [eexecstatus as icon $execstatus]
        }
    }

    #-------------------------------------------------------------------
    # Resource Failure Detail Management
    

    # Fail code message
    #
    # code    - An eresource code
    # message - The failure message
    # 
    # Saves the resource failure message.  This is for use by
    # obligate methods.

    method Fail {code message} {
        dict set faildict $code $message
    }

    # InsufficientCash cash cost
    #
    # cash   - Cash available
    # cost   - Cash required
    #
    # Returns 1 on insufficient cash, setting the failure message,
    # and 0 otherwise.  Cash is always sufficient on lock.

    method InsufficientCash {cash cost} {
        if {[strategy ontick] && $cost > $cash} {

            set cash [commafmt $cash]
            set cost [commafmt $cost]

            my Fail CASH "Required \$$cost, but had only \$$cash."

            return 1
        } else {
            return 0
        }
    }

    # InsufficientPersonnel available required
    #
    # available  - Personnel available
    # required   - Personnel required
    #
    # Returns 1 on insufficient personnel, setting the failure
    # message, and 0 otherwise.

    method InsufficientPersonnel {available required} {
        if {$required > $available} {
            my Fail PERSONNEL \
            "Required $required personnel, but had only $available available."
            return 1
        } else {
            return 0
        }
    }


    # faildict
    #
    # Returns the tactic's failure dictionary.

    method faildict {} {
        return $faildict
    }

    # failicon
    #
    # Returns the icon associated with the first failure
    # in the faildict., or "" if none.

    method failicon {} {
        set code [lindex [dict keys $faildict] 0]

        if {$code ne ""} {
            return [eresource as icon $code]
        } else {
            return ""
        }
    }

    # failures
    #
    # Returns a list of the resource failure messages.

    method failures {} {
        return [dict values $faildict]
    }

    #-------------------------------------------------------------------
    # Tactic Reset

    # reset
    #
    # Resets the execution status of the tactic.

    method reset {} {
        my set execstatus NONE
        my set faildict   [dict create]
    }
    

    #-------------------------------------------------------------------
    # Views

    # view ?view?
    #
    # view   - A view name; defaults to "text".
    #
    # Standard views:
    #
    #    text    - All data, links converted to plain text.
    #    html    - All data, links converted to HTML <a> tags
    #    cget    - Data for [tactic cget] executive command.
    #
    # Returns a view dictionary.

    method view {{view "text"}} {
        set vdict [next $view]

        # FIRST, set up the default view data for text and html

        dict set vdict agent      [my agent]
        dict set vdict typename   [my typename]
        dict set vdict statusicon [my statusicon]
        dict set vdict fullname   [my fullname]

        if {$view eq "html"} {
            dict set vdict narrative [link html [my narrative]]
        } else {
            # text, cget
            dict set vdict narrative [link text [my narrative]]
        }

        dict set vdict failures [join [my failures] "\n"]

        # NEXT, translate and trim for cget view
        if {$view eq "cget"} {
            dict set vdict tactic_id [my id]
            dict set vdict parent    [my get parent]

            set vdict [dict remove $vdict {*}{
                execstatus
                faildict
                failures
                id
                pot
                statusicon
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
    # Produces a complete HTML page describing this tactic in the
    # ht buffer.

    method htmlpage {ht} {
        set block_id [[my block] id]

        $ht page "Agent [my agent], Detail for Tactic [my id] in Block $block_id"
        $ht putln "<b>Agent "
        $ht link my://app/agent/[my agent] [my agent]
        $ht put ", Tactic [my id] in "
        $ht link my://app/bean/$block_id "Block $block_id"
        $ht put "</b>"
        $ht hr
        $ht para
        my html $ht
        $ht /page
    }

    # html ht
    #
    # ht   - An htools(n) buffer
    #
    # Produces an HTML description of the tactic, in the buffer, for
    # inclusion in another page or for use in a myhtmlpane.

    method html {ht} {
        # FIRST, add the header.  Its color and font should indicate
        # the state.
        $ht putln "<a name=\"tactic[my id]\"><b>Tactic [my id]:</b></a>"

        array set view [my view html]

        $ht table {
            "Variable" "Value"
        } {
            foreach key [lsort [array names view]] {
                $ht tr {
                    $ht td left { $ht put "<tt>$key</tt>" }
                    $ht td left { $ht put "<tt>$view($key)</tt>"}
                }
            }
        }
    }

    #-------------------------------------------------------------------
    # Operations
    #
    # These methods represent condition operations whose actions may
    # vary by condition type.
    #
    # Subclasses will usually need to override the SanityCheck, narrative,
    # obligate, and ExecuteTactic methods.

    # check
    #
    # Sanity checks the tactic, returning a dict of variable names
    # and error strings:
    #
    #   $var -> $errmsg 
    #
    # If the dict is empty, there are no problems.

    method check {} {
        set errdict [my SanityCheck [dict create]]

        if {[dict size $errdict] > 0} {
            my set state invalid
        } elseif {$state eq "invalid"} {
            my set state normal
        }

        return $errdict
    }

    # SanityCheck errdict
    #
    # errdict   - A dictionary of instance variable names and error
    #             messages.
    #
    # This command should check the class's variables for errors, and
    # add the error messages to the errdict, returning the errdict
    # on completion.  The usual pattern for subclasses is this:
    #
    #    ... check for errors ...
    #    return [next $errdict]
    #
    # Thus allowing parent classes their chance at it.

    method SanityCheck {errdict} {
        # Check the agent type.
        set atype [agent type [my agent]]
        set validAtypes [[info object class [self object]] atypes]


        if {$atype ni $validAtypes} {
            dict set errdict agent \
                "This agent cannot use [my typename] tactics."
        }
        return $errdict
    }

    # narrative
    #
    # Computes a narrative for this tactic, for use in the GUI.

    method narrative {} {
        return "no narrative defined"
    }

    # obligate coffer
    #
    # coffer - A coffer object, representing the owning actor's
    #          current resources.
    #
    # Obligates the resources for use by this tactic, updating
    # the coffer.  Returns 1 on success, and 0 on failure.
    #
    # Subclasses override ObligateResources.  The obligation is
    # known to have failed if the subclass has registered a
    # resource failure using [my Fail] or one of the other
    # helper methods.

    method obligate {coffer} {
        # FIRST, initialize the failure dictionary
        my set faildict [dict create]

        my ObligateResources $coffer

        return [expr {[dict size $faildict] == 0}]
    }

    # ObligateResources coffer
    #
    # coffer - A coffer object, representing the owning actor's
    #          current resources.
    #
    # Obligates resources required by this tactic, updating
    # the coffer.  Subclasses should override this method.  
    # It is not necessary to call "next".  However, the
    # method should call [my Fail] on resource failure.
    # (This is done automatically by [my InsufficientCash]
    # and [my InsufficientTroops]).

    method ObligateResources {coffer} {
        # By default, obligation trivally succeeds.
    }

    # execute
    #
    # Executes this tactic using the obligated resources.
    # It is assumed that the tactic can execute, given that
    # the tactic is not invalid and the resources were obligated.

    method execute {} {
        # Every tactic should override this.
        error "Tactic execution is undefined"
    }

    #-------------------------------------------------------------------
    # Event Handlers and Order Mutators
    #
    # Order mutators are special operations used to modify this object in 
    # response to user input.  Mutators return an undo script that will
    # undo the change, or "" if the change cannot be undone.
    #
    # Event Handlers do additional work when the object is mutated.

    # onUpdate_
    #
    # On update_, resets status data and does a sanity check
    # if appropriate.
    
    method onUpdate_ {} {
        # FIRST, clear the execstatus; the tactic has changed, and
        # is effectively different from any tactic that ran previously.
        my reset

        # NEXT, Check only if the tactic is not disabled; otherwise, if you
        # try to disable an invalid tactic so that you can lock the
        # scenario, it gets marked invalid again.

        if {$state ne "disabled"} {
            my check
        }

        next
    }

    #----------------------------------------------------------------
    # Order Helpers
    #
    
    # valName name 
    #
    # name  - a name for a tactic
    #
    # This validator checks to make sure that the name is an 
    # identifier AND does not already exist in the set of tactics
    # owned by this tactics parent.

    method valName {name} {
        # FIRST, name must be an identifier
        ident validate $name

        # NEXT, check existing tactics owned by the parent 
        # skipping over the tactic we are checking. Throw 
        # INVALID on first match
        foreach tactic [[my block] tactics] {
            if {[$tactic get id] == [my get id]} {
                continue
            }

            if {$name eq [$tactic get name]} {
                throw INVALID "Name already exists: \"$name\""
            }
        }

        # NEXT, check all conditions owned by parent. Throw
        # INVALID on first match
        foreach condition [[my block] conditions] {
            if {$name eq [$condition get name]} {
                throw INVALID "Name already exists: \"$name\""
            }
        }

        return $name
    }
}


# TACTIC:STATE
#
# Sets a tactic's state to normal or disabled.

::athena::orders define TACTIC:STATE {
    meta title      "Set Tactic State"
    meta sendstates PREP
    meta parmlist   { tactic_id state }

    method _validate {} {
        my prepare tactic_id -required -with {::strategy valclass ::tactic}
        my prepare state     -required -tolower -type ebeanstate
    }

    method _execute {{flunky ""}} {
        set tactic [pot get $parms(tactic_id)]
        my setundo [$tactic update_ {state} [array get parms]]
    }
}






