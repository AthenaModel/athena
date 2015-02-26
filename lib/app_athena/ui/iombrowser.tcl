#-----------------------------------------------------------------------
# TITLE:
#    iombrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    iombrowser(sim) package: IOM/Payload browser
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widget iombrowser {
    #-------------------------------------------------------------------
    # Options

    # Options delegated to the hull
    delegate option * to hull


    #-------------------------------------------------------------------
    # Components

    component reloader       ;# timeout(n) that reloads content

    # IPtree: IOM/Payload Tree
    component iptree         ;# IOM/Payload treectrl.
    component bar            ;# IOM/Payload toolbar
    component iaddbtn        ;# Add IOM button
    component paddbtn        ;# Add Payload button
    component editbtn        ;# The "Edit" button
    component togglebtn      ;# The iom state toggle button
    component checkbtn       ;# Payload/IOM sanity check button
    component deletebtn      ;# The Delete button

    #-------------------------------------------------------------------
    # Instance Variables

    # info array
    #
    #   reloadRequests  - Number of reload requests since the last reload.
    
    variable info -array {
        reloadRequests 0
    }

    # i2item: array of iptree IOM item IDs by iom_id
    variable i2item -array {}

    # p2item: array of iptree payload item IDs by payload ID
    variable p2item -array {}

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the timeout controlling reload requests.
        install reloader using timeout ${selfns}::reloader \
            -command    [mymethod ReloadContent]           \
            -interval   1                                  \
            -repetition no

        # NEXT, create the GUI components
        $self IPtreeCreate $win.tree

        pack $win.tree -fill both -expand yes

        # NEXT, configure the command-line options
        $self configurelist $args

        # NEXT, Behavior

        # Reload the content when the window is mapped.
        bind $win <Map> [mymethod MapWindow]

        # Reload the content on various notifier events.
        notifier bind ::adb     <Sync>     $self [mymethod ReloadOnEvent]
        notifier bind ::adb     <Tick>        $self [mymethod ReloadOnEvent]
        notifier bind ::adb.iom <Check>       $self [mymethod ReloadOnEvent]
        notifier bind ::adb     <hooks>       $self [mymethod ReloadOnEvent]
        notifier bind ::adb     <hook_topics> $self [mymethod ReloadOnEvent]

        # Reload individual entities when they
        # are updated or deleted.

        notifier bind ::adb <ioms>        $self [mymethod MonIOMs]
        notifier bind ::adb <payloads>    $self [mymethod MonPayloads]

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
        $self IPtreeReload
    }

    # MonIOMs update iom_id
    #
    # iom_id   - An IOM ID
    #
    # Displays/adds the IOM to the tree.

    method {MonIOMs update} {iom_id} {
        # FIRST, we need to get the data about this IOM.
        array set data [iom get $iom_id]

        # NEXT, Display the IOM item
        $self DrawIOM data
        $self TreeStripe $iptree
    }

    # MonIOMs delete iom_id
    #
    # iom_id   - An IOM ID
    #
    # Deletes the IOM from the tree.

    method {MonIOMs delete} {iom_id} {
        # FIRST, is this IOM displayed?
        if {![info exists i2item($iom_id)]} {
            return
        }

        # NEXT, delete the item from the tree.
        $iptree item delete $i2item($iom_id)
        unset i2item($iom_id)
        $self TreeStripe $iptree
    }

    # MonPayloads update id
    #
    # id   - A payload ID
    #
    # Displays/adds the payload to the tree.

    method {MonPayloads update} {id} {
        # FIRST, we need to get the data about this payload.
        # If it isn't currently displayed, we can ignore it.
        array set data [payload get $id]

        if {[info exists i2item($data(iom_id))]} {
            $self DrawPayload data
            $self TreeStripe $iptree
        }
    }

    # MonPayloads delete id
    #
    # id   - A payload ID
    #
    # Deletes the payload from the IOMs tree, if it is currently
    # displayed.  NOTE: Payloads are deleted with their IOM; in that
    # case, the item might already be gone from the tree.  So check.

    method {MonPayloads delete} {id} {
        # FIRST, is this payload displayed?
        if {[info exists p2item($id)]} {
            # FIRST, delete the item from the tree.
            if {[$iptree item id $p2item($id)] ne ""} {
                $iptree item delete $p2item($id)
            }

            unset p2item($id)
            $self TreeStripe $iptree
        }
    }

    #-------------------------------------------------------------------
    # iptree: IOMs/Payloads Tree Pane

    # IPtreeCreate pane
    # 
    # pane - The name of the pane widget
    #
    # Creates the IOMs pane, where IOMs and payloads are
    # edited.

    method IPtreeCreate {pane} {
        # FIRST, create the pane
        ttk::frame $pane

        # NEXT, create the toolbar
        install bar using ttk::frame $pane.bar

        # Temporary add button, just for looks
        ttk::label $bar.title \
            -text "Info Ops Messages:"

        install iaddbtn using mktoolbutton $bar.iaddbtn \
            ::marsgui::icon::plusi22                    \
            "Add Info Ops Message"                      \
            -state   normal                             \
            -command [mymethod AddIOM]

        cond::available control $iaddbtn                \
            order IOM:CREATE

        install paddbtn using mktoolbutton $bar.paddbtn \
            ::marsgui::icon::plusp22                    \
            "Add IOM payload"                           \
            -state   normal                             \
            -command [mymethod AddPayload]

        cond::simPrepPredicate control $paddbtn         \
            browser   $win                              \
            predicate {iptree single}

        install editbtn using mkeditbutton $bar.edit    \
            "Edit IOM or payload"                       \
            -state   disabled                           \
            -command [mymethod EditItem]

        cond::simPrepPredicate control $editbtn          \
            browser $win                                 \
            predicate {iptree single}

        install togglebtn using mktoolbutton $bar.toggle   \
            ::marsgui::icon::onoff                         \
            "Toggle State"                         \
            -state   disabled                              \
            -command [mymethod ToggleState]

        cond::simPrepPredicate control $togglebtn       \
            browser $win                                \
            predicate {iptree validitem}

        install checkbtn using ttk::button $bar.check   \
            -style   Toolbutton                         \
            -text    "Check"                            \
            -command [mymethod SanityCheck]

        install deletebtn using mkdeletebutton $bar.delete \
            "Delete IOM or payload"                        \
            -state   disabled                              \
            -command [mymethod DeleteItem]

        cond::simPrepPredicate control $deletebtn \
            browser $win                          \
            predicate {iptree single}
            
        pack $bar.title  -side left
        pack $iaddbtn    -side left
        pack $paddbtn    -side left
        pack $editbtn    -side left
        pack $togglebtn  -side left
        pack $checkbtn   -side left

        pack $deletebtn  -side right

        ttk::separator $pane.sep1 \
            -orient horizontal

        # NEXT, create the tree widget
        install iptree using $self TreeCreate $pane.iptree \
            -height         200                          \
            -yscrollcommand [list $pane.yscroll set]

        ttk::scrollbar $pane.yscroll                 \
            -orient         vertical                 \
            -command        [list $iptree yview]

        # Standard tree column options:
        set colopts [list \
                         -background     $::marsgui::defaultBackground \
                         -borderwidth    1                             \
                         -button         off                           \
                         -font           TkDefaultFont                 \
                         -resize         no]

        # Tree column 0: narrative
        $iptree column create {*}$colopts               \
            -text        "IOM/Payload"                  \
            -itemstyle   wrapStyle                      \
            -expand      yes                            \
            -squeeze     yes                            \
            -weight      1

        $iptree configure -treecolumn first

        # Tree column 1: iom_id/payload id
        $iptree column create {*}$colopts  \
            -text        "Id"              \
            -itemstyle   textStyle         \
            -tags        id

        # Tree column 2: payload_type
        $iptree column create {*}$colopts  \
            -text        "Type"            \
            -itemstyle   textStyle         \
            -tags        type

        # NEXT, grid them all in place
        grid $bar          -row 0 -column 0 -sticky ew -columnspan 2
        grid $pane.sep1    -row 1 -column 0 -sticky ew -columnspan 2
        grid $iptree       -row 2 -column 0 -sticky nsew
        grid $pane.yscroll -row 2 -column 1 -sticky ns

        grid rowconfigure    $pane 2 -weight 1
        grid columnconfigure $pane 0 -weight 1
 
        # NEXT, prepare to handle selection changes.
        $iptree notify bind $iptree <Selection> [mymethod IPtreeSelection]
    }

    # IPtreeReload
    #
    # Loads data from the ioms and payloads tables into iptree.

    method IPtreeReload {} {
        # FIRST, save the selection (at most one thing should be selected.
        set id [lindex [$iptree select get] 0]

        if {$id eq ""} {
            set selKind ""
            set selId   ""
        } else {
            set selId [$iptree item text $id {tag id}]

            if {"iom" in [$iptree item tag names $id]} {
                set selKind iom
            } else {
                set selKind payload
            }
        }

        # NEXT, get a list of the expanded ioms
        set collapsed [list]

        foreach id [$iptree item children root] {
            if {![$iptree item state get $id open]} {
                lappend collapsed [$iptree item text $id {tag id}]
            }
        }


        # NEXT, empty the iptree
        $iptree item delete all
        array unset i2item
        array unset p2item

        # NEXT, insert the ioms
        rdb eval {
            SELECT * FROM gui_ioms ORDER BY iom_id
        } row {
            unset -nocomplain row(*)
            $self DrawIOM row
        }

        # NEXT, insert the payloads
        rdb eval {
            SELECT * FROM gui_payloads
            ORDER BY id;
        } row {
            unset -nocomplain row(*)
            $self DrawPayload row
        }

        # NEXT, set striping
        $self TreeStripe $iptree

        # NEXT, open the same ioms as before
        foreach iom_id $collapsed {
            if {[info exists i2item($iom_id)]} {
                $iptree item collapse $i2item($iom_id)
            }
        }

        # NEXT, if there was a selection before, select it again
        if {$selKind eq "iom"} {
            if {[info exists i2item($selId)]} {
                $iptree selection add $i2item($selId)
            }
        } elseif {$selKind eq "payload"} {
            if {[info exists p2item($selId)]} {
                $iptree selection add $p2item($selId)
            }
        }
    }

    # IPtreeSelection
    #
    # Called when the iptree's selection has changed.

    method IPtreeSelection {} {
        ::cond::simPrepPredicate update \
            [list $paddbtn $togglebtn $editbtn $deletebtn]
    }

    # EditItem
    #
    # Called when the iptree's delete button is pressed.
    # Deletes the selected entity.

    method EditItem {} {
        # FIRST, there should be only one selected.
        set id [lindex [$iptree selection get] 0]

        # NEXT, it has a type and an ID
        set otype [$iptree item text $id {tag type}]
        set oid   [$iptree item text $id {tag id}]

        # NEXT, it's a iom or a payload.
        if {"iom" in [$iptree item tag names $id]} {
            app enter IOM:UPDATE iom_id $oid
        } else {
            set iom_id [payload get $oid iom_id]
            set longname [iom get $iom_id longname]
            app enter PAYLOAD:$otype:UPDATE id $oid longname $longname
        }
    }

    # AddIOM
    #
    # Allows the user to create a new IOM.
    
    method AddIOM {} {
        app enter IOM:CREATE 
    }


    # ToggleState
    #
    # Toggles the item's state from normal to disabled and back
    # again.

    method ToggleState {} {
        # FIRST, there should be only one selected.
        set id [lindex [$iptree selection get] 0]

        # NEXT, get its entity ID
        set oid   [$iptree item text $id {tag id}]

        # NEXT, it's a iom or a payload.
        if {"iom" in [$iptree item tag names $id]} {
            set state [iom get $oid state]

            if {$state eq "normal"} {
                flunky senddict gui IOM:STATE [list iom_id $oid state disabled]
            } elseif {$state eq "disabled"} {
                flunky senddict gui IOM:STATE [list iom_id $oid state normal]
            } else {
                # Do nothing (this should never happen anyway)
            }
        } else {
            set state [payload get $oid state]

            if {$state eq "normal"} {
                flunky senddict gui PAYLOAD:STATE [list id $oid state disabled]
            } elseif {$state eq "disabled"} {
                flunky senddict gui PAYLOAD:STATE [list id $oid state normal]
            } else {
                # Do nothing (this should never happen anyway)
            }
        }
    }

    # SanityCheck
    #
    # Allows the user to check the sanity of the existing payloads. 
    
    method SanityCheck {} {
        if {[iom checker] ne "OK"} {
            app show my://app/sanity/iom
        }
    }


    # DeleteItem
    #
    # Called when the iptree's delete button is pressed.
    # Deletes the selected entity.

    method DeleteItem {} {
        # FIRST, there should be only one selected.
        set id [lindex [$iptree selection get] 0]

        # NEXT, it's a iom or a payload.
        if {"iom" in [$iptree item tag names $id]} {
            flunky senddict gui IOM:DELETE \
                [list iom_id [$iptree item text $id {tag id}]]
        } else {
            flunky senddict gui PAYLOAD:DELETE \
                [list id [$iptree item text $id {tag id}]]
        }
    }

    # DrawIOM idataVar
    #
    # idataVar - Name of an array containing IOM attributes
    #
    # Adds/updates an IOMitem in the iptree.

    method DrawIOM {idataVar} {
        upvar $idataVar idata

        # FIRST, get the IOM item ID; if there is none,
        # create one.
        if {![info exists i2item($idata(iom_id))]} {
            set id [$iptree item create \
                        -parent root   \
                        -button auto   \
                        -tags   iom]

            $iptree item expand $id

            set i2item($idata(iom_id)) $id
        } else {
            set id $i2item($idata(iom_id))
        }

        # NEXT, set the text.
        $iptree item text $id                 \
            0               $idata(narrative) \
            {tag id}        $idata(iom_id)    \
            {tag type}      ""

        # NEXT, set the state
        $self TreeItemState $iptree $id $idata(state)

        # NEXT, sort items by IOM ID
        $iptree item sort root -column {tag id}
    }

    # AddPayload
    #
    # Allows the user to pick a payload type from a pulldown, and
    # then pops up the related PAYLOAD:*:CREATE dialog.
    
    method AddPayload {} {
        # FIRST, get a list of order names and titles
        set odict [dict create]

        foreach name [payload type names] {
            set order "PAYLOAD:$name:CREATE"

            if {![string match "PAYLOAD:*:CREATE" $order]} {
                continue
            }

            # Get title, and remove the "Create payload: " prefix
            set title [::athena::orders title $order]
            set ndx [string first ":" $title]
            set title [string range $title $ndx+2 end]
            dict set odict $title $order
        }

        set list [lsort [dict keys $odict]]

        # NEXT, get the iom_id.  Make sure it's expanded.
        set id    [lindex [$iptree selection get] 0]
        set otype [$iptree item text $id {tag type}]
        set oid   [$iptree item text $id {tag id}]

        if {"iom" in [$iptree item tag names $id]} {
            set iom_id $oid
            $iptree item expand $id
        } else {
            set iom_id [payload get $oid iom_id]
        }

        set longname [iom get $iom_id longname]

        # NEXT, let them pick one
        set title [messagebox pick \
                       -parent    [app topwin]            \
                       -initvalue [lindex $list 0]        \
                       -title     "Select a payload type" \
                       -values    $list                   \
                       -message   [normalize "
                           Select a payload type to add to
                           IOM $iom_id.
                       "]]

        if {$title ne ""} {
            app enter [dict get $odict $title] \
                iom_id $iom_id longname $longname
        }
    }

    # DrawPayload pdataVar
    #
    # pdataVar - Name of an array containing payload attributes
    #
    # Adds/updates a payload item in the iptree.

    method DrawPayload {pdataVar} {
        upvar $pdataVar pdata

        # FIRST, get the payload ID
        set pdata(id) [list $pdata(iom_id) $pdata(payload_num)]

        # NEXT, get the parent item ID
        set parent $i2item($pdata(iom_id))

        # NEXT, get the payload item ID; if there is none,
        # create one.
        if {![info exists p2item($pdata(id))]} {
            set id [$iptree item create     \
                        -parent $parent    \
                        -tags   payload]

            set p2item($pdata(id)) $id
        } else {
            set id $p2item($pdata(id))
        }

        # NEXT, set the text
        $iptree item text $id                \
            0           $pdata(narrative)    \
            {tag id}    $pdata(id)           \
            {tag type}  $pdata(payload_type)

        # NEXT, set the state
        $self TreeItemState $iptree $id $pdata(state)

        # NEXT, sort payloads by payload number.
        $iptree item sort $parent -column {tag id}
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
    # tree     - The ioms tree
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
    # These methods are used in statecontroller -payloads to control
    # the state of toolbar buttons and such-like.

    # iptree single
    #
    # Returns 1 if a single item is selected in the iptree, and 0 
    # otherwise.
    
    method {iptree single} {} {
        expr {[llength [$iptree selection get]] == 1}
    }

    # iptree iom
    #
    # Returns 1 if a iom is selected in the iptree, and 0 
    # otherwise.
    
    method {iptree iom} {} {
        if {[llength [$iptree selection get]] != 1} {
            return 0
        }

        set id [lindex [$iptree selection get] 0]
        
        return [expr {"iom" in [$iptree item tag names $id]}]
    }

    # iptree validitem
    #
    # Returns 1 if a valid (state != invalid) item is selected in the
    # iptree, and 0 otherwise.
    
    method {iptree validitem} {} {
        if {[llength [$iptree selection get]] != 1} {
            return 0
        }

        set id [lindex [$iptree selection get] 0]
       
        if {![$iptree item state get $id invalid]} {
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



