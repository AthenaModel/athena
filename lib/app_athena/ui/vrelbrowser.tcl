#-----------------------------------------------------------------------
# TITLE:
#    vrelbrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    vrelbrowser(sim) package: Vertical Relationship browser, Scenario
#    Mode.
#
#    This widget displays a formatted list of gui_vrel_view
#    or gui_uram_vrel records..
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor vrelbrowser {
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
    }

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
    # Reload on ::parm <Update>: ???.  I'm not sure why we're doing this.

    typevariable modes -array {
        scenario {
            -view gui_vrel_view
            -views {
                gui_vrel_view          "All"
                gui_vrel_override_view "Overridden"
            }
            -layout {
                {g        "Of Group G"                  }
                {a        "With Actor A"                }
                {gtype    "G Type"                      }
                {base     "Baseline"     -sortmode real }
                {current  "Current"      -sortmode real }
                {nat      "Natural"      -sortmode real }
                {override "OV"           -hide 1        }
            }
            -reloadon {
                ::rdb <actors>
                ::rdb <civgroups>
                ::rdb <groups>
                ::sim <DbSyncB>
            }
        }
        simulation {
            -view gui_uram_vrel
            -views {}
            -layout {
                {g        "Of Group G"                                   }
                {a        "With Actor A"                                 }
                {gtype    "G Type"                                       }
                {vrel     "Current"        -sortmode real -foreground %D }
                {base     "Baseline"       -sortmode real -foreground %D }
                {nat      "Natural"        -sortmode real -foreground %D }
                {vrel0    "Current at T0"  -sortmode real -foreground %D }
                {base0    "Baseline at T0" -sortmode real                }
                {nat0     "Natural at T0"  -sortmode real -foreground %D }
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
    component deletebtn   ;# The "Delete" button

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Install the hull
        installhull using sqlbrowser                  \
            -db           ::rdb                       \
            -uid          id                          \
            -titlecolumns 2                           \
            -selectioncmd [mymethod SelectionChanged] \
            -displaycmd   [mymethod DisplayData]      \
            {*}[ModeOptions scenario]


        # NEXT, get the options.
        $self configurelist $args

        # NEXT, create the toolbar buttons
        set bar [$hull toolbar]

        install editbtn using mkeditbutton $bar.edit   \
            "Override Initial Horizontal Relationship" \
            -state   disabled                          \
            -command [mymethod EditSelected]

        cond::availableCanUpdate control $editbtn \
            order   VREL:OVERRIDE                 \
            browser $win

        install deletebtn using mkdeletebutton $bar.delete \
            "Restore Initial Horizontal Relationship"      \
            -state   disabled                              \
            -command [mymethod DeleteSelected]

        cond::availableCanDelete control $deletebtn \
            order   VREL:RESTORE                    \
            browser $win

        pack $editbtn   -side left
        pack $deletebtn -side right

        # NEXT, set the mode when the simulation state changes.
        notifier bind ::sim <State> $self [mymethod StateChange]

        # NEXT, update individual entities when they change.
        $self SetMode scenario
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull

    # When vrel_ga records are deleted, treat it like an update.
    delegate method {uid *}      to hull using {%c uid %m}
    delegate method {uid delete} to hull using {%c uid update}


    # canupdate
    #
    # Returns 1 if the current selection can be "updated" and 0 otherwise.
    #
    # The current selection can be updated if it is a single or multiple
    # selection.

    method canupdate {} {
        if {[sim state] ne "PREP"} {
            return 0
        }

        # FIRST, there must be something selected
        if {[llength [$self uid curselection]] > 0} {
            return 1
        } else {
            return 0
        }
    }

    # candelete
    #
    # Returns 1 if the current selection can be "deleted" and 0 otherwise.
    #
    # The current selection can be deleted if it is a single
    # selection and it is overridden.

    method candelete {} {
        if {[sim state] ne "PREP"} {
            return 0
        }

        # FIRST, there must be one thing selected
        if {[llength [$self uid curselection]] != 1} {
            return 0
        }

        # NEXT, is it an override?
        set id [lindex [$self uid curselection] 0]
        lassign $id g a

        set override [rdb onecolumn {
            SELECT override FROM gui_vrel_view WHERE g=$g AND a=$a
        }]

        if {$override ne "" && $override} {
            return 1
        } else {
            return 0
        }
    }

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
            notifier bind ::rdb <vrel_ga> $self [mymethod uid]
            notifier bind ::mad <Vrel>    $self ""
        } else {
            notifier bind ::rdb <vrel_ga> $self ""
            notifier bind ::mad <Vrel>    $self [mymethod uid]
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

    # DisplayData rindex values
    # 
    # rindex    The row index
    # values    The values in the row's cells
    #
    # Sets the cell foreground color for the color cells.

    method DisplayData {rindex values} {
        if {[sim state] eq "PREP"} {
            set override [lindex $values end-1]

            if {$override} {
                $hull rowconfigure $rindex -foreground "#BB0000"
            } else {
                $hull rowconfigure $rindex -foreground $::app::derivedfg
            }
        }
    }


    # SelectionChanged
    #
    # Enables/disables toolbar controls based on the current selection,
    # and notifies the app of the selection change.

    method SelectionChanged {} {
        # FIRST, update buttons
        cond::availableCanUpdate update $editbtn
        cond::availableCanDelete update $deletebtn
    }

    # EditSelected
    #
    # Called when the user wants to edit the selected entities.

    method EditSelected {} {
        set ids [$hull uid curselection]

        if {[llength $ids] == 1} {
            order enter VREL:OVERRIDE id [lindex $ids 0]
        } else {
            order enter VREL:OVERRIDE:MULTI ids $ids
        }
    }

    # DeleteSelected
    #
    # Called when the user wants to delete the selected entity.

    method DeleteSelected {} {
        # FIRST, there should be only one selected.
        set id [lindex [$hull uid curselection] 0]

        # NEXT, Pop up the dialog, and select this entity
        order send gui VREL:RESTORE id $id
    }
}


