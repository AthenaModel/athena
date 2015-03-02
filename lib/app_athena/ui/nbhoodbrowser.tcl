#-----------------------------------------------------------------------
# TITLE:
#    nbhoodbrowser.tcl
#
# AUTHORS:
#    Dave Hanks,
#    Will Duquette
#
# DESCRIPTION:
#    nbhoodbrowser(sim) package: Neighborhood browser.
#
#    This widget displays a formatted list of neighborhood records.
#    It is a wrapper around sqlbrowser(n).
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor nbhoodbrowser {

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
        { n              "ID"                                            }
        { longname       "Neighborhood"                                  }
        { local          "Local?"                                        }
        { urbanization   "Urbanization"                                  }
        { controller     "Controller"                     -foreground %D }
        { pcf            "Prod. Cap. Factor" -sortmode real              }
        { stacking_order "StkOrd"            -sortmode integer \
                                                          -foreground %D } 
        { obscured_by    "ObscuredBy"                     -foreground %D }
        { refpoint       "RefPoint"          -stretchable yes            }
    }

    #-------------------------------------------------------------------
    # Components

    component editbtn     ;# The "Edit" button
    component raisebtn    ;# The "Bring to Front" button
    component lowerbtn    ;# The "Send to Back" button
    component deletebtn   ;# The "Delete" button

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Install the hull
        installhull using sqlbrowser                  \
            -db           ::adb                       \
            -view         gui_nbhoods                 \
            -uid          id                          \
            -titlecolumns 1                           \
            -selectioncmd [mymethod SelectionChanged] \
            -reloadon {
                ::adb       <Sync>
                ::adb       <Tick>
                ::adb.demog <Update>
            } -layout [string map [list %D $::app::derivedfg] $layout]

        # NEXT, get the options.
        $self configurelist $args

        # NEXT, create the toolbar buttons
        set bar [$hull toolbar]

        install editbtn using mkeditbutton $bar.edit \
            "Edit Selected Neighborhood"             \
            -state   disabled                        \
            -command [mymethod EditSelected]

        # Assumes that *:UPDATE and *:UPDATE:MULTI always have the
        # the same validity.
        cond::availableMulti control $editbtn \
            order   NBHOOD:UPDATE                \
            browser $win


        install raisebtn using mktoolbutton $bar.raise \
            ::marsgui::icon::totop                  \
            "Bring Neighborhood to Front"              \
            -state   disabled                          \
            -command [mymethod RaiseSelected]

        cond::availableSingle control $raisebtn \
            order   NBHOOD:RAISE                   \
            browser $win


        install lowerbtn using mktoolbutton $bar.lower \
            ::marsgui::icon::tobottom               \
            "Send Neighborhood to Back"                \
            -state   disabled                          \
            -command [mymethod LowerSelected]

        cond::availableSingle control $lowerbtn \
            order   NBHOOD:LOWER                   \
            browser $win


        install deletebtn using mkdeletebutton $bar.delete \
            "Delete Selected Neighborhood"                 \
            -state   disabled                              \
            -command [mymethod DeleteSelected]

        cond::availableSingle control $deletebtn \
            order   NBHOOD:DELETE                   \
            browser $win

        pack $editbtn   -side left
        pack $raisebtn  -side left
        pack $lowerbtn  -side left
        pack $deletebtn -side right

        # NEXT, Respond to simulation updates
        notifier bind ::adb <nbhoods> $self [mymethod uid]
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull

    #-------------------------------------------------------------------
    # Private Methods

    # SelectionChanged
    #
    # Enables/disables toolbar controls based on the current selection,
    # and notifies the app of the selection change.

    method SelectionChanged {} {
        # FIRST, update buttons
        cond::availableSingle update [list $deletebtn $lowerbtn $raisebtn]
        cond::availableMulti  update $editbtn

        # NEXT, notify the app of the selection.
        if {[llength [$hull uid curselection]] == 1} {
            set n [lindex [$hull uid curselection] 0]

            notifier send ::app <Puck> \
                [list nbhood $n]
        }
    }


    # EditSelected
    #
    # Called when the user wants to edit the selected entity

    method EditSelected {} {
        set ids [$hull uid curselection]

        if {[llength $ids] == 1} {
            set id [lindex $ids 0]

            app enter NBHOOD:UPDATE n $id
        } else {
            app enter NBHOOD:UPDATE:MULTI ids $ids
        }
    }


    # RaiseSelected
    #
    # Called when the user wants to raise the selected neighborhood.

    method RaiseSelected {} {
        # FIRST, there should be only one selected.
        set id [lindex [$hull uid curselection] 0]

        # NEXT, bring it to the front.
        adb order senddict gui NBHOOD:RAISE [list n $id]
    }


    # LowerSelected
    #
    # Called when the user wants to lower the selected neighborhood.

    method LowerSelected {} {
        # FIRST, there should be only one selected.
        set id [lindex [$hull uid curselection] 0]

        # NEXT, bring it to the front.
        adb order senddict gui NBHOOD:LOWER [list n $id]
    }


    # DeleteSelected
    #
    # Called when the user wants to delete the selected entity.

    method DeleteSelected {} {
        # FIRST, there should be only one selected.
        set id [lindex [$hull uid curselection] 0]

        # NEXT, Send the order.
        adb order senddict gui NBHOOD:DELETE [list n $id]
    }
}




