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
    component ovar    ;# Output Variable pane
    component chain   ;# Tablelist containing chain
    component ivar    ;# Input Variable pane

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
    #   comp    - Comparison(n) object
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
        comp     ""
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
    # | hpaner      | data                                              |
    # | +-------+-+ | +---------------------------------------------+-+ |
    # | |       | | | | OVar: Output variable detail pane           | | |
    # | | OList |s| | |                                             | | |
    # | |       |c| | |                                             | | |
    # | |       |r| | +---------------------------------------------+-+ |
    # | |       |o| | +---------------------------------------------+-+ |
    # | |       |l| | | Chain: Causality chain tree                 | | |
    # | |       |l| | |                                             | | |
    # | |       | | | |                                             | | |
    # | |       | | | +---------------------------------------------+-+ |
    # | |       | | | +---------------------------------------------+-+ |
    # | |       | | | | IVar: Input variable detail pane            | | |
    # | |       | | | |                                             | | |
    # | |       | | | |                                             | | |
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
    #     data   - output variable pane: a frame containing information 
    #               about the selected block.
    #
    # Content:
    #     OList   - An sqlbrowser listing the significant outputs
    #               and their scores.
    #     OVar    - A pane containing data about the selected output itself
    #     Chain   - A pane containing the causality chain for the selected
    #               output.
    #     IVar    - A pane containing data about an input selected in the
    #               Chain.

    constructor {args} {
        # FIRST, create the GUI containers, as listed above.

        # hpaner
        ttk::panedwindow $win.hpaner \
            -orient horizontal

        # data
        ttk::frame $win.hpaner.data

        # NEXT, create the content components
        $self ToolbarCreate $win.toolbar
        ttk::separator $win.sep 

        $self OListCreate   $win.hpaner.olist
        $self OVarCreate    $win.hpaner.data.ovar
        $self ChainCreate   $win.hpaner.data.chain
        $self IVarCreate    $win.hpaner.data.ivar

        # NEXT, manage geometry.

        pack $win.hpaner.data.ovar  -fill x    -side top
        pack $win.hpaner.data.ivar  -fill x    -side bottom
        pack $win.hpaner.data.chain -fill both -expand yes

        $win.hpaner add $win.hpaner.olist 
        $win.hpaner add $win.hpaner.data -weight 1

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

        # NEXT, turn off size propagation, once it has displayed itself.
        after 1 [format {
            if {[winfo exists %s]} {
                pack propagate %s off
            }
        } $win.hpaner.data $win.hpaner.data]
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

        if {$info(comp) ne ""} {
            catch {$info(comp) destroy}
        }
        array unset info
        array set info $defaultInfo

        $self OListClear
        $ovar clear
        $ivar clear
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
        if {$bmode eq "none"} {
            set info(ta) 0
            set info(tb) [$info(a) clock now]
        } else {
            set info(ta) [$info(a) clock now]
            set info(tb) [$info(b) clock now]
        }

        set info(comp) [::athena::comparison new \
            $info(a) $info(ta) $info(b) $info(tb)]

        $info(comp) compare

        # NEXT, Show the data
        $self OListLoad

        return
    }

    # ShowErrors errors
    #
    # errors   - A list of error messages
    #
    # Displays the errors in the body of the browser.

    method ShowErrors {errors} {
        set info(atext) "???? @ ????"
        set info(btext) "???? @ ????"

        messagebox popup \
            -parent     [app topwin]                  \
            -icon       warning                       \
            -title      "Could not compare scenarios" \
            -wraplength 200                           \
            -message    [join $errors \n]
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
        $self OListLoad
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
            -width            30                             \
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
            -xscrollcommand   [list $pane.xscroll set]       \
            -labelcommand     ::tablelist::sortByColumn

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
        $olist insertcolumns end 7 "Score"    right

        $olist columnconfigure 0 -stretchable yes -sortmode ascii
        $olist columnconfigure 1 -stretchable yes -sortmode real


        # NEXT, Behaviour
 
        # Force focus when the tablelist is clicked
        bind [$olist bodytag] <1> [focus $olist]
                
        # Handle selections.
        bind $olist <<TablelistSelect>> [mymethod OListSelectCB]   
    }   

    # OListLoad
    #
    # Loads the current data into the OList

    method OListLoad {} {
        $self OListClear

        if {$info(comp) eq ""} {
            return
        }

        foreach vardiff [$info(comp) list] {
            set score [format %.2f [$info(comp) score $vardiff]]
            if {$score != 0.0 && $score >= $info(siglevel)} {
                $olist insert end [list [$vardiff name] $score]
            }
        }

        $olist sortbycolumn 1 -decreasing
    }

    # OListClear
    #
    # Removes all data from the OList.

    method OListClear {} {
        $olist delete 0 end
    }

    # OListSelectCB
    #
    # Called when an output variable is selected in the OList.

    method OListSelectCB {} {
        set rindex [lindex [$olist curselection] 0]

        if {$rindex ne ""} {
            lassign [$olist get $rindex] varname score

            $ovar show [$info(comp) getdiff $varname] $score

            # TBD: Temporary!
            $ivar show [$info(comp) getdiff $varname] $score            
        }
    }

    #-------------------------------------------------------------------
    # Output Variable Detail Pane (OVar)

    # OVarCreate pane
    #
    # pane - The name of the output variable's pane widget
    #
    # Creates the "ovar" component, which displays detail about the
    # selected output variable.

    method OVarCreate {pane} {
        install ovar using vardisp $pane \
            -prefix "Primary Output:" \
            -prompt "Select an output variable from the left sidebar."
    }

    #-------------------------------------------------------------------
    # Chain Pane (Chain)

    # ChainCreate pane
    #
    # pane - The name of the chain list's pane widget
    #
    # Creates the "chain" component, which lists all of the
    # input variables in a chain in order of signficance.

    method ChainCreate {pane} {
        install chain using tablelist::tablelist $pane
    }

    #-------------------------------------------------------------------
    # Input Variable Detail Pane (IVar)

    # IVarCreate pane
    #
    # pane - The name of the input variable's pane widget
    #
    # Creates the "ivar" component, which displays detail about the 
    # selected input variable.

    method IVarCreate {pane} {
        install ivar using vardisp $pane \
            -prefix "Input:" \
            -prompt "Select an input variable from the list above."
    }
}

