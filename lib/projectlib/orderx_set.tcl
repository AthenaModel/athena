#-----------------------------------------------------------------------
# TITLE:
#    orderx_set.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectlib(n): Order Set Class
#
#    orderx_set(n) is a base class whose instances collect orderx 
#    order classes into sets for introspection purposes.  The collection
#    provides the following services:
#
#    * A "define" command for defining order classes in the set.
#    * Queries to get the names of the defined orders.
#    * Queries to get an order class given the order name.
#    * A factor to get an order instance for a given class.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export orderx_set
}

#-----------------------------------------------------------------------
# orderx class

# TBD: Use TclOO for now; might use snit::type later.
oo::class create ::projectlib::orderx_set {
    #-------------------------------------------------------------------
    # Instance Variables

    # orders - dictionary, order name to order class
    variable orders
    
    #-------------------------------------------------------------------
    # Constructor/Destructor
    
    constructor {} {
        set orders [dict create]
    }

    #-------------------------------------------------------------------
    # Order Definition

    # define order body
    #
    # order   - The order's name, e.g., MY:ORDER
    # body    - The ordex subclass definition script.
    #
    # Defines the new order class.  The full class name is
    # ${self}::${order}.  Also, defines the "name" meta for the class.

    method define {order body} {
        # FIRST, get the class name.
        set cls [self]::$order

        # NEXT, create and configure the class itself.
        oo::class create $cls
        oo::define $cls meta name $order
        oo::define $cls $body

        # NEXT, create the form.
        #
        # TODO: This is very preliminary.  We may want to doctor the
        # form in some way; and for mismatch testing, some orders might
        # have context fields that are distinct from the actual parms.
        if {[$cls form] ne ""} {
            # FIRST, define the form.
            dynaform define $cls [$cls form]

            # NEXT, Check for mismatch errors.
            set fields [lsort [dynaform fields $cls]]
            set parms  [lsort [dict keys [$cls defaults]]]
            if {$fields ne $parms} {
                throw {ORDERX_SET MISMATCH} [outdent "
                Order $order has a mismatch between its parameter list
                and its dynaform.
                "]
            }
        }

        # NEXT, remember that we've successfully defined this order.
        dict set orders $order $cls
    }

    #-------------------------------------------------------------------
    # Queries

    # names
    #
    # Returns the list of order names.

    method names {} {
        return [dict keys $orders]
    }

    # class order
    #
    # order   - The name of an order
    #
    # Returns the full order class name for the order.

    method class {order} {
        dict get $orders $order
    }

    # get order
    #
    # order - The name of an order
    #
    # Returns an instance of the order.

    method get {order} {
        return [[dict get $orders $order] new]
    }
    
}
