#-----------------------------------------------------------------------
# TITLE:
#    demognbrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    demognbrowser(sim) package: Nbhood Demographics browser.
#
#    This widget displays a formatted list of demog_n records.
#    It is a wrapper around sqlbrowser(n).
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor demognbrowser {
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
        { n           "Nbhood"                                       }
        { local       "Local"                                        }
        { population  "Population"  -sortmode integer -foreground %D }
        { subsistence "Subsistence" -sortmode integer -foreground %D }
        { consumers   "Consumers"   -sortmode integer -foreground %D }
        { labor_force "LaborForce"  -sortmode integer -foreground %D }
    }

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Install the hull
        installhull using sqlbrowser                  \
            -db           ::adb                       \
            -view         gui_nbhoods                 \
            -uid          id                          \
            -titlecolumns 1                           \
            -reloadon {
                ::sim <DbSyncB>
                ::demog <Update>
                ::adb <nbhoods>
            } -layout [string map [list %D $::app::derivedfg] $layout]

        # NEXT, get the options.
        $self configurelist $args
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull
}


