#-----------------------------------------------------------------------
# TITLE:
#    capbrowser.tcl
#
# AUTHORS:
#    Dave Hanks
#
# DESCRIPTION:
#    capbrowser(sim) package: Communications Asset Package (CAP) browser.
#
#    This widget displays three sqlbrowser(n) objects inside a set of 
#    paned windows:
#        * Communication Asset Package (CAP) browser
#        * CAP Neighborhood Coverage browser
#        * CAP Group Penetration browser
#
#    Depending on the CAP selected in the CAP browser the neighborhood
#    coverage and group penetration browsers will automatically filter
#    on that CAP
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widget capbrowser {
    #-------------------------------------------------------------------
    # Options

    #-------------------------------------------------------------------
    # Typevariables

    # CAP browser layout

    typevariable caplayout {
        { k              "ID"                               }
        { longname       "Long Name"                        }
        { owner          "Owner"                            }
        { capacity       "Capacity" -sortmode real          }
        { cost           "Cost, $/message/week" 
                         -sortmode command 
                         -sortcommand ::marsutil::moneysort }
    }

    # Neighborhood Coverage browser layout

    typevariable nbcovlayout {
        {k        "Of CAP"                      }
        {n        "In Nbhood"                   }
        {nbcov    "Coverage"     -sortmode real }
    }

    # CAP coverage layout
    #
    # %D is replaced with the color for derived columns.

    typevariable capcovlayout {
        {k        "Of CAP"                                      }
        {owner    "With Owner"                                  }
        {g        "Into Group"                                  }
        {n        "In Nbhood"                                   }
        {capcov   "Grp Cov"       -sortmode real -foreground %D }
        {pen      "= Grp Pen"     -sortmode real                }
        {nbcov    "* Nbhood Cov"  -sortmode real                }
        {capacity "* Capacity"    -sortmode real                }
        {orphan   "ORPHAN"        -hide 1                       }
    }


    #-------------------------------------------------------------------
    # Components

    component caps       ;# The CAP browser
    component caddbtn    ;# The CAP add button
    component ceditbtn   ;# The CAP edit button
    component cdeletebtn ;# The CAP delete button

    component nbcov      ;# The neighborhood coverage browser
    component nceditbtn  ;# The neighborhood coverage edit button

    component capcov     ;# The group penetration browser
    component cceditbtn  ;# The group penetration edit button

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the paned window
        ttk::panedwindow $win.vpaner \
            -orient vertical

        pack $win.vpaner -fill both -expand yes

        ttk::panedwindow $win.vpaner.hpaner \
            -orient horizontal 

        # NEXT, create the sqlbrowser(n) objects
        $self CapViewerCreate    $win.vpaner.caps
        $self NbcovViewerCreate  $win.vpaner.hpaner.nbcov
        $self CapcovViewerCreate $win.vpaner.hpaner.capcov

        # NEXT, fill the paned window with the sqlbrowsers
        $win.vpaner        add $win.vpaner.caps
        $win.vpaner        add $win.vpaner.hpaner        -weight 1
        $win.vpaner.hpaner add $win.vpaner.hpaner.nbcov
        $win.vpaner.hpaner add $win.vpaner.hpaner.capcov -weight 1
    }

    destructor {
        notifier forget $self
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull

    #-------------------------------------------------------------------
    # Private Methods

    # CapViewerCreate   pane
    #
    # pane     - The pane that will contain the sqlbrowser(n) object
    #
    # This method fills a pane in the browser with a sqlbrowser(n)
    # object that displays CAP objects. 

    method CapViewerCreate {pane} {
        # FIRST, create the caps component
        install caps using sqlbrowser $pane              \
            -height   8                                  \
            -width    30                                 \
            -db       ::adb                              \
            -view     gui_caps                           \
            -uid      id                                 \
            -titlecolumns 1                              \
            -selectioncmd [mymethod CapSelectionChanged] \
            -reloadon {
                ::adb <Sync>
            } -layout [string map [list %D $::app::derivedfg] $caplayout]


        # NEXT add the toolbar
        set bar [$caps toolbar]

        install caddbtn using mkaddbutton $bar.add \
            "Add Comm. Asset Package"              \
            -state normal                          \
            -command [mymethod CapAddEntity]

        cond::available control $caddbtn \
            order CAP:CREATE

        install ceditbtn using mkeditbutton $bar.edit \
            "Edit Selected CAP"                      \
            -state   disabled                        \
            -command [mymethod CapEditSelected]

        # CAP:CAPACITY is used when CAP:UPDATE is not available.
        cond::availableMulti control $ceditbtn \
            order   CAP:CAPACITY              \
            browser $caps

        install cdeletebtn using mkdeletebutton $bar.delete \
            "Delete Selected CAP"                          \
            -state   disabled                              \
            -command [mymethod CapDeleteSelected]

        cond::availableSingle control $cdeletebtn \
            order   CAP:DELETE              \
            browser $caps

        pack $caddbtn    -side left
        pack $ceditbtn   -side left
        pack $cdeletebtn -side right

        # NEXT, update individual entities when they change.
        notifier bind ::adb <caps> $self [list $caps uid]
    }

    # CapAddEntity
    #
    # Called when the user presses the "Add CAP" button.

    method CapAddEntity {} {
        app enter CAP:CREATE
    }

    # CapEditSelected
    #
    # Called when the user presses the "Edit Selected CAP" button

    method CapEditSelected {} {
        # FIRST, get the ids of the selected CAPs
        set ids [$caps uid curselection]

        # NEXT, select the correct order processor
        if {[adb state] eq "PREP"} {
            set root CAP:UPDATE
        } else {
            set root CAP:CAPACITY
        }

        # NEXT, if there is more than one CAP selected use the
        # MULTI order
        if {[llength $ids] == 1} {
            set id [lindex $ids 0]

            app enter $root k $id
        } else {
            app enter ${root}:MULTI ids $ids
        }
    }

    # CapDeleteSelected
    #
    # Called when the user wants to delete the selected CAP entity.

    method CapDeleteSelected {} {
        # FIRST, there should be only one selected.
        set id [lindex [$caps uid curselection] 0]

        # NEXT, Pop up the dialog, and select this entity
        app delete CAP:DELETE [list k $id] {
            Are you sure you
            really want to delete this CAP, along
            with all of the entities that depend upon it?
        }

    }

    # CapSelectionChanged
    #
    # Called when the user selects CAPs in the browser

    method CapSelectionChanged {} {
        # FIRST trigger conditions
        cond::availableSingle update $cdeletebtn
        cond::availableMulti  update $ceditbtn

        # NEXT, determine which CAPs are selected
        set ids [$caps uid curselection]
        
        set where ""

        # NEXT, given the selected CAPs filter the data
        # in the neighborhood coverage and CAP coverage
        # browsers. Note: the where clause may be empty
        # in which case there is no filtering
        if {[llength $ids] > 0} {
            set where "k= '"
            append where [join $ids "' OR k= '"]
            append where "'"
        } 

        $nbcov configure  -where $where
        $capcov configure -where $where
    }

    # NbcovViewerCreate pane
    #
    # pane   - The pane that will contain the sqlbrowser(n) object 
    #
    # This method creates an sqlbrowser(n) object for displaying
    # the neighborhood coverage of the CAPs. This browser will be
    # automatically filtered depending on the selected CAP in the 
    # CAP browser.

    method NbcovViewerCreate {pane} {
        # FIRST, create the sqlbrowser(n) object
        install nbcov using sqlbrowser $pane                 \
            -height       20                                 \
            -width        40                                 \
            -db           ::adb                              \
            -view         gui_cap_kn_nonzero                 \
            -uid          id                                 \
            -filterbox    off                                \
            -titlecolumns 2                                  \
            -selectioncmd [mymethod NbcovSelectionChanged]   \
            -reloadon {
                ::adb <caps>
                ::adb <Sync>
            } -views {
                gui_cap_kn         "All"
                gui_cap_kn_nonzero "Non-Zero"
            } -layout [string map [list %D $::app::derivedfg] $nbcovlayout]

        # NEXT, create the toolbar
        set bar [$nbcov toolbar]

        # NEXT, the edit button
        install nceditbtn using mkeditbutton $bar.edit \
            "Set CAP Neighborhood Coverage"            \
            -state disabled                            \
            -command [mymethod NbcovEditSelected] 

        cond::availableMulti control $nceditbtn \
            order CAP:NBCOV:SET                 \
            browser $nbcov

        pack $nceditbtn  -side left

        # NEXT, bind to rdb updates to the appropriate table
        notifier bind ::adb <cap_kn> $self [list $nbcov uid]
    }

    # NbcovSelectionChaged 
    #
    # Called whenever the user changes the selected set of neighborhood
    # coverage records in the browser

    method NbcovSelectionChanged {} {
        cond::availableMulti update $nceditbtn
    }

    # NbcovEditSelected
    #
    # Called whenever the user presses the "Set CAP Neighborhood 
    # Coverage" button in the toolbar

    method NbcovEditSelected {} {
        # FIRST, grab the ids selected and choose the appropriate
        # order handler.
        set ids [$nbcov uid curselection]

        if {[llength $ids] == 1} {
            app enter CAP:NBCOV:SET id [lindex $ids 0]
        } else {
            app enter CAP:NBCOV:SET:MULTI ids $ids
        }
    }

    # CapcovViewerCreate pane
    #
    # pane   - The pane that will contain the sqlbrowser(n) object
    #
    # This methos creates an sqlbrowser(n) object for displaying
    # CAP coverage for all CAPs. It includes the CAP, the owner, the
    # neighborhoods it could potentially reach and the penetration
    # into the groups in each neighborhood.

    method CapcovViewerCreate {pane} {
        # FIRST, create the sqlbrowser(n) object
        install capcov using sqlbrowser $pane               \
            -height 20                                      \
            -width  40                                      \
            -db     ::adb                                   \
            -view   gui_capcov_nonzero                      \
            -uid    id                                      \
            -titlecolumns 4                                 \
            -filterbox off                                  \
            -selectioncmd [mymethod CapcovSelectionChanged] \
            -displaycmd   [mymethod CapcovDataDisplay]      \
            -reloadon {
                ::adb <caps>
                ::adb <cap_kn>
                ::adb <Sync>
            } -views {
                gui_capcov         "All"
                gui_capcov_nonzero "Non-Zero"
                gui_capcov_orphans "Orphans"
            } -layout [string map [list %D $::app::derivedfg] $capcovlayout]

        # NEXT, create and populate the toolbar with an edit button
        set bar [$capcov toolbar]

        install cceditbtn using mkeditbutton $bar.edit \
            "Set CAP Group Penetration"                \
            -state disabled                            \
            -command [mymethod CapcovEditSelected]

        cond::availableMulti control $cceditbtn \
            order CAP:PEN:SET                   \
            browser $capcov

        pack $cceditbtn   -side left

        notifier bind ::adb <cap_kg> $self [list $capcov uid]
    }


    # CapcovSelectionChanged
    #
    # Called when the CAP coverage record selection is changed by the
    # user

    method CapcovSelectionChanged {} {
        cond::availableMulti update $cceditbtn
    }

    # CapcovDataDisplay  rindex values
    #
    # rindex   - the row index of a record in the browser
    # values   - the values in the row
    #
    # This method displays records that are "orphans" with a yellow
    # background. A record is an orphan if its group coverage and
    # neighborhood coverage is zero, but it's group penetration is 
    # non-zero

    method CapcovDataDisplay {rindex values} {
        set orphan [lindex $values end-1]

        if {$orphan} {
            $capcov rowconfigure $rindex \
                -foreground black        \
                -background yellow
        }
    }
    
    # CapcovEditSelected
    #
    # This is called when the user presses the "Set CAP Group Penetration"
    # button in the toolbar.

    method CapcovEditSelected {} {
        # FIRST, grab the list of selected ids (there may be only one)
        # and call the appropriate order processor

        set ids [$capcov uid curselection]

        if {[llength $ids] == 1} {
            app enter CAP:PEN:SET id [lindex $ids 0]
        } else {
            app enter CAP:PEN:SET:MULTI ids $ids
        }
    }
}




