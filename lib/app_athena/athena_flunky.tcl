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
#    This class subclasses and adapts ::marsutil::order_flunky, providing
#    additional features for use by Athena (e.g., RDB transactions and
#    monitoring)
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Athena Order Flunky Adaptor

oo::class create athena_flunky {
    superclass ::marsutil::order_flunky

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
    # and monitoring (unless the order isn't monitored).

    method execute {mode order} {
        if {[$order monitor]} {
            rdb monitor $transMode {
                set result [next $mode $order]
            }
        } else {
            set result [next $mode $order]
        }

        return $result
    }

    # _onExecute order
    #
    # Adds the order to the CIF

    method _onExecute {order} {
        my AddToCIF $order
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


    # _onUndo order
    #
    # Removes the top order from the CIF

    method _onUndo {order} {
        set maxid [rdb onecolumn {
            SELECT max(id) FROM cif
        }]


        rdb eval {
            DELETE FROM cif
            WHERE id = $maxid
        }
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

    # _onRedo order
    #
    # Adds the order to the CIF

    method _onRedo {order} {
        my AddToCIF $order
    }

    # AddToCIF order
    #
    # Adds the order to the CIF.

    method AddToCIF {order} {
        set now [simclock now]

        set name      [$order name]
        set narrative [$order narrative]
        set parmdict  [$order getdict]

        rdb eval {
            INSERT INTO cif(time,name,narrative,parmdict)
            VALUES($now, $name, $narrative, $parmdict);
        }
    }
}


