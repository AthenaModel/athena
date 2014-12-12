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

    # undoStack - stack of orders to be undone.  The top is the end.
    variable undoStack

    # redoStack - stack of orders to be redone.  The top is the end.
    variable redoStack
    
    #-------------------------------------------------------------------
    # Constructor

    # constructor _orderSet
    #
    # _orderSet - The name of the order_set(n) component.
    #
    # TODO: Possibly, we will want an option-based interface.

    constructor {_orderSet} {
        # FIRST, initialize the instance variables
        set oset      $orderSet
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

    # execute order
    #
    # order - An orderx(n) object
    #
    # Validates the order and executes it, adding to the undo stack 
    # (or clearing the undostack if it cannot be undone.)  Throws
    # an error if the order is invalid (i.e., the caller should
    # have already ensured that the order is valid).
    #
    # If the order is successful, then ownership of the order object
    # passes to the flunky.  If not, it is retained by the caller.
    #
    # Returns the order's return value on success.
    #
    # TODO: Need to specify interface
    # TODO: Do all monitoring/notifications!

    method execute {order} {
        if {![$order valid]} {
            error "order [$order name] is invalid."
        }

        set result [$order execute]

        my UndoPush $order
        my RedoClear

        return $result
    }

    # send name options...
    #
    # name      - The order name, as defined in the oset.
    # options   - The order's parameters, in option syntax.
    #
    # Creates an order object, sets its parameters, and executes it
    # if possible.  Throws REJECTED with a detailed human-readable 
    # error message if the order isn't valid.
    #
    # TODO: Need to specify interface

    method send {name args} {
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

        return [my execute $order]
    }


    # senddict name parmdict
    #
    # name      - The order name, as defined in the oset.
    # options   - The order's parameters, as a dictionary.
    #
    # Creates an order object, sets its parameters, and executes it
    # if possible.  Throws REJECTED with an error dictionary 
    # if the order isn't valid.
    #
    # TODO: Need to specify interface

    method senddict {name args} {
        $oset validate $name

        set order [my make $name]

        $order configure {*}$args

        if {![$order valid]} {
            try {
                throw REJECTED [$order errdict]
            } finally {
                $order destroy   
            }
        }

        return [my execute $order]
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
        return [expr {[llength $undoStack] > 1}]
    }

    # canredo
    #
    # Returns 1 if there's an order on the redo stack, and 0 otherwise.

    method canredo {} {
        # TODO: Take the top order's sendstates into account?  In that
        # case, if we can't redo, clear the stack?
        return [expr {[llength $redoStack] > 1}]
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
