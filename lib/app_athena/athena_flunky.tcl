#-----------------------------------------------------------------------
# TITLE:
#    athena_flunky.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_athena(n): Athena Order Flunky Adaptor
#
#    This class subclasses and adapts ::projectlib::order_flunky, providing
#    additional features for use by Athena (e.g., RDB transactions and
#    monitoring)
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Athena Order Flunky Adaptor

oo::class create athena_flunky {
    superclass ::projectlib::order_flunky

    #-------------------------------------------------------------------
    # Instance Variables

    # transMode - if "transaction", orders are executed within an RDB 
    # transaction; if "script", they are not.  The default is 
    # "transaction".

    variable transMode

    #-------------------------------------------------------------------
    # Constructor

    constructor {} {
        next ::myorders
        set transMode transaction
    }
    
    
    #-------------------------------------------------------------------
    # Configuration
    #
    # TBD: Consider mixin options modules.

    # transactions ?flag?
    #
    # flag - on, off, or any boolean
    #
    # Returns the transactions flag.  If a flag is given, assigns it.

    method transactions {{flag ""}} {
        if {$flag ne ""} {
            set transMode [expr {$flag ? "transaction" : "script"}]
        }

        return [expr {$transMode eq "transaction"}]
    }
    

    #-------------------------------------------------------------------
    # order_flunky(n) tweaks

    # make name args
    #
    # Ensures that the order is created with the RDB name.

    method make {name args} {
        next $name ::rdb {*}$args
    }

    # execute mode order
    #
    # Wraps the order_flunky "execute" method.  Adds RDB transactions
    # and monitoring.


    method execute {mode order} {
        rdb monitor $transMode {
            set result [next $mode $order]
        }

        return $result
    }

    # undo
    #
    # Wraps the order_flunky "undo" method.  Adds RDB transactions
    # and monitoring.

    method undo {} {
        rdb monitor $transMode {
            next
        }

        return
    }

    # redo
    #
    # Wraps the order_flunky "redo" method.  Adds RDB transactions
    # and monitoring.

    method redo {} {
        rdb monitor $transMode {
            next
        }

        return
    }
    
}


