#-----------------------------------------------------------------------
# TITLE:
#    order_flunky.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectlib(n): Order Flunky Class
#
#    order_flunky(n) is a class that manages the execution of orderx orders,
#    and the reporting of results to the application.  It also manages
#    the undo/redo stacks.
#
#    An order_flunky is created relative to a particular order_set(n),
#    and handles the orders in that set.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export order_flunky
}

#-----------------------------------------------------------------------
# order_flunky class

oo::class create ::projectlib::order_flunky {
    #-------------------------------------------------------------------
    # Instance Variables

    # oset: The order_set(n) component.
    variable oset

    # order state; used to control which orders are available.
    variable ostate

    # mode: Execution mode, gui|normal|private.  See [$f execute].
    # Set while order is executing.
    variable execMode

    # undoStack - stack of items to be undone.  The top is the end.
    # An item might be an order or a transaction.
    variable undoStack

    # redoStack - stack of items to be redone.  The top is the end.
    # An item might be an order or a transaction.
    variable redoStack

    # transList - list of orders in the current transaction, while 
    # in a transaction.
    #
    # The list begins with the transaction narrative, followed by
    # all orders in the transaction.  Such a list is also called
    # a "transaction".
    #
    # NOTE: If this variable is non-empty, we are in a transaction.
    # While in a transaction, we cannot undo or redo; that's an
    # error which will lead to the transaction's failure.

    variable transList
    
    #-------------------------------------------------------------------
    # Constructor

    # constructor orderSet_
    #
    # orderSet_ - The name of the order_set(n) component.
    #
    # TODO: Possibly, we will want an option-based interface.

    constructor {orderSet_} {
        # FIRST, initialize the instance variables
        set oset      $orderSet_
        set ostate    ""
        set execMode  normal
        set undoStack [list]
        set redoStack [list]
        set transList [list]
    }
    
    #-------------------------------------------------------------------
    # Sending Orders

    # make name args
    #
    # name   - An order name
    #
    # Makes an order object for the named order.  Subclasses can override
    # this to add additional context when creating the order.

    method make {name args} {
        $oset validate $name
        set cls [$oset class $name]
        return [$cls new {*}$args]
    }

    # execute mode order
    #
    # mode   - Execution mode, gui|normal|private
    # order  - An orderx(n) object
    #
    # Executes the given order according to the mode.
    #
    # If the mode is "normal", this command:
    #
    # * Throws an unexpected error if the order isn't valid.
    # * Executes the order.
    # * Adds it to the undo stack (or clears the undo stack if it cannot 
    #   be undone.
    # * Returns the order's return value.
    #
    # If the mode is "gui", execution is as above; but orders that wish
    # to can pop up confirmation dialogs and the like.
    #
    # If the mode is "private", the undo/redo stack is left alone.
    #
    # NOTE: The caller always retains ownership of the order object.  
    # If the order is executed successfully, then a copy is made to
    # put on the undo stack.  Thus, it's up to the caller to destroy
    # the order object when it's done with it.
    #
    # Returns the order's return value on success.

    method execute {mode order} {
        require {$mode in {gui normal private}} "Invalid mode: \"$mode\""
        require {[my available [$order name]]} \
            "Order [$order name] is not available in state \"[my state]\""
        require {[$order valid]} "This [$order name] order is invalid."

        try {
            set execMode $mode
            set result [$order execute [self]]
        } trap CANCEL {result} {
            return "Order was cancelled."
        } finally {
            set execMode normal
        }

        if {$mode ne "private"} {
            my UndoPushNew [oo::copy $order]
        }

        return $result
    }

    # send mode name options...
    #
    # mode      - Execution mode, gui|normal|private
    # name      - The order name, as defined in the oset.
    # options   - The order's parameters, in option syntax.
    #
    # Creates an order object, sets its parameters, and executes it
    # if possible.  Throws REJECT with a detailed human-readable 
    # error message if the order isn't valid.

    method send {mode name args} {
        require {$mode in {gui normal private}} "Invalid mode: \"$mode\""

        # FIRST, get the order object, validating the order name.
        $oset validate $name

        if {![my available $name]} {
            throw REJECT \
                "Order $name isn't available in state \"[my state]\"."
        }

        set order [my make $name]

        try {
            # FIRST, build the parameter dictionary, validating the
            # parameter names as we go.
            set parms [$order parms]
            set userParms [list]

            while {[llength $args] > 0} {
                set opt [lshift args]

                set parm [string range $opt 1 end]

                if {![string match "-*" $opt] ||
                    $parm ni $parms
                } {
                    set text "$name rejected:\n"
                    append text "$opt   Unknown option"
                    throw REJECT $text
                }

                if {[llength $args] == 0} {
                    error "Missing value for option $opt"
                }

                $order set $parm [lshift args]
                lappend userParms $parm
            }

            # NEXT, execute the order and return the result.
            if {[$order valid]} {
                return [my execute $mode $order]
            } else {
                throw REJECT [my SendError $order $userParms]
            }
        } finally {
            $order destroy
        }
    }

    # SendError order userParms
    #
    # order      - An invalid order
    # userParms  - Names of parameters explicitly entered by the user.
    #
    # Formats a nice, human-readable error message for the order.

    method SendError {order userParms} {
        set wid [lmaxlen [$order parms]]
        set text "[$order name] rejected:\n"

        # FIRST, add the parms in error.
        dict for {parm msg} [$order errdict] {
            append text [format "-%-*s   %s\n" $wid $parm $msg]
        }

        # NEXT, add the defaulted parms
        set defaulted [list]
        foreach parm [$order parms] {
            if {$parm ni $userParms &&
                ![dict exists [$order errdict] $parm]
            } {
                lappend defaulted $parm
            }
        }

        if {[llength $defaulted] > 0} {
            append text "\nDefaulted Parameters:\n"
            foreach parm $defaulted {
                set value [$order get $parm]
                append text [format "-%-*s   %s\n" $wid $parm $value]
            }
        }

        return $text
    }


    # senddict mode name parmdict
    #
    # mode      - Execution mode, gui|normal|private
    # name      - The order name, as defined in the oset.
    # options   - The order's parameters, as a dictionary.
    #
    # Creates an order object, sets its parameters, and executes it
    # if possible.  Throws REJECTED with an error dictionary 
    # if the order isn't valid.

    method senddict {mode name parmdict} {
        require {$mode in {gui normal private}} "Invalid mode: \"$mode\""
        $oset validate $name

        if {![my available $name]} {
            throw REJECT \
                "Order $name isn't available in state \"[my state]\"."
        }

        set order [my make $name]

        try {
            $order setdict $parmdict

            if {[$order valid]} {
                return [my execute $mode $order]
            } else {
                throw REJECT [$order errdict]
            }
        } finally {
            $order destroy
        }
    }

    #-------------------------------------------------------------------
    # Order State

    # state ?newState?
    #
    # newState - A new simulation state, e.g., PAUSED.
    #
    # Sets/queries the simulation state.

    method state {{newState ""}} {
        if {$newState ne ""} {
            set ostate $newState
        }

        return $ostate
    }

    # mode
    #
    # Returns the flunky's execution mode.  The mode is set while
    # an order is executing, and is always "normal" otherwise.

    method mode {} {
        return $execMode
    }

    # available name
    #
    # Returns 1 if order $name is available in the current
    # order state, and 0 otherwise.

    method available {name} {
        set ocls [$oset class $name]
        set states [$ocls sendstates]

        # FIRST, what if the order doesn't specify any particular states?
        if {[llength $states] == 0} {
            # FIRST, if there's no state set, assume the state mechanism
            # isn't being used.  Otherwise, it's an error; the developer
            # should have specified the states for this order.
            if {$ostate eq ""} {
                return 1
            } else {
                return 0
            }
        }

        # NEXT, the order is available if it's valid in all
        # states ("*") or the current state is one of its states.
        return [expr {$states eq "*" || $ostate in $states}] 
    }
    
    #-------------------------------------------------------------------
    # Transactions
    #
    # A transaction groups a set of orders that are undone and redone
    # as a unit.  If there is an error during the transaction, all
    # successful orders previously recorded are undone.

    # transaction narrative script
    #
    # narrative  - The narrative for this transaction (i.e., the
    #              undo/redo text).
    # script     - The script that implements the transaction.
    #
    # Executes the script as a single transaction.  All orders executed
    # during the transaction (except "private" orders) are added to the
    # transaction list rather than the undo stack; and then the 
    # the trans list is added to the undo stack as a unit.
    #
    # Transactions may nest; but only the outermost narrative is 
    # preserved.

    method transaction {narrative script} {
        # FIRST, if we're not in a transaction then begin one.
        if {![my InTransaction]} {
            set transList [list $narrative]
            set outermost 1
        } else {
            set outermost 0
        }

        # NEXT, execute the script
        try {
            uplevel 1 $script
        } on error {result eopts} {
            # Roll back changes, and rethrow.
            my Rollback
            return {*}$eopts $result
        }

        # NEXT, end the transaction.
        if {$outermost} {
            # Ensure that an order was sent during the transaction.
            if {[llength $transList] > 1} {
                my UndoPushNew $transList
            }
            set transList ""
        }
    }

    # InTransaction
    #
    # Returns 1 if we're in the middle of an order transaction, and 0
    # otherwise.

    method InTransaction {} {
        return [got $transList]
    }

    # IsTrans item
    #
    # item  - An undo item
    #
    # Returns 1 if the item is a transaction, and 0 otherwise.

    method IsTrans {item} {
        return [expr {[llength $item] > 1}]
    }

    # Rollback
    #
    # Rolls back the current transaction.  If there are nested
    # transactions, this will get called multiple times; only handle
    # transList the first time.

    method Rollback {} {
        if {![got $transList]} {
            return
        }

        set orders [lreverse [lrange $transList 1 end]]
        set transList [list]

        foreach order $orders {
            $order undo
            $order destroy
        }
    }

    #-------------------------------------------------------------------
    # Undo/Redo
    #
    # TODO: Need to handle undo blocks.  That probably means we need
    # an undoable interface.

    # reset
    #
    # Clears the undo and redo stacks.

    method reset {} {
        my UndoClear
        my RedoClear

        set transList [list]
        return
    }

    # canundo
    #
    # Returns 1 if there's an order on the undo stack, and 0 otherwise.

    method canundo {} {
        # TODO: Take the top order's sendstates into account?  In that
        # case, if we can't undo, clear the stack?

        if {[my InTransaction]} {
            return 0
        }

        return [got $undoStack]
    }

    # undotext
    #
    # Returns the narrative of the item at the top of the undo stack,
    # or "" if none.

    method undotext {} {
        if {![my canundo]} {
            return ""
        }

        return [my ItemNarrative "Undo" [ltop $undoStack]]

    }

    # canredo
    #
    # Returns 1 if there's an order on the redo stack, and 0 otherwise.

    method canredo {} {
        if {[my InTransaction]} {
            return 0
        }

        # TODO: Take the top order's sendstates into account?  In that
        # case, if we can't redo, clear the stack?
        return [got $redoStack]
    }

    # redotext
    #
    # Returns the narrative of the item at the top of the redo stack,
    # or "" if none.

    method redotext {} {
        if {![my canredo]} {
            return ""
        }

        return [my ItemNarrative "Redo" [ltop $redoStack]]
    }

    # undo
    #
    # Undo the top order on the undo stack, and move it to the 
    # redo stack.  It's an error if there's no order to redo.

    method undo {} {
        require {![my InTransaction]} "Cannot undo during transaction."

        if {![my canundo]} {
            error "Nothing to undo; stack is empty."
        }

        set item [lpop undoStack]

        if {[my IsTrans $item]} {
            foreach order [lreverse [lrange $item 1 end]] {
                $order undo
            }
        } else {
            $item undo            
        }

        lpush redoStack $item
        return
    }

    # redo
    #
    # Redoes the top order on the redo stack, and move it to the 
    # undo stack.  It's an error if there's no order to redo.

    method redo {} {
        require {![my InTransaction]} "Cannot redo during transaction."

        if {![my canredo]} {
            error "Nothing to redo; stack is empty."
        }

        set item [lpop redoStack]

        if {[my IsTrans $item]} {
            foreach order [lrange $item 1 end] {
                $order execute
            }
        } else {
            $item execute    
        }

        # We know it can undone, because it wouldn't be on the redo
        # stack otherwise.
        lpush undoStack $item
        return
    }



    # UndoPushNew item
    #
    # item - An order or transaction list that was successfully executed.
    #
    # If the item can be undone, it is pushed onto the Undo Stack;
    # otherwise, the stack is cleared.

    method UndoPushNew {item} {
        # FIRST, we've got a new successful order or transaction; the
        # redo history is now irrelevant.
        my RedoClear

        # NEXT, transaction lists are always undoable.
        if {[my IsTrans $item]} {
            lpush undoStack $item
            return
        }

        # NEXT, what happens depends on whether we are in a transaction
        # or not.
        set order $item

        if {[my InTransaction]} {
            if {[$order canundo]} {
                lpush transList $order
            } else {
                error "Non-undoable order used in transaction: [$order name]"
            }
        } else {
            if {[$order canundo]} {
                lpush undoStack $order
            } else {
                my UndoClear
            }
        }
    }

    # UndoClear
    #
    # Clears the undoStack

    method UndoClear {} {
        try {
            my DestroyItems $undoStack
        } finally {
            set undoStack [list]
        }
    }
    
    # RedoClear
    #
    # Clears the redoStack

    method RedoClear {} {
        try {
            my DestroyItems $redoStack
        } finally {
            set redoStack [list]
        }
    }

    # DestroyItems list
    #
    # list - A list of saved items to destroy.
    #
    # Destroys all orders and transactions in the list.

    method DestroyItems {list} {
        foreach item $list {
            if {[my IsTrans $item]} {
                foreach o [lrange $item 1 end] {
                    $o destroy
                }
            } else {
                $item destroy
            }
        }
    }

    # ItemNarrative op item
    #
    # op    - The operation
    # item  - an order or transaction
    #
    # Returns the item's narrative string.

    method ItemNarrative {op item} {
        if {[my IsTrans $item]} {
            return "$op: [lindex $item 0]"
        } else {
            return "$op: [$item narrative]"
        }
    }


    #-------------------------------------------------------------------
    # Debugging Commands
    

    # dump
    #
    # Dumps the undo/redo info.

    method dump {} {
        set out [list]

        if {[got $redoStack]} {
            foreach o $redoStack {
                if {[my IsTrans $o]} {
                    lappend out \
                        "redo transaction -- [lindex $o 0]"
                } else {
                    lappend out "redo $o -- [$o name] <[$o getdict]>"

                }
            }
            lappend out ""
        }

        lappend out "*** top of stack ***"

        if {[got $undoStack]} {
            lappend out ""

            foreach o [lreverse $undoStack] {
                if {[my IsTrans $o]} {
                    lappend out \
                        "undo transaction -- [lindex $o 0]"
                } else {
                    lappend out "undo $o -- [$o name] <[$o getdict]>"

                }
            }
        }

        return [join $out \n]
    }
}
