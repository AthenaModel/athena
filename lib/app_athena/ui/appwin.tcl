#-----------------------------------------------------------------------
# TITLE:
#    appwin.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Main application window
#
#    This window is implemented as snit::widget; however, it's set up
#    to exit the program when it's closed, just like ".".  It's expected
#    that "." will be withdrawn at start-up.
#
#    Because this is an application window, it can make use of
#    application-wide resources, such as the RDB.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appwin

snit::widget appwin {
    hulltype toplevel
    widgetclass Topwin

    #-------------------------------------------------------------------
    # Lookup Variables

    # Dictionary of duration values by label strings 
    # for the durations pulldown
    typevariable durations {
        "1 week"         1
        "2 weeks"        2
        "3 weeks"        3
        "4 weeks"        4
        "5 weeks"        5
        "6 weeks"        6
        "7 weeks"        7
        "8 weeks"        8
        "10 weeks"       10
        "12 weeks"       12
        "24 weeks"       24
        "26 weeks"       26
        "36 weeks"       36
        "48 weeks"       48
        "1 year"         52
        "2 years"        104
    }

    #-------------------------------------------------------------------
    # Components

    component reloader              ;# timeout(n) that reloads content
    component editmenu              ;# The Edit menu
    component viewmenu              ;# The View menu
    component toolbar               ;# The main toolbar
    component simtools              ;# The simulation controls
    component cli                   ;# The cli(n) pane
    component msgline               ;# The messageline(n)
    component content               ;# The content notebook
    component viewer -public viewer ;# The mapviewer(n)
    component slog                  ;# The scrolling log
    component wmswin                ;# The WMS import toplevel
 
    #-------------------------------------------------------------------
    # Options

    delegate option * to hull

    # -dev flag
    #
    # If true, display the development tabs.  Otherwise not.

    option -dev \
        -default  0   \
        -readonly yes

    #-------------------------------------------------------------------
    # Instance variables

    # Dictionary of tabs to be created.
    #
    # label   - The tab text
    # vistype - The tab's visibility type.  See "visibility", below.
    # parent  - The tag of the parent tab, or "" if this is a top-level
    #           tab.
    # script  - Widget command (and options) to create the tab.
    #           "%W" is replaced with the name of the widget contained
    #           in the new tab.  For tabs containing notebooks, the
    #           script is "".
    # tabwin  - Once the tab is created, its window.

    variable tabs {
        detail {
            label   "Detail"
            vistype "*"
            parent  ""
            script  { detailbrowser %W }
        }

        strategyt {
            label   "Strategy"
            vistype *
            parent  ""
            script  ""
        }

        strategy {
            label   "Editor"
            vistype *
            parent  strategyt
            script  { strategybrowser %W }
        }

        physical {
            label   "Physical"
            vistype *
            parent  ""
            script  ""
        }

        map {
            label   "Map"
            vistype *
            parent  physical
            script  { mapviewer %W -width 600 -height 400 }
        }

        nbhoods {
            label   "Neighborhoods"
            vistype *
            parent  physical
            script  { nbhoodbrowser %W }
        }

        prox {
            label   "Proximities"
            vistype *
            parent  physical
            script  { nbrelbrowser %W }
        }

        absit {
            label   "AbSits"
            vistype *
            parent  physical
            script  { absitbrowser %W }
        }

        curses {
            label   "CURSEs"
            vistype *
            parent physical
            script { cursebrowser %W }
        }

        security {
            label   "Security"
            vistype simulation
            parent  physical
            script  { securitybrowser %W }
        }

        activity {
            label   "Activity"
            vistype simulation
            parent  physical
            script  { activitybrowser %W }
        }

        demogn {
            label   "NbhoodDemog"
            vistype simulation
            parent  "physical"
            script  { demognbrowser %W }
        }


        pol {
            label "Political"
            vistype *
            parent ""
            script ""
        }

        actors {
            label   "Actors"
            vistype *
            parent  pol
            script  { actorbrowser %W }
        }

        vrel {
            label   "VRel"
            vistype *
            parent  pol
            script  { vrelbrowser %W }
        }

        mil {
            label "Military"
            vistype *
            parent ""
            script ""
        }

        frcgroups {
            label   "Force Groups"
            vistype *
            parent  mil
            script  { frcgroupbrowser %W }
        }   


        econt {
            label   "Economics"
            vistype *
            parent  ""
            script  ""
        }

        econcontrol {
            label   "Control"
            vistype *
            parent  econt
            script  { econtrol %W }
        }

        econsam {
            vistype *
            label   "SAM"
            parent  econt
            script  { samsheet %W }
        }

        econcge {
            vistype simulation
            label   "Overview"
            parent  econt
            script  { cgesheet %W }
        }

        econexp {
            label   "Expenditures"
            vistype simulation
            parent  econt
            script  { econexpbrowser %W }
        }

        econpop {
            label   "Population"
            vistype simulation
            parent  econt
            script  { econpopbrowser %W }
        }

        econg {
            label   "Groups"
            vistype simulation
            parent  econt
            script  { econngbrowser %W }
        }

        social {
            label   "Social"
            vistype *
            parent  ""
            script  "" 
        }

        bsys {
            label   "Beliefs"
            vistype *
            parent  social
            script  { bsysbrowser %W }
        }

        civgroups {
            label   "CivGroups"
            vistype *
            parent  social
            script  { civgroupbrowser %W }
        }

        orggroups {
            label   "OrgGroups"
            vistype *
            parent  social
            script  { orggroupbrowser %W }
        }

        sat {
            label   "Satisfaction"
            vistype *
            parent  social
            script  { satbrowser %W }
        }

        hrel {
            label   "HRel"
            vistype *
            parent  social
            script  { hrelbrowser %W }
        }

        demogg {
            label   "Demog"
            vistype simulation
            parent  "social"
            script  { demogbrowser %W }
        }



        infra {
            label   "Infrastructure"
            vistype *
            parent  ""
            script  "" 
        }

        caps {
            label  "CAPs"
            vistype *
            parent infra
            script { capbrowser %W }
        }

        plants {
            label   "GOODS Plants"
            vistype  *
            parent   infra
            script   { plantbrowser %W }
        }

        info {
            label   "Information"
            vistype *
            parent  ""
            script  ""
        }

        coop {
            label   "Cooperation"
            vistype *
            parent  info
            script  { coopbrowser %W }
        }

        nbcoop {
            label   "NbhoodCoop"
            vistype simulation
            parent  info
            script  { nbcoopbrowser %W }
        }

        hooks {
            label   "Semantic Hooks"
            vistype *
            parent  info
            script  {hookbrowser %W}

        }

        ioms {
            label   "Info Ops Messages"
            vistype *
            parent  info
            script  {iombrowser %W}
        }

        timet {
            label   "Time"
            vistype *
            parent  ""
            script ""
        }

        sigevent {
            label   "Significant Events"
            vistype *
            parent  timet
            script  { sigeventbrowser %W }
        }

        orders {
            label   "Orders"
            vistype orders
            parent  timet
            script  { 
                ordersentbrowser %W
            }
        }

        slog {
            label   "Log"
            vistype slog
            parent  timet
            script  {
                scrollinglog %W \
                    -relief        flat                \
                    -height        20                  \
                    -logcmd        [mymethod puts]     \
                    -loglevel      "normal"            \
                    -showloglist   yes                 \
                    -rootdir       [workdir join log]  \
                    -defaultappdir app_sim             \
                    -format        {
                        {week 7 yes}
                        {v    7 yes}
                        {c    9 yes}
                        {m    0 yes}
                    }
            }
        }

        scripts {
            label "Scripts"
            vistype scripts
            parent ""
            script {
                scriptbrowser %W
            }
        }
    }


    # Status info
    #
    # mode        Window mode, scenario or simulation
    # simstate    Current simulation state
    # tick        Current sim time as a four-digit tick 
    # date        Current sim time as a week(n) string.

    variable info -array {
        mode           scenario
        simstate       ""
        tick           "0000"
        date           ""
    }

    # Visibility Array: this array determines whether or not various 
    # components are visible in the window.  The key is a "visibility
    # type", or "vistype"; components with the same vistype are visible
    # or hidden together.
    #
    # *          - Used to tag tabs that are always visible.
    # scenario   - Visible in scenario mode
    # simulation - Visible in simulation mode
    # orders     - Order tabs; visible in -dev mode or on request.
    # slog       - Scrolling log; visible in -dev mode, on request, or
    #              on error.
    # scripts    - Scripts editor tab; visible in -dev mode or on request.
    # cli        - Command-line Interface; visible in -dev mode or on
    #              request.

    variable visibility -array {
        *           1
        scenario    1
        simulation  0
        orders      0
        slog        0
        scripts     0
        cli         0
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, withdraw the hull widget, until it's populated.
        wm withdraw $win

        # NEXT, get the options
        $self configurelist $args

        # FIRST, create the timeout controlling reload requests.
        install reloader using timeout ${selfns}::reloader \
            -command    [mymethod ReloadContent]           \
            -interval   1                                  \
            -repetition no

        # NEXT, enable the development tabs
        set visibility(orders)  $options(-dev)
        set visibility(slog)    $options(-dev)
        set visibility(scripts) $options(-dev)
        set visibility(cli)     $options(-dev)

        # NEXT, Exit the app when this window is closed.
        wm protocol $win WM_DELETE_WINDOW [mymethod FileExit]

        # NEXT, set the icon for this and subsequent windows on X11.
        if {[tk windowingsystem] eq "x11"} {
            set icon [image create photo \
                          -file [file join $::app_athena::library icon.png]]
            wm iconphoto $win -default $icon
        }

        # NEXT, Allow the developer to pop up the debugger.
        bind all <Control-F12> [list debugger new]

        # NEXT, Create the major window components
        $self CreateMenuBar
        $self CreateComponents

        # NEXT, Allow the created widget sizes to propagate to
        # $win, so the window gets its default size; then turn off 
        # propagation.  From here on out, the user is in control of the 
        # size of the window.

        update idletasks
        grid propagate $win off

        # NEXT, Prepare to receive notifier events.
        notifier bind ::sim      <DbSyncB>       $self [mymethod reload]
        notifier bind ::scenario <ScenarioSaved> $self [mymethod reload]
        notifier bind ::sim      <State>         $self [mymethod SimState]
        notifier bind ::sim      <Time>          $self [mymethod SimTime]
        notifier bind ::app      <Prefs>         $self [mymethod AppPrefs]

        # NEXT, Prepare to receive window events
        bind $viewer <<Unit-1>>       [mymethod Unit-1   %d]
        bind $viewer <<Absit-1>>      [mymethod Absit-1  %d]
        bind $viewer <<Nbhood-1>>     [mymethod Nbhood-1 %d]

        # NEXT, restore the window
        wm deiconify $win
        raise $win

        # NEXT, Reload content
        $self reload
    }

    destructor {
        notifier forget $self
    }

    # CreateMenuBar
    #
    # Creates the main menu bar

    method CreateMenuBar {} {
        # Menu Bar
        set menubar [menu $win.menubar -relief flat]
        $win configure -menu $menubar
        
        # File Menu
        set mnu [menu $menubar.file]
        $menubar add cascade -label "File" -underline 0 -menu $mnu

        cond::simIsStable control \
            [menuitem $mnu command "New Scenario..."  \
                 -underline 0                         \
                 -accelerator "Ctrl+N"                \
                 -command   [mymethod FileNew]]
        bind $win <Control-n> [mymethod FileNew]
        bind $win <Control-N> [mymethod FileNew]

        $mnu add command \
            -label     "New Detail Browser..."     \
            -underline 4                           \
            -command   [list detailbrowser new]

        cond::simIsStable control \
            [menuitem $mnu command "Open Scenario..." \
                 -underline 0                         \
                 -accelerator "Ctrl+O"                \
                 -command   [mymethod FileOpen]]
        bind $win <Control-o> [mymethod FileOpen]
        bind $win <Control-O> [mymethod FileOpen]

        cond::simIsStable control \
            [menuitem $mnu command "Save Scenario" \
                 -underline   0                    \
                 -accelerator "Ctrl+S"             \
                 -command     [mymethod FileSave]]
        bind $win <Control-s> [mymethod FileSave]
        bind $win <Control-S> [mymethod FileSave]

        cond::simIsStable control \
            [menuitem $mnu command "Save Scenario As..." \
                 -underline 14                           \
                 -command   [mymethod FileSaveAs]]

        cond::simIsPrep control \
            [menuitem $mnu command "Export Scenario As..." \
                 -underline 14                           \
                 -command   [mymethod FileExportAs]]

        $mnu add command                               \
            -label     "Save CLI Scrollback Buffer..." \
            -underline 5                               \
            -command   [mymethod FileSaveCLI]

        $mnu add separator

        cond::available control                  \
            [menuitem $mnu command "Import Map From File..."    \
                 -underline 4                         \
                 -command   [mymethod FileImportMap]] \
            order MAP:IMPORT:FILE

        cond::simIsPrep control                  \
            [menuitem $mnu command "Import Map From WMS..."    \
                 -underline 5                         \
                 -command   [mymethod WmsImportMap]] 

        $mnu add separator

        set submenu [menu $mnu.parm]
        $mnu add cascade -label "Parameters" \
            -underline 0 -menu $submenu

        cond::available control                           \
            [menuitem $submenu command "Import..."           \
                 -underline 0                                \
                 -command   [mymethod FileParametersImport]] \
            order PARM:IMPORT

        $submenu add command \
            -label     "Export..."                     \
            -underline 0                               \
            -command   [mymethod FileParametersExport]
        
        $mnu add separator

        $mnu add command                          \
            -label       "Exit"                   \
            -underline   1                        \
            -accelerator "Ctrl+Q"                 \
            -command     [mymethod FileExit]
        bind $win <Control-q> [mymethod FileExit]
        bind $win <Control-Q> [mymethod FileExit]

        # Edit menu
        set editmenu [menu $menubar.edit \
                          -postcommand [mymethod PostEditMenu]]
        $menubar add cascade -label "Edit" -underline 0 -menu $editmenu

        $editmenu add command                \
            -label       "Undo"              \
            -underline   0                   \
            -accelerator "Ctrl+Z"            \
            -command     [mymethod EditUndo]

        bind $win <Control-z> [mymethod EditUndo]
        bind $win <Control-Z> [mymethod EditUndo]

        $editmenu add command                \
            -label       "Redo"              \
            -underline   0                   \
            -accelerator "Ctrl+Shift+Z"      \
            -command     [mymethod EditRedo]

        bind $win <Shift-Control-z> [mymethod EditRedo]
        bind $win <Shift-Control-Z> [mymethod EditRedo]

        $editmenu add separator
        
        $editmenu add command \
            -label "Cut" \
            -underline 2 \
            -accelerator "Ctrl+X" \
            -command {event generate [focus] <<Cut>>}

        $editmenu add command \
            -label "Copy" \
            -underline 0 \
            -accelerator "Ctrl+C" \
            -command {event generate [focus] <<Copy>>}
        
        $editmenu add command \
            -label "Paste" \
            -underline 0 \
            -accelerator "Ctrl+V" \
            -command {event generate [focus] <<Paste>>}
        
        $editmenu add separator
        
        $editmenu add command \
            -label "Select All" \
            -underline 7 \
            -accelerator "Ctrl+Shift+A" \
            -command {event generate [focus] <<SelectAll>>}

        # View menu
        set viewmenu [menu $menubar.view]
        $menubar add cascade -label "View" -underline 0 -menu $viewmenu

        # The rest of the view menu is added later.


        # Orders menu
        set ordersmenu [menu $menubar.orders]
        $menubar add cascade -label "Orders" -underline 0 -menu $ordersmenu

        # Orders/Simulation
        set submenu [menu $ordersmenu.sim]
        $ordersmenu add cascade -label "Simulation" \
            -underline 0 -menu $submenu
        
        $self AddOrder $submenu SIM:STARTDATE
        $self AddOrder $submenu SIM:STARTTICK
        
        cond::available control \
            [menuitem $submenu command [myorders title SIM:REBASE]... \
                -command [list flunky send gui SIM:REBASE]]    \
                order SIM:REBASE

        # Orders/Unit
        set submenu [menu $ordersmenu.unit]
        $ordersmenu add cascade -label "Unit" \
            -underline 0 -menu $submenu
        
        $self AddOrder $submenu UNIT:MOVE

        # Orders/Situation
        set submenu [menu $ordersmenu.sit]
        $ordersmenu add cascade -label "Situation" \
            -underline 0 -menu $submenu
        
        $self AddOrder $submenu ABSIT:CREATE
        $self AddOrder $submenu ABSIT:MOVE
        $self AddOrder $submenu ABSIT:DELETE
        $self AddOrder $submenu ABSIT:RESOLVE
        $self AddOrder $submenu ABSIT:UPDATE

        # Orders/Magic Attitude Drivers
        set submenu [menu $ordersmenu.mad]
        $ordersmenu add cascade -label "Magic Attitude Driver" \
            -underline 0 -menu $submenu

        $self AddOrder $submenu MAD:CREATE
        $self AddOrder $submenu MAD:UPDATE
        $self AddOrder $submenu MAD:DELETE

        $self AddOrder $submenu MAD:HREL
        $self AddOrder $submenu MAD:VREL
        $self AddOrder $submenu MAD:SAT
        $self AddOrder $submenu MAD:COOP

        # Orders/Actors
        set submenu [menu $ordersmenu.actor]
        $ordersmenu add cascade -label "Actors" \
            -underline 0 -menu $submenu
        
        $self AddOrder $submenu ACTOR:CREATE
        $self AddOrder $submenu ACTOR:UPDATE
        $self AddOrder $submenu ACTOR:INCOME
        $self AddOrder $submenu ACTOR:SUPPORTS
        $self AddOrder $submenu ACTOR:DELETE

        # Orders/Civilian Group
        set submenu [menu $ordersmenu.civgroup]
        $ordersmenu add cascade -label "Civilian Group" \
            -underline 0 -menu $submenu
        
        $self AddOrder $submenu CIVGROUP:CREATE
        $self AddOrder $submenu CIVGROUP:UPDATE
        $self AddOrder $submenu CIVGROUP:DELETE

        # Orders/Force Group
        set submenu [menu $ordersmenu.frcgroup]
        $ordersmenu add cascade -label "Force Group" \
            -underline 0 -menu $submenu
        
        $self AddOrder $submenu FRCGROUP:CREATE
        $self AddOrder $submenu FRCGROUP:UPDATE
        $self AddOrder $submenu FRCGROUP:DELETE

        # Orders/Org Group
        set submenu [menu $ordersmenu.orggroup]
        $ordersmenu add cascade -label "Org Group" \
            -underline 0 -menu $submenu
        
        $self AddOrder $submenu ORGGROUP:CREATE
        $self AddOrder $submenu ORGGROUP:UPDATE
        $self AddOrder $submenu ORGGROUP:DELETE

        # Orders/Neighborhood Menu
        set submenu [menu $ordersmenu.nbhood]
        $ordersmenu add cascade -label "Neighborhood" \
            -underline 0 -menu $submenu
        
        $self AddOrder $submenu NBHOOD:CREATE
        $self AddOrder $submenu NBHOOD:UPDATE
        $self AddOrder $submenu NBHOOD:LOWER
        $self AddOrder $submenu NBHOOD:RAISE
        $self AddOrder $submenu NBHOOD:DELETE
        $self AddOrder $submenu NBREL:UPDATE

        # Orders/Horz. Relationship Menu
        set submenu [menu $ordersmenu.hrel]
        $ordersmenu add cascade -label "Horz. Relationship" \
            -underline 0 -menu $submenu
        
        $self AddOrder $submenu HREL:OVERRIDE
        $self AddOrder $submenu HREL:RESTORE
        $self AddOrder $submenu MAD:HREL
    
        # Orders/Vert. Relationship Menu
        set submenu [menu $ordersmenu.vrel]
        $ordersmenu add cascade -label "Vert. Relationship" \
            -underline 0 -menu $submenu
        
        $self AddOrder $submenu VREL:OVERRIDE
        $self AddOrder $submenu VREL:RESTORE
        $self AddOrder $submenu MAD:VREL
    
        # Orders/Satisfaction Menu
        set submenu [menu $ordersmenu.sat]
        $ordersmenu add cascade -label "Satisfaction" \
            -underline 0 -menu $submenu
        
        $self AddOrder $submenu SAT:UPDATE
        $self AddOrder $submenu MAD:SAT

        # Orders/Cooperation Menu
        set submenu [menu $ordersmenu.coop]
        $ordersmenu add cascade -label "Cooperation" \
            -underline 0 -menu $submenu
        
        $self AddOrder $submenu COOP:UPDATE
        $self AddOrder $submenu MAD:COOP

        # Orders/Comm. Asset Package Menu
        set submenu [menu $ordersmenu.cap]
        $ordersmenu add cascade -label "Comm. Asset Package" \
            -underline 2 -menu $submenu

        $self AddOrder $submenu {
            CAP:CREATE
            CAP:UPDATE
            CAP:DELETE
            CAP:NBCOV:SET
            CAP:PEN:SET
        }

        # Orders/Economics Menu
        set submenu [menu $ordersmenu.econ]
        $ordersmenu add cascade -label "Economics" \
            -underline 0 -menu $submenu
        
        $self AddOrder $submenu ECON:UPDATE:REMRATE
        $self AddOrder $submenu ECON:CGE:UPDATE

        cond::available control \
            [menuitem $submenu command [myorders title ECON:UPDATE:HIST]... \
            -command {app enter ECON:UPDATE:HIST [econ hist]}]    \
            order ECON:UPDATE:HIST

        # Wizard menu
        set wizmenu [menu $menubar.wizmenu]
        $menubar add cascade -label "Wizard" -underline 0 -menu $wizmenu

        cond::simIsPrep control \
            [menuitem $wizmenu command "Neighborhood Ingestion..." \
                 -underline 0                         \
                 -command   [list wnbhood::wizard invoke]]

        # Help menu
        set helpmenu [menu $menubar.helpmenu]
        $menubar add cascade -label "Help" -underline 0 -menu $helpmenu

        $helpmenu add command                      \
            -label       "Help Contents"           \
            -underline   0                         \
            -accelerator "F1"                      \
            -command     [list app show my://help]

        bind $win <F1> [list app show my://help]

        $helpmenu add command                           \
            -label       "Application Menus"            \
            -underline   0                              \
            -command     [list app show my://help/menu]

        $helpmenu add command                    \
            -label       "Application Tabs"      \
            -underline   0                       \
            -command     [list app show my://help/tab]

        $helpmenu add command                    \
            -label       "Orders"                \
            -underline   0                       \
            -command     [list app show my://help/order]

        $helpmenu add command                    \
            -label       "Display Variables"     \
            -underline   0                       \
            -command     [list app show my://help/var]

        $helpmenu add command                    \
            -label       "Executive Commands"    \
            -underline   0                       \
            -command     [list app show my://help/command]

        $helpmenu add command                    \
            -label       "Model Parameters"      \
            -underline   0                       \
            -command     [list app show my://help/parmdb]

        $helpmenu add separator

        $helpmenu add command                    \
            -label       "Release Notes"         \
            -underline   0                       \
            -command     [list app show my://help/release]

        $helpmenu add command                    \
            -label       "About Athena"          \
            -underline   0                       \
            -command     [list app show my://help/about]


    }

    # AddOrder mnu orders
    #
    # mnu    - A pull-down menu
    # orders - A list of order names
    #
    # Adds menu items for the orders

    method AddOrder {mnu orders} {
        foreach order $orders {
            set cls [flunky class $order]
            cond::available control \
                [menuitem $mnu command [$cls title]... \
                     -command [list app enter $order]]    \
                order $order
        }
    }

    # CreateComponents
    #
    # Creates the main window's components

    method CreateComponents {} {
        # FIRST, prepare the grid.  The scrolling log/shell paner
        # should stretch vertically on resize; the others shouldn't.
        # And everything should stretch horizontally.

        grid rowconfigure $win 0 -weight 0    ;# Separator
        grid rowconfigure $win 1 -weight 0    ;# Tool Bar
        grid rowconfigure $win 2 -weight 0    ;# Separator
        grid rowconfigure $win 3 -weight 1    ;# Content
        grid rowconfigure $win 4 -weight 0    ;# Separator
        grid rowconfigure $win 5 -weight 0    ;# Status line

        grid columnconfigure $win 0 -weight 1

        # NEXT, put in the row widgets

        # ROW 0, add a separator between the menu bar and the rest of the
        # window.
        ttk::separator $win.sep0

        # ROW 1, add a toolbar
        install toolbar using ttk::frame $win.toolbar

        # Prep Lock/Unlock
        ttk::button $toolbar.preplock                \
            -style    Toolbutton                     \
            -image    ::projectgui::icon::unlocked22 \
            -command  [mymethod PrepLock]

        # SIM TOOLS
        install simtools using ttk::frame $toolbar.sim

        # RunPause
        ttk::button $simtools.runpause          \
            -style   Toolbutton                 \
            -image   ::marsgui::icon::play22    \
            -command [mymethod RunPause]

        # Duration

        menubox $simtools.duration            \
            -justify   left                   \
            -width     10                     \
            -takefocus 0                      \
            -values    [dict keys $durations]

        $simtools.duration set [lindex [dict keys $durations] 0]

        DynamicHelp::add $simtools.duration -text "Duration of run"

        # Sim State
        ttk::label $toolbar.state                \
            -text "State:"

        ttk::label $toolbar.simstate             \
            -font         codefont               \
            -width        26                     \
            -anchor       w                      \
            -textvariable [myvar info(simstate)]

        # Date 
        ttk::label $toolbar.datelab \
            -text "Date:"

        ttk::label $toolbar.date                 \
            -font         codefont               \
            -width        7                      \
            -textvariable [myvar info(date)]

        # Tick
        ttk::label $toolbar.ticklab              \
            -text "Week:"

        ttk::label $toolbar.tick                 \
            -font         codefont               \
            -width        4                      \
            -textvariable [myvar info(tick)]

        pack $simtools.runpause  -side left    
        pack $simtools.duration  -side left -padx {0 15}

        pack $toolbar.preplock  -side left
        pack $toolbar.tick      -side right -padx 2 
        pack $toolbar.ticklab   -side right
        pack $toolbar.date      -side right -padx 2 
        pack $toolbar.datelab   -side right
        pack $toolbar.simstate  -side right -padx 2 
        pack $toolbar.state     -side right -padx {15 0}

        # ROW 2, add a separator between the tool bar and the content
        # window.
        ttk::separator $win.sep2

        # ROW 3, create the content widgets.
        ttk::panedwindow $win.paner -orient vertical

        install content using ttk::notebook $win.paner.content \
            -padding 2 

        $win.paner add $content \
            -weight 1

        # ROW 4, add a separator
        ttk::separator $win.sep4

        # ROW 5, Create the Status Line frame.
        ttk::frame $win.status    \
            -borderwidth        2 

        # Message line
        install msgline using messageline $win.status.msgline

        pack $win.status.msgline -fill both -expand yes


        # NEXT, add the content tabs, and save relevant tabs
        # as components.  Also, finish configuring the tabs.
        $self CreateTabs

        # Viewer
        set viewer [$self tab win map]

        # Scrolling log
        set slog   [$self tab win slog]
        $slog load [log cget -logfile]
        notifier bind ::log <NewLog> $self [list $slog load]

        # NEXT, add the CLI to the paner
        install cli using cli $win.paner.cli    \
            -height    15                       \
            -relief    flat                     \
            -maxlines  [prefs get cli.maxlines] \
            -promptcmd [mymethod CliPrompt]     \
            -evalcmd   [list ::executive eval]

        # Load the CLI command history
        $self LoadCliHistory

        # NEXT, manage all of the components.
        grid $win.sep0     -sticky ew
        grid $toolbar      -sticky ew
        grid $win.sep2     -sticky ew
        grid $win.paner    -sticky nsew
        grid $win.sep4     -sticky ew
        grid $win.status   -sticky ew
    }

    # ToggleCLI
    #
    # Toggles visibility of the CLI.  Or, actually, it doesn't;
    # the checkbox on the View menu does that.  This just shows
    # it or hides it.

    method ToggleCLI {} {
        if {$visibility(cli)} {
            if {$cli ni [$win.paner panes]} {
                $win.paner add $cli
            }
        } else {
            if {$cli in [$win.paner panes]} {
                $win.paner forget $cli
            }
        }
    }

    # CliPrompt
    #
    # Returns a prompt string for the CLI

    method CliPrompt {} {
        if {[executive usermode] eq "super"} {
            return "super>"
        } else {
            return ">"
        }
    }

    # AddSimTool name icon tooltip command
    #
    # Creates a simtools button with standard style
    # TBD: Does the toolbutton module cover this?

    method AddSimTool {name icon tooltip command} {
        ttk::button $simtools.$name \
            -style   Toolbutton        \
            -state   normal            \
            -command $command          \
            -image   [list ::marsgui::icon::$icon \
                          disabled ::marsgui::icon::${icon}d]

        DynamicHelp::add $simtools.$name -text $tooltip
    }

    #-------------------------------------------------------------------
    # Window Mode

    # SetMode mode
    #
    # mode - scenario | simulation
    #
    # Sets the overall window mode.

    method SetMode {mode} {
        # FIRST, save the new mode
        set info(mode) $mode

        # NEXT, make changes
        if {$info(mode) eq "simulation"} {
            # Display the Sim Tools
            pack $simtools -after $toolbar.preplock -side left

            # Simulation tabs are visible
            set visibility(scenario)   0
            set visibility(simulation) 1
        } else {
            # Hide the Sim Tools
            pack forget $simtools

            # Scenario tabs are visible
            set visibility(scenario)   1
            set visibility(simulation) 0
        }

        # NEXT, Update the tabs
        $self MakeTabsVisible

        # NEXT, update the display
        $self SetWindowTitle
    }

    # SetWindowTitle
    #
    # Sets the window title given the mode, the current scenario, etc.

    method SetWindowTitle {} {
        # FIRST, get the file name.
        set dbfile [file tail [scenario dbfile]]

        if {$dbfile eq ""} {
            set dbfile "Untitled"
        }

        # NEXT, get the Mode String
        if {$info(mode) eq "scenario"} {
            set modeText "Scenario"
        } else {
            set modeText "Simulation"
        }

        wm title $win "Athena [kiteinfo version]: $modeText, $dbfile"
    }



    #-------------------------------------------------------------------
    # Tab Management

    # CreateTabs
    #
    # Creates all of the content tabs and subtabs; hides the ones that
    # aren't currently visible.  Bind to track the currently selected tab.

    method CreateTabs {} {
        # FIRST, bind to the main content notebook.

        # NEXT, add each tab
        foreach tab [dict keys $tabs] {
            # Add a "tabwin" key to the tab dictionary
            dict set tabs $tab tabwin ""

            # Create the tab
            dict with tabs $tab {
                # FIRST, get the parent
                if {$parent eq ""} {
                    set p $content
                } else {
                    set p [dict get $tabs $parent tabwin]
                }

                # NEXT, get the new tabwin name
                set tabwin $p.$tab

                # NEXT, create the new tab widget
                if {$script eq ""} {
                    ttk::notebook $tabwin -padding 2
                } else {
                    eval [string map [list %W $tabwin] $script]
                }

                # NEXT, add it to the parent notebook
                $p add $tabwin      \
                    -sticky  nsew   \
                    -padding 2      \
                    -text    $label
            }
        }
    }


    # MakeTabsVisible
    #
    # Given the current visibility() flags, makes tabs visible or not.

    method MakeTabsVisible {} {
        # FIRST, make each visible tab visible
        foreach tab [dict keys $tabs] {
            dict with tabs $tab {
                # FIRST, get the parent
                if {$parent eq ""} {
                    set p $content
                } else {
                    set p [dict get $tabs $parent tabwin]
                }

                # NEXT, if this is a subtab and it has the same 
                # visibility class as its parent, there's no need
                # to touch it.
                if {$parent ne ""} {
                    set pvistype [dict get $tabs $parent vistype]
                    if {$pvistype eq $vistype} {
                        continue
                    }
                }

                # NEXT, if it isn't visible, hide it.
                if {$visibility($vistype)} {
                    $p add $tabwin
                } else {
                    $p hide $tabwin
                }
            }
        }

        # NEXT, for each parent tab, if no child is selected, select
        # the first one.
        foreach tab [dict keys $tabs] {
            # FIRST, parent tabs have no script
            if {[dict get $tabs $tab script] ne ""} {
                continue
            }

            # NEXT, get the parent tab's window, which is a 
            # ttk::notebook.
            set tabwin [dict get $tabs $tab tabwin]

            # NEXT, if no tab is selected, select the first one that
            # isn't hidden.
            if {[$tabwin select] ne ""} {
                continue
            }

            for {set i 0} {$i < [$tabwin index end]} {incr i} {
                if {[$tabwin tab $i -state] ne "hidden"} {
                    $tabwin select $i
                    break
                }
            }
        }

        # NEXT, add the View menu items for the visible tabs.
        $self AddTabMenuItems
    }


    # AddTabMenuItems
    #
    # Adds items to pop up the visible tabs to the View menu

    method AddTabMenuItems {} {
        # FIRST, delete old tab entries.
        $viewmenu delete 0 end

        # NEXT, save the parent menu for toplevel tabs
        set pmenu() $viewmenu
        
        # NEXT, add each tab
        foreach tab [dict keys $tabs] {
            dict with tabs $tab {
                # FIRST, if this tab isn't visible, ignore it.
                if {!$visibility($vistype)} {
                    continue
                }

                # NEXT, if this is a leaf tab just add its item.
                if {$script ne ""} {
                    $pmenu($parent) add command \
                        -label $label           \
                        -command [mymethod tab view $tab]
                    continue
                }

                # NEXT, this tab has subtabs.  Create a new menu
                set newMenu $pmenu($parent).$tab

                if {[winfo exists $newMenu]} {
                    destroy $newMenu
                }

                set pmenu($tab) [menu $newMenu]

                $pmenu($parent) add cascade \
                    -label $label \
                    -menu  $pmenu($tab)
            }
        }

        # NEXT, replace the check boxes at the bottom
        $viewmenu add separator

        $viewmenu add checkbutton                   \
            -label    "Scripts Editor"              \
            -variable [myvar visibility(scripts)]   \
            -command  [mymethod ToggleHiddenTab scripts]

        $viewmenu add checkbutton                   \
            -label    "Order History"               \
            -variable [myvar visibility(orders)]    \
            -command  [mymethod ToggleHiddenTab orders]

        $viewmenu add checkbutton                   \
            -label    "Scrolling Log"               \
            -variable [myvar visibility(slog)]      \
            -command  [mymethod ToggleHiddenTab slog]

        $viewmenu add checkbutton                   \
            -label    "Command Line"                \
            -variable [myvar visibility(cli)]       \
            -command  [mymethod ToggleCLI]
    }


    # ToggleHiddenTab tab
    #
    # This is called when the tab's View menu item toggles the visibility
    # flag for the tab.  Makes the tab actually visible or invisible; and
    # if visible, brings it to the front.

    method ToggleHiddenTab {tab} {
        $self MakeTabsVisible

        if {$visibility($tab)} {
            $self tab view $tab
        }
    }

    # tab win tab
    #
    # Returns the window name of the specified tab
    
    method {tab win} {tab} {
        dict get $tabs $tab tabwin
    }

    # tab exists tab
    #
    # tab   - A tab name
    #
    # Returns 1 if the tab exists, and 0 otherwise

    method {tab exists} {tab} {
        expr {$tab in [dict keys $tabs]}
    }

    # tab view tab
    #
    # Makes the window display the specified tab.

    method {tab view} {tab} {
        dict with tabs $tab {
            # FIRST, you can only view simulation and scenario tabs
            # in the proper info(mode).  If they aren't visible,
            # they shouldn't be.
            if {$vistype in {simulation scenario} &&
                !$visibility($vistype)
            } {
                return
            }

            # NEXT, if it's one of the optional tabs, set its visibility
            # flags.
            if {$vistype in [array names visibility]} {
                set visibility($vistype) 1
                $self MakeTabsVisible
            }

            if {$parent eq ""} {
                $content select $tabwin
            } else {
                set pwin [dict get $tabs $parent tabwin]

                $content select $pwin
                $pwin select $tabwin
            }
        }
    }
    
   
    #-------------------------------------------------------------------
    # CLI history

    # SaveCliHistory
    #
    # If there's a CLI, saves its command history to the preferences
    # directory.

    method savehistory {} {
        assert {$cli ne ""}

        set f [open [prefsdir join history.cli] w]

        puts $f [$cli saveable checkpoint]
        
        close $f
    }

    # LoadCliHistory
    #
    # If there's a CLI, and a history file, read its command history.

    method LoadCliHistory {} {
        set histFile [prefsdir join history.cli]
        if {[file exists $histFile]} {
            $cli saveable restore [readfile $histFile]
        }
    }


    #-------------------------------------------------------------------
    # File Menu Handlers

    # FileNew
    #
    # Prompts the user to create a brand new scenario.

    method FileNew {} {
        # FIRST, we can only create a new scenario if we're not RUNNING.
        # The menu item will be unavailable in this case, but we might
        # still get here via a hot-key.
        if {![sim stable]} {
            return
        }

        # NEXT, Allow the user to save unsaved data.
        if {![$self SaveUnsavedData]} {
            return
        }

        # NEXT, create the new scenario
        scenario new
    }

    # FileOpen
    #
    # Prompts the user to open a scenario in a particular file.

    method FileOpen {} {
        # FIRST, we can only open a new scenario if we're not RUNNING.
        # The menu item will be unavailable in this case, but we might
        # still get here via a hot-key.
        if {![sim stable]} {
            return
        }

        # NEXT, Allow the user to save unsaved data.
        if {![$self SaveUnsavedData]} {
            return
        }

        # NEXT, query for the scenario file name.
        set filename [tk_getOpenFile                      \
                          -parent $win                    \
                          -title "Open Scenario"          \
                          -filetypes {
                              {{Athena Scenario}     {.adb} }
                          }]

        # NEXT, If none, they cancelled
        if {$filename eq ""} {
            return
        }

        # NEXT, Open the requested scenario.
        scenario open $filename
    }

    # FileSaveAs
    #
    # Prompts the user to save the scenario as a particular file.

    method FileSaveAs {} {
        # FIRST, we can only save a new scenario if we're not RUNNING.
        # The menu item will be unavailable in this case, but we might
        # still get here via a hot-key.
        if {![sim stable]} {
            return
        }

        # NEXT, query for the scenario file name.  If the file already
        # exists, the dialog will automatically query whether to 
        # overwrite it or not. Returns 1 on success and 0 on failure.

        set filename [tk_getSaveFile                       \
                          -parent $win                     \
                          -title "Save Scenario As"        \
                          -filetypes {
                              {{Athena Scenario} {.adb} }
                          }]

        # NEXT, If none, they cancelled.
        if {$filename eq ""} {
            return 0
        }

        # NEXT, Save the scenario using this name
        return [scenario save $filename]
    }

    # FileSave
    #
    # Saves the scenario to the current file, making a backup
    # copy.  Returns 1 on success and 0 on failure.

    method FileSave {} {
        # FIRST, we can only save a scenario if we're not RUNNING.
        # The menu item will be unavailable in this case, but we might
        # still get here via a hot-key.
        if {![sim stable]} {
            return
        }

        # FIRST, if no file name is known, do a SaveAs.
        if {[scenario dbfile] eq ""} {
            return [$self FileSaveAs]
        }

        # NEXT, Save the scenario to the current file.
        return [scenario save]
    }

    # FileExportAs
    #
    # Prompts the user to export the scenario as an order script.

    method FileExportAs {} {
        # FIRST, we can only export a new scenario if we're in PREP
        # The menu item will be unavailable in this case, but we might
        # still get here via a hot-key.
        if {[sim state] ne "PREP"} {
            return
        }

        # NEXT, query for the script file name.  If the file already
        # exists, the dialog will automatically query whether to 
        # overwrite it or not. Returns 1 on success and 0 on failure.

        set filename [tk_getSaveFile                       \
                          -parent $win                     \
                          -title "Export Scenario As"        \
                          -filetypes {
                              {{Athena Script} {.tcl} }
                          }]

        # NEXT, If none, they cancelled.
        if {$filename eq ""} {
            return 0
        }

        # NEXT, add a ".tcl" if they didn't.
        if {[file extension $filename] ne ".tcl"} {
            append filename ".tcl"
        }


        # NEXT, Save the scenario using this name
        exporter fromdata $filename
        app puts "Exported scenario from current data as $filename."

    }

    # FileSaveCLI
    #
    # Prompts the user to save the CLI scrollback buffer to disk
    # as a text file.
    #
    # TBD: This has become a standard pattern (catch, try/finally,
    # logging errors, etc).  Consider packaging it up as a standard
    # save file mechanism.

    method FileSaveCLI {} {
        # FIRST, query for the file name.  If the file already
        # exists, the dialog will automatically query whether to 
        # overwrite it or not. Returns 1 on success and 0 on failure.

        set filename [tk_getSaveFile                                   \
                          -parent      $win                            \
                          -title       "Save CLI Scrollback Buffer As" \
                          -initialfile "cli.txt"                       \
                          -filetypes   {
                              {{Text File} {.txt} }
                          }]

        # NEXT, If none, they cancelled.
        if {$filename eq ""} {
            return 0
        }

        # NEXT, make sure it has a .txt extension.
        if {[file extension $filename] ne ".txt"} {
            append filename ".txt"
        }

        # NEXT, Save the CLI using this name
        if {[catch {
            try {
                set f [open $filename w]
                puts $f [$cli get 1.0 end]
            } finally {
                close $f
            }
        } result opts]} {
            log warning app "Could not save CLI buffer: $result"
            log error app [dict get $opts -errorinfo]
            app error {
                |<--
                Could not save the CLI buffer to
                
                    $filename

                $result
            }
            return
        }

        log normal scenario "Saved CLI Buffer to: $filename"

        app puts "Saved CLI Buffer to [file tail $filename]"

        return
    }


    # WmsImportMap
    #
    # Prompts the user to select a map from a Web Map Service (WMS)
    
    method WmsImportMap {} {
        if {![winfo exists $wmswin]} {
            set wmswin [wmswin .wmswin]
        } else {
            wm deiconify $wmswin
        }
    }

    # FileImportMap
    #
    # Asks the user to select a map file for import.

    method FileImportMap {} {
        # FIRST, query for a map file.
        set filename [tk_getOpenFile                  \
                          -parent $win                \
                          -title "Select a map image" \
                          -filetypes {
                              {{JPEG Images} {.jpg} }
                              {{GIF Images}  {.gif} }
                              {{PNG Images}  {.png} }
                              {{TIF Images}  {.tif} }
                              {{Any File}    *      }
                          }]

        # NEXT, If none, they cancelled
        if {$filename eq ""} {
            return
        }

        # NEXT, Import the map
        if {[catch {
            flunky senddict gui MAP:IMPORT:FILE [list filename $filename]
        } result]} {
            app error {
                |<--
                Import failed: $result

                $filename
            }
        }
    }


    # FileParametersImport
    #
    # Imports model parameters from a .parmdb file

    method FileParametersImport {} {
        # FIRST, query for a parameters file.
        set filename [tk_getOpenFile                  \
                          -parent $win                \
                          -title "Select a parameters file" \
                          -filetypes {
                              {{Model Parameters} {.parmdb} }
                              {{Any File}         *         }
                          }]

        # NEXT, If none, they cancelled
        if {$filename eq ""} {
            return
        }

        # NEXT, Import the parmdb file
        if {[catch {
            flunky senddict gui PARM:IMPORT [list filename $filename]
        } result]} {
            app error {
                |<--
                Import failed: $result

                $filename
            }
        }
    }

    # FileParametersExport
    #
    # Exports model parameters to a .parmdb file

    method FileParametersExport {} {
        # FIRST, query for the file name.  If the file already
        # exists, the dialog will automatically query whether to 
        # overwrite it or not. Returns 1 on success and 0 on failure.

        set filename [tk_getSaveFile                       \
                          -parent $win                     \
                          -title "Export Parameters As"        \
                          -filetypes {
                              {{Model Parameters} {.parmdb} }
                          }]

        # NEXT, If none, they cancelled.
        if {$filename eq ""} {
            return 0
        }

        # NEXT, make sure it has a .txt extension.
        if {[file extension $filename] ne ".parmdb"} {
            append filename ".parmdb"
        }

        # NEXT, Save the scenario using this name
        return [parm save $filename]
    }

    # FileExit
    #
    # Verifies that the user has saved data before exiting.

    method FileExit {} {
        # FIRST, check for modal dialogs, this is a problem on Linux
        if {[grab current] ne ""} {
            return
        }

        # NEXT, Allow the user to save unsaved data.
        if {![$self SaveUnsavedData]} {
            return
        }

        # NEXT, the data has been saved if it's going to be; so exit.
        app exit
    }

    # SaveUnsavedData
    #
    # Allows the user to save unsaved changes.  Returns 1 if the user
    # is ready to proceed, and 0 if the current activity should be
    # cancelled.

    method SaveUnsavedData {} {
        if {[scenario unsaved]} {
            # FIRST, deiconify the window, this gives the message box
            # a parent to popup over.
            wm deiconify $win

            # NEXT, popup the message box for the user
            set name [file tail [scenario dbfile]]

            set message [tsubst {
                |<--
                The scenario [tif {$name ne ""} {"$name" }]has not been saved.
                Do you want to save your changes?
            }]

            set answer [messagebox popup                 \
                            -icon    warning             \
                            -message $message            \
                            -parent  $win                \
                            -title   "Athena [version]"  \
                            -onclose cancel              \
                            -buttons {
                                save    "Save"
                                discard "Discard"
                                cancel  "Cancel"
                            }]

            if {$answer eq "cancel"} {
                return 0
            } elseif {$answer eq "save"} {
                # Stop exiting if the save failed
                if {![$self FileSave]} {
                    return 0
                }
            }
        }

        return 1
    }

    #-------------------------------------------------------------------
    # Edit Menu Handlers

    # PostEditMenu
    #
    # Enables/Disables the undo/redo menu items when the menu is posted.

    method PostEditMenu {} {
        # Undo item
        set text [flunky undotext]

        if {$text ne ""} {
            $editmenu entryconfigure 0 \
                -state normal          \
                -label $text
        } else {
            $editmenu entryconfigure 0 \
                -state disabled        \
                -label "Undo"
        }

        # Redo item
        set text [flunky redotext]

        if {$text ne ""} {
            $editmenu entryconfigure 1 \
                -state normal          \
                -label $text
        } else {
            $editmenu entryconfigure 1 \
                -state disabled        \
                -label "Redo"
        }
    }

    # EditUndo
    #
    # Undoes the top order on the undo stack, if any.

    method EditUndo {} {
        if {[flunky canundo]} {
            flunky undo
        }
    }

    # EditRedo
    #
    # Redoes the last undone order if any.

    method EditRedo {} {
        if {[flunky canredo]} {
            flunky redo
        }
    }

    #-------------------------------------------------------------------
    # Toolbar Event Handlers

    # RunPause
    #
    # Sends SIM:RUN or SIM:PAUSE, depending on state.

    method RunPause {} {
        if {[sim state] eq "RUNNING"} {
            flunky send gui SIM:PAUSE
        } else {
            flunky send gui SIM:RUN \
                -weeks [dict get $durations [$simtools.duration get]]
        }
    }


    # PrepLock
    #
    # Sends SIM:LOCK or SIM:UNLOCK, depending on state.

    method PrepLock {} {
        # FIRST, if we're in PREP then it's time to leave it.
        if {[sim state] eq "PREP"} {
            if {[sanity onlock check] eq "ERROR"} {
                app show my://app/sanity/onlock

                messagebox popup \
                    -parent  $win               \
                    -icon    error              \
                    -title   "Not ready to run" \
                    -message [normalize {
            The on-lock sanity check failed with one or more errors;
            time cannot advance.  Fix the error, and try again.
            Please see the On-lock Sanity Check Report in the 
            Detail Browser for details.
                    }]

                return
            }

            flunky send gui SIM:LOCK
            return
        }

        # NEXT, we're not in PREP; we want to return to it.  But
        # give the user the option.
        set answer [messagebox popup \
                        -parent        $win                  \
                        -icon          warning               \
                        -title         "Are you sure?"       \
                        -default       cancel                \
                        -ignoretag     "sim_unlock"          \
                        -ignoredefault ok                    \
                        -onclose       cancel                \
                        -buttons       {
                            ok      "Return to Prep"
                            cancel  "Cancel"
                        } -message [normalize {
                            If you return to Scenario Preparation, you 
                            will lose any changes made since leaving
                            Scenario Preparation.
                        }]]

        if {$answer eq "ok"} {
            flunky send gui SIM:UNLOCK
        }
    }


    #-------------------------------------------------------------------
    # Mapviewer Event Handlers


    # Unit-1 u
    #
    # u      A unit ID
    #
    # Called when the user clicks on a unit icon.

    method Unit-1 {u} {
        rdb eval {SELECT * FROM gui_units WHERE u=$u} row {
            $self puts \
                "Unit $u  at: $row(location)  group: $row(g)  activity: $row(a)  personnel: $row(personnel)"
        }
    }

    # Absit-1 s
    #
    # s      An absit ID
    #
    # Called when the user clicks on an absit icon.

    method Absit-1 {s} {
        rdb eval {SELECT * FROM gui_absits WHERE s=$s} row {
        $self puts \
            "Situation $s: $row(stype)  at: $row(location)  coverage: $row(coverage)"
        }
    }

    # Nbhood-1 n
    #
    # n      A nbhood ID
    #
    # Called when the user clicks on a nbhood.

    method Nbhood-1 {n} {
        rdb eval {SELECT longname FROM nbhoods WHERE n=$n} {}

        $self puts "Neighborhood $n: $longname"
    }

    #-------------------------------------------------------------------
    # Notifier Event Handlers

    # ReloadContent
    #
    # Reloads all of *this* window's content.  (Tab windows are on
    # their own).

    method ReloadContent {} {
        # FIRST, set the window title
        $self SetWindowTitle

        # NEXT, make the CLI visible/invisible
        $self ToggleCLI

        # NEXT, set the status variables
        $self SimState
        $self SimTime
    }

    # SimState
    #
    # This routine is called when the simulation state has changed
    # in some way.

    method SimState {} {
        # FIRST, display the simulation state
        if {[sim state] eq "RUNNING"} {
            set prefix [esimstate longname [sim state]]

            if {[sim stoptime] == 0} {
                set info(simstate) "$prefix until paused"
            } else {
                set info(simstate) \
                    "$prefix until [simclock toString [sim stoptime]]"
            }
        } else {
            set info(simstate) [esimstate longname [sim state]]
        }

        # NEXT, update the window mode
        if {[sim state] in {PREP WIZARD}} {
            $self SetMode scenario
        } else {
            $self SetMode simulation
        }
        
        # NEXT, update the Prep Lock button
        if {[sim state] eq "PREP"} {
            $toolbar.preplock configure -image {
                ::projectgui::icon::unlocked22
                disabled ::projectgui::icon::unlocked22d
            } -state normal
            DynamicHelp::add $toolbar.preplock \
                -text "Lock Scenario Preparation"
        } elseif {[sim state] eq "WIZARD"} {
            $toolbar.preplock configure -state disabled
        } else {
            $toolbar.preplock configure -image {
                ::projectgui::icon::locked22
                disabled ::projectgui::icon::locked22d
            }

            if {[sim state] eq "RUNNING"} {
                $toolbar.preplock configure -state disabled
            } else {
                $toolbar.preplock configure -state normal
            }
                    
            DynamicHelp::add $toolbar.preplock \
                -text "Unlock Scenario Preparation"
        }

        # NEXT, Update Run/Pause button and the Duration
        if {[sim state] eq "RUNNING"} {
            $simtools.runpause configure \
                -image ::marsgui::icon::pause22 \
                -state normal
            DynamicHelp::add $simtools.runpause -text "Pause Simulation"

            $simtools.duration configure -state disabled
        } elseif {[sim state] eq "PAUSED"} {
            $simtools.runpause configure \
                -image ::marsgui::icon::play22 \
                -state normal
            DynamicHelp::add $simtools.runpause -text "Run Simulation"

            $simtools.duration configure -state readonly
        } else {
            # PREP
            $simtools.runpause configure \
                -image ::marsgui::icon::play22d \
                -state disabled
            DynamicHelp::add $simtools.runpause -text "Run Simulation"

            $simtools.duration configure -state disabled
        }
    }

    # SimTime
    #
    # This routine is called when the simulation time display has changed,
    # either because the start date has changed, or the time has advanced.

    method SimTime {} {
        # Display current sim time.
        set info(tick) [format "%04d" [simclock now]]
        set info(date) [simclock asString]
    }

    # AppPrefs parm
    #
    # parm     Name of the preferences parm, or ""
    #
    # This routine is called when application preferences have changed.

    method AppPrefs {parm} {
        switch -exact -- $parm {
            cli.maxlines -
            ""           {
                $cli configure -maxlines [prefs get cli.maxlines]
            }
        }
    }

    #-------------------------------------------------------------------
    # Utility Methods

    delegate method nbfill to viewer

    # reload 
    #
    # Triggers a reload of this window's content

    method reload {} {
        $reloader schedule -nocomplain
    }
    
    # error text
    #
    # text       A tsubst'd text string
    #
    # Displays the error in a message box

    method error {text} {
        set text [uplevel 1 [list tsubst $text]]

        messagebox popup      \
            -message    $text \
            -icon       error \
            -wraplength ""    \
            -parent     $win
    }

    # puts text
    #
    # text     A text string
    #
    # Writes the text to the message line

    method puts {text} {
        $msgline puts $text
    }

    # cli clear
    #
    # Clears the contents of the CLI scrollback buffer

    method {cli clear} {} {
        require {$cli ne ""} "No CLI in this window: $win"

        $cli clear
    }

    #-------------------------------------------------------------------
    # saveable(i) interface

    # checkpoint ?-saved?
    #
    # Returns a checkpoint of the window state

    method checkpoint {{option ""}} {
        set checkpoint [dict create]
        
        dict set checkpoint mode           $info(mode)
        dict set checkpoint visibility     [array get visibility]

        return $checkpoint
    }

    # restore checkpoint ?-saved?
    #
    # checkpoint     A string returned by the checkpoint typemethod
    
    method restore {checkpoint {option ""}} {
        # FIRST, restore the checkpoint data
        set info(mode)           [dict get $checkpoint mode]
        array set visibility     [dict get $checkpoint visibility]
    }

    # changed
    #
    # Returns 1 if saveable(i) data has changed, and 0 otherwise.
    #
    # Always returns 0, as this is just window state.

    method changed {} {
        return 0
    }

}






