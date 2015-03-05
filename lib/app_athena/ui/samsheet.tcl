#-----------------------------------------------------------------------
# FILE: samsheet.tcl
#
#   Economics SAM Spreadsheet view (new for 6x6)
#   This is an experimental sheet for now
#
# PACKAGE:
#   app_sim(n) -- athena_sim(1) implementation package
#
# PROJECT:
#   Athena S&RO Simulation
#
# AUTHOR:
#    Will Duquette
#    Dave Hanks
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget: cgesheet
#
# This module is responsible for displaying the initial state of 
# the economy via a Social Accounting Matrix (SAM)
#
# TBD: Consider doing lazy update.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widget samsheet {
    #-------------------------------------------------------------------
    # Group: Lookup Tables
    #
    # These variables contain constant data used in building and
    # operating the GUI.

    # This variable serves two purposes: its keys are the sector names,
    # and its values are the units for each sector.
    #
    # NOTE: If we have more meta-data, we will need something more
    # complicated.

    typevariable units {
        goods goodsBKT/yr
        black blackBKT/yr
        pop   workyear/yr
    }

    # Look-up table for colors of various kinds.
    #
    #  e - Color for editable cells
    #  r - Color for readonly cells
    #  d - Color for editable cells when they are disabled
    #  a - Color for "A" shape parameters (Leontief production function)
    #  f - Color for "f" shape parameters (Cobb-Douglas parameter)
    #  t - Color for "t" shape parameters (tax-like rates)

    typevariable color -array {
        e "#CCFF99"
        r "#BABABA"
        d "#E3E3E3"
        a "#C16610"
        f "#8BAE56"
        t "#40ABB0"
    }

    # The html layout of the cmsheet(n) objects on this tab

    typevariable layout {
        <table>
          <tr>
            <td colspan="3">
              <input name="mmatrix"><p>
            </td>
          </tr>
          <tr>
            <td colspan="2">
              <b style="font-size:12px">Other Inputs</b><p>
              <input name="inputs">
            </td>
            <td>
              <b style="font-size:12px">Size Outputs</b><p>
              <input name="sizeout">
            </td>
          </tr>
          <tr>
            <td colspan="2">
              <b style="font-size:12px">Exports/Foreign Aid Outputs</b><p>
              <input name="exfaout">
            </td>
            <td>
              <b style="font-size:12px">Misc. Outputs</b><p>
              <input name="miscout">
            </td>
          </tr>
          <tr>
            <td valign="top">
              <b style="font-size:12px">Shape Parameters</b><p>
              <input name="smatrix">
            </td>
            <td valign="center">
              <p class="leglbl" style="background-color:#C16610">A.i.j</p>
              <p class="leglbl" style="background-color:#8BAE56">f.i.j</p>
              <p class="leglbl" style="background-color:#40ABB0">t.i.j</p>
            </td>
            <td valign="center">
              <p class="legtxt">- Leontief coefficients</p>
              <p class="legtxt">- Cobb-Douglas coefficients</p>
              <p class="legtxt">- tax-like rates</p>
            </td>
          </tr>
        </table>
    }

    # CSS for the legend in the layout

    typevariable css {
        p.leglbl {margin: 0px 0px 1px 0px; width: 30px}
        p.legtxt {margin: 0px 0px 1px 0px}
    }

    # info
    #
    # array of scalars
    # 
    # mode - INPUT, BAL, BASE, indicating how the SAM data is displayed:
    #    
    #    INPUT - the input money flows from one sector to another
    #    BAL   - the balancing flows computed from inputs
    #    BASE  - the base SAM; sum of INPUT and BAL

    variable info -array {
        mode BASE
    }

    # Dictionary of views available for the SAM sheet.
    variable vdict

    #-------------------------------------------------------------------
    # Options
    #
    # Unknown options delegated to the hull

    delegate option * to hull
 
    # The economic model's SAM cellmodel(n).
    component sam

    # The toolbar and it's components
    component toolbar
    component vmenu

    # The cmsheet(n) widgets used to display the SAM data.

    # Inputs
    component mmatrix  ;# The money matrix, displays $ amounts
    component inputs   ;# Scalar inputs

    # Outputs 
    component smatrix  ;# The shape matrix, displays shape parameters
    component sizeout  ;# The size of the base economy (scalars)
    component exfaout  ;# Exports and foreign aid (scalars)
    component miscout  ;# Miscellaneous outputs (scalars)

    #--------------------------------------------------------------------
    # Constructor
    #
    # Create the widget and map the CGE.

    constructor {args} {
        # FIRST, get the options.
        $self configurelist $args

        # NEXT the dropdown menu of views and their keys
        set vdict [dict create       \
            "Base SAM"        BASE  \
            "Input Flows"     INPUT \
            "Balancing Flows" BAL]

        # NEXT, get a copy of the sam and solve it
        set sam [adb econ getsam 1]
        $sam solve

        htmlframe $win.h \
            -yscrollcommand [list $win.yscroll set]

        $win.h configure -styles $css

        # NEXT, Create the GUI components
        $self CreateMoneyMatrix   $win.h.mmatrix
        $self CreateShapeMatrix   $win.h.smatrix
        $self CreateScalarInputs  $win.h.inputs
        $self CreateScalarOutputs $win.h

        ttk::scrollbar $win.yscroll \
            -command [list $win.h yview]

        install toolbar using ttk::frame $win.h.toolbar

        $self CreateViewMenu $win.h.toolbar

        # NEXT grid the html frame and scrollbar
        # Note that the widgets in the html frame are layed out once
        # sim state is determined. See the SimState method below
        grid $win.h       -row 0 -column 0 -sticky nsew
        grid $win.yscroll -row 0 -column 1 -sticky ns

        grid rowconfigure    $win 0 -weight 1
        grid columnconfigure $win 0 -weight 1

        # NEXT, prepare for updates.
        notifier bind ::adb      <Sync>    $self [mymethod SyncSheet]
        notifier bind ::adb      <Tick>       $self [mymethod refresh]
        notifier bind ::adb      <State>      $self [mymethod SimState]
        notifier bind ::adb.econ <SamUpdate>  $self [mymethod SamUpdate]
        notifier bind ::adb.econ <SyncSheet>  $self [mymethod SyncSheet]

        # NEXT, populate the HTML frame based on view
        $self DisplayCurrentView
    }

    # Constructor: Destructor
    #
    # Forget the notifier bindings.
    
    destructor {
        notifier forget $self
    }

    # CreateViewMenu m
    #
    # w  - window in which the menu resides
    #
    # This method creates the drop down list of views available
    # for the cmsheet(n).

    method CreateViewMenu {w} {
        # FIRST, the label
        ttk::label $w.viewlabel \
            -text "View:"

        # NEXT, create the menu with an appropriate width
        install vmenu using menubox $w.vmenu                   \
            -width   [expr {[lmaxlen [dict keys $vdict]] + 2}] \
            -values  [dict keys $vdict]                        \
            -command [mymethod DisplayCurrentView] 

        pack $vmenu       -side right -fill y -padx {2 0}
        pack $w.viewlabel -side right -fill y -padx {2 0}

        # NEXT, set the menu to the first one in the dict
        $vmenu set [lindex [dict keys $vdict] 1]
    }

    # CreateShapeMatrix w
    #
    # w - The frame widget
    #
    # Creates the matrix component for displaying the shape parameters
    # of the economy as specified in the SAM.

    method CreateShapeMatrix {w} {
        set sectors [$sam index i]
        set ns [llength $sectors]
        let nrows {$ns + 1}
        let ncols {$ns + 1}


        install smatrix using cmsheet $w    \
            -cellmodel $sam                 \
            -state     disabled             \
            -rows      $nrows               \
            -cols      $ncols               \
            -roworigin -1                   \
            -colorigin -1                   \
            -titlerows 1                    \
            -titlecols 1                    \
            -formatcmd {format "%.4f"}

        set titlecol [concat "i,j" $sectors] 
        $smatrix textrow -1,-1 $titlecol
        $smatrix textcol 0,-1  $sectors
        $smatrix textcol 0,5 {
            "n/a"
            "n/a"
            "n/a"
            "n/a"
            "n/a"
            "n/a"
        } 

        $smatrix mapcol 0,0 il  f.%il.goods   f -background $color(f)
        $smatrix mapcol 3,0 inp t.%inp.goods  t -background $color(t)

        $smatrix mapcol 0,1 il  A.%il.black   a -background $color(a)
        $smatrix mapcol 3,1 inp t.%inp.black  t -background $color(t)

        $smatrix mapcol 0,2 il  f.%il.pop     f -background $color(f)
        $smatrix mapcol 3,2 inp t.%inp.pop    t -background $color(t)

        $smatrix mapcol 0,3 i   f.%i.actors   f -background $color(f)

        $smatrix mapcol 0,4 i   f.%i.region   f -background $color(f)
    }

    # CreateMoneyMatrix w
    #
    # w - The frame widget
    #
    # Creates the "matrix" component for displaying monetary flows in 
    # the SAM.

    method CreateMoneyMatrix {w} {
        # FIRST, get some important values
        set sectors [$sam index i]
        set ns      [llength $sectors]
        let nrows   {$ns + 2}
        let ncols   {$ns + 6}
        
        # Main area
        let ractors {$ns - 3}
        let rworld  {$ns - 1}
        let rbe     {$ns + 1}
        set rexp    $ns
        set cbr     $ns
        let cbp     {$ns + 1}
        let cbd     {$ns + 3}
        let cactors {$ns - 3}
        let cpunits {$ncols - 4}
        let cdunits {$ncols - 2}

        # NEXT, create the cmsheet(n).
        install mmatrix using cmsheet $w              \
            -cellmodel     $sam                       \
            -state         normal                     \
            -rows          $nrows                     \
            -cols          $ncols                     \
            -roworigin     -1                         \
            -colorigin     -1                         \
            -titlerows     1                          \
            -titlecols     1                          \
            -browsecommand [mymethod BrowseCmd $w %C] \
            -validatecmd   [mymethod ValidateMoney]   \
            -changecmd     [mymethod CellChanged]     \
            -formatcmd     ::marsutil::moneyfmt


        # NEXT, add titles and empty area
        set titlecol [concat "BX.i.j" $sectors {"Base Rev"} \
                      {"Base Price"} {""} {"Base Demand"}]

        $mmatrix textrow -1,-1 $titlecol        
        $mmatrix textcol 0,-1  [concat $sectors {"Base Exp"}]

        $mmatrix width -1 8

        $mmatrix textcol 0,$cpunits {
            "$/goodsBKT"
            "$/blackBKT"
            "$/work-year"
            ""
            ""
            ""
            ""
        } units -anchor w -relief flat

        $mmatrix textcol 0,$cdunits {
            "goodsBKTs"
            "blackBKTs"
            "work-years"
            ""
            ""
            ""
            ""
        } units -anchor w -relief flat

        $mmatrix empty $ractors,$cbp $nrows,$ncols
        $mmatrix empty $rbe,$cbr $rbe,$cbr
        $mmatrix width $cpunits 15
        $mmatrix width $cdunits 15
        $mmatrix width $cbd     13


        # NEXT, Set up the cells
        $mmatrix map    0,0     i j BX.%i.%j e -background $color(e)
        $mmatrix maprow $rexp,0 j   BEXP.%j  r -background $color(r)
        $mmatrix mapcol 0,$cbr  i   BREV.%i  r -background $color(r)
        $mmatrix mapcol 0,$cbp  il  BP.%il   e -background $color(e)
        $mmatrix mapcol 0,$cbd  il  BQD.%il  r -background $color(r)

        $mmatrix tag configure e -state normal
        
        # NEXT, disable the actor sector row and column, these are 
        # computed from the actor definitions and strategies
        $mmatrix maprow $ractors,0 j BX.actors.%j a -background $color(d)
        $mmatrix mapcol 0,$cactors i BX.%i.actors a -background $color(d)

        $mmatrix tag configure a -state disabled
    }

    # CreateScalarInputs   w
    #
    # w   - the name of the window to use as the cmsheet
    #
    # This method creates the cmsheet for some scalar inputs
    # used by the SAM

    method CreateScalarInputs {w} {
        # FIRST, create the cmsheet(n), which is readonly
        install inputs using cmsheet $w               \
            -roworigin     0                          \
            -colorigin     0                          \
            -cellmodel     $sam                       \
            -state         normal                     \
            -rows          10                          \
            -cols          3                          \
            -titlerows     0                          \
            -titlecols     1                          \
            -browsecommand [mymethod BrowseCmd $w %C] \
            -validatecmd   [mymethod ValidateMoney]   \
            -changecmd     [mymethod CellChanged]     \
            -formatcmd     ::marsutil::moneyfmt

        # NEXT, add titles 
        $inputs textcol 0,0 {
            "Black mkt Feedstock Price"
            "Feedstock per Unit Product"
            "Max Feedstock Avail."
            "Black mkt capacity"
            "Base Consumers"
            "Base Unemployment Rate"
            "Base Subsisters"
            "Subsistence Wage"
            "Remittances"
            "REM Change Rate"
        }

        $inputs textcol 0,2 {
            "$/blackFeedBKT"
            ""
            "blackFeedBKTs/year"
            "blackBKTs"
            ""
            "%"
            ""
            "$/year"
            "$/year"
            "%/year"
        } units -anchor w -relief flat

        # NEXT, add data
        $inputs mapcell 0,1 PF.world.black e 
        $inputs mapcell 1,1 AF.world.black e
        $inputs mapcell 2,1 MF.world.black e
        $inputs mapcell 3,1 BaseCAP.black  e
        $inputs mapcell 4,1 BaseConsumers  e
        $inputs mapcell 5,1 BaseUR         e
        $inputs mapcell 6,1 BaseSubsisters e
        $inputs mapcell 7,1 BaseSubWage    e
        $inputs mapcell 8,1 BREM           e
        $inputs mapcell 9,1 REMChangeRate  e        \
            -formatcmd {format "%.1f"}              \
            -validatecmd [mymethod ValidatePercent] \
            -changecmd [mymethod GlobalChanged]

        $inputs width 0 25
        $inputs width 2 20 

        $inputs tag configure e -state normal -background $color(e)
    }

    # CreateScalarOutputs   w
    #
    # w  - the name of the window to hold the outputs
    #
    # This method creates the cmsheets for some scalar outputs
    # generated by the SAM

    method CreateScalarOutputs {w} {
        # FIRST, create the output cmsheets(n)
        $self CreateSizeOutputs $w.sizeout
        $self CreateExportsFAOutputs $w.exfaout
        $self CreateMiscOutputs $w.miscout
    }

    # CreateSizeOutputs w
    #
    # w - the name of the window to use as the cmsheet
    #
    # This method creates the cmsheet(n) object to hold scalar
    # outputs related to the base size of the economy

    method CreateSizeOutputs {w} {
        # FIRST, create the cmsheet(n)
        install sizeout using cmsheet $w              \
            -roworigin     0                          \
            -colorigin     0                          \
            -cellmodel     $sam                       \
            -state         disabled                   \
            -rows          3                          \
            -cols          3                          \
            -titlerows     0                          \
            -titlecols     1                          \
            -browsecommand [mymethod BrowseCmd $w %C] \
            -formatcmd     ::marsutil::moneyfmt

        # NEXT, the labels to the left and right of the 
        # cells
        $sizeout textcol 0,0 {
            "Base GDP"
            "Base Per Cap. Demand"
            "Base Sub. Agriculture"
        }

        $sizeout textcol 0,2 {
            "$/year"
            "goodsBKT/year"
            "$/year"
        } units -anchor w -relief flat

        # NEXT, map the cells and set the label widths
        $sizeout mapcell  0,1 BaseGDP       r -background $color(r)
        $sizeout mapcell  1,1 BA.goods.pop  r -background $color(r)
        $sizeout mapcell  2,1 BaseSA        r -background $color(r)

        $sizeout width 0 20
        $sizeout width 2 20
    }

    # CreateExportsFAOutputs w
    #
    # w - the name of the window to use as the cmsheet
    #
    # This method creates the cmsheet(n) object to hold scalar
    # outputs related to base exports and base foreign aid

    method CreateExportsFAOutputs {w} {
        # FIRST, create the cmsheet(n)
        install exfaout using cmsheet $w              \
            -roworigin     0                          \
            -colorigin     0                          \
            -cellmodel     $sam                       \
            -state         disabled                   \
            -rows          5                          \
            -cols          3                          \
            -titlerows     0                          \
            -titlecols     1                          \
            -browsecommand [mymethod BrowseCmd $w %C] \
            -formatcmd     ::marsutil::moneyfmt

        # NEXT, the labels to the left and right of the 
        # cells
        $exfaout textcol 0,0 {
            "Aid to Actors"
            "Aid to Region"
            "Goods Exports"
            "Black Mkt. Exports"
            "Labor Exports"
        }

        $exfaout textcol 0,2 {
            "$/year"
            "$/year"
            "goodsBKTs/year"
            "blackBKTs/year"
            "work-years/year"
        } units -anchor w -relief flat

        # NEXT, map the cells and set the label widths
        $exfaout mapcell  0,1 BFAA           r -background $color(r)
        $exfaout mapcell  1,1 BFAR           r -background $color(r)
        $exfaout mapcell  2,1 BEXPORTS.goods r -background $color(r)
        $exfaout mapcell  3,1 BEXPORTS.black r -background $color(r)
        $exfaout mapcell  4,1 BEXPORTS.pop   r -background $color(r)

        $exfaout width 0 20
        $exfaout width 2 15
    }

    # CreateMiscOutputs w
    #
    # w - the name of the window to use as the cmsheet
    #
    # This method creates the cmsheet(n) object to hold scalar
    # outputs related miscellaneous base outputs for the 
    # economy

    method CreateMiscOutputs {w} {
        # FIRST, create the cmsheet(n)
        install miscout using cmsheet $w              \
            -roworigin     0                          \
            -colorigin     0                          \
            -cellmodel     $sam                       \
            -state         disabled                   \
            -rows          2                          \
            -cols          3                          \
            -titlerows     0                          \
            -titlecols     1                          \
            -browsecommand [mymethod BrowseCmd $w %C] \
            -formatcmd     ::marsutil::moneyfmt

        # NEXT, the labels to the left and right of the 
        # cells
        $miscout textcol 0,0 {
            "Black Profit"
            "Black Feedstock"
        }

        $miscout textcol 0,2 {
            "$/year"
            "$/year"
        } units -anchor w -relief flat

        # NEXT, map the cells and set the label widths
        $miscout mapcell 0,1 BNR.black      r -background $color(r)
        $miscout mapcell 1,1 FEED.black     r -background $color(r)

        $miscout width 0 20 
        $miscout width 2 20
    }

    # DisplayMode mode
    #
    # INPUT - the money flows input by the analyst, including the actors
    #         sector
    # BAL   - the balancing flows computed from input values
    # BASE  - the base case SAM; sum of INPUT and BAL matrices

    method DisplayCurrentView {} {
        # FIRST, get the mode
        set mode [dict get $vdict [$vmenu get]]

        # FIRST, get some important values
        set sectors [$sam index i]
        set ns      [llength $sectors]
        
        # Main area
        let rpop    {$ns - 4}
        let ractors {$ns - 3}
        let rregion {$ns - 2}
        let rworld  {$ns - 1}
        let cgoods  {$ns - 6}
        let cblack  {$ns - 5}
        let cpop    {$ns - 4}
        let cactors {$ns - 3}
        let cworld  {$ns - 1}
        set rexp    $ns
        set crev    $ns

        if {$mode eq "INPUT"} {
            # NEXT, map the main area of the matrix to the BX values which
            # are from the X-matrix
            $mmatrix map 0,0 i j BX.%i.%j e 
            $mmatrix maprow $ractors,0 j BX.actors.%j a -background $color(d)
            $mmatrix mapcol 0,$cactors i BX.%i.actors a -background $color(d)

            $mmatrix maprow $rexp,0    j BEXP.%j  r -background $color(r)
            $mmatrix mapcol 0,$crev    i BREV.%i  r -background $color(r) 

            $mmatrix tag configure a -state disabled
            $mmatrix tag configure e -background $color(d)

        } elseif {$mode eq "BAL"} {
            # NEXT, show zeroes in the main area
            $mmatrix map 0,0 i j ZED.%i.%j t 

            # NEXT, override some of the zeroes with balancing factors
            # from the T-matrix
            $mmatrix mapcell $ractors,$cblack T.actors.black t
            $mmatrix mapcell $rworld,$cblack  T.world.black  t
            $mmatrix mapcell $rworld,$cpop    T.world.pop    t
            $mmatrix mapcell $rworld,$cgoods  T.world.goods  t
            $mmatrix mapcell $ractors,$cworld T.actors.world t 
            $mmatrix mapcell $rregion,$cworld T.region.world t

            $mmatrix maprow $rexp,0 j NA r \
                -formatcmd {format "%s"} -background $color(r)
            $mmatrix mapcol 0,$crev i NA r \
                -formatcmd {format "%s"} -background $color(r)

            $mmatrix tag configure t -background $color(d)
        } elseif {$mode eq "BASE"} {
            # NEXT, set the main area to the XT values
            $mmatrix map 0,0 i j XT.%i.%j xt 

            $mmatrix maprow $rexp,0 j XTEXP.%j r -background $color(r)
            $mmatrix mapcol 0,$crev i XTREV.%i r -background $color(r)

            $mmatrix tag configure xt -background $color(d)
        } else {
            error "Invalid mode for samsheet: $mode"
        }

        # NEXT, take focus off the menu
        focus $win
    }


    #-------------------------------------------------------------------
    # Event handlers

    # BrowseCmd sheet rc
    #
    # sheet  - the cmsheet(n) object that contains the cells
    # rc     - row,col index into the supplied cmsheet
    #
    # This method extracts the cell name from the supplied cmsheet
    # object and then converts it to the cell name and extracts the 
    # raw data and displays it in the app messageline(n) 
    # using a comma formatted number

    method BrowseCmd {sheet rc} {
        # FIRST, extract the cell name, if it does not exist, done.
        if {[$sheet cell $rc] ne ""} {
            set cell [$sheet cell $rc]

            # NEXT, convert and display in the app message line
            set val [$sam value $cell]
            if {[string is double $val]} {
                app puts [commafmt $val -places 2]
            } 
        }
    }

    # ValidateMoney cell new
    #
    #  cell - The cell that has a new value
    #  val  - The new value
    #
    # This method validates an entry that has been edited and if its
    # valid returns the new value. If it's invalid, the money command
    # throws an error and the cell remains in edit mode until fixed.

    method ValidateMoney {cell val} {
        set value [money validate $val]
        return $value
    }
    
    # ValidatePercent cell val
    #
    # cell - The cell that has a new value
    # val  - The new value that is a percentage.
    #
    # This method validates an entry that has been edited and if its
    # valid returns the new value. If it's invalid, it
    # throws an error and the cell remains in edit mode until fixed.

    method ValidatePercent {cell val} {
        set value [snit::double validate $val]
        return $value
    }

    # CellChanged cell new
    #
    #  cell - The name of the cell in the underlying cellmodel(n)
    #  new  - The new value to assume
    #
    # This method is called when the user has successfully edited a 
    # cell with a valid monetary value. The new value is converted 
    # to a number before being sent to the order processor.
    #
    # TBD: Need to deal with conversion between money format and number
    #      better, there could be a loss of precision.

    method CellChanged {cell new} {
        # FIRST convert the monetary value
        set new [::marsutil::moneyscan $new]

        # NEXT, send the order to the econ model
        adb order senddict gui ECON:SAM:UPDATE [list id $cell val $new]
    }

    # GlobalChanged cell new
    #
    # cell - The name of the cell that corresponds to a global variable
    #        in the cell model
    # new  - The new value
    #
    # This method is called when the user has successfully edited a 
    # cell that corresponds to a global variable with a valid value. 
    # The new value is sent to the order processor.

    method GlobalChanged {cell new} {
        adb order senddict gui ECON:SAM:GLOBAL [list id $cell val $new]
    }

    # SamUpdate index value
    #
    #  index - the cell index as a cellmodel(n) value (ie. BX.actors.actors)
    #  value - the new value represented as a number (not a moneyfmt)
    #
    # This event handler is called when the econ model sends a notifier
    # that a cell model value has changed. This typically is called as
    # part of undo/redo
    #
    # TBD: Need to deal with conversion between money format and number
    #      better, there could be a loss of precision.

    method SamUpdate {index value} {
        # FIRST, set the cell, solve the updated SAM and refresh the
        # sheet
        $sam set [list $index $value]

        $sam solve

        $self refresh
    }

    # SimState
    #
    # Responds to notifier events from the simulation that the state
    # of the simulation has changed. If the sim is in PREP then the
    # SAM is editable, otherwise it is not.

    method SimState {} {
        # FIRST, get the state
        if {[adb state] eq "PREP"} {
            # NEXT, set the view to input flows
            $vmenu set [lindex [dict keys $vdict] 1]

            $self DisplayCurrentView 

            # NEXT, we are in PREP set the SAM and inputs to normal 
            # and display the layout with help text.
            $mmatrix configure -state normal
            $inputs configure -state normal
            $mmatrix tag configure e -background $color(e)
            $inputs tag configure e -background $color(e)

            $win.h layout "
                Double click a cell to edit. Press \"Enter\" to save, 
                press \"Esc\" to cancel editing.<p>
                Actual actors revenue and expenses will be determined from
                the actor definitions and their strategies once the scenario
                is locked.<p>
                <table>
                  <tr>
                    <td valign=top align=left>
                      <b style=\"font-size:12px\">SAM Inputs</b><p>
                    </td>
                  </tr>
                </table>
                $layout
            "
        } else {
            # NEXT, set the view to base SAM
            $vmenu set [lindex [dict keys $vdict] 0]

            $self DisplayCurrentView

            # NEXT, we are not in PREP, disable the SAM and inputs and
            # remove the help text.
            $mmatrix configure -state disabled
            $inputs configure -state disabled
            $mmatrix tag configure e -background $color(d)
            $inputs tag configure e -background $color(d)

            $win.h layout "
                <br>
                <table width=\"80%\">
                  <tr>
                    <td colspan=2 valign=top align=left>
                      <b style=\"font-size:12px\">SAM Inputs</b><p>
                    </td>
                    <td valign=top align=right>
                      <input name=\"toolbar\"
                    </td>
                  </tr>
                </table>
                $layout
            "
        }
    }
            
    # SyncSheet
    #
    # This is called when a <Sync> notifier is received. The SAM
    # data is copied from the econ module and the SAM solved before
    # the cmsheet(n) objects are refreshed.

    method SyncSheet {} {
        $sam set [[adb econ getsam] get]
        $sam solve
        $self refresh
    }

    #-------------------------------------------------------------------
    # Public Methods

    # refresh
    #
    # Refreshes all components in the widget.
    
    method refresh {} {
        $mmatrix  refresh
        $smatrix  refresh
        $inputs   refresh
        $sizeout  refresh
        $exfaout  refresh
        $miscout  refresh
    }
}


