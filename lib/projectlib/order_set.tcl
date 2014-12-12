#-----------------------------------------------------------------------
# TITLE:
#    order_set.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectlib(n): Order Set Class
#
#    order_set(n) is a base class whose instances collect orderx 
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
    namespace export order_set
}

#-----------------------------------------------------------------------
# order_set class

oo::class create ::projectlib::order_set {
    #-------------------------------------------------------------------
    # Instance Variables

    # orders - dictionary, order name to order class
    variable orders
    
    #-------------------------------------------------------------------
    # Constructor/Destructor
    
    constructor {} {
        set orders [dict create]
    }

    destructor {
        my reset
    }

    #-------------------------------------------------------------------
    # Order Definition

    # define order body
    #
    # order   - The order's name, e.g., MY:ORDER
    # body    - The ordex subclass definition script.
    #
    # Defines the new order class.  The full class name is
    # ${self}::${order}.  Also, defines the "name" meta for the class,
    # and provides empty defaults for the "from" and "parmtags" metas.

    method define {order body} {
        # FIRST, get the class name.
        set cls [self]::$order

        # NEXT, create and configure the class itself.
        oo::class create $cls
        oo::define $cls meta name       $order
        oo::define $cls meta title      $order
        oo::define $cls meta sendstates ""
        oo::define $cls meta form       ""
        oo::define $cls meta parmtags   ""
        oo::define $cls $body

        # TODO: add orderx if it isn't an ancestor class, whether
        # direct or indirect.
        if {[info class superclasses $cls] == "::oo::object"} {
            oo::define $cls superclass ::projectlib::orderx
        }

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

    # reset
    #
    # Destroys all orders and clears the saved data.  Note that
    # dynaforms aren't destroyed because there's no way to do it.

    method reset {} {
        dict for {name cls} $orders {
            $cls destroy
        }

        set orders [dict create]
    }

    #-------------------------------------------------------------------
    # Queries

    # names
    #
    # Returns the list of order names.

    method names {} {
        return [dict keys $orders]
    }

    # exists order
    #
    # order     An order order
    #
    # Returns 1 if there's an order with this name, and 0 otherwise

    method exists {order} {
        return [dict exists $orders $order]
    }

    # validate order
    #
    # order  - Possibly, the name of an order.
    #
    # Throws INVALID if the order name is unknown.  Returns the 
    # canonicalized order name.

    method validate {order} {
        set order [string toupper $order]

        if {![my exists $order]} {
            throw INVALID  \
                "Order is undefined: \"$order\""
        }

        return $order
    }

    # class order
    #
    # order   - The name of an order
    #
    # Returns the full order class name for the order.

    method class {order} {
        dict get $orders $order
    }

    # title order
    #
    # order - The name of an order.
    #
    # Returns the order's title.

    method title {order} {
        [my class $order] title
    }

    # get order
    #
    # order - The name of an order
    #
    # Returns an instance of the order.

    method get {order} {
        return [[my class $order] new]
    }


}