#-----------------------------------------------------------------------
# vardisp widget

snit::widget vardisp {
    #-------------------------------------------------------------------
    # Components

    component triangle  ;# Triangle button
    component detail    ;# An htmlframe containing the detailed info.
    
    #-------------------------------------------------------------------
    # Options

    # -prefix text
    #
    # Specify a prefix to display prior to the variable name at the
    # top of the widget.
    option -prefix \
        -default "Variable:"

    option -prompt \
        -default "No variable selected."

    # -prompt text
    #
    # Specify a string to use as a prompt when no vardiff is selected.

    option -prompt \
        -default "No variable selected."


    #-------------------------------------------------------------------
    # Instance Variables

    # info array
    #
    #   open     - 1 if detail is open, 0 otherwise.
    #   title    - Content of title widget
    #   vardiff  - The vardiff object to display, or ""
    #   score    - The score for this vardiff in this context. 

    variable info -array {
        open     0
        title    ""
        vardiff  ""
        score    0.0
    }


    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        $self configurelist $args

        install triangle using ArrowButton $win.triangle \
            -relief             flat                     \
            -clean              2                        \
            -type               button                   \
            -dir                right                    \
            -width              20                       \
            -height             20                       \
            -highlightthickness 0                        \
            -command            [mymethod toggle]

        ttk::label $win.title \
            -textvariable [myvar info(title)]

        install detail using htmlframe $win.detail

        grid $win.triangle  -row 0 -column 0
        grid $win.title     -row 0 -column 1 -sticky ew
        # $win.detail is hidden by default.

        grid columnconfigure $win 1 -weight 1
        grid rowconfigure    $win 2 -weight 1

        $self clear
    }

    #-------------------------------------------------------------------
    # Methods

    # show vardiff score
    #
    # vardiff   - A vardiff to display
    # score     - Its score in some particular context.

    method show {vardiff score} {
        set info(vardiff) $vardiff
        set info(score)   $score

        $triangle configure -state normal

        $self Refresh
    }

    # clear
    #
    # Clears the current vardiff.

    method clear {} {
        set info(vardiff) ""
        set info(score)   0.0

        $triangle configure -state disabled

        $self Refresh
    }
    

    # toggle 
    #
    # Toggles the open/close state.  If there is no vardiff specified,
    # closes the detail if it's open.

    method toggle {} {
        # FIRST, determine the detail open/close state
        if {$info(vardiff) ne ""} {
            # Toggle display of detail.
            set info(open) [expr {!$info(open)}]
        } else {
            # Close detail if open.
            set info(open) 0
        }

        # NEXT, update the triangle button accordingly.
        set direction [expr {$info(open) ? "bottom" : "right"}]

        $triangle configure \
            -dir $direction

        # NEXT, show/hide the detail pane
        if {$info(open)} {
            grid $win.detail -row 1 -column 0 -columnspan 2 -sticky nsew
        } else {
            grid forget $win.detail
        }
    }

    #-------------------------------------------------------------------
    # Private Methods

    # Refresh
    #
    # Displays the current vardiff.

    method Refresh {} {
        # FIRST, if there's no vardiff clear the display.
        if {$info(vardiff) eq ""} {
            # FIRST, display the prompt instead of a vardiff name.
            set info(title) $options(-prompt)

            # NEXT, if the detail is open, close it.
            if {$info(open)} {
                $self toggle
            }

            return
        }

        # NEXT, set the title to the vardiff's name.
        array set vinfo [$info(vardiff) view]

        set info(title) "$vinfo(name): $vinfo(narrative)"


        # NEXT, populate the detail pane
        $detail layout [tsubst {
            <p>$vinfo(narrative)</p>

            <table>
            <tr>
            <td><b>Type:</b></td>
            <td>$vinfo(category) / $vinfo(type)</td>
            </tr>

            <tr>
            <td><b>Case A:</b></td>
            <td>$vinfo(fancy1)</td>
            </tr>

            <tr>
            <td><b>Case B:</b></td>
            <td>$vinfo(fancy2)</td>
            </tr>

            <tr>
            <td><b>Delta:</b></td>
            <td>[format %.3f $vinfo(delta)]</td>
            </tr>

            [tif {$vinfo(context) ne ""} {
            <tr>
            <td><b>Context:</b></td>
            <td>$vinfo(context)</td>
            </tr>
            }]


            </table>
        }]
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


