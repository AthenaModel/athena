#-----------------------------------------------------------------------
# TITLE:
#    econngbrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    econngbrowser(sim) package: Nbhood Group economics
#    browser.
#
#    This widget displays a formatted list of demog_g records,
#    focussing on the labor statistics. It is a wrapper around sqlbrowser(n).
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor econngbrowser {
    #-------------------------------------------------------------------
    # Options

    # Options delegated to the hull
    delegate option * to hull

    #-------------------------------------------------------------------
    # Lookup Tables

    # Layout
    #
    # %D is replaced with the color for derived columns.

    typevariable modes -array {
        econ_enabled {
            -layout {
                { g           "Civ\nGroup"                                     }
                { longname    "Long\nName"                                     }
                { n           "\nNbhood"                                       }
                { population  "\nPop."        -sortmode integer -foreground %D }
                { subsistence "\nSubsist."    -sortmode integer -foreground %D }
                { consumers   "\nConsumers"   -sortmode integer -foreground %D }
                { labor_force "Labor\nForce"  -sortmode integer -foreground %D }
                { unemployed  "\nUnemployed"  -sortmode integer -foreground %D }
                { ur          "Unemp.\nRate%" -sortmode real    -foreground %D }
                { aloc        "Actual\nLOC"   -sortmode real    -foreground %D }
                { eloc        "Expected\nLOC" -sortmode real    -foreground %D }
                { rloc        "Required\nLOC" -sortmode real    -foreground %D }
                { povpct      "\nPoverty%"    -sortmode real    -foreground %D }
            }
            -reloadon {
                ::sim <DbSyncB>
                ::demog <Update>
                ::rdb <nbhoods>
                ::rdb <groups>
                ::rdb <civgroups>
            }
        }
        econ_disabled {
            -layout {
                { g           "Civ\nGroup"                                     }
                { longname    "Long\nName"                                     }
                { n           "\nNbhood"                                       }
                { population  "\nPop."        -sortmode integer -foreground %D }
                { subsistence "\nSubsist."    -sortmode integer -foreground %D }
                { consumers   "\nConsumers"   -sortmode integer -foreground %D }
                { labor_force "Labor\nForce"  -sortmode integer -foreground %D }
                { unemployed  "\nUnemployed"  -sortmode integer -foreground %D }
                { ur          "Unemp.\nRate%" -sortmode real    -foreground %D }
            }
            -reloadon {
                ::sim <DbSyncB>
                ::demog <Update>
                ::rdb <nbhoods>
                ::rdb <groups>
                ::rdb <civgroups>
            }
        }
    }

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Install the hull
        installhull using sqlbrowser                  \
            -db           ::rdb                       \
            -view         gui_econ_g                  \
            -uid          id                          \
            -titlecolumns 1                           \
            {*}[ModeOptions econ_disabled]

        notifier bind ::econ <State> $self [mymethod EconChange]
        notifier bind ::sim  <State> $self [mymethod SimChange]

        # NEXT, get the options.
        $self configurelist $args
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull

    # EconChange
    #
    # Responds to a change in the econ model while the simulation is
    # running.  It's possible that the econ model will disable itself
    # if it runs into problems.

    method EconChange {} {
        if {[econ state] eq "DISABLED"} {
            $self SetMode econ_disabled
        } else {
            $self SetMode econ_enabled
        }
    }

    # SimChange
    #
    # This method makes sure the correct layout is used when the scenario
    # is locked.

    method SimChange {} {
        if {[econ state] eq "DISABLED"} {
            $self SetMode econ_disabled
        } else {
            $self SetMode econ_enabled
        }
    }

    # SetMode mode
    #
    # mode - econ_disabled | econ_enabled
    #
    # Sets the widget to display the content for the given mode.

    method SetMode {mode} {
        $hull configure {*}[ModeOptions $mode]
    }

    # ModeOptions mode
    #
    # mode - econ_disabled | econ_enabled
    #
    # Returns a dictionary of the mode options and values.

    proc ModeOptions {mode} {
        set opts $modes($mode)
        dict with opts {
            set -layout [string map [list %D $::app::derivedfg] ${-layout}]
        }

        return $opts
    }
}


