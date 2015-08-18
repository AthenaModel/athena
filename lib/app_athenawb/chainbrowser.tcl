#-----------------------------------------------------------------------
# TITLE:
#    chainbrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    chainbrowser(sim) package: Browser for significant outputs and
#    causality chains
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widget chainbrowser {
    #-------------------------------------------------------------------
    # Lookup Tables and Constants

    typevariable sigLevels {
        100.0
         90.0
         80.0
         70.0
         60.0
         50.0
         40.0
         30.0
         20.0
         10.0
          0.0
    }
    
    #-------------------------------------------------------------------
    # Options

    # Options delegated to the hull
    delegate option * to hull

    #-------------------------------------------------------------------
    # Components

    component olist   ;# Tablelist containing output variables

    #-------------------------------------------------------------------
    # Instance Variables

    # info array
    #
    #   atext   - Case A description
    #   btext   - Case B description
    #   outvar  - Name of currently displayed output variable, or ""
    
    variable info -array {}

    typevariable defaultInfo -array {
        atext    "???? @ ????"
        btext    "???? @ ????"
        outvar   ""
        siglevel 20.0
    }


    #--------------------------------------------------------------------
    # Constructor
    #
    # The GUI appearance of this browser is as follows:
    # +-----------------------------------------------------------------+
    # | Toolbar                                                         |
    # +-------------+---------------------------------------------------+
    # | hpaner      | opane                                             |
    # | +-------+-+ | +-----------------------------------------------+ |
    # | |       | | | | Detail                                        | |
    # | | OList |s| | |                                               | |
    # | |       |c| | |                                               | |
    # | |       |r| | +-----------------------------------------------+ |
    # | |       |o| | +---------------------------------------------+-+ |
    # | |       |l| | | Chain                                       |s| |
    # | |       |l| | |                                             |c| |
    # | |       | | | |                                             |r| |
    # | |       | | | |                                             |o| |
    # | |       | | | |                                             |l| |
    # | |       | | | |                                             |l| |
    # | +-------+-+ | +---------------------------------------------+-+ |
    # +-------------+---------------------------------------------------+ 
    #
    # Names with an initial cap are major components containing application
    # data.  Names beginning with a lower case letter are purely for
    # geometry management.
    #
    # Containers:
    #     toolbar - The toolbar
    #     hpaner  - a panedwindow, split horizontally.
    #     opane   - output variable pane: a frame containing information 
    #               about the selected block.
    #
    # Content:
    #     OList   - An sqlbrowser listing the significant outputs
    #               and their scores.
    #     OVar    - A pane containing data about the selected output itself
    #     Chain   - A pane containing the causality chain for the selected
    #               output.

    constructor {args} {
        # FIRST, create the GUI containers, as listed above.

        # hpaner
        ttk::panedwindow $win.hpaner \
            -orient horizontal

        # opane
        ttk::frame $win.hpaner.opane

        # NEXT, create the content components
        $self ToolbarCreate $win.toolbar
        ttk::separator $win.sep 

        $self OListCreate   $win.hpaner.olist
        # $self DetailCreate  $win.hpaner.opane.detail
        # $self ChainCreate   $win.hpaner.opane.chain

        # NEXT, manage geometry.

        # pack $win.hpaner.opane.detail -side top -fill x
        # pack $win.hpaner.opane.chain  -fill both -expand yes

        $win.hpaner add $win.hpaner.olist 
        $win.hpaner add $win.hpaner.opane -weight 1

        pack $win.toolbar -side top -fill x
        pack $win.sep -side top -pady 2 -fill x
        pack $win.hpaner            -fill both -expand yes

        # NEXT, configure the command-line options
        $self configurelist $args

        # NEXT, Monitor the application so that we know when the current
        # scenario has changed in some way.

        # TBD: <Time>, <State>

        # sNEXT, clear all content
        $self clear
    }

    destructor {
        notifier forget $self
    }

    #-------------------------------------------------------------------
    # clear

    # clear
    #
    # Reset the browser to display nothing.

    method clear {} {
        array unset info
        array set info [array get defaultInfo]
    }
    

    #-------------------------------------------------------------------
    # Toolbar

    # ToolbarCreate w
    #
    # w  - The name of the toolbar widget.
    #
    # Creates and populates the tool bar widget.

    method ToolbarCreate {w} {
        # FIRST, create the frame.
        frame $w

        # NEXT, add the children.

        ttk::button $w.select \
            -text    "Select Cases" \
            -command [mymethod SelectCasesCB]

        ttk::label $w.alabel \
            -text "Case A:"
        ttk::label $w.atext \
            -textvariable [myvar info(atext)]

        ttk::label $w.blabel \
            -text "Case B:"
        ttk::label $w.btext \
            -textvariable [myvar info(btext)]

        ttk::label $w.levlabel \
            -text "Significance Level:"

        ttk::combobox $w.siglevel \
            -height       [llength $sigLevels]   \
            -width        5                      \
            -state        readonly               \
            -values       $sigLevels             \
            -textvariable [myvar info(siglevel)]

        bind $w.siglevel <<ComboboxSelected>> [mymethod SigLevelCB]

        # NEXT, pack them in.
        pack $w.select -side left -padx {0 10}
        pack $w.alabel -side left
        pack $w.atext  -side left -padx {0 10}
        pack $w.blabel -side left
        pack $w.btext  -side left -padx {0 5}

        pack $w.siglevel -side right
        pack $w.levlabel -side right
    } 


    # SelectCasesCB
    #
    # The user has pressed the "Select Cases" button.

    method SelectCasesCB {} {
        set choice [dynabox popup \
            -formtype     ::chainbrowser::selectcases   \
            -parent       .main                         \
            -initvalue    {mode single amode current}   \
            -oktext       "Analyze"                     \
            -title        "Analyze Significant Outputs" \
            -validatecmd  [mymethod ValidateCasesCB]]

        if {[dict size $choice] == 0} {
            return
        }

        puts "Cases: $choice"
    }

    # ValidateCasesCB dict
    #
    # dict  - the choice dictionary
    #
    # Validates the user's choice of cases.

    method ValidateCasesCB {dict} {
        return
    }

    # SigLevelCB
    #
    # The user has chosen a new significance level.

    method SigLevelCB {} {
        puts "SigLevelCB $info(siglevel)"
    }


    #-------------------------------------------------------------------
    # Output Variable List (OList)

    # OListCreate pane
    #
    # pane - The name of the output variable list's pane widget
    #
    # Creates the "olist" component, which lists all of the
    # output variables in order of signficance.

    method OListCreate {pane} {
        ttk::frame $pane

        # FIRST, create the components
        install olist using tablelist::tablelist $pane.tlist \
            -background       white                          \
            -foreground       black                          \
            -font             codefont                       \
            -width            25                             \
            -height           14                             \
            -state            normal                         \
            -stripebackground #CCFFBB                        \
            -selectbackground black                          \
            -selectforeground white                          \
            -labelborderwidth 1                              \
            -labelbackground  $::marsgui::defaultBackground  \
            -selectmode       browse                         \
            -exportselection  false                          \
            -movablecolumns   no                             \
            -activestyle      none                           \
            -yscrollcommand   [list $pane.yscroll set]       \
            -xscrollcommand   [list $pane.xscroll set]

        ttk::scrollbar $pane.yscroll      \
            -orient  vertical             \
            -command [list $olist yview]

        ttk::scrollbar $pane.xscroll      \
            -orient  horizontal           \
            -command [list $olist xview]

        # NEXT, lay out the components.
        grid $olist        -row 0 -column 0 -sticky nsew
        grid $pane.yscroll -row 0 -column 1 -sticky ns -pady {1 0}
        grid $pane.xscroll -row 1 -column 0 -sticky ew -padx {1 0}

        grid columnconfigure $pane 0 -weight 1
        grid rowconfigure    $pane 0 -weight 1

        # NEXT, Columns

        $olist insertcolumns end 0 "Variable" left
        $olist insertcolumns end 5 "Score"    right

        $olist columnconfigure 0 -stretchable yes


        # NEXT, Behaviour
 
        # Force focus when the tablelist is clicked
        bind [$olist bodytag] <1> [focus $olist]
                
        # Handle selections.
        bind $olist <<TablelistSelect>> [mymethod OListSelectCB]   
    }   
}

