#-----------------------------------------------------------------------
# TITLE:
#    activitybrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    activitybrowser(sim) package: Unit Activity browser.
#
#    This widget displays a formatted list of activity_nga records.
#    It is a wrapper around sqlbrowser(n).
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor activitybrowser {
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
        {n              "\nNeighborhood"      }
        {g              "\nGroup"             }
        {a              "\nActivity"          }
        {coverage       "\nCoverage"           
            -sortmode real -foreground %D }
        {security_flag  "Security\nFlag"
            -foreground %D }
        {nominal        "Nominal\nPersonnel"   
            -sortmode integer -foreground %D }
        {effective      "Effective\nPersonnel" 
            -sortmode integer -foreground %D }
    }

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Install the hull
        installhull using sqlbrowser              \
            -db                 ::adb             \
            -view               gui_activity_nga  \
            -uid                id                \
            -titlecolumns       3                 \
            -reloadon {
                ::sim <Tick>
                ::sim <DbSyncB>
            } -layout [string map [list %D $::app::derivedfg] $layout]


        # NEXT, get the options.
        $self configurelist $args
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull
}

