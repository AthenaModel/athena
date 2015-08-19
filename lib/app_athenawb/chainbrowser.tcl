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
    #   a       - Case A scenario object
    #   amode   - Case A mode
    #   afile   - Case A scenario file, or ""
    #   atext   - Case A description
    #   b       - Case B scenario object
    #   bmode   - Case B mode
    #   bfile   - case B scenario file, or ""
    #   btext   - Case B description
    #   outvar  - Name of currently displayed output variable, or ""
    
    variable info -array {}

    typevariable defaultInfo {
        a        ""
        amode    "current"
        afile    ""
        atext    "???? @ ????"
        b        ""
        bmode    "none"
        bfile    ""
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

        # NEXT, clear all content
        array set info $defaultInfo
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
        if {$info(a) ne "" && $info(a) ne "::adb"} {
            catch {$info(a) destroy}
        }
        if {$info(b) ne "" && $info(b) ne "::adb"} {
            catch {$info(b) destroy}
        }
        array unset info
        array set info $defaultInfo
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
        set parmdict [dict create]

        dict set parmdict amode $info(amode)
        dict set parmdict afile $info(afile)
        dict set parmdict bmode $info(bmode)
        dict set parmdict bfile $info(bfile)

        set choice [dynabox popup \
            -formtype     ::chainbrowser::selectcases   \
            -parent       .main                         \
            -initvalue    $parmdict                     \
            -oktext       "Analyze"                     \
            -title        "Analyze Significant Outputs" \
            -validatecmd  [mymethod ValidateCasesCB]]

        if {[dict size $choice] == 0} {
            return
        }

        $self CompareCases $choice
    }

    # ValidateCasesCB dict
    #
    # dict  - the choice dictionary
    #
    # Validates the user's choice of cases.

    method ValidateCasesCB {dict} {
        dict with dict {}

        set errdict [dict create]

        if {$amode eq "current" && [adb is unlocked]} {
            dict set errdict amode \
                "The current scenario is unlocked, and has no outputs."      
        }

        if {$amode eq "external" && ![file isfile $afile]} {
            dict set errdict afile "Specify a scenario file for Case A"
        }

        if {$bmode eq "current" && [adb is unlocked]} {
            dict set errdict bmode \
                "The current scenario is unlocked, and has no outputs."      
        }

        if {$bmode eq "external" && ![file isfile $bfile]} {
            dict set errdict bfile "Specify a scenario file for Case B"
        }

        if {[dict size $errdict] > 0} {
            throw REJECTED $errdict
        }
        return
    }

    # CompareCases dict
    #
    # dict  - A parameter dictionary from the dialog.
    #
    # Attempts to compare the cases, displaying the results in the
    # body of the browser.

    method CompareCases {dict} {
        # FIRST, set up the variables.
        $self clear
        dict with dict {}
        set errors [list]

        # NEXT, if case B is identical to case A we really have one case.
        if {$amode eq $bmode} {
            if {$amode eq "current" || 
                $amode eq "external" && $afile eq $bfile
            } {
                # Just one case.
                set bmode none
                set bfile ""
            }
        }

        set info(amode) $amode
        set info(afile) $afile
        set info(bmode) $bmode
        set info(bfile) $bfile

        # NEXT, get case A
        switch $amode {
            current {
                set info(a) ::adb
                set info(atext) "Current @ [ClockTime $info(a)]"
            }
            external {
                set info(a) [::athena::athena new]
                set info(atext) "[file tail $afile] @ "

                try {
                    $info(a) load $afile
                    append info(atext) [ClockTime $info(a)]
                } on error {result} {
                    append info(atext) "???"
                    lappend errors "Could not load Case A: $result"
                }
            }
            default {
                error "Unknown amode: \"$amode\""
            }
        }


        # NEXT, get case B
        switch $bmode {
            none {
                set info(b) $info(a)
                set info(btext) "None"
            }
            current {
                set info(b) ::adb
                set info(atext) "Current @ [ClockTime $info(b)]"
            }
            external {
                set info(b) [::athena::athena new]
                set info(btext) "[file tail $bfile] @ "

                try {
                    $info(b) load $bfile
                    append info(btext) [ClockTime $info(b)]
                } on error {result} {
                    append info(btext) "???"
                    lappend errors "Could not load Case B: $result"
                }
            }
            default {
                error "Unknown bmode: \"$bmode\""
            }
        }

        # NEXT, if there are errors display them.
        if {[llength $errors] > 0} {
            $self ShowErrors $errors
            return
        }


        # NEXT, validate case A
        if {[$info(a) is unlocked]} {
            lappend errors "Case A is unlocked, and has no outputs."
        }

        # NEXT, if we have two cases verify that case B is unlocked and
        # comparable to case A.
        if {$bmode ne "none"} {
            if {[$info(b) is unlocked]} {
                lappend errors "Case B is unlocked, and has no outputs."
            } else {
                try {
                    ::athena::comparison check $info(a) $info(b)
                } trap {ATHENA INCOMPARABLE} {result} {
                    lappend errors $result
                }                
            }
        }

        # NEXT, if there are errors display them.
        if {[llength $errors] > 0} {
            $self ShowErrors $errors
            return
        }

        # NEXT, create a comparison object, and display its contents.
        # TBD

        return
    }

    # ShowErrors errors
    #
    # errors   - A list of error messages
    #
    # Displays the errors in the body of the browser.

    method ShowErrors {errors} {
        # For now, just print
        puts [join $errors \n]
    }

    # ClockTime scn
    #
    # scn  - A scenario object
    #
    # Gets the clock time string.

    proc ClockTime {scn} {
        return "[$scn clock asString] ([$scn clock now])"
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

    rcc "Case A:" -for amode
    selector amode {
        case current "Current Scenario" {}
        case external "External Scenario" {
            rcc "Scenario&nbsp;File:" -for afile
            file afile \
                -title "Select a scenario file to compare" \
                -width 30 \
                -filetypes {
                    { {Athena Scenario} {.adb} }
                }
        }
    }

    rcc "&nbsp;"

    rcc "Case B:" -for bmode
    selector bmode {
        case none    "None" {}
        case current "Current Scenario" {}
        case external "External Scenario" {
            rcc "Scenario&nbsp;File:" -for bfile
            file bfile \
                -title "Select a scenario file to compare" \
                -width 30 \
                -filetypes {
                    { {Athena Scenario} {.adb} }
                }
        }
    }
}


