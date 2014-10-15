#-----------------------------------------------------------------------
# TITLE:
#    securitybrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    securitybrowser(sim) package: Group Security browser.
#
#    This widget displays a formatted list of force_ng records.
#    It is a variation of browser_base(n).
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor securitybrowser {
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
        { n              "\nNbhood"                                      }
        { g              "\nGroup"                                       }
        { personnel      "\nPersonnel"  -sortmode integer -foreground %D }
        { security       "\nSecurity"   -sortmode integer -foreground %D }
        { symbol         "\nSymbol"                       -foreground %D }
        { pct_nominal_cf "\nCrim. Frac."                  -foreground %D }
        { pct_actual_cf  "Effective\nCrim. Frac."         -foreground %D }
        { pct_force      "\n%Force"     -sortmode integer -foreground %D }
        { pct_enemy      "\n%Enemy"     -sortmode integer -foreground %D }
        { volatility     "\nVolatility" -sortmode integer -foreground %D }
    }

    #-------------------------------------------------------------------
    # Components

    # None

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Install the hull
        installhull using sqlbrowser                  \
            -db           ::rdb                       \
            -view         gui_security                \
            -uid          id                          \
            -titlecolumns 2                           \
            -reloadon {
                ::sim <DbSyncB>
                ::sim <Tick>
            } -layout [string map [list %D $::app::derivedfg] $layout]

        # FIRST, get the options.
        $self configurelist $args
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull
}


