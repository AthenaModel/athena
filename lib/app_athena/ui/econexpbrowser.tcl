#-----------------------------------------------------------------------
# TITLE:
#    econexpbrowser.tcl
#
# AUTHORS:
#    Dave Hanks
#
# DESCRIPTION:
#    econexpbrowser(sim) package: Actor by actor expenditure browser.
#
#    This widget displays a formatted list of actor expenditure data
#    by economic sector.  It is a wrapper around sqlbrowser(n).
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor econexpbrowser {
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
        { a             "Actor"                                          }
        { tot_exp       "Total"        -sortcommand ::marsutil::moneysort
                                       -foreground %D                    }
        { exp_goods     "Goods"        -sortcommand ::marsutil::moneysort
                                       -foreground %D                    }
        { exp_black     "Black Market" -sortcommand ::marsutil::moneysort
                                       -foreground %D                    }
        { exp_pop       "Population"   -sortcommand ::marsutil::moneysort
                                       -foreground %D                    }
        { exp_actor     "Actors"       -sortcommand ::marsutil::moneysort
                                       -foreground %D                    }
        { exp_region    "Region"       -sortcommand ::marsutil::moneysort
                                       -foreground %D                    }
        { exp_world     "World"        -sortcommand ::marsutil::moneysort
                                       -foreground %D                    }
    }

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Install the hull
        installhull using sqlbrowser                  \
            -db           ::adb                       \
            -view         gui_econ_exp_now_a          \
            -uid          id                          \
            -titlecolumns 1                           \
            -reloadon {
                ::sim  <DbSyncB>
                ::sim  <Tick>
            } -layout [string map [list %D $::app::derivedfg] $layout] \
            -views {
                gui_econ_exp_now_a  "This Week"
                gui_econ_exp_tot_a  "To Date"
                gui_econ_exp_year_a "Annualized"
            }

        # NEXT, get the options.
        $self configurelist $args

        # NEXT, add a label to the toolbar
        set bar [$hull toolbar]

        set lbl [ttk::label $bar.lbl -text "Actor Expenditures by Sector"]

        pack $lbl -side left
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull
}




