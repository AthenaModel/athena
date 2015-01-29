#-----------------------------------------------------------------------
# TITLE:
#    ordersentbrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    ordersentbrowser(sim) package: Order History browser.
#
#    This widget displays a formatted list of the orders that have
#    already been executed.
#
#    It is a wrapper around sqlbrowser(n).
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor ordersentbrowser {
    #-------------------------------------------------------------------
    # Options

    # Options delegated to the hull
    delegate option * to hull

    #-------------------------------------------------------------------
    # Lookup Tables

    # Layout
    #
    # %D is replaced with the color for derived columns.

    typevariable layout {
        { id        "ID"         -sortmode integer   }
        { tick      "Week"       -sortmode integer   }
        { week      "Date"                           }
        { narrative "Narrative"  -width 50 -wrap yes }
        { name      "Order"                          }
        { parmdict  "Parameters" -width 70 -wrap yes }
    }

    #-------------------------------------------------------------------
    # Components

    component cancelbtn   ;# The "Cancel" button

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Install the hull
        installhull using sqlbrowser                  \
            -db           ::rdb                       \
            -view         gui_cif                     \
            -uid          id                          \
            -titlecolumns 3                           \
            -reloadon {
                ::sim    <DbSyncB>
                ::sim    <Tick>
                ::flunky <Sync>
            } -layout [string map [list %D $::app::derivedfg] $layout]

        # NEXT, get the options.
        $self configurelist $args
    }

    destructor {
        notifier forget $self
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull
}



