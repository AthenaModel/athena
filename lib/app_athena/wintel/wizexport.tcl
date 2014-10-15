#-----------------------------------------------------------------------
# TITLE:
#    wizexport.tcl
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
#    wizexport(n): A wizard manager page for viewing and exporting the 
#    simevents script and HTML documentation.
#    
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# wizexport widget


snit::widget ::wintel::wizexport {
    #-------------------------------------------------------------------
    # Lookup table

    # The HTML help for this widget.
    typevariable helptext {
        <h1>Ingest Events Into Scenario</h1>

        Events To Ingest: 
        
        Athena is now ready to ingest these intel-derived events into
        the current scenario.  The righthand pane shows documentation for 
        each of the ingested simulation events, relating them to the TIGR
        messages that drove their creation.  If desired, you may press the 
        "Save Documentation" button to save this documentation to
        disk as an HTML file.<p>

        When you are ready, press "Finish" to ingest the events, or 
        "Cancel" to leave the scenario unchanged.<p>

        The events will be ingested as a block, and can be undone as
        a block by selecting Edit/Undo from the main menu.
    }

    
    #-------------------------------------------------------------------
    # Components

    component hframe    ;# htmlframe(n), for documentation at top.
    component detail    ;# htmlviewer(n) to display documentation

    #-------------------------------------------------------------------
    # Options

    delegate option * to hull

    #-------------------------------------------------------------------
    # Constructor
    #
    #   +----------------------+
    #   | hframe    | detail   |
    #   |           +----------+
    #   |           |  save    |
    #   +-----------+----------+


    constructor {args} {
        $self configurelist $args

        $self MakeHtmlFrame  $win.hframe  ;# hframe
        ttk::separator $win.vsep \
            -orient vertical
        $self MakeDetailPane $win.detail  ;# detail
        ttk::separator $win.hsep
        ttk::button $win.bdoc \
            -text "Save Documentation" \
            -command [mymethod SaveDocsAs]

        # NEXT, grid the major components.
        grid $hframe      -row 0 -column 0 -rowspan 3 -sticky nsew
        grid $win.vsep    -row 0 -column 1 -rowspan 3 -sticky ns
        grid $win.detail  -row 0 -column 2 -sticky nsew
        grid $win.hsep    -row 1 -column 2 -sticky ew
        grid $win.bdoc    -row 2 -column 2 -pady 3

        grid rowconfigure    $win 0 -weight 1
        grid columnconfigure $win 2 -weight 1
    }

    # MakeHtmlFrame w
    #
    # Creates an htmlframe to hold a page title and description.

    method MakeHtmlFrame {w} {
        install hframe using htmlframe $win.hframe \
            -shrink yes \
            -width  400

        $hframe layout $helptext

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
    # Event handlers

    # SaveDocsAs
    #
    # Prompts the user to save the ingestion docs.

    method SaveDocsAs {} {
        set filename [tk_getSaveFile                        \
                          -parent $win                      \
                          -title "Save Ingestion Documentation As" \
                          -filetypes {
                              {{HTML Document} {.html} }
                          }]

        # NEXT, If none, they cancelled.
        if {$filename eq ""} {
            return 0
        }

        # NEXT, add the .html, if need be.
        if {[file extension $filename] eq ""} {
            set filename "$filename.html"
        }

        # NEXT, Save the scenario using this name
        try {
            wizard saveFile $filename [wizard docs]
        } on error {errmsg} {
            app error "Could not save $filename:\n$errmsg"
            return
        } 

        app puts "Saved docs as: $filename"
    }

    #-------------------------------------------------------------------
    # Wizard Page Interface

    # enter
    #
    # This command is called when wizman selects this page for
    # display.  It should do any necessary set up (i.e., pull
    # data from the data model).

    method enter {} {
        $detail set [wizard docs]
        $hframe layout [$self StatusText]
        return
    }

    template method StatusText {} {
        set num [llength [simevent normals]]
    } {
        <h1>Ingest Events Into Scenario</h1>

        Events To Ingest: $num<p>
        
        Athena is now ready to ingest these intel-derived events into
        the current scenario.  The righthand pane shows documentation for 
        each of the ingested simulation events, relating them to the TIGR
        messages that drove their creation.  If desired, you may press the 
        "Save Documentation" button to save this documentation to
        disk as an HTML file.<p>

        When you are ready, press "Finish" to ingest the events, or 
        "Cancel" to leave the scenario unchanged.  The ingested
        events can be found in the SYSTEM agent's strategy; click "SYSTEM"
        in the left sidebar of the Strategy/Editor tab.<p>

        The events will be ingested as a block, and can be undone as
        a block by selecting Edit/Undo from the main menu.
    }


    # finished
    #
    # This command is called to determine whether or not the user has
    # completed all necessary tasks on this page.  It returns 1
    # if we can go on to the next page, and 0 otherwise.

    method finished {} {
        # This is the last page.
        return 1
    }


    # leave
    #
    # This command is called when the user presses the wizman's
    # "Next" button to go on to the next page.  It should trigger
    # any processing that needs to be done as the result of the
    # choices made on this page, before the next page is entered.

    method leave {} {
        # Nothing to be done at the moment.
        return
    }
}
