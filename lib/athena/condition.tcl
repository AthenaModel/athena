#-----------------------------------------------------------------------
# TITLE:
#    condition.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Mark II Conditions
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
oo::class create ::athena::condition {
    superclass ::projectlib::bean
}

# NEXT, define class methods
oo::objdefine ::athena::condition {
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
        set fullname ::athena::condition::$typename
        lappend types $fullname

        oo::class create $fullname {
            superclass ::athena::condition
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
        return ::athena::condition::$typename
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
}


# NEXT, define instance methods
oo::define ::athena::condition {
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

    constructor {pot_} {
        next $pot_
        set parent  ""
        set state   normal
        set metflag ""
        set name    ""
    }

    #-------------------------------------------------------------------
    # Queries
    #
    # These methods will rarely if ever be overridden by subclasses.
    
    # adb
    #
    # Returns the scenario athenadb(n) handle.

    method adb {} {
        return [[my pot] cget -rdb]
    }

    # subject
    #
    # Set subject for notifier events.  It's the athenadb(n) subject
    # plus ".condition".

    method subject {} {
        set adb [[my pot] cget -rdb]
        return "[$adb cget -subject].condition"
    }


    # fullname
    #
    # The fully qualified name of the condition

    method fullname {} {
        return "[[my block] fullname]/[my get name]"
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
        dict set vdict fullname   [my fullname]

        if {$view eq "html"} {
            dict set vdict narrative [::athena::link html [my narrative]]
        } else {
            # text, cget
            dict set vdict narrative [::athena::link text [my narrative]]
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

        # NEXT, check names of all conditions owned by the parent
        # skipping over the condition we are checking. Throw INVALID
        # on first match.
        foreach condition [[my block] conditions] {
            if {[$condition get id] == [my get id]} {
                continue
            }

            if {$name eq [$condition get name]} {
                throw INVALID "Name already exists as condition: \"$name\""
            }
        }

        # NEXT, check all tactics owned by the parent. Throw INVALID
        # on first match
        foreach tactic [[my block] tactics] {
            if {$name eq [$tactic get name]} {
                throw INVALID "Name already exists as tactic: \"$name\""
            }
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

::athena::orders define CONDITION:STATE {
    meta title      "Set Condition State"
    meta sendstates PREP
    meta parmlist   {condition_id state}

    method _validate {} {
        my prepare condition_id -required -with [list $adb strategy valclass ::athena::condition]
        my prepare state        -required -tolower -type ebeanstate
    }

    method _execute {{flunky ""}} {
        set cond [$adb pot get $parms(condition_id)]
        my setundo [$cond update_ {state} [array get parms]]
    }
}






