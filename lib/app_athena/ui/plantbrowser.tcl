#-----------------------------------------------------------------------
# TITLE:
#    plantbrowser.tcl
#
# AUTHORS:
#    Dave Hanks
#
# DESCRIPTION:
#
#    This browser displays the allocation of GOODS production plants among
# the actors who have them along with their initial repair level.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor plantbrowser {
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
    # scenario   - [adb state] eq PREP
    # simulation - [adb state] ne PREP 
    #
    #    -layout   - The layout spec for the sqlbrowser.  %D is replaced
    #                with the color for derived columns.
    #    -view     - The view name.
    #    -reloadon - The default reload events 
    #
    # Reload on ::adb <plants_shares>
    #

    # %D is replaced with the color for derived columns.
    
    typevariable modes -array {
        scenario {
            -view gui_plants_shares
            -layout {
                { n   "Neighborhood"                               }
                { a   "Owning Agent"                               }
                { rho "Average\nRepair Level"   -sortmode real     }
                { num "Shares of Goods\nPlants" -sortmode integer  }
            }
            -reloadon {
                ::adb <Sync>
                ::adb <plants_shares>
            }
        }
        simulation {
            -view gui_plants_na
            -layout {
                { n   "Neighborhood"                               }
                { a   "Owning Agent"                               }
                { rho "Average\nRepair Level"   -sortmode real     }
                { num "Number of Goods\nPlants" -sortmode integer  }
            }
            -reloadon {
                ::adb <Tick>
                ::adb <Sync>
            }
        }
    }

    #-------------------------------------------------------------------
    # Components

    component addbtn      ;# The "Add" button
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
            {*}[ModeOptions scenario]

        # NEXT, get the options.
        $self configurelist $args

        # NEXT, create the toolbar buttons
        set bar [$hull toolbar]

        install addbtn using mkaddbutton $bar.add \
            "Add Plant Ownership"                 \
            -state normal                         \
            -command [mymethod AddOwnership]

        cond::available control $addbtn \
            order PLANT:SHARES:CREATE
            
        install editbtn using mkeditbutton $bar.edit \
            "Edit Plant Ownership"             \
            -state   disabled                        \
            -command [mymethod EditSelected]

        # Assumes that *:UPDATE and *:UPDATE:MULTI always have the
        # the same validity.
        cond::availableMulti control $editbtn \
            order   PLANT:SHARES:UPDATE       \
            browser $win

        install deletebtn using mkdeletebutton $bar.delete \
            "Delete Plant Ownership" \
            -state disabled          \
            -command [mymethod DeleteSelected]

        cond::availableSingle control $deletebtn \
            order PLANT:SHARES:DELETE \
            browser $win

        pack $addbtn    -side left
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

    #-------------------------------------------------------------------
    # Private Methods and Procs

    # StateChange
    #
    # The simulation state has changed.  Update the display.

    method StateChange {} {
        if {[adb state] eq "PREP"} {
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
            notifier bind ::adb <plants_shares> $self [mymethod uid]
        } else {
            notifier bind ::adb <plants_shares> $self ""
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
        cond::availableSingle update $deletebtn
        cond::availableMulti  update $editbtn
    }

    # AddOwnership
    #
    # Called when the user want to specify ownership of GOODS production plants
    # for an agent

    method AddOwnership {} {
        app enter PLANT:SHARES:CREATE
    }

    # EditSelected
    #
    # Called when the user wants to edit ownership

    method EditSelected {} {
        set ids [$hull uid curselection]

        if {[llength $ids] == 1} {
            set id [lindex $ids 0]

            app enter PLANT:SHARES:UPDATE id $id
        } else {
            app enter PLANT:SHARES:UPDATE:MULTI ids $ids
        }
    }

    # DeleteSelected
    #
    # Called when the user wants to remove ownership

    method DeleteSelected {} {
        set id [lindex [$hull uid curselection] 0]

        adb order senddict gui PLANT:SHARES:DELETE [list id $id]
    }
}




