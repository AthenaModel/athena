#-----------------------------------------------------------------------
# TITLE:
#    cursebrowser.tcl
#
# AUTHORS:
#    Dave Hanks
#
# DESCRIPTION:
#    cursebrowser(sim) package: CURSE/Inject Browser
#
#    This browser displays Complex User-defined Role-based Situations
#    and Events or CURSEs
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widget cursebrowser {
    #-------------------------------------------------------------------
    # Options

    # Options delegated to the hull
    delegate option * to hull


    #-------------------------------------------------------------------
    # Components

    component reloader       ;# timeout(n) that reloads content

    # CItree: CURSE/Inject Tree
    component citree         ;# CURSE/Inject treectrl.
    component bar            ;# CURSE/Inject toolbar
    component caddbtn        ;# Add CURSE button
    component iaddbtn        ;# Add Inject button
    component editbtn        ;# The "Edit" button
    component togglebtn      ;# The CURSE state toggle button
    component checkbtn       ;# CURSE/Inject sanity check button
    component deletebtn      ;# The Delete button

    #-------------------------------------------------------------------
    # Instance Variables

    # info array
    #
    #   reloadRequests  - Number of reload requests since the last reload.
    
    variable info -array {
        reloadRequests 0
    }

    # c2item: array of citree CURSE item IDs by curse_id
    variable c2item -array {}

    # i2item: array of citree inject item IDs by inject ID
    variable i2item -array {}

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the timeout controlling reload requests.
        install reloader using timeout ${selfns}::reloader \
            -command    [mymethod ReloadContent]           \
            -interval   1                                  \
            -repetition no

        # NEXT, create the GUI components
        $self CItreeCreate $win.tree

        pack $win.tree -fill both -expand yes

        # NEXT, configure the command-line options
        $self configurelist $args

        # NEXT, Behavior

        # Reload the content when the window is mapped.
        bind $win <Map> [mymethod MapWindow]

        # Reload the content on various notifier events.
        notifier bind ::sim     <DbSyncB>     $self [mymethod ReloadOnEvent]
        notifier bind ::sim     <Tick>        $self [mymethod ReloadOnEvent]
        notifier bind ::curse   <Check>       $self [mymethod ReloadOnEvent]

        # Reload individual entities when they
        # are updated or deleted.

        notifier bind ::adb <curses>        $self [mymethod MonCURSEs]
        notifier bind ::adb <curse_injects> $self [mymethod MonInjects]

        # NEXT, schedule the first reload
        $self reload
    }

    destructor {
        notifier forget $self
    }

    # MapWindow
    #
    # Reload the browser when the window is mapped, if there have
    # been any reload requests.
    
    method MapWindow {} {
        # If a reload has been requested, but the reloader is no
        # longer scheduled (i.e., the reload was requested while
        # the window was unmapped) then reload it now.
        if {$info(reloadRequests) > 0 &&
            ![$reloader isScheduled]
        } {
            $self ReloadContent
        }
    }

    # ReloadOnEvent
    #
    # Reloads the widget when various notifier events are received.
    # The "args" parameter is so that any event can be handled.
    
    method ReloadOnEvent {args} {
        $self reload
    }
    
    # ReloadContent
    #
    # Reloads the current data.  Has no effect if the window is
    # not mapped.
    
    method ReloadContent {} {
        # FIRST, we don't do anything until we're mapped.
        if {![winfo ismapped $win]} {
            return
        }

        # NEXT, clear the reload request counter.
        set info(reloadRequests) 0

        # NEXT, Reload each of the components
        $self CItreeReload
    }

    # MonCURSEs update curse_id
    #
    # curse_id   - A CURSE ID
    #
    # Displays/adds the CURSE to the tree.

    method {MonCURSEs update} {curse_id} {
        # FIRST, we need to get the data about this CURSE.
        array set data [curse get $curse_id]

        # NEXT, Display the CURSE item
        $self DrawCURSE data
        $self TreeStripe $citree
    }

    # MonCURSEs delete curse_id
    #
    # curse_id   - A CURSE ID
    #
    # Deletes the CURSE from the tree.

    method {MonCURSEs delete} {curse_id} {
        # FIRST, is this CURSE displayed?
        if {![info exists c2item($curse_id)]} {
            return
        }

        # NEXT, delete the item from the tree.
        $citree item delete $c2item($curse_id)
        unset c2item($curse_id)
        $self TreeStripe $citree
    }

    # MonInjectss update id
    #
    # id   - An inject ID
    #
    # Displays/adds the inject to the tree.

    method {MonInjects update} {id} {
        # FIRST, we need to get the data about this inject.
        # If it isn't currently displayed, we can ignore it.
        array set data [inject get $id]

        if {[info exists c2item($data(curse_id))]} {
            $self DrawInject data
            $self TreeStripe $citree
        }
    }

    # MonInjects delete id
    #
    # id   - An inject ID
    #
    # Deletes the inject from the CURSEs tree, if it is currently
    # displayed.  NOTE: Injects are deleted with their CURSE; in that
    # case, the item might already be gone from the tree.  So check.

    method {MonInjects delete} {id} {
        # FIRST, is this inject displayed?
        if {[info exists i2item($id)]} {
            # FIRST, delete the item from the tree.
            if {[$citree item id $i2item($id)] ne ""} {
                $citree item delete $i2item($id)
            }

            unset i2item($id)
            $self TreeStripe $citree
        }
    }

    #-------------------------------------------------------------------
    # citree: CURSEs/Injects Tree Pane

    # CItreeCreate pane
    # 
    # pane - The name of the pane widget
    #
    # Creates the CURSESs pane, where CURSEs and injects are
    # edited.

    method CItreeCreate {pane} {
        # FIRST, create the pane
        ttk::frame $pane

        # NEXT, create the toolbar
        install bar using ttk::frame $pane.bar

        # Temporary add button, just for looks
        ttk::label $bar.title \
            -text "CURSEs:"

        install caddbtn using mktoolbutton $bar.caddbtn \
            ::marsgui::icon::plusc22                    \
            "Add CURSE"                                 \
            -state   normal                             \
            -command [mymethod AddCURSE]

        cond::available control $caddbtn                \
            order CURSE:CREATE

        install iaddbtn using mktoolbutton $bar.iaddbtn \
            ::marsgui::icon::plusi22                    \
            "Add CURSE inject"                          \
            -state   normal                             \
            -command [mymethod AddInject]

        cond::simPrepPredicate control $iaddbtn         \
            browser   $win                              \
            predicate {citree single}

        install editbtn using mkeditbutton $bar.edit    \
            "Edit CURSE or inject"                      \
            -state   disabled                           \
            -command [mymethod EditItem]

        cond::simPrepPredicate control $editbtn          \
            browser $win                                 \
            predicate {citree single}

        install togglebtn using mktoolbutton $bar.toggle   \
            ::marsgui::icon::onoff                         \
            "Toggle State"                         \
            -state   disabled                              \
            -command [mymethod ToggleState]

        cond::simPrepPredicate control $togglebtn       \
            browser $win                                \
            predicate {citree validitem}

        install checkbtn using ttk::button $bar.check   \
            -style   Toolbutton                         \
            -text    "Check"                            \
            -command [mymethod SanityCheck]

        install deletebtn using mkdeletebutton $bar.delete \
            "Delete CURSE or inject"                       \
            -state   disabled                              \
            -command [mymethod DeleteItem]

        cond::simPrepPredicate control $deletebtn \
            browser $win                          \
            predicate {citree single}
            
        pack $bar.title  -side left
        pack $caddbtn    -side left
        pack $iaddbtn    -side left
        pack $editbtn    -side left
        pack $togglebtn  -side left
        pack $checkbtn   -side left

        pack $deletebtn  -side right

        ttk::separator $pane.sep1 \
            -orient horizontal

        # NEXT, create the tree widget
        install citree using $self TreeCreate $pane.citree \
            -height         200                          \
            -yscrollcommand [list $pane.yscroll set]

        ttk::scrollbar $pane.yscroll                 \
            -orient         vertical                 \
            -command        [list $citree yview]

        # Standard tree column options:
        set colopts [list \
                         -background     $::marsgui::defaultBackground \
                         -borderwidth    1                             \
                         -button         off                           \
                         -font           TkDefaultFont                 \
                         -resize         no]

        # Tree column 0: narrative
        $citree column create {*}$colopts \
            -text        "CURSE/Inject"   \
            -itemstyle   wrapStyle        \
            -expand      yes              \
            -squeeze     yes              \
            -weight      1

        $citree configure -treecolumn first

        # Tree column 1: cause
        $citree column create {*}$colopts  \
            -text        "Cause"           \
            -itemstyle   textStyle

        # Tree column 2: curse_id/inject id
        $citree column create {*}$colopts  \
            -text        "Id"              \
            -itemstyle   textStyle         \
            -tags        id

        # Tree column 3: inject_type
        $citree column create {*}$colopts  \
            -text        "Type"            \
            -itemstyle   textStyle         \
            -tags        type

        # Tree column 4: mode
        $citree column create {*}$colopts  \
            -text        "Mode"            \
            -itemstyle   textStyle         \
            -tags        mode

        # NEXT, grid them all in place
        grid $bar          -row 0 -column 0 -sticky ew -columnspan 2
        grid $pane.sep1    -row 1 -column 0 -sticky ew -columnspan 2
        grid $citree       -row 2 -column 0 -sticky nsew
        grid $pane.yscroll -row 2 -column 1 -sticky ns

        grid rowconfigure    $pane 2 -weight 1
        grid columnconfigure $pane 0 -weight 1
 
        # NEXT, prepare to handle selection changes.
        $citree notify bind $citree <Selection> [mymethod CItreeSelection]
    }

    # CItreeReload
    #
    # Loads data from the curses and injects tables into citree.

    method CItreeReload {} {
        # FIRST, save the selection (at most one thing should be selected.
        set id [lindex [$citree select get] 0]

        if {$id eq ""} {
            set selKind ""
            set selId   ""
        } else {
            set selId [$citree item text $id {tag id}]

            if {"curse" in [$citree item tag names $id]} {
                set selKind curse
            } else {
                set selKind inject
            }
        }

        # NEXT, get a list of the expanded curses
        set collapsed [list]

        foreach id [$citree item children root] {
            if {![$citree item state get $id open]} {
                lappend collapsed [$citree item text $id {tag id}]
            }
        }


        # NEXT, empty the citree
        $citree item delete all
        array unset c2item
        array unset i2item

        # NEXT, insert the curses
        rdb eval {
            SELECT * FROM gui_curses ORDER BY curse_id
        } row {
            unset -nocomplain row(*)
            $self DrawCURSE row
        }

        # NEXT, insert the injects
        rdb eval {
            SELECT * FROM gui_injects
            ORDER BY id;
        } row {
            unset -nocomplain row(*)
            $self DrawInject row
        }

        # NEXT, set striping
        $self TreeStripe $citree

        # NEXT, open the same curses as before
        foreach curse_id $collapsed {
            if {[info exists c2item($curse_id)]} {
                $citree item collapse $c2item($curse_id)
            }
        }

        # NEXT, if there was a selection before, select it again
        if {$selKind eq "curse"} {
            if {[info exists c2item($selId)]} {
                $citree selection add $c2item($selId)
            }
        } elseif {$selKind eq "inject"} {
            if {[info exists i2item($selId)]} {
                $citree selection add $i2item($selId)
            }
        }
    }

    # CItreeSelection
    #
    # Called when the citree's selection has changed.

    method CItreeSelection {} {
        ::cond::simPrepPredicate update \
            [list $iaddbtn $togglebtn $editbtn $deletebtn]
    }

    # EditItem
    #
    # Called when the citree's delete button is pressed.
    # Deletes the selected entity.

    method EditItem {} {
        # FIRST, there should be only one selected.
        set id [lindex [$citree selection get] 0]

        # NEXT, it has a type and an ID
        set otype [$citree item text $id {tag type}]
        set oid   [$citree item text $id {tag id}]

        # NEXT, it's a curse or an inject.
        if {"curse" in [$citree item tag names $id]} {
            app enter CURSE:UPDATE curse_id $oid
        } else {
            set curse_id [inject get $oid curse_id]
            set longname [curse get $curse_id longname]
            app enter INJECT:$otype:UPDATE id $oid longname $longname
        }
    }

    # AddCURSE
    #
    # Allows the user to create a new CURSE.
    
    method AddCURSE {} {
        app enter CURSE:CREATE 
    }


    # ToggleState
    #
    # Toggles the item's state from normal to disabled and back
    # again.

    method ToggleState {} {
        # FIRST, there should be only one selected.
        set id [lindex [$citree selection get] 0]

        # NEXT, get its entity ID
        set oid   [$citree item text $id {tag id}]

        # NEXT, it's a curse or an inject.
        if {"curse" in [$citree item tag names $id]} {
            set state [curse get $oid state]

            if {$state eq "normal"} {
                flunky senddict gui CURSE:STATE \
                    [list curse_id $oid state disabled]
            } elseif {$state eq "disabled"} {
                flunky senddict gui CURSE:STATE \
                    [list curse_id $oid state normal]
            } else {
                # Do nothing (this should never happen anyway)
            }
        } else {
            set state [inject get $oid state]

            if {$state eq "normal"} {
                flunky senddict gui INJECT:STATE [list id $oid state disabled]
            } elseif {$state eq "disabled"} {
                flunky senddict gui INJECT:STATE [list id $oid state normal]
            } else {
                # Do nothing (this should never happen anyway)
            }
        }
    }

    # SanityCheck
    #
    # Allows the user to check the sanity of the existing injectss. 
    
    method SanityCheck {} {
        if {[curse checker] ne "OK"} {
            app show my://app/sanity/curse
        }
    }


    # DeleteItem
    #
    # Called when the citree's delete button is pressed.
    # Deletes the selected entity.

    method DeleteItem {} {
        # FIRST, there should be only one selected.
        set id [lindex [$citree selection get] 0]

        # NEXT, it's a curse or an inject.
        if {"curse" in [$citree item tag names $id]} {
            flunky senddict gui CURSE:DELETE \
                [list curse_id [$citree item text $id {tag id}]]
        } else {
            flunky senddict gui INJECT:DELETE \
                [list id [$citree item text $id {tag id}]]
        }
    }

    # DrawCURSE cdataVar
    #
    # cdataVar - Name of an array containing CURSE attributes
    #
    # Adds/updates a CURSE item in the citree.

    method DrawCURSE {cdataVar} {
        upvar $cdataVar cdata

        # FIRST, get the CURSE item ID; if there is none,
        # create one.
        if {![info exists c2item($cdata(curse_id))]} {
            set id [$citree item create \
                        -parent root   \
                        -button auto   \
                        -tags   curse]

            $citree item expand $id

            set c2item($cdata(curse_id)) $id
        } else {
            set id $c2item($cdata(curse_id))
        }

        # NEXT, set the text.
        $citree item text $id                 \
            0               $cdata(narrative) \
            1               $cdata(cause)     \
            {tag id}        $cdata(curse_id)  \
            {tag type}      ""                \
            {tag mode}      ""

        # NEXT, set the state
        $self TreeItemState $citree $id $cdata(state)

        # NEXT, sort items by CURSE ID
        $citree item sort root -column {tag id}
    }

    # AddInject
    #
    # Allows the user to pick an inject type from a pulldown, and
    # then pops up the related INJECT:*:CREATE dialog.
    
    method AddInject {} {
        # FIRST, get a list of order names and titles
        set odict [dict create]

        foreach name [inject type names] {
            set order "INJECT:$name:CREATE"

            if {![string match "INJECT:*:CREATE" $order]} {
                continue
            }

            # Get title, and remove the "Create inject: " prefix
            set title [::athena::orders title $order]
            set ndx [string first ":" $title]
            set title [string range $title $ndx+2 end]
            dict set odict $title $order
        }

        set list [lsort [dict keys $odict]]

        # NEXT, get the curse_id.  Make sure it's expanded.
        set id    [lindex [$citree selection get] 0]
        set otype [$citree item text $id {tag type}]
        set oid   [$citree item text $id {tag id}]

        if {"curse" in [$citree item tag names $id]} {
            set curse_id $oid
            $citree item expand $id
        } else {
            set curse_id [inject get $oid curse_id]
        }

        set longname [curse get $curse_id longname]

        # NEXT, let them pick one
        set title [messagebox pick \
                       -parent    [app topwin]            \
                       -initvalue [lindex $list 0]        \
                       -title     "Select an inject type" \
                       -values    $list                   \
                       -message   [normalize "
                           Select an inject type to add to
                           CURSE $curse_id.
                       "]]

        if {$title ne ""} {
            app enter [dict get $odict $title] \
                curse_id $curse_id longname $longname
        }
    }

    # DrawInject idataVar
    #
    # idataVar - Name of an array containing inject attributes
    #
    # Adds/updates an inject item in the citree.

    method DrawInject {idataVar} {
        upvar $idataVar idata

        # FIRST, get the inject ID
        set idata(id) [list $idata(curse_id) $idata(inject_num)]

        # NEXT, get the parent item ID
        set parent $c2item($idata(curse_id))

        # NEXT, get the inject item ID; if there is none,
        # create one.
        if {![info exists i2item($idata(id))]} {
            set id [$citree item create     \
                        -parent $parent    \
                        -tags   inject]

            set i2item($idata(id)) $id
        } else {
            set id $i2item($idata(id))
        }

        # NEXT, set the text
        $citree item text $id                \
            0           $idata(narrative)    \
            {tag id}    $idata(id)           \
            {tag type}  $idata(inject_type)  \
            {tag mode}  $idata(mode)

        # NEXT, set the state
        $self TreeItemState $citree $id $idata(state)

        # NEXT, sort injects by inject number.
        $citree item sort $parent -column {tag id}
    }

    #-------------------------------------------------------------------
    # Tree Routines
    #
    # This section contains generic tree code.

    # TreeCreate tree ?options...?
    #
    # tree    - The name of the treectrl to create
    # options - treectrl options and their values
    #
    # Creates and returns a new treectrl with standard options, states,
    # elements, and styles.

    method TreeCreate {tree args} {
        # NEXT, create the tree widget
        treectrl $tree                 \
            -width          400        \
            -height         100        \
            -borderwidth    0          \
            -relief         flat       \
            -background     white      \
            -linestyle      dot        \
            -usetheme       1          \
            -showheader     1          \
            -showroot       0          \
            -showrootlines  0          \
            -indent         14         \
            {*}$args

        # NEXT, create the states, elements, and styles.

        # Define Item states
        $tree state define stripe     ;# Item is striped
        $tree state define disabled   ;# Item is disabled by user
        $tree state define invalid    ;# Item is invalid.

        # Fonts
        set overstrike [dict merge [font actual codefont] {-overstrike 1}]

        set fontList [list \
                          $overstrike disabled \
                          codefont    {}]

        # Text fill
        set fillList [list \
                          "#999999" disabled \
                          red        invalid  \
                          black      {}]

        # Elements
        $tree element create itemText text  \
            -font    $fontList              \
            -fill    $fillList

        $tree element create wrapText text  \
            -font    $fontList              \
            -fill    $fillList              \
            -wrap    word

        $tree element create numText text   \
            -font    $fontList              \
            -fill    $fillList              \
            -justify right

        $tree element create elemRect rect               \
            -fill {gray {selected} "#CCFFBB" {stripe}}

        # wrapStyle: wrapped text over a fill rectangle.

        $tree style create wrapStyle
        $tree style elements wrapStyle {elemRect wrapText}
        $tree style layout wrapStyle wrapText  \
            -squeeze x                         \
            -iexpand nse                       \
            -ipadx   4
        $tree style layout wrapStyle elemRect \
            -union   {wrapText}

        # textStyle: text over a fill rectangle.
        $tree style create textStyle
        $tree style elements textStyle {elemRect itemText}
        $tree style layout textStyle itemText \
            -iexpand nse                      \
            -ipadx   4
        $tree style layout textStyle elemRect \
            -union   {itemText}

        # numStyle: numeric text over a fill rectangle.
        $tree style create numStyle
        $tree style elements numStyle {elemRect numText}
        $tree style layout numStyle numText \
            -iexpand nsw                    \
            -ipadx   4
        $tree style layout numStyle elemRect \
            -union {numText}

        # NEXT, return the new widget
        return $tree
    }

    # TreeItemState tree id state
    #
    # tree     - The curses tree
    # id       - The item ID
    # state    - normal|disabled|invalid
    #
    # Sets the tree state flags for a tree item to match the 
    # state of the application entity.

    method TreeItemState {tree id state} {
        if {$state eq "normal"} {
            $tree item state set $id !disabled
            $tree item state set $id !invalid
        } elseif {$state eq "disabled"} {
            $tree item state set $id disabled
            $tree item state set $id !invalid
        } else {
            # invalid
            $tree item state set $id !disabled
            $tree item state set $id invalid
        }
    }

    # TreeStripe tree
    #
    # Stripes the even-numbered top-level items, and colors their
    # children the same way.

    method TreeStripe {tree} {
        set count 0
        
        foreach id [$tree item children root] {
            set last  [$tree item lastchild $id]

            if {$last eq ""} {
                set last $id
            }

            if {$count % 2 == 1} {
                $tree item state set $id $last stripe
            } else {
                $tree item state set $id $last !stripe
            }

            incr count
        }
    }


    #-------------------------------------------------------------------
    # State Controller Predicates
    #
    # These methods are used in statecontroller -injects to control
    # the state of toolbar buttons and such-like.

    # citree single
    #
    # Returns 1 if a single item is selected in the citree, and 0 
    # otherwise.
    
    method {citree single} {} {
        expr {[llength [$citree selection get]] == 1}
    }

    # citree curse
    #
    # Returns 1 if a curse is selected in the citree, and 0 
    # otherwise.
    
    method {citree curse} {} {
        if {[llength [$citree selection get]] != 1} {
            return 0
        }

        set id [lindex [$citree selection get] 0]
        
        return [expr {"curse" in [$citree item tag names $id]}]
    }

    # citree validitem
    #
    # Returns 1 if a valid (state != invalid) item is selected in the
    # citree, and 0 otherwise.
    
    method {citree validitem} {} {
        if {[llength [$citree selection get]] != 1} {
            return 0
        }

        set id [lindex [$citree selection get] 0]
       
        if {![$citree item state get $id invalid]} {
            return 1
        } else {
            return 0
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull

    # reload
    #
    # Schedules a reload of the content.  Note that the reload will
    # be ignored if the window isn't mapped.
    
    method reload {} {
        incr info(reloadRequests)
        $reloader schedule -nocomplain
    }
}



