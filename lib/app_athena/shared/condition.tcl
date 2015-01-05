#-----------------------------------------------------------------------
# TITLE:
#    condition.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Mark II Conditions
#
#    A condition is an bean that represents a boolean proposition
#    regarding the state of the simulation.  It can be evaluated to 
#    determine whether or not the condition is currently met.
#
#    Athena uses many different kinds of condition.  This module
#    defines a base class for condition types.
#
#-----------------------------------------------------------------------

# FIRST, create the class.
oo::class create condition {
    superclass ::projectlib::bean
}

# NEXT, define class methods
#
# TBD: This is essentially the same as tactic; can we refactor this
# somehow?
oo::objdefine condition {
    # List of defined condition types
    variable types

    # define typename title atypes script
    #
    # typename - The condition type name
    # title    - A condition title
    # script   - The condition's oo::define script
    #
    # Defines a new condition type.

    method define {typename title script} {
        # FIRST, create the new type
        set fullname ::condition::$typename
        lappend types $fullname

        oo::class create $fullname {
            superclass ::condition
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
        } $typename $title]
    }

    # types
    #
    # Returns a list of the available types.

    method types {} {
        return $types
    }

    # typenames
    #
    # Returns a list of the names of the available types.

    method typenames {} {
        set result [list]

        foreach type [my types] {
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
        return ::condition::$typename
    }

    # typedict
    #
    # Returns a dictionary of type objects and titles.

    method typedict {} {
        set result [dict create]

        foreach type [my types] {
            dict set result $type "[$type typename]: [$type title]"
        }

        return $result
    }

    # titledict
    #
    # Returns a dictionary of titles and type names.

    method titledict {} {
        set result [dict create]

        foreach type [my types] {
            dict set result "[$type typename]: [$type title]" [$type typename]
        }

        return $result
    }

    #-------------------------------------------------------------------
    # Pasting of Conditions

    # paste block_id copysets
    #
    # block_id  - The ID of the block to receive the conditions
    # copysets  - A list of condition copysets from [$bean copydata].
    #
    # Pastes the conditions into the given block.  This call should be
    # wrapped by [cif startblock]/[cif endblock] calls.  These are
    # not included in [paste] itself, because pasting conditions can be
    # done as part of a larger paste (i.e., pasting blocks).

    method paste {block_id copysets} {
        # FIRST, paste the copied conditions into the block
        foreach copyset $copysets {
            # FIRST, get the condition data
            set cls   [dict get $copyset class_]
            set cname [$cls typename]
            set cdict [my GetOrderParmsFromCopySet $cname $copyset]

            # NEXT, create the condition with default settings
            set condition_id \
                [order send gui BLOCK:CONDITION:ADD \
                    block_id $block_id typename $cname]

            # NEXT, update the condition with the right data.
            order send gui CONDITION:$cname condition_id $condition_id \
                {*}$cdict
        }
    }

    # GetOrderParmsFromCopySet cname copyset
    #
    # cname   - The condition type name
    # copyset - The copyset from [$bean copydata]
    #
    # Pulls out the required parameters from the copyset.

    method GetOrderParmsFromCopySet {cname copyset} {
        set pdict [dict create]

        foreach parm [order parms CONDITION:$cname] {
            if {$parm eq "condition_id"} {
                continue
            }

            dict set pdict $parm [dict get $copyset $parm]
        }

        return $pdict
    }
}


