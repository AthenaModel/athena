#------------------------------------------------------------------------
# TITLE:
#    mapviewer.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    mapviewer(sim): athena_sim(1) Map viewer widget
#
#    The mapviewer uses a mapcanvas(n) widget to display a map, and
#    neighborhood polygons and icons upon that map.  Its purpose is 
#    to wrap up all of the application-specific details of interacting
#    with the map.
#
# OUTLINE:
#    This is a large and complex file; the following outline may prove
#    useful.
#
#      I. General Behavior
#         A. Button Icon Definitions
#         B. Widget Options
#         C. Widget Components
#         D. Instance Variables
#         E. Constructor
#         F. Event Handlers: Tool Buttons
#         G. Event Handlers: Order Entry 
#         H. Public Methods
#     II. Neighborhood Display and Behavior
#         A. Instance Variables
#         B. Neighborhood Display
#         C. Context Menu
#         D. Event Handlers: mapcanvas(n)
#         E. Event Handlers: notifier(n)
#         F. Public Methods
#    III. Icon Display and Behavior
#         A. Instance Variables
#         B. Helper Routines
#         C. Event Handlers: mapcanvas(n)
#     IV. Unit Display and Behavior
#         A. Unit Display
#         B. Context Menu
#         C. Event Handlers: notifier(n)
#     V.  Absit Display and Behavior
#         A. Absit Display
#         B. Context Menu
#         C. Event Handlers: notifier(n)
#         D. Public Methods
#    VI.  Group Entity Handlers
#
#-----------------------------------------------------------------------

