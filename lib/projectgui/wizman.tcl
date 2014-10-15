#-----------------------------------------------------------------------
# TITLE:
#    wizman.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    wizman(n): A wizard manager widget based on
#    ttk::notebook.  The user adds wizard pages, which are arbitrary
#    widgets.
#
#    wizard page widgets must implement the following subcommands:
#
#    enter     - Called whenever the wizard begins to display this page.
#    finished  - Returns 1 when all data has been successfully entered
#                and 0 otherwise, i.e., 1 when it's OK to go on to
#                to the next page.
#    leave     - Called when the user successfully presses the "Next"
#                button to leave the page.
# 
#-----------------------------------------------------------------------

namespace eval ::projectgui:: {
    namespace export wizman
}

#-----------------------------------------------------------------------
# wizman widget

snit::widget ::projectgui::wizman {
    #-------------------------------------------------------------------
    # Components

    component notebook   ;# ttk::notebook to contain wizard pages.
    component bcancel    ;# "cancel" button
    component bnext      ;# "next" button
    component bfinish    ;# "Finish" button
    
    #-------------------------------------------------------------------
    # Options

    delegate option * to notebook

    # -cancelcmd cmd
    option -cancelcmd

    # -finishcmd cmd
    option -finishcmd

    #-------------------------------------------------------------------
    # Variables

    # Info array: data about the pages in the wizard.
    #
    # pages               - A list of page widget names.

    variable info -array {
        pages {}
    }

    #-------------------------------------------------------------------
    # Constructor
    #

    constructor {args} {
        # FIRST, create the notebook
        install notebook using ttk::notebook $win.notebook \
            -style   Tabless.TNotebook \
            -padding 2 

        # NEXT, create separator
        ttk::separator $win.sep

        # NEXT, create the button bar
        ttk::frame $win.bar

        # NEXT, create the cancel button
        install bcancel using ttk::button $win.bar.bcancel \
            -text    "Cancel"                              \
            -command [mymethod Cancel]

        # NEXT, create the next button
        install bnext using ttk::button $win.bar.bnext \
            -text "Next >>" \
            -command [mymethod NextPage]

        # NEXT, create the Finish button
        install bfinish using ttk::button $win.bar.bfinish \
            -text "Finish"  \
            -state disabled \
            -command [mymethod Finish]

        pack $bcancel -side left  -padx 3
        pack $bfinish -side right -padx 3
        pack $bnext   -side right -padx 3 

        # NEXT, grid them in
        grid $notebook -row 0 -column 0 -sticky nsew 
        grid $win.sep  -row 1 -column 0 -sticky ew -pady 3
        grid $win.bar  -row 2 -column 0 -sticky ew -pady {0 3} 

        grid rowconfigure    $win 0 -weight 1
        grid columnconfigure $win 0 -weight 1

        # NEXT, get the options.
        $self configurelist $args
    }

    #-------------------------------------------------------------------
    # Event handlers

    # Cancel
    # 
    # This is called when the "Cancel" button is pressed.  It calls
    # the -cancelcmd, which should shut down the wizard.

    method Cancel {} {
        callwith $options(-cancelcmd)
    }

    # NextPage
    #
    # This is called when the "Next" button is pressed.  This should
    # never be called when there's no next page.
    
    method NextPage {} {
        # FIRST, get the current and next page
        set page [$self thispage]
        set next [$self nextpage]

        assert {$next ne ""}

        # NEXT, transition to the next page.
        $page leave
        $next enter
        $notebook select $next
        $self refresh
    }

    # Finish
    #
    # This is called when the "Finish" button is pressed.  This only
    # every happens once, at the very end.  Disables the button and
    # calls the -finishcmd.

    method Finish {} {
        $bfinish configure -state disabled
        callwith $options(-finishcmd)
    }

    #-------------------------------------------------------------------
    # Public Typemethods

    # add page ?option value...?
    #
    # page - A wizard page widget
    # 
    # Options:
    #
    #   Any options are as for ttk::notebook tabs.  By default,
    #   pages get: -sticky nsew -padding 2 
    #   
    # Adds a wizard page to the notebook; it can be accessed by its
    # widget name.

    method add {page args} {
        ladd info(pages) $page

        $notebook add $page -sticky nsew -padding 2 {*}$args
    }

    # start
    #
    # Selects the first page, and calls its "entercmd".

    method start {} {
        set page [lindex $info(pages) 0]
        $page enter
        $notebook select $page
        $self refresh
    }

    # thispage
    #
    # Returns the window for the current page.

    method thispage {} {
        return [$notebook select]
    }

    # nextpage
    #
    # Returns the window of the page after the current page.

    method nextpage {} {
        # FIRST, get the current page
        set page [$self thispage]

        # NEXT, get the next page
        set ndx [lsearch -exact $info(pages) $page]
        
        return [lindex $info(pages) $ndx+1]
    }
    
    # refresh
    #
    # Refreshes the state of the manager, e.g., checks the
    # finishedcmd for the current page and sets the state
    # of the "Next" button.

    method refresh {} {
        # FIRST, get the current and next pages.
        set page [$self thispage]
        set next [$self nextpage]

        # NEXT, if there is no next page, hide the next button.
        # Otherwise, set its state.
        if {$next eq ""} {
            pack forget $bnext
            $bfinish configure -state normal
        } elseif {[$page finished]} {
            $bnext configure -state normal
        } else {
            $bnext configure -state disabled
        }
    }
}