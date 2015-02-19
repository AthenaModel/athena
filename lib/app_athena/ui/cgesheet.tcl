#-----------------------------------------------------------------------
# FILE: cgesheet.tcl
#
#   Economics CGE Spreadsheet view for the 6 sector model.
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
# This module is responsible for displaying the current state of 
# the economy via a Computable General Equilibrium matrix
#
# TBD: Consider doing lazy update.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widget cgesheet {
    #-------------------------------------------------------------------
    # Group: Lookup Tables
    #
    # These variables contain constant data used in building and
    # operating the GUI.

    # Type Variable: units
    #
    # This variable serves two purposes: its keys are the sector names,
    # and its values are the units for each sector.
    #
    # NOTE: If we have more meta-data, we will need something more
    # complicated.

    typevariable units {
        goods goodsBKT/yr
        black blackBKT/yr
        pop   work-years/yr
    }

    # Type Variable: color
    #
    # Look-up table for colors of various kinds.
    #
    #  q - Color for quantities of things
    #  x - Color for money amounts

    #  old x "#CCFF99"

    typevariable color -array {
        q "#FFCC33"
        x "#D4E3FF"
    }

    # Dictionary of views available for the CGE sheet.
    variable vdict

    # Array of narrative text that describes each view in vdict
    variable ntext -array {
        Out {
            The economy constrained by sector capacity, geographic unemployment
            and security factors taken into consideration. In addition to 
            labor and goods capacity limits, this view reflects the 
            labor force proximity to where the jobs are and whether 
            people are either afraid to work or to go to market.
        }

        M   {
            The economy constrained by sector capacity. This view of the 
            economy reflects labor and goods capacity limits.
        }

        L   {
            The economy with all available capacity being utilized. This view
            shows what the economy would look like if everyone that could
            work was working except for those between jobs.
        }

        Cal {
            The economy as calibrated from the Base SAM. The GDP and 
            unemployment rate should match those in the Base SAM. 
            Geographic unemployment is not accounted for.
        }
    }

    #-------------------------------------------------------------------
    # Group: Options
    #
    # Unknown options delegated to the hull

    delegate option * to hull
 
    # The economic model's CGE cellmodel(n) .
    component cge

    # A label widget that displays the econ model as disabled, if
    # it is so.
    component sheetlbl

    # The toolbar 
    component toolbar
    component vmenu

    # The htmlframe that holds all the widgets
    component hframe

    # The cmsheet(n) widgets used to display values from the CGE.
    component money
    component quant
    component inputs
    component outputs
        
    #--------------------------------------------------------------------
    # Group: Constructor

    # Constructor: Constructor
    #
    # Create the widget and map the CGE.

    constructor {args} {
        # FIRST, get the options.
        $self configurelist $args

        # NEXT the dropdown menu of views and their keys
        set vdict [dict create \
            "Constrained with Geo. Unemp. and Sec. Factors" Out \
            "Constrained by Labor and Goods Capacities"     M   \
            "Constrained by Total Labor"                    L   \
            "Calibrated Values from Base SAM"               Cal]

        # NEXT, Get the CGE.
        set cge [econ getcge]

        # NEXT, the frame for the htmlframe and scroll bar
        ttk::frame $win.frm

        # NEXT create the htmlfram and GUI components
        install hframe using htmlframe $win.frm.h \
            -yscrollcommand [list $win.frm.yscroll set]

        $self CreateMoneyMatrix    $win.frm.h.money
        $self CreateQuantMatrix    $win.frm.h.quant
        $self CreateScalarInputs   $win.frm.h.inputs
        $self CreateScalarOutputs  $win.frm.h.outputs

        ttk::scrollbar $win.frm.yscroll \
            -command [list $win.frm.h yview]

        # NEXT the toolbar and the menu that goes in it
        install toolbar using ttk::frame $win.frm.h.toolbar

        $self CreateViewMenu $win.frm.h.toolbar

        install sheetlbl using ttk::label $win.frm.h.sheetlbl \
            -text "Current Economy" -font messagefontb

        # NEXT, pack all the widgets into tab
        pack $win.frm.h       -side left  -expand 0 -fill both      
        pack $win.frm.yscroll -side left  -expand 1 -fill y -anchor e
        pack $win.frm                     -expand 1 -fill both

        # NEXT, prepare for updates.
        notifier bind ::sim  <DbSyncB>   $self [mymethod refresh]
        notifier bind ::sim  <Tick>      $self [mymethod refresh]
        notifier bind ::econ <CgeUpdate> $self [mymethod refresh]

        # NEXT, populate the HTML frame based on view
        $self DisplayCurrentView
    }

    # Constructor: Destructor
    #
    # Forget the notifier bindings.
    
    destructor {
        notifier forget $self
    }

    # CreateViewMenu w
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
        $vmenu set [lindex [dict keys $vdict] 0]
    }

    # CreateMoneyMatrix   w
    #
    #   w - The widget window
    #
    # Creates the CGE money component, which displays the current
    # 6x6 CGE in amounts of money with elaborations.
    
    method CreateMoneyMatrix {w} {
        # FIRST, get some important values
        set sectors [$cge index i]
        set ns      [llength $sectors]
        set rexp    $ns
        let nrows   {$ns + 2}
        let ncols   {$ns + 5}

        # NEXT, create the cmsheet(n), which is readonly.
        install money using cmsheet $w             \
            -cellmodel     $cge                    \
            -state         disabled                \
            -rows          $nrows                  \
            -cols          $ncols                  \
            -roworigin     -1                      \
            -colorigin     -1                      \
            -titlerows     1                       \
            -titlecols     1                       \
            -browsecommand [mymethod BrowseCmd $w %C] \
            -formatcmd     ::marsutil::moneyfmt

        $money textcol 0,-1 [concat $sectors {Expense}]

        $money maprow $rexp,0 j Out::EXP.%j %cell \
            -background $color(x)

        # Main area
        let ractors {$ns - 3}
        let rworld  {$ns - 1}
        set rexp    $ns
        let cactors {$ns - 3}
        let cworld  {$ns - 1}
        set crev    $ns
        let cp      {$ns + 1}
        let cq      {$ns + 2}
        let cunits  {$ns + 3}
        let cidle   {$ns + 4}

        # NEXT, add titles and empty area
        $money textrow -1,0 [concat $sectors {
            Revenue Price Quantity ""}]

        $money textcell -1,$cunits "Units" units \
            -relief flat                         \
            -anchor w
        $money textcol 0,$cunits [dict values $units] units

        $money width -1 12
        $money width $cunits 13

        $money empty $rexp,$crev $rexp,$cidle
        $money empty $ractors,$cp $rworld,$cidle

        # NEXT, Set up the cells
        $money mapcol 0,$crev i Out::REV.%i %cell \
            -background $color(x)
        $money mapcol 0,$cp   gbp Out::P.%gbp   p     \
            -background $color(x)
        $money mapcol 0,$cq   gbp Out::QS.%gbp  q     \
            -background $color(q)

        $money textcell -1,-1 "X.i.j" 

        # NEXT, map amounts of money to the cmsheet
        $money map 0,0 i j Out::X.%i.%j x \
            -background $color(x)
    }

    # CreateQuantMatrix   w
    #
    #   w -  the widget window
    #
    # Creates the CGE quantities component, which displays the 
    # current 6x6 CGE in quantities for those sectors that have
    # them.

    method CreateQuantMatrix {w} {
        # FIRST, get some important values
        set csectors [$cge index i]
        set rsectors [$cge index gbp]
        set nc       [llength $csectors]
        set nr       [llength $rsectors]
        set rdem     $nr
        let cactors  {$nc - 3}
        let cidle    {$nc + 3}
        let nrows    {$nr + 2}
        let ncols    {$nc + 5}

        # NEXT, create the cmsheet(n), which is readonly.
        install quant using cmsheet $w             \
            -cellmodel     $cge                    \
            -state         disabled                \
            -rows          $nrows                  \
            -cols          $ncols                  \
            -roworigin     -1                      \
            -colorigin     -1                      \
            -titlerows     1                       \
            -titlecols     1                       \
            -browsecommand [mymethod BrowseCmd $w %C] \
            -formatcmd     [mymethod FormatOutput]

        $quant textcol 0,-1 [concat $rsectors {Demand}]

        $quant maprow $rdem,0 gbp Out::QD.%gbp %cell \
            -background $color(q)

        # Main area
        set ractors $nr
        let cworld  {$nc - 1}
        set cq      $nc
        let cunits  {$nc + 1}
        let clatent {$nc + 2}

        # NEXT, add titles and empty area
        $quant textrow -1,0 [concat $csectors {
            Quantity "" LatentDmd IdleCap}]

        $quant textcell -1,$cunits "Units" units \
            -relief flat                         \
            -anchor w

        $quant textcol 0,$cunits [dict values $units] units

        $quant width -1 12
        $quant width $cunits 13

        $quant empty $rdem,$cactors $rdem,$cidle

        # NEXT, Set up the cells
        $quant mapcol 0,$cq   gbp Out::QS.%gbp  q     \
            -background $color(q)
        $quant mapcol 0,$clatent gbp Out::LATENTDEMAND.%gbp q
        $quant mapcol 0,$cidle   gbp Out::IDLECAP.%gbp q

        $quant textcell -1,-1 "QD.i.j"

        # NEXT, map quantities to the cmsheet
        $quant map 0,0 gbp j Out::QD.%gbp.%j qij \
            -background $color(q)
    }

    # Type Method: CreateScalarInputs
    #
    # Creates the "inputs" component, which displays the current
    # scalar inputs.
    # 
    # Syntax:
    #   CreateScalarInputs _w_
    #
    #   w - The frame widget

    method CreateScalarInputs {w} {
        # FIRST, create the cmsheet(n), which is readonly.
        install inputs using cmsheet $w               \
            -roworigin     0                          \
            -colorigin     0                          \
            -cellmodel     $cge                       \
            -state         disabled                   \
            -rows          10                         \
            -cols          3                          \
            -titlerows     0                          \
            -titlecols     1                          \
            -browsecommand [mymethod BrowseCmd $w %C] \
            -formatcmd     ::marsutil::moneyfmt

        pack $inputs -fill both -expand 1

        # NEXT, add titles
        $inputs textcol 0,0 {
            "Consumers"
            "Consumer Sec. Factor"
            "Labor Force"
            "Geo. Unemployed"
            "Labor Sec. Factor"
            "Price Index"
            "Wage Index"
            "FAR Graft Factor"
            "Remittances"
            "REM Chage Rate"
        }

        $inputs textcol 0,2 {
            "People"
            ""
            "People"
            "People"
            ""
            ""
            ""
            ""
            "$/year"
            "%/year"
        } units -anchor w -relief flat
        
        # NEXT, add data
        $inputs mapcell 0,1 In::Consumers  q -background $color(q)
        $inputs mapcell 1,1 In::CSF        q -formatcmd {format "%.3f"}
        $inputs mapcell 2,1 In::LF         q
        $inputs mapcell 3,1 In::GU         q
        $inputs mapcell 4,1 In::LSF        q -formatcmd {format "%.3f"}
        $inputs mapcell 5,1 In::PriceIndex q -formatcmd {format "%.3f"}
        $inputs mapcell 6,1 In::WageIndex  q -formatcmd {format "%.3f"}
        $inputs mapcell 7,1 graft          q -formatcmd {format "%.3f"}
        $inputs mapcell 8,1 In::REM        q 
        $inputs mapcell 9,1 Global::REMChangeRate q -formatcmd {format "%.1f"}

        # NEXT, expand widths
        $inputs width 0 21
    }

    # Type Method: CreateScalarOutputs
    #
    # Creates the "outputs" component, which displays the current
    # scalar outputs.
    # 
    # Syntax:
    #   CreateScalarOutputs _w_
    #
    #   w - The frame widget

    method CreateScalarOutputs {w} {
        # FIRST, create the cmsheet(n), which is readonly.
        install outputs using cmsheet $w  \
            -roworigin     0                          \
            -colorigin     0                          \
            -cellmodel     $cge                       \
            -state         disabled                   \
            -rows          9                          \
            -cols          3                          \
            -titlerows     0                          \
            -titlecols     1                          \
            -browsecommand [mymethod BrowseCmd $w %C] \
            -formatcmd     [mymethod FormatOutput]

        # NEXT, add titles
        $outputs textcol 0,0 {
            "GDP"
            "CPI"
            "Deflated GDP"
            "Per Capita Deflated GDP"
            "Per Cap. Demand for goods"
            "Real Unemployment"
            "Unemployment"
            "Unemp. Rate"
            "Insecure Labor Force"
        }

        $outputs width 0 25

        $outputs textcol 0,2 {
            "$/Year"
            ""
            "$/Year, Deflated"
            "$/Year, Deflated"
            "goodsBKT/year"
            "work-years"
            "work-years"
            "%"
            "work-years"
        } units -anchor w -relief flat

        $outputs width 2 17
        
        # NEXT, add data
        $outputs mapcell  0,1 Out::GDP          x -background $color(x)
        $outputs mapcell  1,1 Out::CPI          q -background $color(q)
        $outputs mapcell  2,1 Out::DGDP         x
        $outputs mapcell  3,1 Out::PerCapDGDP   x 
        $outputs mapcell  4,1 Out::A.goods.pop  q
        $outputs mapcell  5,1 Out::RealUnemp    q
        $outputs mapcell  6,1 Out::Unemployment q
        $outputs mapcell  7,1 Out::UR           q
        $outputs mapcell  8,1 Out::LFU          q
    }

    # FormatOutput value
    # 
    # This callback takes a value and, depending on whether it is a
    # number or not, returns it's formatted value

    method FormatOutput {value} {
        if {[string is double -strict $value]} {
            return [::marsutil::moneyfmt $value]
        } else {
            return [format "%s" $value]
        }
    }

    # DisplayCurrentView
    #
    # This method remaps appropriate cells in cmsheets to cells that
    # reside either in the "Cal", "L", "M" or "Out" namespaces in the 
    # cellmodel(n) that is being displayed.
    #
    # Cal - the values for which the cellmodel was calibrated 
    # L   - the "long" term or unconstrained solution
    # M   - the "medium" term or capacity constrained 
    # Out - the output or "short" term capacity, geo. unemp. and security 
    #       factor constrained solution

    method DisplayCurrentView {} {
        # FIRST, extract the mode from the menu selection
        set mode [dict get $vdict [$vmenu get]]

        # NEXT, set the narrative based on mode.
        $hframe layout "
            <table width=100%>
              <tr>
                <td valign=top>
                  <input name=sheetlbl><p>
                </td>
                <td valign=top align=right>
                  <input name=toolbar>
                </td>
              </tr>
            </table>
            <table width=100%>
              <tr>
                <td>
                  [normalize $ntext($mode)]<p>
                </td>
              </tr>
            </table>
            <table>
              <tr>
                <td colspan=2>
                  <b style=font-size:12px>Dollars</b><br>
                  <input name=money><p>
                  <br><br>
                  <b style=font-size:12px>Quantities</b><br>
                  <input name=quant><p>
                </td>
              </tr>
              <tr>
                <td valign=top>
                  <b style=font-size:12px>Current Inputs</b><p>
                  <input name=inputs>
                </td>
                <td valign=top>
                  <b style=font-size:12px>Other Outputs</b><p>
                  <input name=outputs>
                </td>
              </tr>
            </table>
        " 
        # NEXT, some local variable to get the mapping right
        set sectors [$cge index i]
        set ns      [llength $sectors]
        set rexp    $ns
        set crev    $ns
        let cp      {$ns + 1}
        let cq1     {$ns + 2}
        set csectors [$cge index i]
        set rsectors [$cge index gbp]
        set nc       [llength $csectors]
        set nr       [llength $rsectors]
        let clatent {$nc + 2}
        let cidle   {$nc + 3}
        set rdem     $nr
        set cq2      $nc

        # NEXT, expenditures for each sector
        $money maprow $rexp,0 j ${mode}::EXP.%j %cell \
            -background $color(x)

        # NEXT, revenues for all sectors and prices and
        # quantities supplied for sectors with product
        $money mapcol 0,$crev i ${mode}::REV.%i %cell \
            -background $color(x)
        $money mapcol 0,$cp   gbp ${mode}::P.%gbp   p \
            -background $color(x)
        $money mapcol 0,$cq1  gbp ${mode}::QS.%gbp  q \
            -background $color(q)

        # NEXT, the main area of sector by sector money flows
        $money map 0,0 i j ${mode}::X.%i.%j x \
            -background $color(x)

        # NEXT, quantities demanded by goods, black and pop
        $quant maprow $rdem,0 gbp ${mode}::QD.%gbp %cell \
            -background $color(q)

        # NEXT, quantities supplied by goods, black and pop
        $quant mapcol 0,$cq2  gbp ${mode}::QS.%gbp  q     \
            -background $color(q)

        # NEXT, the main area of sector by sector supply and demand
        $quant map 0,0 gbp j ${mode}::QD.%gbp.%j qij \
            -background $color(q)

        $quant mapcol 0,$clatent gbp ${mode}::LATENTDEMAND.%gbp q
        $quant mapcol 0,$cidle   gbp ${mode}::IDLECAP.%gbp q

        # NEXT, some outputs that depend on mode
        $outputs mapcell  0,1 ${mode}::GDP          x -background $color(x)
        $outputs mapcell  1,1 ${mode}::CPI          q -background $color(q)
        $outputs mapcell  2,1 ${mode}::DGDP         x
        $outputs mapcell  3,1 ${mode}::PerCapDGDP   x 
        $outputs mapcell  4,1 ${mode}::A.goods.pop  q
        $outputs mapcell  5,1 ${mode}::RealUnemp    q
        $outputs mapcell  6,1 ${mode}::Unemployment q
        $outputs mapcell  7,1 ${mode}::UR           q
        $outputs mapcell  8,1 ${mode}::LFU          q

        # NEXT, take focus off the menu
        focus $win
    }

    #------------------------------------------------------------------
    # Event Callback Handler

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
            set val [$cge value $cell]
            if {[string is double $val]} {
                app puts [commafmt $val -places 2]
            } 
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    # Method: refresh
    #
    # Refreshes all components in the widget.
    
    method refresh {} {
        if {[econ state] eq "DISABLED"} {
            $sheetlbl configure -text "Current Economy (*DISABLED*)" 
        } else {
            $sheetlbl configure -text "Current Economy" 
        }

        $money   refresh
        $quant   refresh
        $inputs  refresh
        $outputs refresh
    }
}


