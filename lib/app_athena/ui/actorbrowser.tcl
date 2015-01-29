#-----------------------------------------------------------------------
# TITLE:
#    actorbrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    actorbrowser(sim) package: Actor browser.
#
#    This widget displays a formatted list of actor records.
#    It is a variation of browser_base(n).
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor actorbrowser {
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
        { a                "\nID"                                      }
        { longname         "\nLong Name"                               }
        { bsysname         "\nBelief System"                           }
        { supports         "\nSupports"                                }
        { atype            "Funding\nType"                             }
        { pretty_am_flag   "Auto-maintain\nInfrastructure?"            }
        { cash_reserve     "Cash Reserve\n$"
                           -sortmode command 
                           -sortcommand ::marsutil::moneysort          }
        { cash_on_hand     "Cash on Hand\n$"
                           -sortmode command 
                           -sortcommand ::marsutil::moneysort          }
        { budget           "Budget\n$/Week"
                           -sortmode command 
                           -sortcommand ::marsutil::moneysort          }
        { income_goods     "Income, GOODS\n$/Week"
                           -sortmode command 
                           -sortcommand ::marsutil::moneysort          }
        { shares_black_nr  "Income, BLACK NR\nShares" -sortmode integer}
        { income_black_tax "Income, BLACK Tax\n$/Week"
                           -sortmode command 
                           -sortcommand ::marsutil::moneysort          }
        { income_pop       "Income, POP\n$/Week"
                           -sortmode command 
                           -sortcommand ::marsutil::moneysort          }
        { income_graft     "Income, Graft\n$/Week"
                           -sortmode command 
                           -sortcommand ::marsutil::moneysort          }
        { income_world     "Income, WORLD\n$/Week"
                           -sortmode command 
                           -sortcommand ::marsutil::moneysort          }
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
            -db           ::rdb                       \
            -view         gui_actors                  \
            -uid          id                          \
            -titlecolumns 1                           \
            -selectioncmd [mymethod SelectionChanged] \
            -reloadon {
                ::sim <DbSyncB>
                ::sim <Tick>
            } -layout [string map [list %D $::app::derivedfg] $layout]

        # NEXT, get the options.
        $self configurelist $args

        # NEXT, create the toolbar buttons
        set bar [$hull toolbar]

        install addbtn using mkaddbutton $bar.add "Add Actor" \
            -command [mymethod AddEntity]

        cond::available control $addbtn \
            order ACTOR:CREATE


        install editbtn using mkeditbutton $bar.edit "Edit Actor" \
            -state   disabled                                     \
            -command [mymethod EditSelected]

        cond::availableSingle control $editbtn   \
            order   ACTOR:UPDATE                    \
            browser $win


        install deletebtn using mkdeletebutton $bar.delete \
            "Delete Actor"                                 \
            -state   disabled                              \
            -command [mymethod DeleteSelected]

        cond::availableSingle control $deletebtn \
            order   ACTOR:DELETE           \
            browser $win

        pack $addbtn    -side left
        pack $editbtn   -side left
        pack $deletebtn -side right

        # NEXT, update individual entities when they change.
       notifier bind ::rdb <actors> $self [mymethod uid]
    }

    destructor {
        notifier forget $self
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
        cond::availableSingle update [list $editbtn $deletebtn]
    }


    # AddEntity
    #
    # Called when the user wants to add a new entity.

    method AddEntity {} {
        # FIRST, Pop up the dialog
        app enter ACTOR:CREATE
    }


    # EditSelected
    #
    # Called when the user wants to edit the selected entity(s).

    method EditSelected {} {
        # FIRST, there should be only one selected.
        set id [lindex [$hull uid curselection] 0]

        # NEXT, Pop up the dialog, and select this entity
        app enter ACTOR:UPDATE a $id
    }

    # DeleteSelected
    #
    # Called when the user wants to delete the selected entity.

    method DeleteSelected {} {
        # FIRST, there should be only one selected.
        set id [lindex [$hull uid curselection] 0]

        # NEXT, Delete the entity
        flunky senddict gui ACTOR:DELETE [list a $id]
    }
}




