#-----------------------------------------------------------------------
# TITLE:
#    wiznbhood.tcl
#
# AUTHOR:
#    Dave Hanks
#
# PACKAGE:
#   wnbhood(n) -- package for athena(1) intel ingestion wizard.
#
# PROJECT:
#   Athena Regional Stability Simulation
#
# DESCRIPTION:
#    wiznbhood(n): A wizard manager page for choosing an
#    athena scenario.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# wiznbhood widget


snit::widget ::wnbhood::wiznbhood {
    #-------------------------------------------------------------------
    # Layout

    # The HTML layout for this widget.
    typevariable layout {
        <h1>Retrieve Neighborhood Polygons</h1>

        This wizard allows for the retrieval of neighborhood polygons
        to be used in an Athena scenario.  Press the "Test Data" button 
        to ingest polygons from test files.  Press the "Browse" button
        to browse for Neighborhood Polygon (.npf) files<p>

    }
    
    #-------------------------------------------------------------------
    # Components

    component hframe     ;# htmlframe(n) widget to contain the content.
    component bbrowse    ;# browse button
    component nbchooser  ;# nbchooser(n) widget
    
    #-------------------------------------------------------------------
    # Options

    delegate option * to hull

    #-------------------------------------------------------------------
    # Variables

    # Info array: wizard data
    #

    variable info -array {
    }

    #-------------------------------------------------------------------
    # Constructor
    #

    constructor {args} {
        # FIRST, set the default size of this page.
        $hull configure \
            -height 600 \
            -width  800

        # NEXT, create the HTML frame and widgets that go in it
        install hframe using htmlframe $win.hframe

        install bbrowse using ttk::button $hframe.btest \
            -text    "Test Data"                        \
            -command [mymethod TestData]

        install bbrowse using ttk::button $hframe.bbrowse \
            -text    "Browse"                             \
            -command [mymethod BrowseForData]

        # NEXT, create the nbchooser widget and layout the GUI
        $self CreateNbChooser $win.nbchooser
        $self layout

        grid columnconfigure $win 0 -weight 1
        grid rowconfigure    $win 1 -weight 1

        grid $win.hframe    -row 0 -column 0 -sticky ew
        grid $win.nbchooser -row 1 -column 0 -sticky nsew

        notifier bind ::wnbhood::wizard <update> $win [mymethod Refresh]
    }

    # CreateNbChooser w
    #
    # w   - the window to create
    #
    # This method creates an nbchooser widget that is used to select
    # which neighborhoods should be ingested into Athena.  The 
    # widget is configured with the map image and projection currently
    # loaded into the scenario.

    method CreateNbChooser {w} {
        # FIRST, grab the map image and projection object from
        # the scenario.
        rdb eval {
            SELECT width,height,projtype,proj_opts,data
            FROM maps WHERE id=1

        } {
            set mapimage [image create photo -format jpeg -data $data]

            set proj [[eprojtype as proj $projtype] %AUTO% \
                                       -width $width       \
                                       -height $height     \
                                       {*}$proj_opts]
        }

        install nbchooser using nbchooser $w \
            -projection $proj                \
            -map        $mapimage
    }

    #-------------------------------------------------------------------
    # Event handlers

    # TestData
    #
    # Loads the test data straight from disk

    method TestData {} {
        wizard retrievePolygons \
            [appdir join data polygons CentralAsia.npf]
    }

    # BrowseForData
    #
    # Browses for .npf files and passes it along.

    method BrowseForData {} {
        # FIRST, get the filenames to parse
        set fname [tk_getOpenFile \
                       -initialdir [pwd]                  \
                       -title      "Select NPF files"     \
                       -parent     [app topwin]           \
                       -multiple   0                      \
                       -filetypes {
                           {{NPF files} {.npf}}
                       }]

        if {$fname eq ""} {
            return
        }

        wizard retrievePolygons $fname
    }

    # layout
    #
    # Lays out the content at the top of the page, including the boiler
    # plate first and then buttons and ancillary data about what's going
    # on.

    method layout {} {
        # NEXT, layout the buttons and polygon information
        set status [$self LayoutStatus]

        set title "Playbox:"
        # NEXT, layout the playbox boundary to give a reference
        append status [$self LayoutBox $title [$nbchooser pbbox]]

        $hframe layout "$layout<p>\n\n$status"
    }

    # LayoutStatus
    #
    # Lays out the buttons and the number of polygons read and number
    # inside the playbox

    template method LayoutStatus {} {
        set numread [$nbchooser size]
        set numvis  [$nbchooser visible]
    } {
        |<--
        <table>
        <tr><td width="200"><input name="bbrowse"> <input name="btest"></td>
            <td width="150">Polygons Read: $numread</td>
            <td width="200">Polygons In Playbox: $numvis</td>
        </tr>
        </table>
    }

    # LayoutBox
    # 
    # Formats the coordinates of a bounding box into a nice human
    # readable form and returns them in a table.

    template method LayoutBox {title bbox} {
        lassign $bbox minlat minlon maxlat maxlon
        set ll "([format "%.3fN" $minlat], [format "%.3fE" $minlon])"
        set ur "([format "%.3fN" $maxlat], [format "%.3fE" $maxlon])"
    } {
        |<--
        <table>
        <tr>
            <td width="80"><b>$title</b><td>
            <td width="200">Lower Left: $ll</td>
            <td width="200">Upper Right: $ur</td>
        </tr>
        </table>
    }

    method Refresh {args} {
        # FIRST, clear the nb chooser and refresh the polygons
        # in it. 
        $nbchooser clear
        $nbchooser refresh

        $self layout
    }

    # getnbhoods
    #
    # Returns a dictionary of selected polygons in the nbchooser 

    method getnbhoods {} {
        return [$nbchooser getpolys]
    }

    #-------------------------------------------------------------------
    # Wizard Page Interface

    # enter
    #
    # This command is called when wizman selects this page for
    # display.  It should do any necessary set up (i.e., pull
    # data from the data model).

    method enter {} {
        # Nothing to do
    }


    # finished
    #
    # This command is called to determine whether or not the user has
    # completed all necessary tasks on this page.  It returns 1
    # if we can go on to the next page, and 0 otherwise.

    method finished {} {
        return 1
    }

    # leave
    #
    # This command is called when the user presses the wizman's
    # "Next" button to go on to the next page.  It should trigger
    # any processing that needs to be done as the result of the
    # choices made on this page, before the next page is entered.

    method leave {} {
        # Nothing to do
    }
}
