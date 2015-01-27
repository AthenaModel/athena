#-----------------------------------------------------------------------
# TITLE:
#    coopbrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    coopbrowser(sim) package: Cooperation browser, Scenario Mode.
#
#    This widget displays a formatted list of coop_fg records.
#    It is a wrapper around sqlbrowser(n).
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor coopbrowser {
    #-------------------------------------------------------------------
    # Options

    # Options delegated to the hull
    delegate option * to hull
 
    #-------------------------------------------------------------------
    # Lookup Tables

    # modes
    #
    # Array of configuration data for different app modes.
    #
    # scenario   - [sim state] eq PREP
    # simulation - [sim state] ne PREP 
    #
    #    -layout   - The layout spec for the sqlbrowser.  %D is replaced
    #                with the color for derived columns.
    #    -view     - The view name.
    #    -reloadon - The default reload events 
    #
    # Reload on ::rdb <civgroups> because changes to basepop will affect the
    # rows to display.
    #
    # Reload on ::parm <Update>: ???.  I'm not sure why we're doing this.

    typevariable modes -array {
        scenario {
            -view gui_coop_view
            -layout {
                { f        "Of Group"                         }
                { g        "With Group"                       }
                { base     "Baseline Level"    -sortmode real }
                { natural  "Natural Level"     -sortmode real }
            }
            -reloadon {
                ::sim <DbSyncB>
                ::rdb <civgroups>
            }
        }
        simulation {
            -view gui_uram_coop
            -layout {
                { f        "Of Group"                                     }
                { g        "With Group"                                   }
                { coop     "Current"        -sortmode real -foreground %D }
                { base     "Baseline"       -sortmode real -foreground %D }
                { nat      "Natural"                       -foreground %D }
                { coop0    "Current at T0"  -sortmode real -foreground %D }
                { base0    "Baseline at T0" -sortmode real                }
                { nat0     "Natural at T0"                 -foreground %D }
            }
            -reloadon {
                ::sim <Tick>
                ::sim <DbSyncB>
                ::parm <Update>
            }
        }
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
            -uid          id                          \
            -titlecolumns 2                           \
            -selectioncmd [mymethod SelectionChanged] \
            {*}[ModeOptions scenario]

        # NEXT, get the options.
        $self configurelist $args

        # NEXT, create the toolbar buttons
        set bar [$hull toolbar]

        install editbtn using mkeditbutton $bar.edit \
            "Edit Initial Curve"                     \
            -state   disabled                        \
            -command [mymethod EditSelected]

        cond::availableMulti control $editbtn \
            order   COOP:UPDATE           \
            browser $win

        pack $editbtn   -side left

        # NEXT, set the mode when the simulation state changes.
        notifier bind ::sim <State> $self [mymethod StateChange]

        # NEXT, update individual entities when they change.
        $self SetMode scenario
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull

    #-------------------------------------------------------------------
    # Private Methods

    # StateChange
    #
    # The simulation state has changed.  Update the display.

    method StateChange {} {
        if {[sim state] eq "PREP"} {
            $self SetMode scenario
        } else {
            $self SetMode simulation
        }
    }

    # SetMode mode
    #
    # mode - scenario | simulation
    #
    # Sets the widget to display the content for the given mode.

    method SetMode {mode} {
        $hull configure {*}[ModeOptions $mode]

        if {$mode eq "scenario"} {
            notifier bind ::rdb <coop_fg> $self [mymethod uid]
            notifier bind ::mad <Coop>    $self ""
        } else {
            notifier bind ::rdb <coop_fg> $self ""
            notifier bind ::mad <Coop>    $self [mymethod uid]
        }
    }

    # ModeOptions mode
    #
    # mode - scenario | simulation
    #
    # Returns a dictionary of the mode options and values.

    proc ModeOptions {mode} {
        set opts $modes($mode)
        dict with opts {
            set -layout [string map [list %D $::app::derivedfg] ${-layout}]
        }

        return $opts
    }


    # SelectionChanged
    #
    # Enables/disables toolbar controls based on the current selection,
    # and notifies the app of the selection change.

    method SelectionChanged {} {
        # FIRST, update buttons
        cond::availableMulti  update $editbtn
    }


    # EditSelected
    #
    # Called when the user wants to edit the selected entities

    method EditSelected {} {
        set ids [$hull uid curselection]

        if {[llength $ids] == 1} {
            app enter COOP:UPDATE id [lindex $ids 0]
        } else {
            app enter COOP:UPDATE:MULTI ids $ids
        }
    }
}




