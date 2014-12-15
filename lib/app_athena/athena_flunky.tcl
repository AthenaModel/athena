#-----------------------------------------------------------------------
# TITLE:
#    athena_flunky.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_flunky(n) Order handling object
#
#    This module is responsible for handling all Athena orders; it takes
#    care of all required tracing and notifications.
#
#-----------------------------------------------------------------------

oo::class create athena_flunky {
    superclass ::projectlib::order_flunky

    #-------------------------------------------------------------------
    # Constructor

    # constructor orderSet_
    #
    # orderSet_   - The set of orders handled by this flunky, an
    #               order_set(n) object.
    #
    # Creates the flunky.

    constructor {orderSet_} {
        next $orderSet_
    }
    
    #-------------------------------------------------------------------
    # Sending orders


}