# NEXT, define instance methods
oo::define condition {
    #-------------------------------------------------------------------
    # Instance Variables

    variable parent   ;# The bean ID of the condition's owning block
                       # TBD: in the long run, it won't always be a block.
    variable state    ;# The condition's state
    variable metflag  ;# 1 if condition is met, 0 if it is unmet, 
                       # or "" if the result is unknown
    variable name     ;# Condition name; can be set by user
    
    #-------------------------------------------------------------------
    # Constructor

    constructor {} {
        next
        set parent  ""
        set state   normal
        set metflag ""
        set name    ""
    }

    #-------------------------------------------------------------------
    # Queries
    #
    # These methods will rarely if ever be overridden by subclasses.
    
    # subject
    #
    # Set subject for notifier events.

    method subject {} {
        return "::condition"
    }


    # typename
    #
    # Returns the condition's typename

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
    # Returns the block's state, normal or invalid.

    method state {} {
        return $state
    }

    # isknown
    #
    # Returns 1 if the value of the metflag is known, and 0 otherwise.

    method isknown {} {
        return [expr {$metflag ne ""}]
    }

    # ismet
    #
    # Returns 1 if the value of the metflag is known, and the flag
    # is met.  Returns 0 otherwise.

    method ismet {} {
        return [expr {$metflag ne "" && $metflag}]
    }

    # statusicon
    #
    # Returns a status icon for this condition, for use in 
    # the GUI.

    method statusicon {} {
        return [eflagstatus as icon $metflag]
    }


    #-------------------------------------------------------------------
    # Views

    # view ?view?
    #
    # view   - A view name; defaults to "text"
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

        if {$view eq "html"} {
            dict set vdict narrative [link html [my narrative]]
        } else {
            # text, cget
            dict set vdict narrative [link text [my narrative]]
        }

        # NEXT, translate and trim for cget view
        if {$view eq "cget"} {
            dict set vdict condition_id [my id]
            dict set vdict parent       [my get parent]

            set vdict [dict remove $vdict {*}{
                pot
                id
                metflag
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
    # Produces a complete HTML page describing this condition in the
    # ht buffer.

    method htmlpage {ht} {
        set block_id [[my block] id]

        $ht page "Agent [my agent], Detail for Condition [my id] in Block $block_id"
        $ht putln "<b>Agent "
        $ht link my://app/agent/[my agent] [my agent]
        $ht put ", Condition [my id] in "
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
    # Produces an HTML description of the condition, in the buffer, for
    # inclusion in another page or for use in a myhtmlpane.

    method html {ht} {
        # FIRST, add the header.  Its color and font should indicate
        # the state.
        $ht putln "<a name=\"condition[my id]\"><b>Condition [my id]:</b></a>"

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
    # and Evaluate methods.

    # reset
    #
    # Resets execution status variables.

    method reset {} {
        my set metflag ""
    }
    
    # check
    #
    # Sanity checks the condition, returning a dict of variable names
    # and error strings:
    #
    #   $var -> $errmsg 
    #
    # If the dict is empty, there are no problems.
    # If the subclass has possible sanity check failures, it should
    # override SanityCheck.

    method check {} {
        set errdict [my SanityCheck [dict create]]

        if {[dict size $errdict] > 0} {
            my set state invalid
            my set metflag ""
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
    # thus allowing parent classes their chance at it.
    #
    # This method should be overridden by every condition type that
    # can have sanity check failures.

    method SanityCheck {errdict} {
        return $errdict
    }

    # narrative
    #
    # Returns the condition's narrative.  This should be overridden by 
    # the subclass.
    method narrative {} {
        return "no narrative defined"
    }

    # eval
    #
    # Evaluates the condition and saves the metflag.  The subclass
    # should override Evaluate.

    method eval {} {
        my set metflag [my Evaluate]
        return $metflag
    }

    # Evaluate
    #
    # This method should be overridden by every condition type; it
    # should compute whether the condition is met or not, and return
    # 1 if so and 0 otherwise.  The [eval] method will call it on
    # demand and cache the result.

    method Evaluate {} {
        return 1
    }

    #-------------------------------------------------------------------
    # Event Handlers

    # onUpdate_
    #
    # On update_, clears the metflag and does a sanity check, if appropriate.

    method onUpdate_ {} {
        # FIRST, clear execution status; the condition has changed, and
        # we don't know what its status is.
        my reset

        # NEXT, do a sanity check (unless it's already disabled)
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
    # identifier AND does not already exist in the set of conditions
    # owned by this conditions parent.

    method valName {name} {
        # FIRST, name must be an identifier
        ident validate $name

        # NEXT, gather a list of existing names for all conditions
        # owned by the parent skipping over the condition we 
        # are checking
        set cnames [list]

        set parent [my get parent]
        foreach condition [[pot get $parent] conditions] {
            if {[$condition get id] == [my get id]} {
                continue
            }

            lappend cnames [$condition get name]
        }

        # NEXT, invalid if it already exists
        if {$name in $cnames} {
            throw INVALID "Name already exists: \"$name\""
        }

        return $name
    }
}

#-----------------------------------------------------------------------
# Orders

# CONDITION:STATE
#
# Sets a condition's state to normal or disabled.  The order dialog
# is not generally used.

order define CONDITION:STATE {
    title "Set Condition State"

    options -sendstates PREP

    form {
        label "Condition ID:" -for condition_id
        text condition_id -context yes

        rc "State:" -for state
        text state
    }
} {
    # FIRST, prepare and validate the parameters
    prepare condition_id -required          -with {::pot valclass ::condition}
    prepare state        -required -tolower -type ebeanstate
    returnOnError -final

    set cond [pot get $parms(condition_id)]

    # NEXT, update the block
    setundo [$cond update_ {state} [array get parms]]
}





