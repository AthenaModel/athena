#-----------------------------------------------------------------------
# TITLE:
#    hrelbrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    hrelbrowser(sim) package: Relationship browser.
#
#    This widget displays the scenario's HREL inputs and current values.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor hrelbrowser {
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
    # Reload on ::adb.parm <Update>: ???.  I'm not sure why we're doing this.

    typevariable modes -array {
        scenario {
            -view gui_hrel_view
            -views {
                gui_hrel_view          "All"
                gui_hrel_override_view "Overridden"
            }
            -layout {
                {f        "Of Group F"                  }
                {g        "With Group G"                }
                {ftype    "F Type"                      }
                {gtype    "G Type"                      }
                {base     "Baseline"     -sortmode real }
                {current  "Current"      -sortmode real }
                {nat      "Natural"      -sortmode real }
                {override "OV"           -hide 1        }
            }
            -reloadon {
                ::adb <groups>
                ::adb <Sync>
                ::adb <civgroups>
            }
        }
        simulation {
            -view gui_uram_hrel
            -views {}
            -layout {
                {f        "Of Group F"                                   }
                {g        "With Group G"                                 }
                {ftype    "F Type"                                       }
                {gtype    "G Type"                                       }
                {hrel     "Current"        -sortmode real -foreground %D }
                {base     "Baseline"       -sortmode real -foreground %D }
                {nat      "Natural"        -sortmode real -foreground %D }
                {hrel0    "Current at T0"  -sortmode real -foreground %D }
                {base0    "Baseline at T0" -sortmode real                }
                {nat0     "Natural at T0"  -sortmode real -foreground %D }
            }
            -reloadon {
                ::adb <Tick>
                ::adb <Sync>
                ::adb.parm <Update>
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
            -db           ::adb                       \
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
            "Override Baseline Horizontal Relationship" \
            -state   disabled                          \
            -command [mymethod EditSelected]

        cond::availableCanUpdate control $editbtn \
            order   HREL:OVERRIDE                 \
            browser $win

        install deletebtn using mkdeletebutton $bar.delete \
            "Restore Baseline Horizontal Relationship"      \
            -state   disabled                              \
            -command [mymethod DeleteSelected]

        cond::availableCanDelete control $deletebtn \
            order   HREL:RESTORE                    \
            browser $win

        pack $editbtn   -side left
        pack $deletebtn -side right

        # NEXT, set the mode when the simulation state changes.
        notifier bind ::adb <State> $self [mymethod StateChange]

        # NEXT, update individual entities when they change.
        $self SetMode scenario
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull

    # When hrel_fg records are deleted, treat it like an update.
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
        lassign $id f g

        set override [rdb onecolumn {
            SELECT override FROM gui_hrel_view WHERE f=$f AND g=$g
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
            notifier bind ::adb <hrel_fg> $self [mymethod uid]
            notifier bind ::mad <Hrel>    $self ""
        } else {
            notifier bind ::adb <hrel_fg> $self ""
            notifier bind ::mad <Hrel>    $self [mymethod uid]
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
            app enter HREL:OVERRIDE id [lindex $ids 0]
        } else {
            app enter HREL:OVERRIDE:MULTI ids $ids
        }
    }

    # DeleteSelected
    #
    # Called when the user wants to delete the selected entity.

    method DeleteSelected {} {
        # FIRST, there should be only one selected.
        set id [lindex [$hull uid curselection] 0]

        # NEXT, Pop up the dialog, and select this entity
        flunky senddict gui HREL:RESTORE [list id $id]
    }
}


