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
#    the undo/redo static.
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

    # undoStack - stack of orders to be undone.  The top is the end.
    variable undoStack

    # redoStack - stack of orders to be redone.  The top is the end.
    variable redoStack
    
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
    }
    
    #-------------------------------------------------------------------
    # Sending Orders

    # make name
    #
    # name   - An order name
    #
    # Makes an order object for the named order.  Subclasses can override
    # this to add additional context when creating the order.

    method make {name} {
        set cls [$oset class $name]
        return [$cls new]
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
    # NOTE: If the order is successful, then ownership of the order 
    # object passes to the flunky.  If not, it is retained by the caller.
    #
    # Returns the order's return value on success.

    method execute {mode order} {
        if {![$order valid]} {
            error "order [$order name] is invalid."
        }

        try {
            set execMode $mode
            set result [$order execute [self]]
        } finally {
            set execMode normal
        }

        if {$mode eq "private"} {
            # We no longer need the order.
            $order destroy
        } else {
            my UndoPush $order
            my RedoClear
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
    # if possible.  Throws REJECTED with a detailed human-readable 
    # error message if the order isn't valid.

    method send {mode name args} {
        $oset validate $name

        set order [my make $name]

        $order configure {*}$args

        if {![$order valid]} {
            # TODO: Turn errdict into human-readable message, a la
            # "send" executive command.
            try {
                throw REJECTED [$order errdict]
            } finally {
                $order destroy   
            }
        }

        return [my execute $mode $order]
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
        $oset validate $name

        set order [my make $name]

        $order setdict $parmdict

        if {![$order valid]} {
            try {
                throw REJECTED [$order errdict]
            } finally {
                $order destroy   
            }
        }

        return [my execute $mode $order]
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

        return [expr {$states eq "*" || $ostate in $states}] 
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
    }

    # canundo
    #
    # Returns 1 if there's an order on the undo stack, and 0 otherwise.

    method canundo {} {
        # TODO: Take the top order's sendstates into account?  In that
        # case, if we can't undo, clear the stack?
        return [expr {[llength $undoStack] > 0}]
    }

    # canredo
    #
    # Returns 1 if there's an order on the redo stack, and 0 otherwise.

    method canredo {} {
        # TODO: Take the top order's sendstates into account?  In that
        # case, if we can't redo, clear the stack?
        return [expr {[llength $redoStack] > 0}]
    }

    # undo
    #
    # Undo the top order on the undo stack, and move it to the 
    # redo stack.  It's an error if there's no order to redo.

    method undo {} {
        if {![my canundo]} {
            error "Can't undo"
        }

        set order [my UndoPop]

        $order undo

        my RedoPush $order
        # TODO: Do all monitoring/notifications
    }

    # redo
    #
    # Redoes the top order on the redo stack, and move it to the 
    # undo stack.  It's an error if there's no order to redo.

    method redo {} {
        if {![my canredo]} {
            error "Can't redo"
        }

        set order [my RedoPop]

        $order execute

        # We know it can undone, because it wouldn't be on the redo
        # stack otherwise.
        my UndoPush $order
        # TODO: Do all monitoring/notifications
    }

    # UndoPush order
    #
    # order - An order that was successfully executed.
    #
    # If the order can be undone, it is pushed onto the Undo Stack;
    # otherwise, the stack is cleared.

    method UndoPush {order} {
        if {[$order canundo]} {
            lappend undoStack $order
        } else {
            my UndoClear
        }
    }

    # UndoPop
    #
    # Pops the order off of the top of the undo stack, and returns it.

    method UndoPop {} {
        set order [lindex $undoStack end]
        set undoStack [lrange $undoStack 0 end-1]
        return $order
    }

    # UndoClear
    #
    # Clears the undoStack

    method UndoClear {} {
        foreach o $undoStack {
            $o destroy
        }

        set undoStack [list]
    }
    
    # RedoPush order
    #
    # order - An order that was successfully undone.
    #
    # Pushes the order onto the Redo Stack.

    method RedoPush {order} {
        lappend redoStack $order
    }

    # RedoPop
    #
    # Pops the order off of the top of the redo stack, and returns it.

    method RedoPop {} {
        set order [lindex $redoStack end]
        set redoStack [lrange $redoStack 0 end-1]
        return $order
    }

    # RedoClear
    #
    # Clears the redoStack

    method RedoClear {} {
        foreach o $redoStack {
            $o destroy
        }

        set redoStack [list]
    }

}
