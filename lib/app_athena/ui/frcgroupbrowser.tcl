#-----------------------------------------------------------------------
# TITLE:
#    frcgroupbrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    frcgroupbrowser(sim) package: Force Group browser.
#
#    This widget displays a formatted list of force group records.
#    It is a wrapper around sqlbrowser(n).
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor frcgroupbrowser {
    #-------------------------------------------------------------------
    # Options

    # Options delegated to the hull
    delegate option * to hull

    #-------------------------------------------------------------------
    # Look-up Tables

    # Layout
    #
    # %D is replaced with the color for derived columns.

    typevariable layout {
        { g                "\nID"                               }
        { longname         "\nLong Name"                        }
        { a                "\nOwner"                            }
        { color            "\nColor"                            }
        { forcetype        "Force\nType"                        }
        { training         "Training\nLevel"                    }
        { base_personnel   "Base\nPersonnel"                    }
        { demeanor         "\nDemeanor"                         }
        { cost             "Cost,\n$/person/week" 
                           -sortmode command 
                           -sortcommand ::marsutil::moneysort   }
        { pretty_local     "\nLocal?"                           }
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
            -view         gui_frcgroups               \
            -uid          id                          \
            -titlecolumns 1                           \
            -selectioncmd [mymethod SelectionChanged] \
            -displaycmd   [mymethod DisplayData]      \
            -reloadon {
                ::sim <DbSyncB>
            } -layout [string map [list %D $::app::derivedfg] $layout]

        # NEXT, get the options.
        $self configurelist $args

        # NEXT, create the toolbar buttons
        set bar [$hull toolbar]

        install addbtn using mkaddbutton $bar.add \
            "Add Force Group"                     \
            -state   normal                       \
            -command [mymethod AddEntity]

        cond::available control $addbtn \
            order FRCGROUP:CREATE


        install editbtn using mkeditbutton $bar.edit \
            "Edit Selected Group"                    \
            -state   disabled                        \
            -command [mymethod EditSelected]

        cond::availableMulti control $editbtn \
            order   FRCGROUP:UPDATE           \
            browser $win


        install deletebtn using mkdeletebutton $bar.delete \
            "Delete Selected Group"                        \
            -state   disabled                              \
            -command [mymethod DeleteSelected]

        cond::availableSingle control $deletebtn \
            order   FRCGROUP:DELETE              \
            browser $win

       
        pack $addbtn    -side left
        pack $editbtn   -side left
        pack $deletebtn -side right

        # NEXT, update individual entities when they change.
        notifier bind ::adb <groups>    $self [mymethod uid]
        notifier bind ::adb <frcgroups> $self [mymethod uid]
    }

    destructor {
        notifier forget $self
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull

    #-------------------------------------------------------------------
    # Private Methods

    # DisplayData rindex values
    # 
    # rindex    The row index of an updated row
    # values    The values in the row's cells.
    #
    # Colors the "color" cell.

    method DisplayData {rindex values} {
        $hull cellconfigure $rindex,3 -background [lindex $values 3]
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


    # AddEntity
    #
    # Called when the user wants to add a new entity.

    method AddEntity {} {
        # FIRST, Pop up the dialog
        app enter FRCGROUP:CREATE
    }


    # EditSelected
    #
    # Called when the user wants to edit the selected entities.

    method EditSelected {} {
        set ids [$hull uid curselection]

        if {[llength $ids] == 1} {
            set id [lindex $ids 0]

            app enter FRCGROUP:UPDATE g $id
        } else {
            app enter FRCGROUP:UPDATE:MULTI ids $ids
        }
    }


    # DeleteSelected
    #
    # Called when the user wants to delete the selected entity.

    method DeleteSelected {} {
        # FIRST, there should be only one selected.
        set id [lindex [$hull uid curselection] 0]

        # NEXT, Pop up the dialog, and select this entity
        flunky senddict gui FRCGROUP:DELETE [list g $id]
    }
}




