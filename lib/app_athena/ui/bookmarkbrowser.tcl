#-----------------------------------------------------------------------
# TITLE:
#    bookmarkbrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    bookmarkbrowser(sim) package: Bookmark browser.
#
#    This widget displays a formatted list of detail browser bookmarks.
#    It is a wrapper around sqlbrowser(n).
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor bookmarkbrowser {
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
        { title          "Title" -width 20                  }
        { url            "URL"   -width 40                  }
    }

    #-------------------------------------------------------------------
    # Components

    component gobtn       ;# The "Go" button
    component addbtn      ;# The "Add" button
    component editbtn     ;# The "Edit" button
    component topbtn      ;# The "Top Rank" button
    component raisebtn    ;# The "Raise Rank" button
    component lowerbtn    ;# The "Lower Rank" button
    component bottombtn   ;# The "Bottom Rank" button
    component deletebtn   ;# The "Delete" button

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Install the hull
        installhull using sqlbrowser                  \
            -db            ::rdb                       \
            -view          gui_bookmarks               \
            -uid           bookmark_id                 \
            -titlecolumns  1                           \
            -columnsorting off                         \
            -selectioncmd  [mymethod SelectionChanged] \
            -reloadon {
                ::rdb <bookmarks>
                ::sim <DbSyncB>
            } -layout [string map [list %D $::app::derivedfg] $layout]

        # NEXT, get the options.
        $self configurelist $args

        # NEXT, create the toolbar buttons
        set bar [$hull toolbar]

        # Go
        install gobtn using ttk::button $bar.go   \
            -style   Toolbutton                   \
            -text    "Go"                         \
            -command [mymethod GoToBookmark]

        DynamicHelp::add $bar.go -text "Go to Bookmark"

        cond::single control $gobtn \
            browser $win
        
        # Add
        install addbtn using mkaddbutton $bar.add \
            "Add Bookmark"                        \
            -state   normal                       \
            -command [mymethod AddEntity]

        cond::available control $addbtn \
            order BOOKMARK:CREATE

        # Edit
        install editbtn using mkeditbutton $bar.edit \
            "Edit Bookmark"                          \
            -state   disabled                        \
            -command [mymethod EditSelected]

        cond::availableSingle control $editbtn \
            order   BOOKMARK:UPDATE            \
            browser $win

        # Top
        install topbtn using mktoolbutton $bar.top         \
            ::marsgui::icon::totop                         \
            "Raise to Top"                                 \
            -state   disabled                              \
            -command [mymethod SetRank top]

        cond::availableSingle control $topbtn              \
            order   BOOKMARK:RANK                          \
            browser $win

        # Raise
        install raisebtn using mktoolbutton $bar.raise     \
            ::marsgui::icon::raise                         \
            "Raise"                                        \
            -state   disabled                              \
            -command [mymethod SetRank raise]

        cond::availableSingle control $raisebtn            \
            order   BOOKMARK:RANK                          \
            browser $win

        # Lower
        install lowerbtn using mktoolbutton $bar.lower     \
            ::marsgui::icon::lower                         \
            "Lower"                                        \
            -state   disabled                              \
            -command [mymethod SetRank lower]

        cond::availableSingle control $lowerbtn            \
            order   BOOKMARK:RANK                          \
            browser $win

        # Bottom
        install bottombtn using mktoolbutton $bar.bottom   \
            ::marsgui::icon::tobottom                      \
            "Lower to Bottom"                              \
            -state   disabled                              \
            -command [mymethod SetRank bottom]

        cond::availableSingle control $bottombtn           \
            order   BOOKMARK:RANK                          \
            browser $win

        # Delete
        install deletebtn using mkdeletebutton $bar.delete \
            "Delete Bookmark"                              \
            -state   disabled                              \
            -command [mymethod DeleteSelected]

        cond::availableSingle control $deletebtn \
            order   BOOKMARK:DELETE              \
            browser $win

        pack $gobtn      -side left
        pack $addbtn     -side left
        pack $editbtn    -side left
        pack $topbtn     -side left
        pack $raisebtn   -side left
        pack $lowerbtn   -side left
        pack $bottombtn  -side left
        pack $deletebtn  -side right
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
        cond::availableSingle update \
            [list $editbtn $topbtn $raisebtn $lowerbtn $bottombtn $deletebtn]
    }


    # GoToBookmark
    #
    # Called when the user wants to view the selected bookmark in the
    # Detail Browser

    method GoToBookmark {} {
        # FIRST, there should be only one selected.
        set id [lindex [$hull uid curselection] 0]

        # NEXT, retrieve the URL.
        set url [rdb onecolumn {
            SELECT url FROM bookmarks WHERE bookmark_id=$id
        }]

        if {$url ne ""} {
            app show $url
        }
    }


    # AddEntity
    #
    # Called when the user wants to add a new entity.

    method AddEntity {} {
        # FIRST, Pop up the dialog
        order enter BOOKMARK:CREATE
    }


    # EditSelected
    #
    # Called when the user wants to edit the selected entities.

    method EditSelected {} {
        # FIRST, there should be only one selected.
        set id [lindex [$hull uid curselection] 0]

        order enter BOOKMARK:UPDATE bookmark_id $id
    }


    # SetRank change
    #
    # change - One of top, raise, lower, bottom.
    #
    # Called when the user wants to change the ranking of a bookmark. 

    method SetRank {change} {
        # FIRST, there should be only one selected.
        set id [lindex [$hull uid curselection] 0]

        order send gui BOOKMARK:RANK bookmark_id $id rank $change
    }


    # DeleteSelected
    #
    # Called when the user wants to delete the selected entity.

    method DeleteSelected {} {
        # FIRST, there should be only one selected.
        set id [lindex [$hull uid curselection] 0]

        # NEXT, Pop up the dialog, and select this entity
        order send gui BOOKMARK:DELETE bookmark_id $id
    }
}




