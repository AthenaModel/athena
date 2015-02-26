#-----------------------------------------------------------------------
# TITLE:
#    civgroupbrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    civgroupbrowser(sim) package: Civilian Group browser.
#
#    This widget displays a formatted list of civilian group records.
#    It is a variation of browser_base(n).
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor civgroupbrowser {
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
        { g              "\nID"                                           }
        { longname       "\nLong Name"                                    }
        { n              "\nNbhood"                                       }
        { bsysname       "\nBelief System"                                }
        { color          "\nColor"                                        }
        { demeanor       "\nDemeanor"                                     }
        { basepop        "Base\nPopulation"             -sortmode integer }
        { pop_cr         "Pop. Change Rate\n% per year" -sortmode real    }
        { pretty_sa_flag "Subsistence\nAgriculture"                       }
        { lfp            "\nLabor Force%"               -sortmode integer }
        { housing        "\nHousing"                                      }
        { upc            "Unemployment\nPer Capita%"    -sortmode real    }
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
            -view         gui_civgroups               \
            -uid          id                          \
            -titlecolumns 1                           \
            -selectioncmd [mymethod SelectionChanged] \
            -displaycmd   [mymethod DisplayData]      \
            -reloadon {
                ::adb <Sync>
                ::adb <Tick>
                ::adb.demog <Update>
            } -layout [string map [list %D $::app::derivedfg] $layout]

        # NEXT, get the options.
        $self configurelist $args

        # NEXT, create the toolbar buttons
        set bar [$hull toolbar]

        install addbtn using mkaddbutton $bar.add "Add Civilian Group" \
            -command [mymethod AddEntity]

        cond::available control $addbtn \
            order CIVGROUP:CREATE


        install editbtn using mkeditbutton $bar.edit "Edit Selected Group" \
            -state   disabled                                              \
            -command [mymethod EditSelected]

        cond::availableSingle control $editbtn \
            order   CIVGROUP:UPDATE           \
            browser $win


        install deletebtn using mkdeletebutton $bar.delete \
            "Delete Selected Group"                        \
            -state   disabled                              \
            -command [mymethod DeleteSelected]

        cond::availableSingle control $deletebtn \
            order   CIVGROUP:DELETE           \
            browser $win

        pack $addbtn    -side left
        pack $editbtn   -side left
        pack $deletebtn -side right

        # NEXT, update individual entities when they change.
       notifier bind ::adb <groups>    $self [mymethod uid]
       notifier bind ::adb <civgroups> $self [mymethod uid]
    }

    destructor {
        notifier forget $self
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull

    #-------------------------------------------------------------------
    # Private Methods

    # DisplayData r values
    # 
    # r       - The row index
    # values  - The values in the row's cells
    #
    # Sets the cell background color for the color cells.

    method DisplayData {r values} {
        set c [$hull cname2cindex color]
        $hull cellconfigure $r,$c -background [lindex $values $c]
    }


    # SelectionChanged
    #
    # Enables/disables toolbar controls based on the current selection,
    # and notifies the app of the selection change.

    method SelectionChanged {} {
        # FIRST, update buttons
        cond::availableSingle update $deletebtn
        cond::availableSingle update $editbtn
    }


    # AddEntity
    #
    # Called when the user wants to add a new entity.

    method AddEntity {} {
        # FIRST, Pop up the dialog
        app enter CIVGROUP:CREATE
    }


    # EditSelected
    #
    # Called when the user wants to edit the selected entity(s).

    method EditSelected {} {
        # FIRST, there should be only one selected.
        set id [lindex [$hull uid curselection] 0]

        app enter CIVGROUP:UPDATE g $id
    }

    # DeleteSelected
    #
    # Called when the user wants to delete the selected entity.

    method DeleteSelected {} {
        # FIRST, there should be only one selected.
        set id [lindex [$hull uid curselection] 0]

        # NEXT, Pop up the dialog, and select this entity
        flunky senddict gui CIVGROUP:DELETE [list g $id]
    }
}




