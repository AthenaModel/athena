#-----------------------------------------------------------------------
# TITLE:
#    wizevents.tcl
#
# AUTHOR:
#    Will Duquette
#
# PACKAGE:
#   wintel(n) -- package for athena(1) intel ingestion wizard.
#
# PROJECT:
#   Athena Regional Stability Simulation
#
# DESCRIPTION:
#    wizevents(n): A wizard manager page for listing and editing
#    simevents.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# wizevents widget


snit::widget ::wintel::wizevents {
    #-------------------------------------------------------------------
    # Lookup table

    # The HTML help for this widget.
    typevariable helptext {
        <h1>Customize Events</h1>
        
        The next task is to examine (and possibly edit) the 
        simulation events ingested from the TIGR reports.<p>

        <ul>
        <li> Click on an event to see the TIGR reports which drive
             it.<p>
        <li> Press the pencil icon to edit the selected event.<p>
        <li> Press the On/Off icon to disable or re-enable an event.
             Disabled events will not be added to the scenario.<p>
        </ul>
    }

    
    #-------------------------------------------------------------------
    # Components

    component toolbar   ;# Toolbar for the widget
    component elist     ;# databrowser(n), event list
    component editbtn   ;# Event edit button
    component togglebtn ;# Event toggle state button
    component detail    ;# htmlviewer(n) to display details.
    
    #-------------------------------------------------------------------
    # Options

    delegate option * to hull

    #-------------------------------------------------------------------
    # Variables

    # Info array: wizard data

    variable info -array {
    }

    #-------------------------------------------------------------------
    # Constructor
    #
    #   +----------------------+
    #   | toolbar              |
    #   +----------------------+
    #   | separator1           |
    #   +-----------+----------+
    #   | elist     | detail   |
    #   +-----------+----------+


    constructor {args} {
        $self configurelist $args

        $self MakeToolbar    $win.toolbar ;# toolbar
        ttk::separator       $win.sep1
        $self MakeEventList  $win.elist   ;# elist
        $self MakeDetailPane $win.detail  ;# detail

        # NEXT, grid the major components.
        grid $toolbar    -row 0 -column 0 -columnspan 2 -sticky ew
        grid $win.sep1   -row 1 -column 0 -columnspan 2 -sticky ew
        grid $elist      -row 2 -column 0 -sticky ns
        grid $win.detail -row 2 -column 1 -sticky nsew

        grid rowconfigure    $win 2 -weight 1
        grid columnconfigure $win 1 -weight 1

        # NEXT, put in initial detail.
        $detail set $helptext
    }

    # MakeToolbar w
    #
    # Creates the toolbar component with the given widget name.

    method MakeToolbar {w} {
        # FIRST, create the Widget
        install toolbar using ttk::frame $w

        # NEXT, fill in the toolbar
        ttk::label $toolbar.lab \
            -text "Candidate Events:"

        # Edit Button
        install editbtn using mkeditbutton $toolbar.edit \
            "Edit Event"                                 \
            -state   disabled                            \
            -command [mymethod EListEdit]

        # State Toggle button
        install togglebtn using mktoolbutton $toolbar.toggle \
            ::marsgui::icon::onoff                           \
            "Toggle State"                                   \
            -state   disabled                                \
            -command [mymethod EListToggle]

        pack $toolbar.lab -side left
        pack $editbtn     -side left
        pack $togglebtn   -side left

    }


    # MakeDetailPane w
    #
    # The name of the frame window.

    method MakeDetailPane {w} {
        frame $w

        install detail using htmlviewer $w.hv \
            -height         300                   \
            -width          300                   \
            -xscrollcommand [list $w.xscroll set] \
            -yscrollcommand [list $w.yscroll set]

        ttk::scrollbar $w.xscroll \
            -orient horizontal \
            -command [list $detail xview]

        ttk::scrollbar $w.yscroll \
            -orient vertical \
            -command [list $detail yview]

        grid $w.hv      -row 0 -column 0 -sticky nsew
        grid $w.yscroll -row 0 -column 1 -sticky ns
        grid $w.xscroll -row 1 -column 0 -sticky ew

        grid rowconfigure    $w 0 -weight 1
        grid columnconfigure $w 0 -weight 1
    }


    #-------------------------------------------------------------------
    # Event List Code

    # MakeEventList w 
    #
    # w   - The widget name
    #
    # Creates the event list widget.

    method MakeEventList {w} {
        install elist using databrowser $win.elist          \
            -sourcecmd    [list ::wintel::pot ids ::wintel::simevent] \
            -dictcmd      [list ::wintel::pot view]                   \
            -selectmode   browse                            \
            -height       15                                \
            -width        80                                \
            -filterbox    no                                \
            -displaycmd   [mymethod EListDisplay]           \
            -selectioncmd [mymethod EListSelection]         \
            -layout {
                { id        "Obj ID"    -sortmode integer }
                { num       "Number"    -sortmode integer }
                { state     "State"                       }
                { week      "Week"                        }
                { n         "Nbhood"                      }
                { narrative "Narrative" -stretchable yes  }
                { cidcount  "#TIGR"     -sortmode integer }
            }


        # NEXT, respond to updates.
        notifier bind ::wintel::simevent <update> $self [list $elist uid update]
    }


    # EListDisplay rindex values
    # 
    # rindex    The row index
    # values    The values in the row's cells
    #
    # Sets the state color and font

    method EListDisplay {rindex values} {
        set sIndex [$elist cname2cindex state]
        set nIndex [$elist cname2cindex narrative]

        set state [lindex $values $sIndex]

        $elist cellconfigure $rindex,$sIndex \
            -foreground [ebeanstate as color $state]

        $elist cellconfigure $rindex,$nIndex \
            -foreground [ebeanstate as color $state] \
            -font       [ebeanstate as font  $state]
    }

    # EListSelection
    #
    # Called when the elist's selection has changed.

    method EListSelection {} {
        # FIRST, enable/disable controls
        $editbtn   configure -state [$self EListEditState]
        $togglebtn configure -state [$self EListToggleState]

        # NEXT, display the detail for the selected event, if
        # if any.
        set id [lindex [$elist uid curselection] 0]

        if {$id eq ""} {
            $detail set $helptext
        } else {
            set e [::wintel::pot get $id]
            $detail set [$e htmltext]
        }
    }

    # EListEditState
    # 
    # Returns the proper state for the edit button.  We can edit
    # if exactly one event is selected, and if the event's data
    # is editable.

    method EListEditState {} {
        if {[llength [$elist uid curselection]] != 1} {
            return disabled
        }

        set id [lindex [$elist uid curselection]]
        set e [::wintel::pot get $id]

        if {[$e canedit]} {
            return normal
        } else {
            return disabled
        }
    }

    # EListToggleState
    # 
    # Returns the proper state for the toggle button.  We can toggle
    # if exactly one event is selected.

    method EListToggleState {} {
        if {[llength [$elist uid curselection]] != 1} {
            return disabled
        }

        return normal
    }
    
    # EListEdit
    #
    # Edits the state of the currently selected event.

    method EListEdit {} {
        # FIRST, there should be only one selected.
        set id [lindex [$elist uid curselection] 0]

        if {$id eq ""} {
            return
        }

        # NEXT, get the event.
        set e [::wintel::pot get $id]

        # NEXT, pop up the order.
        wizard enter SIMEVENT:[$e typename] event_id $id
    }

    # EListToggle
    #
    # Toggles the state of the currently selected event.

    method EListToggle {} {
        # FIRST, there should be only one selected.
        set id [lindex [$elist uid curselection] 0]

        if {$id eq ""} {
            return
        }

        # NEXT, get the event's state.
        set e [::wintel::pot get $id]
        set state [$e state]

        if {$state eq "disabled"} {
            $e update_ {state} [list state normal]
        } else {
            $e update_ {state} [list state disabled]
        }
    }

    #-------------------------------------------------------------------
    # Wizard Page Interface

    # enter
    #
    # This command is called when wizman selects this page for
    # display.  It should do any necessary set up (i.e., pull
    # data from the data model).

    method enter {} {
        $elist reload 
        return
    }


    # finished
    #
    # This command is called to determine whether or not the user has
    # completed all necessary tasks on this page.  It returns 1
    # if we can go on to the next page, and 0 otherwise.

    method finished {} {
        return [expr {[llength [simevent normals]] > 0}]
    }


    # leave
    #
    # This command is called when the user presses the wizman's
    # "Next" button to go on to the next page.  It should trigger
    # any processing that needs to be done as the result of the
    # choices made on this page, before the next page is entered.

    method leave {} {
        # Nothing to do be done at the moment.
        return
    }
}