snit::widget mapviewer {
    #===================================================================
    # General Behavior

    #-------------------------------------------------------------------
    # Button Icon Definitions

    typeconstructor {
        # Create the button icons
        namespace eval ${type}::icon { }

        mkicon ${type}::icon::left_ptr {
            X..........
            XX.........
            XXX........
            XXXX.......
            XXXXX......
            XXXXXX.....
            XXXXXXX....
            XXXXXXXX...
            XXXXXXXXX..
            XXXXXXXXXX.
            XXXXXXXXXXX
            XXXXXXX....
            XXX.XXXX...
            XX..XXXX...
            X....XXXX..
            .....XXXX..
            ......XXXX.
            ......XXXX.
        } { . trans  X black } d { X gray }

        mkicon ${type}::icon::fleur {
            ..........X..........
            .........XXX.........
            ........XXXXX........
            .......XXXXXXX.......
            ......XXXXXXXXX......
            ..........X..........
            ....X.....X.....X....
            ...XX.....X.....XX...
            ..XXX.....X.....XXX..
            .XXXX.....X.....XXXX.
            XXXXXXXXXXXXXXXXXXXXX
            .XXXX.....X.....XXXX.
            ..XXX.....X.....XXX..
            ...XX.....X.....XX...
            ....X.....X.....X....
            ..........X..........
            ......XXXXXXXXX......
            .......XXXXXXX.......
            ........XXXXX........
            .........XXX.........
            ..........X..........
        } { . trans  X black } d { X gray }

        mkicon ${type}::icon::fill_poly {

            ..XX..........
            ..XaXX........
            ..XaaaXX......
            ..XaaaaaXX....
            .XaaaaaaaaXX..
            .XaaaaaaaaaaXX
            .XaaaaaaaaaaaX
            .XaaaaaaaaaaaX
            XaaaaaaaaaaaaX
            XaaaaaaaaaaaaX
            XaaaaaaaaaaaaX
            XaaaaaaaaaaaaX
            .XaaaaaaaaaaaX
            .XaaaaaaaaaaaX
            .XaaaaaaaaaaaX
            .XaaaaaaaaaXXX
            ..XaaaaaXXX...
            ..XaaXXX......
            ..XXX.........
        } {
            .  trans
            X  #000000
            a  #FFFFFF
        }


        mkicon ${type}::icon::nbpoly {
            ..............
            ..XX..........
            ..X.XX........
            ..X...XX......
            ..X.....XX....
            .X........XX..
            .X..........XX
            .X...........X
            .X..X.....X..X
            X...XX....X..X
            X...X.X...X..X
            X...X..X..X..X
            X...X...X.X..X
            .X..X....XX..X
            .X..X.....X..X
            .X...........X
            .X.........XXX
            ..X.....XXX...
            ..X..XXX......
            ..XXX.........
            ..............
            ..............
        } { . trans  X black } d { X gray }


        mkicon ${type}::icon::abpoly {
            ..............
            ..XX..........
            ..X.XX........
            ..X...XX......
            ..X.....XX....
            .X........XX..
            .X..........XX
            .X...........X
            .X....XXX....X
            X....X...X...X
            X....X...X...X
            X....XXXXX...X
            X....X...X...X
            .X...X...X...X
            .X...X...X...X
            .X...........X
            .X.........XXX
            ..X.....XXX...
            ..X..XXX......
            ..XXX.........
            ..............
            ..............
        } { . trans  X black } d { X gray }

    }

    #-------------------------------------------------------------------
    # Look-up tables

    # Default fill specs

    typevariable defaultFills {
        none
        nbmood
        pcf
    }

    #-------------------------------------------------------------------
    # Type Variables

    # Shared pick list info.
    #
    # recentFills    Recently selected fill tags
    # filltags       Current set of filltags for fillbox pulldown

    typevariable picklist -array {
        recentFills {}
        filltags    {}
    }

    #-------------------------------------------------------------------
    # Widget Options

    # All options are delegated to the mapcanvas(n).
    delegate option * to hull
    
    #-------------------------------------------------------------------
    # Widget Components

    component canvas           ;# The mapcanvas(n)
    component projection       ;# A projection(i) instance
    component mapimage         ;# The map image
    component fillbox          ;# ComboBox of nbhood fill criteria

    #-------------------------------------------------------------------
    # Instance Variables

    # Info array; used for most scalars
    #
    #    mode           The current mapcanvas(n) mode
    #    ordertags      List of parameter type tags, if an order is
    #                   being entered and the current field has tags.
    #    ref            The current map reference

    variable info -array {
        mode      ""
        ordertags {}
        loc       ""
        check     OK
    }

    # View array; used for values that control the view
    #
    #    absits   - 1 if absits should be displayed, 0 otherwise
    #    CIV      - 1 if CIV units should be displayed, 0 otherwise.
    #    FRC      - 1 if FRC units should be displayed, 0 otherwise.
    #    ORG      - 1 if ORG units should be displayed, 0 otherwise.
    #    names    - 1 if icons should include names, 0 otherwise.
    #    fillpoly - 1 if polygons should be filled, and 0 otherwise.
    #    zoom     - Current zoom factor show in the zoombox
    #    filltag  - Current fill tag (neighborhood variable)

    variable view -array {
        absits       1
        CIV          1
        FRC          1
        ORG          1
        names        1
        fillpoly     0
        filltag     none
        recentFills {}
        filltags    {}
        zoom        "100%"
    }

    # Default map data array; used when no map image is loaded
    # The default map is a matrix of plus signs used as map markers
    #
    # width   - width  of the default canvas
    # height  - height of the default canvas
    # dx      - deltax between map markers
    # dy      - deltay between map markers
    # color   - color of map markers
    # ll      - line length of map markers

    variable dmap -array {
        width    1000
        height   1000
        dx       40
        dy       40
        color    #B2B2B2
        ll       2
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Configure the hull's appearance.
        $hull configure    \
            -borderwidth 0 \
            -relief flat

        # NEXT, create the components.

        # Frame to contain the canvas
        ttk::frame $win.mapsw

        # Map canvas
        install canvas using mapcanvas $win.mapsw.canvas  \
            -background     white                         \
            -modevariable   [myvar info(mode)]            \
            -locvariable    [myvar info(loc)]             \
            -xscrollcommand [list $win.mapsw.xscroll set] \
            -yscrollcommand [list $win.mapsw.yscroll set]

        ttk::scrollbar $win.mapsw.xscroll \
            -orient  horizontal           \
            -command [list $canvas xview]

        ttk::scrollbar $win.mapsw.yscroll \
            -command [list $canvas yview]

        grid columnconfigure $win.mapsw 0 -weight 1
        grid rowconfigure    $win.mapsw 0 -weight 1
        
        grid $win.mapsw.canvas  -row 0 -column 0 -sticky nsew
        grid $win.mapsw.yscroll -row 0 -column 1 -sticky ns
        grid $win.mapsw.xscroll -row 1 -column 0 -sticky ew

        # Horizontal tool bar
        ttk::frame $win.hbar

        # Nbhood boundary check 
        ttk::label $win.hbar.check \
            -textvariable [myvar info(check)] \
            -justify      left                \
            -anchor       w                   \
            -width        35 
        
        # MapLoc
        ttk::label $win.hbar.loc \
            -textvariable [myvar info(loc)] \
            -justify      right             \
            -anchor       e                 \
            -width        60 

        # CIV Icon toggle
        ttk::checkbutton $win.hbar.civ                  \
            -style       Toolbutton                     \
            -variable    [myvar view(CIV)]              \
            -image       ::projectgui::icon::civgroup22 \
            -command     [mymethod UnitDrawAll]

        DynamicHelp::add $win.hbar.civ \
            -text "Display civilian group icons"

        # FRC Icon toggle
        ttk::checkbutton $win.hbar.frc                  \
            -style       Toolbutton                     \
            -variable    [myvar view(FRC)]              \
            -image       ::projectgui::icon::frcgroup22 \
            -command     [mymethod UnitDrawAll]

        DynamicHelp::add $win.hbar.frc \
            -text "Display force group icons"

        # ORG Icon toggle
        ttk::checkbutton $win.hbar.org                  \
            -style       Toolbutton                     \
            -variable    [myvar view(ORG)]              \
            -image       ::projectgui::icon::orggroup22 \
            -command     [mymethod UnitDrawAll]

        DynamicHelp::add $win.hbar.org \
            -text "Display organization group icons"

        # Absit Icon toggle
        ttk::checkbutton $win.hbar.absit                \
            -style       Toolbutton                     \
            -variable    [myvar view(absits)]           \
            -image       ${type}::icon::abpoly          \
            -command     [mymethod AbsitDrawAll]

        DynamicHelp::add $win.hbar.absit \
            -text "Display abstract situation icons"

        # Icon Names Toggle
        ttk::checkbutton $win.hbar.names          \
            -style       Toolbutton               \
            -variable    [myvar view(names)]      \
            -text        "Names"                  \
            -command     [mymethod IconDrawAll]

        DynamicHelp::add $win.hbar.names \
            -text "Display names in icons"


        # Nbhood fill toggle
        ttk::checkbutton $win.hbar.fillpoly         \
            -style       Toolbutton                 \
            -variable    [myvar view(fillpoly)]     \
            -image       ${type}::icon::fill_poly   \
            -command     [mymethod NbhoodFill]

        DynamicHelp::add $win.hbar.fillpoly \
            -text "Display neighborhood polygons with an opaque fill"

        # Nbhood fill criteria
        install fillbox using menubox $win.hbar.fillbox \
            -textvariable [myvar view(filltag)]         \
            -font          codefont                     \
            -width         16                           \
            -values        $defaultFills                \
            -postcommand   [mymethod FillBoxPost]       \
            -command       [mymethod NbhoodFill]

        DynamicHelp::add $win.hbar.fillbox \
            -text "Select the neighborhood fill criteria"

        # Zoom Box
        set factors [list]
        foreach factor [$canvas zoomfactors] {
            lappend factors "$factor%"
        }

        menubox $win.hbar.zoombox               \
            -textvariable [myvar view(zoom)]    \
            -font         codefont              \
            -width        4                     \
            -justify      right                 \
            -values       $factors              \
            -command      [mymethod ZoomBoxSet]

        DynamicHelp::add $win.hbar.zoombox \
            -text "Select zoom factor for the map display"

        pack $win.hbar.zoombox  -side right -padx {5 0}
        pack $win.hbar.fillbox  -side right
        pack $win.hbar.fillpoly -side right -padx 3
        pack $win.hbar.names    -side right -padx 5
        pack $win.hbar.org      -side right -padx 1
        pack $win.hbar.frc      -side right -padx 1
        pack $win.hbar.civ      -side right -padx 1
        pack $win.hbar.absit    -side right -padx 5
        pack $win.hbar.loc      -side right -padx 5
        pack $win.hbar.check    -side left 

        # Separators
        ttk::separator $win.sep1
        ttk::separator $win.sep2 \
            -orient vertical

        # Vertical tool bar
        ttk::frame $win.vbar

        $self AddModeTool browse left_ptr   "Browse tool"
        $self AddModeTool pan    fleur      "Pan tool"

        # Separator
        ttk::separator $win.vbar.sep

        cond::available control \
            [ttk::button $win.vbar.nbhood                       \
                 -style   Toolbutton                            \
                 -image   [list ${type}::icon::nbpoly           \
                               disabled ${type}::icon::nbpolyd] \
                 -command [list app enter NBHOOD:CREATE]]     \
            order NBHOOD:CREATE

        DynamicHelp::add $win.vbar.nbhood \
            -text [::athena::orders title NBHOOD:CREATE]

        cond::available control \
            [ttk::button $win.vbar.newabsit                                  \
                 -style   Toolbutton                                         \
                 -image   [list ${type}::icon::abpoly                       \
                               disabled ${type}::icon::abpolyd]             \
                 -command [list app enter ABSIT:CREATE]] \
            order ABSIT:CREATE

        DynamicHelp::add $win.vbar.newabsit \
            -text [::athena::orders title ABSIT:CREATE]

        pack $win.vbar.sep       -side top -fill x -pady 2
        pack $win.vbar.nbhood    -side top -fill x -padx 2
        pack $win.vbar.newabsit  -side top -fill x -padx 2

        # Pack all of these components
        pack $win.hbar  -side top  -fill x
        pack $win.sep1  -side top  -fill x
        pack $win.vbar  -side left -fill y
        pack $win.sep2  -side left -fill y
        pack $win.mapsw            -fill both -expand yes

        # NEXT, Create the context menus
        $self CreateNbhoodContextMenu
        $self CreateUnitContextMenu
        $self CreateAbsitContextMenu

        # NEXT, process the arguments
        $self configurelist $args

        # NEXT, Subscribe to mapcanvas(n) events.
        bind $canvas <<Icon-1>>       [mymethod Icon-1 %d]
        bind $canvas <<Icon-3>>       [mymethod Icon-3 %d %X %Y]
        bind $canvas <<IconMoved>>    [mymethod IconMoved %d]
        bind $canvas <<Nbhood-1>>     [mymethod Nbhood-1 %d]
        bind $canvas <<Nbhood-3>>     [mymethod Nbhood-3 %d %X %Y %x %y]
        bind $canvas <<Point-1>>      [mymethod Point-1 %d]
        bind $canvas <<PolyComplete>> [mymethod PolyComplete %d]

        # NEXT, Subscribe to application notifier(n) events.
        notifier bind ::sim      <DbSyncB>     $self [mymethod dbsync]
        notifier bind ::sim      <Tick>        $self [mymethod dbsync]
        notifier bind ::adb.map  <MapChanged>  $self [mymethod dbsync]
        notifier bind ::marsgui::order_dialog <OrderEntry>  \
            $self [mymethod OrderEntry]
        notifier bind ::adb        <nbhoods>   $self [mymethod EntityNbhood]
        
        # TBD: Should be ::adb.nbhood
        notifier bind ::adb.nbhood <Stack>     $self [mymethod NbhoodStack]
        notifier bind ::adb        <units>     $self [mymethod EntityUnit]
        notifier bind ::adb        <absits>    $self [mymethod EntityAbsit]
        notifier bind ::adb        <groups>    $self [mymethod EntityGroup]
        notifier bind ::adb        <econ_n>    $self [mymethod EntityEcon]

        # NEXT, draw everything for the current map, whatever it is.
        $self dbsync
    }

    destructor {
        notifier forget $self
    }

    # AddModeTool mode icon tooltip
    #
    # mode       The mapcanvas(n) mode name
    # icon       The icon to display on the button
    # tooltip    Dynamic help string

    method AddModeTool {mode icon tooltip} {
        ttk::radiobutton $win.vbar.$mode           \
            -style       Toolbutton                \
            -variable    [myvar info(mode)]        \
            -image       ${type}::icon::$icon      \
            -value       $mode                     \
            -command     [list $canvas mode $mode]

        pack $win.vbar.$mode -side top -fill x -padx {2 3} -pady 3

        DynamicHelp::add $win.vbar.$mode -text $tooltip
    }

    #-------------------------------------------------------------------
    # Event Handlers: Tool Buttons

    # ZoomBoxSet
    #
    # Sets the map zoom to the specified amount.

    method ZoomBoxSet {} {
        scan $view(zoom) "%d" factor
        $canvas zoom $factor
        if {[map image] eq ""} {
            $self DefaultMap $factor
        }
    }

    # FillBoxPost
    #
    # Sets the values for the fillbox on post.

    method FillBoxPost {} {
        $fillbox configure -values $picklist(filltags)
    }

    #-------------------------------------------------------------------
    # Event Handlers: Order Entry

    # OrderEntry tags
    #
    # tags   The tags for the current order field.
    #
    # Detects when we are in order entry mode and when we are not.
    #
    # On leaving order entry mode the transient graphics are deleted.
    #
    # In addition, in order entry mode this sets the viewer to the 
    # appropriate mode for the parameter type. 
    #
    # TBD: In the long run, certain modes shouldn't be allowed in order
    # entry mode.  But unfortunately, pan mode can't be one of them.

    method OrderEntry {tags} {
        # FIRST, handle entering and leaving order entry mode
        if {$tags eq "" && $info(ordertags) ne ""} {
            $canvas delete transient
        }

        set info(ordertags) $tags

        # NEXT, set the mode according to the first tag
        switch -exact -- [lindex $info(ordertags) 0] {
            point   { $self mode point  }
            nbpoint { $self mode point  }
            polygon { $self mode poly   }
            default { $self mode browse }
        }
    }


    # Point-1 ref
    #
    # ref     A map reference string
    #
    # The user has pucked a point in point mode.  If there's an active 
    # order dialog, and the current field type is appropriate, set the 
    # field's value to this point.  Otherwise, propagate the event.

    method Point-1 {ref} {
        if {"point" in $info(ordertags) || "nbpoint" in $info(ordertags)} {
            # FIRST, if nbpoint we must be in a neighborhood.
            if {"nbpoint" in $info(ordertags)} {
                set n [nbhood find {*}[$canvas ref2m $ref]]

                if {$n eq ""} {
                    return
                } else {
                    set data [list nbpoint $ref]
                }
            } else {
                set data [list point $ref]
            }
            
            # NEXT, Delete previous point
            $canvas delete {transient&&point}

            # NEXT, plot the new point
            lassign [$canvas ref2c $ref] cx cy
                
            $canvas create oval [boxaround 3.0 $cx $cy] \
                -outline blue                           \
                -fill    cyan                           \
                -tags    [list transient point]

            # NEXT, notify the app that a point has been selected.
            notifier send ::app <Puck> $data
        } else {
            event generate $win <<Point-1>> -data $ref
        }
    }


    # PolyComplete poly
    #
    # poly     A list of map references defining a polygon
    #
    # The user has drawn a polygon on the map.  If there's an active 
    # order dialog, and the current field type is appropriate, set the 
    # field's value to the polygon coordinates.  Otherwise, propagate 
    # the event.

    method PolyComplete {poly} {
        if {"polygon" in $info(ordertags)} {
            # FIRST, delete existing polygons, and plot the new one.
            $canvas itemconfigure {transient&&polygon} -outline blue

            $canvas create polygon [$canvas ref2c {*}$poly] \
                -outline cyan                               \
                -fill    ""                                 \
                -tags    [list transient polygon]

            # NEXT, notify the app that a polygon has been selected.
            notifier send ::app <Puck> [list polygon $poly]
        } else {
            event generate $win <<PolyComplete>> -data $poly
        }
    }

    #-------------------------------------------------------------------
    # Public Methods: General

    delegate method * to canvas

    # dbsync
    #
    # Clears the map; and redraws the scenario features

    method dbsync {} {
        # FIRST, delete the old map image and projection
        if {$mapimage ne ""} {
            # FIRST, delete the image
            image delete $mapimage
            set mapimage ""
        }

        if {$projection ne ""} {
            $projection destroy
            set projection ""
        }

        # NEXT, load the map.
        rdb eval {
            SELECT width,height,projtype,llat,llon,ulat,ulon,data 
            FROM maps WHERE id=1
        } {
            # May not have an image
            if {$data ne ""} {
                set mapimage [image create photo -format jpeg -data $data]                
            }

            # NEXT, create projection
            set projection [maprect %AUTO% \
                               -width $width -height $height \
                               -minlat $llat -minlon $ulon   \
                               -maxlat $ulat -maxlon $llon] 
        }

        if {$projection eq ""} {
            set projection [maprect %AUTO%]
        }

        # FIRST, get the current projection
        $canvas configure -projection $projection
        $canvas configure -map ""

        # NEXT, clear the canvas
        $canvas clear

        # NEXT, either load the map image or set default
        if {$mapimage ne ""} {
            $canvas configure -map $mapimage
            $canvas refresh
        } else { 
            scan $view(zoom) "%d" factor
            $self DefaultMap $factor
        }

        $self IconDeleteAll

        # NEXT, update the set of fill tags
        $self NbhoodUpdateFillTags

        # NEXT, clear all remembered state, and redraw everything
        $self NbhoodDrawAll
        $self UnitDrawAll
        $self AbsitDrawAll

        # NEXT, set zoom
        set view(zoom)   "[$canvas zoom]%"
    }

    # Method: nbfill
    #
    # Directs the mapviewer to use the specified 
    # neighborhood variable to determine the fill color for each 
    # neighborhood, and enables filling.  Rejects the variable
    # if it:
    #
    #   - Is clearly invalid, or
    #   - Has no associated gradient (required for filling), or
    #   - Has no associated data in the RDB.
    #
    # If the variable is accepted, it is added to the nbfill picklist,
    # possible displacing older picks.

    method nbfill {varname} {
        # FIRST, validate the varname and put it in canonical form.
        set varname [view n validate $varname]

        # NEXT, get the view dict.
        array set vdict [view n get $varname]

        # NEXT, does it have a gradient?
        set gradient [dict get $vdict(meta) $varname gradient]

        if {$gradient eq ""} {
            return -code error -errorcode INVALID \
      "can't use variable as fill: no associated color gradient: \"$varname\""
        }

        if {![rdb exists "SELECT * FROM $vdict(view)"]} {
            return -code error -errorcode INVALID \
                "variable has no associated data in the database: \"$varname\""
        }

        # NEXT, ask the mapviewer to enable filling, and fill!
        set view(fillpoly) [expr {$varname ne "none"}]
        set view(filltag)  $varname

        $self NbhoodFill

        # NEXT, if the variable name is not on the global picklist, add it,
        # and prune old picks.
        if {$varname ni $picklist(recentFills)} {
            set picklist(recentFills) \
                [lrange [linsert $picklist(recentFills) 0 $varname] 0 9]

            $self NbhoodUpdateFillTags
        }

        return
    }
    
    #-------------------------------------------------------------------
    # DefaultMap
    #
    # zoom   - the current zoom factor of the map viewer
    #
    # This method is called if there's no map image data to display on
    # the mapcanvas(n).  It set's the default map image as a 
    # matrix of plus signs

    method DefaultMap {zoom} {
        let frac {double($zoom/100.0)}

        # FIRST, load up the data from the default background array
        # and scale it according to zoom factor
        let px    {int($dmap(width)  * $frac)}
        let py    {int($dmap(height) * $frac)}
        let dx    {int($dmap(dx)     * $frac)}
        let dy    {int($dmap(dy)     * $frac)}
        let len   {int($dmap(ll)     * $frac)}

        set color $dmap(color)

        # NEXT, create the plus signs as canvas line objects and make
        # sure they are at the bottom of the display stack
        for {set x $dx} {$x < $px} {incr x $dx} {
            for {set y $dy} {$y < $py} {incr y $dy} {
                # Horizontal part
                let x1 {$x-$len}
                let x2 {$x+$len+1}
                set l [$canvas create line $x1 $y $x2 $y -fill $color]
                $canvas lower $l all

                # Vertical part
                let y1 {$y-$len}
                let y2 {$y+$len+1}
                set l [$canvas create line $x $y1 $x $y2 -fill $color]
                $canvas lower $l all
            }
        }
    }

    #===================================================================
    # Neighborhood Display and Behavior
    #
    # The mapcanvas(n) has a basic ability to display neighborhoods. 
    # This section of mapviewer(n) provides the glue between the 
    # mapcanvas(n) and the remainder of the application.

    #-------------------------------------------------------------------
    # Neighborhood Instance Variables

    # nbhoods array:  maps between neighborhood names and canvas IDs.
    #
    #     $id is canvas nbhood ID
    #     $n  is "n" column from nbhoods table.
    #
    # n-$id      n, given ID
    # id-$n      id, given n
    # trans      Transient $n, used in event bindings
    # transref   Transient mapref, used in event bindings

    variable nbhoods -array { }

    #-------------------------------------------------------------------
    # Neighborhood Display

    # NbhoodRedrawAll
    #
    # Clears and redraws all neighborhoods

    method NbhoodRedrawAll {} {
        foreach id [$canvas nbhood ids] {
            $canvas nbhood delete $id
        }

        $self NbhoodDrawAll
    }

    # NbhoodDrawAll
    #
    # Draws all neighborhoods

    method NbhoodDrawAll {} {
        array unset nbhoods

        # NEXT, add neighborhoods
        rdb eval {
            SELECT n, refpoint, polygon 
            FROM nbhoods
            ORDER BY stacking_order
        } {
            $self NbhoodDraw $n $refpoint $polygon
        }

        # NEXT, reveal obscured refpoints
        $self NbhoodShowObscured

        # NEXT, fill them, or not.
        $self NbhoodFill

        # NEXT, check that neighborhoods fit inside map area
        $self NbhoodBoundsCheck
    }


    # NbhoodDraw n refpoint polygon
    #
    # n          The neighborhood ID
    # refpoint   The neighborhood's reference point
    # polygon    The neighborhood's polygon

    method NbhoodDraw {n refpoint polygon} {
        # FIRST, if there's an existing neighborhood called this,
        # delete it.
        if {[info exists nbhoods(id-$n)]} {
            $canvas nbhood delete $nbhoods(id-$n)
            unset nbhoods(n-$nbhoods(id-$n))
            unset nbhoods(id-$n)
        }

        # NEXT, draw it.
        set id [$canvas nbhood create $refpoint $polygon]

        # NEXT, fill it if necessary.
        if {$view(fillpoly)} {
            $canvas nbhood configure $id -fill white
        }

        # NEXT, save the name by the ID.
        set nbhoods(n-$id) $n
        set nbhoods(id-$n) $id
    }
    
    # compatible pdict
    #
    # pdict   - optional dictionary of projection information
    #
    # This method checks to see if the data in the supplied projection
    # dictionary is compatible with the current laydown of neighborhoods. If 
    # no dictionary is supplied then the current projection is used to 
    # determine if any neighborhoods are outside the bounds of the map.
    #
    # TBD: may support different projection types in the future. For now
    # only rectangular projection is recognized

    method Compatible {} {
        # FIRST, if there are no neighborhoods, then it's always compatible
        if {[llength [nbhood names]] == 0} {
            return 1
        }

        # NEXT check projection bounds against nbhood bounding box
        set minlat [$projection cget -minlat]
        set minlon [$projection cget -minlon]
        set maxlat [$projection cget -maxlat]
        set maxlon [$projection cget -maxlon]

        lassign [nbhood bbox] nminlat nminlon nmaxlat nmaxlon
        return [expr {$nminlon > $minlon && $nminlat > $minlat &&
                      $nmaxlat < $maxlat && $nmaxlon < $maxlon}]
    }

    # NbhoodBoundsCheck
    #
    # Checks to see that all neighborhood boundaries fit within the
    # defined map area

    method NbhoodBoundsCheck {} {
        if {![$self Compatible]} {
            set info(check) "Neighborhood(s) extend beyond map"
            $win.hbar.check configure -foreground red
        } else {
            set info(check) ""
            $win.hbar.check configure -foreground ""
        }
    }

    # NbhoodFill
    #
    # Fills the neighborhood polygons according to the current
    # FillPoly setting

    method NbhoodFill {} {
        # FIRST, get the fill type, and retrieve nbhood moods if need be.
        if {!$view(fillpoly)} {
            set fill ""
        } else {
            set fill data

            array set vdict [view n get $view(filltag)]

            array set data [rdb eval "SELECT n, x0 FROM $vdict(view)"]

            set gradient [dict get $vdict(meta) $view(filltag) gradient]
        }
        
        # NEXT, fill the nbhoods
        foreach id [$canvas nbhood ids] {
            set n $nbhoods(n-$id)

            if {$fill eq "data"} {
                if {[info exists data($n)] && $data($n) ne ""} {
                    set color [$gradient color $data($n)]
                } else {
                    set color ""
                }
            } else {
                set color ""
            }

            $canvas nbhood configure $id -fill $color
        }
    }

    # NbhoodShowObscured
    #
    # Shows the obscured status of each neighborhood by lighting
    # up the refpoint.

    method NbhoodShowObscured {} {
        rdb eval {
            SELECT n,obscured_by FROM nbhoods
        } {
            if {$obscured_by ne ""} {
                $canvas nbhood configure $nbhoods(id-$n) -pointcolor red
            } else {
                $canvas nbhood configure $nbhoods(id-$n) -pointcolor black
            }
        }
    }

    # NbhoodUpdateFillTags
    #
    # Updates the list of nbhood fill tags on the toolbar

    method NbhoodUpdateFillTags {} {
        # FIRST, get the recent fill tags, verifying that they are
        # still good.
        set tags [list]

        foreach tag $picklist(recentFills) {
            if {[view n exists $tag]} {
                lappend tags $tag
            }
        }

        # NEXT, add the standard fill tags, if they aren't
        # already on the list.
        set standards $defaultFills

        foreach g [frcgroup names] {
            lappend standards "nbcoop.$g"
        }

        foreach tag $standards {
            if {$tag ni $tags} {
                lappend tags $tag
            }
        }

        # NEXT, clear the selected fill tag if it is no longer
        # available.

        if {$view(filltag) ni $tags} {
            set view(filltag) none

            if {$view(fillpoly)} {
                $self NbhoodFill
            }
        }

        # NEXT, save the list of tags.
        set picklist(filltags) $tags
    }

    #-------------------------------------------------------------------
    # Neighborhood Context Menu

    # CreateNbhoodContextMenu
    #
    # Creates the context menu

    method CreateNbhoodContextMenu {} {
        set mnu [menu $canvas.nbhoodmenu]

        $mnu add command \
            -label   "Browse Neighborhood Detail" \
            -command [mymethod NbhoodBrowseDetail]

        cond::available control \
            [menuitem $mnu command "Create Abstract Situation" \
                 -command [mymethod NbhoodCreateAbsitHere]]         \
            order ABSIT:CREATE

        $mnu add separator

        cond::available control \
            [menuitem $mnu command "Bring Neighborhood to Front" \
                 -command [mymethod NbhoodBringToFront]]         \
            order NBHOOD:RAISE

        cond::available control \
            [menuitem $mnu command "Send Neighborhood to Back" \
                 -command [mymethod NbhoodSendToBack]]         \
            order NBHOOD:LOWER
    }


    # NbhoodBrowseDetail
    #
    # Displays the neighborhood's detail page in the detail
    # browser.

    method NbhoodBrowseDetail {} {
        app show my://app/nbhood/$nbhoods(trans)
    }


    # NbhoodCreateAbsitHere
    #
    # Pops up the create absit dialog with this location filled in.

    method NbhoodCreateAbsitHere {} {
        app enter ABSIT:CREATE location $nbhoods(transref)
    }


    # NbhoodBringToFront
    #
    # Brings the transient neighborhood to the front

    method NbhoodBringToFront {} {
        flunky senddict gui NBHOOD:RAISE [list n $nbhoods(trans)]
    }


    # NbhoodSendToBack
    #
    # Sends the transient neighborhood to the back

    method NbhoodSendToBack {} {
        flunky senddict gui NBHOOD:LOWER [list n $nbhoods(trans)]
    }

    #-------------------------------------------------------------------
    # Event Handlers: mapcanvas(n)

    # Nbhood-1 id
    #
    # id      A nbhood canvas ID
    #
    # Called when the user clicks on a nbhood.  First, support pucking 
    # of neighborhoods into orders.  Next, translate it to a 
    # neighborhood ID and forward for use by the containing appwin(sim).

    method Nbhood-1 {id} {
        notifier send ::app <Puck> [list nbhood $nbhoods(n-$id)]

        event generate $win <<Nbhood-1>> -data $nbhoods(n-$id)
    }

    
    # Nbhood-3 id rx ry wx wy
    #
    # id      A nbhood canvas ID
    # rx,ry   Root window coordinates
    #
    # Called when the user right-clicks on a nbhood.  Pops up the
    # neighborhood context menu.

    method Nbhood-3 {id rx ry wx wy} {
        set nbhoods(trans)    $nbhoods(n-$id)
        set nbhoods(transref) [$canvas w2ref $wx $wy]

        tk_popup $canvas.nbhoodmenu $rx $ry
    }


    #-------------------------------------------------------------------
    # Event Handlers: notifier(n)

    # EntityNbhood delete n
    #
    # n     The neighborhood ID
    #
    # Delete the neighborhood from the mapcanvas.

    # EntityNbhood update n
    #
    # n     The neighborhood ID
    #
    # Something changed about neighborhood n.  Update it.

    method {EntityNbhood update} {n} {
        # FIRST, get the nbhood data we care about
        rdb eval {SELECT refpoint, polygon FROM nbhoods WHERE n=$n} {}

        # NEXT, if this is a new neighborhood, just draw it;
        # otherwise, update the refpoint and polygon
        if {![info exists nbhoods(id-$n)]} {
            $self NbhoodDraw $n $refpoint $polygon
        } else {
            $canvas nbhood point $nbhoods(id-$n)   $refpoint
            $canvas nbhood polygon $nbhoods(id-$n) $polygon
        }

        # NEXT, show refpoints obscured by the change
        $self NbhoodShowObscured

        # NEXT, check for nbhoods outside map boundaries
        $self NbhoodBoundsCheck
    }

    method {EntityNbhood delete} {n} {
        # FIRST, delete it from the canvas
        $canvas nbhood delete $nbhoods(id-$n)

        # NEXT, delete it from the mapviewer's data.
        set id $nbhoods(id-$n)
        unset nbhoods(n-$id)
        unset nbhoods(id-$n)

        # NEXT, show refpoints revealed by the change
        $self NbhoodShowObscured

        # NEXT, check for nbhoods outside map boundaries
        $self NbhoodBoundsCheck
    }
      

    # NbhoodStack
    #
    # The neighborhood stacking order has changed; redraw all
    # neighborhoods

    method NbhoodStack {} {
        $self NbhoodRedrawAll
    }

    #-------------------------------------------------------------------
    # Public Methods: Neighborhoods

    # nbhood configure n option value...
    #
    # n    A neighborhood name
    #
    # Configures the neighborhood polygon in the mapcanvas given
    # the neighborhood name, rather than the canvas ID

    method {nbhood configure} {n args} {
        $canvas nbhood configure $nbhoods(id-$n) {*}$args
    }


    # nbhood cget n option
    #
    # n       A neighborhood name
    # option  An option name
    #
    # Retrieves the option's value for the neighborhood given 
    # the neighborhood name, rather than the canvas ID

    method {nbhood cget} {n option} {
        $canvas nbhood cget $nbhoods(id-$n) $option
    }



    #===================================================================
    # Icon Display and Behavior
    #
    # Eventually we will have many different kinds of icon: units,
    # situations, sites, etc.  This section covers the general 
    # behavior, including dispatch of mapcanvas(n) events to 
    # other sections.

    #-------------------------------------------------------------------
    # Instance Variables

    # icons array: 
    #
    #   $cid is canvas icon ID
    #   $sid is scenario ID:
    #        For units: "u" column from units table.
    #
    #   sid-$cid      sid, given cid
    #   cid-$sid      cid, given sid
    #   itype-$cid    Icon type, given cid
    #   context       Transient sid, using in context menu bindings
   
    variable icons -array { }

    #-------------------------------------------------------------------
    # Helper Routines

    method IconDeleteAll {} {
        # Deletes all icons, clears metadata
        array unset icons
        $canvas icon delete all
    }

    # IconDelete sid
    #
    # sid     An icon's scenario ID
    #
    # Deletes an icon given its scenario ID

    method IconDelete {sid} {
        # FIRST, delete it from the canvas
        set cid $icons(cid-$sid)
        $canvas icon delete $cid

        # NEXT, delete it from the mapviewer's data.
        unset icons(sid-$cid)
        unset icons(itype-$cid)
        unset icons(cid-$sid)

        # NEXT, clear the context; the icon might not be there
        # any more
        set icons(context) ""
    }

    # IconExists sid
    #
    # Returns 1 if there's an icon with the given sid, and 0 otherwise.

    method IconExists {sid} {
        return [info exists icons(cid-$sid)]
    }



    #-------------------------------------------------------------------
    # Event Handlers: mapcanvas(n)

    # canupdate
    #
    # returns 1 if you can update the icon, and 0 otherwise.

    method canupdate {} {
        if {![info exists icons(context)] ||
            $icons(context) eq ""} {
            return 0
        }

        set sid $icons(context)

        # If the icon once exist but has been deleted, forget
        # it and return 0.
        if {![info exists icons(cid-$sid)]} {
            set icons(context) ""
            return 0
        }

        set cid $icons(cid-$sid)
        set itype $icons(itype-$cid)

        if {$itype eq "situation"} {
            return [expr {$sid in [absit initial names]}]
        } else {
            return 1
        }
    }



    # Icon-1 cid
    #
    # cid      A canvas icon ID
    #
    # Called when the user clicks on an icon.  First, support pucking 
    # of icons into orders.  Next, translate it to a scenario ID
    # and forward as the appropriate kind of entity.

    method Icon-1 {cid} {
        notifier send ::app <Puck> \
            [list $icons(itype-$cid) $icons(sid-$cid)]

        set sid $icons(sid-$cid)

        switch $icons(itype-$cid) {
            unit      { event generate $win <<Unit-1>>  -data $sid }
            situation { event generate $win <<Absit-1>> -data $sid }
        } 
    }

 
    # Icon-3 cid rx ry
    #
    # cid     A canvas icon ID
    # rx,ry   Root window coordinates
    #
    # Called when the user right-clicks on an icon.  Pops up the
    # icon context menu.

    method Icon-3 {cid rx ry} {
        # FIRST, save the context.
        set icons(context) $icons(sid-$cid)

        # NEXT, Update any menu items that depend on this condition
        cond::availableCanUpdate update

        # NEXT, popup the menu
        switch -exact $icons(itype-$cid) {
            situation {
                tk_popup $canvas.absitmenu $rx $ry
            }

            unit {
                tk_popup $canvas.unitmenu $rx $ry
            }
        }
    }


    # IconMoved cid
    #
    # cid    A canvas icon ID
    #
    # Called when the user drags an icon.  Moves the underlying
    # scenario object to the desired location.

    method IconMoved {cid} {
        switch -exact $icons(itype-$cid) {
            unit {
                if {[catch {
                    flunky senddict gui UNIT:MOVE [list  \
                        u        $icons(sid-$cid)        \
                        location [$canvas icon ref $cid]]
                }]} {
                    $self UnitDrawSingle $icons(sid-$cid)
                }
            }

            situation {
                if {[catch {
                    flunky senddict gui ABSIT:MOVE [list \
                        s        $icons(sid-$cid)        \
                        location [$canvas icon ref $cid]]
                }]} {
                    $self AbsitDrawSingle $icons(sid-$cid)
                }
            }
        }
    }

    # IconDrawAll
    #
    # Clears and redraws all icons

    method IconDrawAll {} {
        $self UnitDrawAll
        $self AbsitDrawAll
    }


    #===================================================================
    # Unit Display and Behavior

    #-------------------------------------------------------------------
    # Unit Display

    # UnitDrawAll
    #
    # Clears and redraws all units

    method UnitDrawAll {} {
        rdb eval {
            SELECT * FROM units_view
            WHERE active
        } row {
            $self UnitDraw [array get row]
        } 
    }

    # UnitDraw parmdict
    #
    # parmdict   Data about the unit

    method UnitDraw {parmdict} {
        dict with parmdict {
            # FIRST, if there's an existing unit called this,
            # delete it.
            if {[info exists icons(cid-$u)]} {
                $self IconDelete $u
            }

            # NEXT, if we only draw certain group types.
            if {!$view($gtype)} {
                return
            }

            # NEXT, we only draw active units.
            if {!$active} {
                return
            }

            # NEXT, if the unit is an empty civilian unit, skip it.
            if {$gtype eq "CIV" && $personnel == 0} {
                return
            }

            # NEXT, set background color
            set bg black

            if {$personnel == 0} {
                set bg gray
            }

            # NEXT, get text
            if {$view(names)} {
                set unitText $g

                if {$a ne "NONE"} {
                    append unitText "\n$a"
                }
            } else {
                set unitText ""
            }
    
            # NEXT, draw it.
            set cid [$canvas icon create unit  \
                         {*}$location          \
                         -foreground $color    \
                         -background $bg       \
                         -text       $unitText]
            
            # NEXT, save the name by the ID.
            set icons(itype-$cid) unit
            set icons(sid-$cid) $u
            set icons(cid-$u)   $cid
        }
    }

    # UnitDrawSingle u
    #
    # u    The name of the unit.
    #
    # Redraws just unit u.  Use this when only a single unit is
    # to be redrawn.

    method UnitDrawSingle {u} {
        rdb eval {
            SELECT * FROM units_view
            WHERE u=$u
        } row {
            $self UnitDraw [array get row]
        } 
    }

    #-------------------------------------------------------------------
    # Context Menu

    # CreateUnitContextMenu
    #
    # Creates the context menu

    method CreateUnitContextMenu {} {
        set mnu [menu $canvas.unitmenu]

        $mnu add command \
            -label   "Browse Group Detail" \
            -command [mymethod UnitBrowseDetail]
    }

    # UnitBrowseDetail
    #
    # Displays the group detail browser page for this unit's 
    # group.

    method UnitBrowseDetail {} {
        set g [unit get $icons(context) g]

        app show my://app/group/$g
    }

    

    #-------------------------------------------------------------------
    # Event Handlers: notifier(n)

    # EntityUnit update n
    #
    # n     The unit ID
    #
    # Something changed about unit n.  Update it.

    method {EntityUnit update} {u} {
        $self UnitDrawSingle $u
    }


    # EntityUnit delete u
    #
    # u     The unit ID
    #
    # Delete the unit from the mapcanvas.

    method {EntityUnit delete} {u} {
        # There's an icon only if the unit is currently active.
        if {[$self IconExists $u]} {
            $self IconDelete $u
        }
    }
      
    #===================================================================
    # Absit Display and Behavior

    #-------------------------------------------------------------------
    # Absit Display

    # AbsitDrawAll
    #
    # Clears and redraws all absits

    method AbsitDrawAll {} {
        rdb eval {
            SELECT * FROM absits
        } row {
            $self AbsitDraw [array get row]
        } 

    }

    # AbsitDraw parmdict
    #
    # parmdict   Data about the absit

    method AbsitDraw {parmdict} {
        dict with parmdict {
            # FIRST, if there's an existing absit called this,
            # delete it.
            if {[info exists icons(cid-$s)]} {
                $self IconDelete $s
            }

            # NEXT, if we are not drawing absits, don't draw it.
            if {!$view(absits)} {
                return
            }

            # NEXT, determine the text.
            if {$view(names)} {
                set text $stype
            } else {
                set text ""
            }


            # NEXT, draw it.
            set cid [$canvas icon create situation \
                         {*}$location              \
                         -text $text]

            if {$state eq "INITIAL"} {
                $canvas icon configure $cid -foreground red
                $canvas icon configure $cid -background white
            } elseif {$state eq "RESOLVED"} {
                $canvas icon configure $cid -foreground "#009900"
                $canvas icon configure $cid -background white
            } else {
                $canvas icon configure $cid -foreground red
                $canvas icon configure $cid -background yellow
            }
            
            # NEXT, save the name by the ID.
            set icons(itype-$cid) situation
            set icons(sid-$cid) $s
            set icons(cid-$s)   $cid
        }
    }

    # AbsitDrawSingle s
    #
    # s    The ID of the absit.
    #
    # Redraws just absit s.  Use this when only a single absit is
    # to be redrawn.
    # 
    # Note that s might be any situation; make sure that non-absits
    # are ignored.

    method AbsitDrawSingle {s} {
        # FIRST, draw it, if it's current.
        rdb eval {
            SELECT * FROM absits
            WHERE s=$s
        } row {
            $self AbsitDraw [array get row]
            return
        } 

        # NEXT, the absit is no longer current; delete the icon.
        if {[info exists icons(cid-$s)]} {
            $self IconDelete $s
        }
    }


    #-------------------------------------------------------------------
    # Absit Context Menu

    # CreateAbsitContextMenu
    #
    # Creates the context menu

    method CreateAbsitContextMenu {} {
        set mnu [menu $canvas.absitmenu]

        cond::availableCanUpdate control \
            [menuitem $mnu command "Update Situation" \
                 -command [mymethod UpdateAbsit]] \
            order ABSIT:UPDATE browser $win
    }

    # UpdateAbsit
    #
    # Pops up the "Update Abstract Situation" dialog for this unit

    method UpdateAbsit {} {
        app enter ABSIT:UPDATE s $icons(context)
    }

    #-------------------------------------------------------------------
    # Event Handlers: notifier(n)

    # EntityAbsit update s
    #
    # s     The absit ID
    #
    # Something changed about absit s.  Update it.
    #
    # Note that s might be any situation; make sure that non-absits
    # are ignored.

    method {EntityAbsit update} {s} {
        $self AbsitDrawSingle $s
    }

    # EntityAbsit delete s
    #
    # s     The absit ID
    #
    # Delete the absit from the mapcanvas.
    #
    # Note that s might be any situation; make sure that non-absits
    # are ignored.

    method {EntityAbsit delete} {s} {
        # FIRST, Delete the icon only if it actually exists.
        if {[info exists icons(cid-$s)]} {
            $self IconDelete $s
        }
    }
      
    #===================================================================
    # Group Entity Event Handlers

    # EntityGroup op g
    #
    # op    The operation
    # g     The group ID
    #
    # A group was created/updated/deleted.
    #
    # * Update the list of nbhood fill tags.
    # * If the group was updated, redraw units; their shapes or
    #   colors might have changed.
    #
    # TBD: It appears that these things can change in PREP only,
    # when it doesn't matter.

    method EntityGroup {op g} { 
        $self NbhoodUpdateFillTags

        if {$op eq "update"} {
            $self UnitDrawAll
        }
    }

    #===================================================================
    # Economics Entity Event Handlers

    # EntityEcon op n
    #
    # op   The operation
    # n    The nbhood ID
    #
    # If nbhood data was changed for the economic model, update the
    # nbhood colors.

    method EntityEcon {op g} {
        $self NbhoodFill
    }
}





