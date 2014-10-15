#-----------------------------------------------------------------------
# TITLE:
#    econpopbrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    econpopbrowser(sim) package: Neighborhood browser, 
#    Population Statistics.
#
#    This widget displays a formatted list of neighborhood economic
#    data.  It is a wrapper around sqlbrowser(n).
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor econpopbrowser {
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
        { n              "ID"                                             }
        { longname       "Neighborhood"                                   }
        { population     "Population"    -sortmode integer -foreground %D }
        { subsistence    "Subsistence"   -sortmode integer -foreground %D }
        { consumers      "Consumers"     -sortmode integer -foreground %D }
        { labor_force    "Labor Force"   -sortmode integer -foreground %D }
        { jobs           "Jobs"          -sortmode integer -foreground %D }
        { unemployed     "Unemployed"    -sortmode integer -foreground %D }
        { ur             "UnempRate%"    -sortmode real    -foreground %D }
        { upc            "UnempPerCap%"  -sortmode real    -foreground %D }
        { uaf            "UAFactor"      -sortmode real    -foreground %D }
    }

    #-------------------------------------------------------------------
    # Components

    component editbtn     ;# The "Edit" button

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Install the hull
        installhull using sqlbrowser                  \
            -db           ::rdb                       \
            -view         gui_econ_n                  \
            -uid          id                          \
            -titlecolumns 1                           \
            -selectioncmd [mymethod SelectionChanged] \
            -reloadon {
                ::sim  <DbSyncB>
                ::sim  <Tick>
            } -layout [string map [list %D $::app::derivedfg] $layout]

        # NEXT, get the options.
        $self configurelist $args

        # NEXT, Respond to simulation updates
        notifier bind ::rdb <econ_n>  $self [mymethod uid]
        notifier bind ::rdb <nbhoods> $self [mymethod uid]
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull

    #-------------------------------------------------------------------
    # Private Methods

    # SelectionChanged
    #
    # Enables/disables toolbar controls based on the current selection,
    # and notifies the app of the selection change.

    method SelectionChanged {} {
        # FIRST, notify the app of the selection.
        if {[llength [$hull uid curselection]] == 1} {
            set n [lindex [$hull uid curselection] 0]

            notifier send ::app <Puck> \
                [list nbhood $n]
        }
    }
}