#-----------------------------------------------------------------------
# Dynaform: Select Cases

dynaform define ::chainbrowser::selectcases {
    rc {
        Enter the scenario(s) whose outputs you wish to analyze.
    } -span 2

    rc ""

    rcc "Compare&nbsp;Cases:"
    selector mode {
        case single "Beginning and End of Run" {
            rcc "Case:" -for amode
            selector amode {
                case current "Current Scenario" {}
                case external "External Scenaro" {
                    rcc "Scenario&nbsp;File:"
                    file afile \
                        -title "Select a scenario file to compare" \
                        -width 30 \
                        -filetypes {
                            { {Athena Scenario} {.adb} }
                        }
                }
            }
        }
        case double "Two Distinct Runs" {
            rcc "Case A:" -for amode
            selector amode {
                case current "Current Scenario" {}
                case external "External Scenario" {
                    rcc "Scenario&nbsp;File:"
                    file afile \
                        -title "Select a scenario file to compare" \
                        -width 30 \
                        -filetypes {
                            { {Athena Scenario} {.adb} }
                        }
                }
            }

            rcc "Case B:" -for bmode
            selector bmode {
                case current "Current Scenario" {}
                case external "External Scenaro" {
                    rcc "Scenario&nbsp;File:"
                    file bfile \
                        -title "Select a scenario file to compare" \
                        -width 30 \
                        -filetypes {
                            { {Athena Scenario} {.adb} }
                        }
                }
            }
        }
    }
}


