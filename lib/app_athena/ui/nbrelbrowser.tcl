#-----------------------------------------------------------------------
# TITLE:
#    nbrelbrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    nbrelbrowser(sim) package: Nbhood Relationship browser.
#
#    This widget displays a formatted list of nbrel_mn records.
#    It is a wrapper around sqlbrowser(n).
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor nbrelbrowser {
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
        { m             "Of Nbhood"                    }
        { n             "With Nbhood"                  }
        { proximity     "Proximity"                    }
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
            -view         gui_nbrel_mn                \
            -uid          id                          \
            -titlecolumns 2                           \
            -selectioncmd [mymethod SelectionChanged] \
            -reloadon {
                ::sim <DbSyncB>
            } -layout [string map [list %D $::app::derivedfg] $layout]

        # NEXT, get the options.
        $self configurelist $args

        # NEXT, create the toolbar buttons
        set bar [$hull toolbar]

        install editbtn using mkeditbutton $bar.edit \
            "Edit Selected Relationship"             \
            -state   disabled                        \
            -command [mymethod EditSelected]

        cond::availableCanUpdatex control $editbtn \
            order   NBREL:UPDATE   \
            browser $win

        pack $editbtn   -side left

        # NEXT, update individual entities when they change.
        notifier bind ::rdb <nbrel_mn> $self [mymethod uid]
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull

    # canupdate
    #
    # Returns 1 if the current selection can be "updated" and 0 otherwise.
    #
    # The current selection can be updated if it is a single or multiple
    # selection and none of the selected entries has f=g.

    method canupdate {} {
        # FIRST, there must be something selected
        if {[llength [$self curselection]] > 0} {
            foreach id [$self curselection] {
                lassign $id m n

                if {$m eq $n} {
                    return 0
                }
            }

            return 1
        } else {
            return 0
        }
    }

    #-------------------------------------------------------------------
    # Private Methods

    # SelectionChanged
    #
    # Enables/disables toolbar controls based on the current selection,
    # and notifies the app of the selection change.

    method SelectionChanged {} {
        # FIRST, update buttons
        cond::availableCanUpdatex update $editbtn

        # NEXT, notify the app of the selection.
        if {[llength [$hull uid curselection]] == 1} {
            set id [lindex [$hull uid curselection] 0]
            lassign $id m n

            notifier send ::app <Puck> \
                [list mn $id  nbhood $m]
        }
    }


    # EditSelected
    #
    # Called when the user wants to edit the selected entities

    method EditSelected {} {
        set ids [$hull uid curselection]

        if {[llength $ids] == 1} {
            app enter NBREL:UPDATE id [lindex $ids 0]
        } else {
            app enter NBREL:UPDATE:MULTI ids $ids
        }
    }
}






