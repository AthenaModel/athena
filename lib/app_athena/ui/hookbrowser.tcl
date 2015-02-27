#-----------------------------------------------------------------------
# TITLE:
#    hookbrowser.tcl
#
# AUTHORS:
#    Dave Hanks
#
# DESCRIPTION:
#    hookbrowser(sim) package: Semantic Hook/Topic browser
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widget hookbrowser {
    #-------------------------------------------------------------------
    # Options

    # Options delegated to the hull
    delegate option * to hull


    #-------------------------------------------------------------------
    # Components

    component reloader       ;# timeout(n) that reloads content

    # htree: Hook/Topic Tree
    component htree          ;# Hook/Topic treectrl
    component bar            ;# Hook/Topic toolbar
    component haddbtn        ;# Add Hook button
    component taddbtn        ;# Add Topic button
    component editbtn        ;# The "Edit" button
    component togglebtn      ;# The hook state toggle button
    component deletebtn      ;# The Delete button

    #-------------------------------------------------------------------
    # Instance Variables

    # info array
    #
    #   reloadRequests  - Number of reload requests since the last reload.
    
    variable info -array {
        reloadRequests 0
    }

    # hitem: array of htree semantic hook item IDs by hook_id
    variable hitem -array {}

    # titem: array of htree topic item IDs by topic_id
    variable titem -array {}

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the timeout controlling reload requests.
        install reloader using timeout ${selfns}::reloader \
            -command    [mymethod ReloadContent]           \
            -interval   1                                  \
            -repetition no

        # NEXT, create the GUI components
        $self HtreeCreate $win.tree

        pack $win.tree -fill both -expand yes

        # NEXT, configure the command-line options
        $self configurelist $args

        # NEXT, Behavior

        # Reload the content when the window is mapped.
        bind $win <Map> [mymethod MapWindow]

        # Reload the content on various notifier events.
        notifier bind ::adb     <Sync> $self [mymethod ReloadOnEvent]
        notifier bind ::adb     <Tick>    $self [mymethod ReloadOnEvent]

        # Reload individual entities when they
        # are updated or deleted.

        notifier bind ::adb <hooks>       $self [mymethod MonHooks]
        notifier bind ::adb <hook_topics> $self [mymethod MonTopics]

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
        $self HtreeReload
    }

    # MonHooks update hook_id
    #
    # hook_id   - A Semantic Hook ID
    #
    # Displays/adds the hook to the tree.

    method {MonHooks update} {hook_id} {
        # FIRST, we need to get the data about this hook.
        array set data [hook get $hook_id]

        # NEXT, Display the hook item
        $self DrawHook data
        $self TreeStripe $htree
    }

    # MonHooks delete hook_id
    #
    # hook_id   - A Semantic Hook ID
    #
    # Deletes the hook from the tree.

    method {MonHooks delete} {hook_id} {
        # FIRST, is this hook displayed?
        if {![info exists hitem($hook_id)]} {
            return
        }

        # NEXT, delete the item from the tree.
        $htree item delete $hitem($hook_id)
        unset hitem($hook_id)
        $self TreeStripe $htree
    }

    # MonTopics update id
    #
    # id   - A topic ID
    #
    # Displays/adds the topic to the tree.

    method {MonTopics update} {id} {
        # FIRST, we need to get the data about this topic.
        # If it isn't currently displayed, we can ignore it.
        array set data [hook topic get $id]

        if {[info exists hitem($data(hook_id))]} {
            $self DrawTopic data
            $self TreeStripe $htree
        }
    }

    # MonTopics delete id
    #
    # id   - A hook topic ID
    #
    # Deletes the hook topic from the hooks tree, if it is currently
    # displayed.  NOTE: Topics are deleted with their hook; in that
    # case, the item might already be gone from the tree.  So check.

    method {MonTopics delete} {id} {
        # FIRST, is this topic displayed?
        if {[info exists titem($id)]} {
            # FIRST, delete the item from the tree.
            if {[$htree item id $titem($id)] ne ""} {
                $htree item delete $titem($id)
            }

            unset titem($id)
            $self TreeStripe $htree
        }
    }

    #-------------------------------------------------------------------
    # htree: Semantic Hook/Topic Tree Pane

    # HtreeCreate pane
    # 
    # pane - The name of the pane widget
    #
    # Creates the Hooks pane, where semantic hooks and topics are
    # edited.

    method HtreeCreate {pane} {
        # FIRST, create the pane
        ttk::frame $pane

        # NEXT, create the toolbar
        install bar using ttk::frame $pane.bar

        # Temporary add button, just for looks
        ttk::label $bar.title \
            -text "Semantic Hooks:"

        install haddbtn using mktoolbutton $bar.haddbtn \
            ::marsgui::icon::plush22                    \
            "Add Semantic Hook"                         \
            -state   normal                             \
            -command [mymethod AddHook]

        cond::available control $haddbtn                \
            order HOOK:CREATE

        install taddbtn using mktoolbutton $bar.taddbtn \
            ::marsgui::icon::plust22                    \
            "Add Hook topic"                            \
            -state   normal                             \
            -command [mymethod AddTopic]

        cond::simPrepPredicate control $taddbtn         \
            browser   $win                              \
            predicate {htree single}

        install editbtn using mkeditbutton $bar.edit    \
            "Edit Hook or Topic"                        \
            -state   disabled                           \
            -command [mymethod EditItem]

        cond::simPrepPredicate control $editbtn          \
            browser $win                                 \
            predicate {htree single}

        install togglebtn using mktoolbutton $bar.toggle   \
            ::marsgui::icon::onoff                         \
            "Toggle Topic State"                           \
            -state   disabled                              \
            -command [mymethod ToggleTopicState]

        cond::simPrepPredicate control $togglebtn       \
            browser $win                                \
            predicate {htree validtopic}

        install deletebtn using mkdeletebutton $bar.delete \
            "Delete hook or topic"                         \
            -state   disabled                              \
            -command [mymethod DeleteItem]

        cond::simPrepPredicate control $deletebtn \
            browser $win                          \
            predicate {htree single}
            
        pack $bar.title  -side left
        pack $haddbtn    -side left
        pack $taddbtn    -side left
        pack $editbtn    -side left
        pack $togglebtn  -side left

        pack $deletebtn  -side right

        ttk::separator $pane.sep1 \
            -orient horizontal

        # NEXT, create the tree widget
        install htree using $self TreeCreate $pane.htree \
            -height         200                          \
            -yscrollcommand [list $pane.yscroll set]

        ttk::scrollbar $pane.yscroll                 \
            -orient         vertical                 \
            -command        [list $htree yview]

        # Standard tree column options:
        set colopts [list \
                         -background     $::marsgui::defaultBackground \
                         -borderwidth    1                             \
                         -button         off                           \
                         -font           TkDefaultFont                 \
                         -resize         no]

        # Tree column 0: narrative
        $htree column create {*}$colopts               \
            -text        "Hook/Topic"                   \
            -itemstyle   wrapStyle                      \
            -expand      yes                            \
            -squeeze     yes                            \
            -weight      1

        $htree configure -treecolumn first

        # Tree column 1: hook/topic id
        $htree column create {*}$colopts  \
            -text        "Id"              \
            -itemstyle   textStyle         \
            -tags        id

        # NEXT, grid them all in place
        grid $bar          -row 0 -column 0 -sticky ew -columnspan 2
        grid $pane.sep1    -row 1 -column 0 -sticky ew -columnspan 2
        grid $htree        -row 2 -column 0 -sticky nsew
        grid $pane.yscroll -row 2 -column 1 -sticky ns

        grid rowconfigure    $pane 2 -weight 1
        grid columnconfigure $pane 0 -weight 1
 
        # NEXT, prepare to handle selection changes.
        $htree notify bind $htree <Selection> [mymethod HtreeSelection]
    }

    # HtreeReload
    #
    # Loads data from the hooks and hook_topics tables into htree.

    method HtreeReload {} {
        # FIRST, save the selection (at most one thing should be selected.
        set id [lindex [$htree select get] 0]

        if {$id eq ""} {
            set selKind ""
            set selId   ""
        } else {
            set selId [$htree item text $id {tag id}]

            if {"hook" in [$htree item tag names $id]} {
                set selKind hook
            } else {
                set selKind topic
            }
        }

        # NEXT, get a list of the expanded hooks 
        set collapsed [list]

        foreach id [$htree item children root] {
            if {![$htree item state get $id open]} {
                lappend collapsed [$htree item text $id {tag id}]
            }
        }


        # NEXT, empty the htree
        $htree item delete all
        array unset hitem
        array unset titem

        # NEXT, insert the hooks
        adb eval {
            SELECT * FROM hooks ORDER BY hook_id
        } row {
            unset -nocomplain row(*)
            $self DrawHook row
        }

        # NEXT, insert the topics 
        adb eval {
            SELECT * FROM gui_hook_topics
            ORDER BY id;
        } row {
            unset -nocomplain row(*)
            $self DrawTopic row
        }

        # NEXT, set striping
        $self TreeStripe $htree

        # NEXT, open the same hooks as before
        foreach hook_id $collapsed {
            if {[info exists hitem($hook_id)]} {
                $htree item collapse $hitem($hook_id)
            }
        }

        # NEXT, if there was a selection before, select it again
        if {$selKind eq "hook"} {
            if {[info exists hitem($selId)]} {
                $htree selection add $hitem($selId)
            }
        } elseif {$selKind eq "topic"} {
            if {[info exists titem($selId)]} {
                $htree selection add $titem($selId)
            }
        }
    }

    # HtreeSelection
    #
    # Called when the htree's selection has changed.

    method HtreeSelection {} {
        ::cond::simPrepPredicate update \
            [list $taddbtn $togglebtn $editbtn $deletebtn]
    }

    # EditItem
    #
    # Called when the htree's delete button is pressed.
    # Deletes the selected entity.

    method EditItem {} {
        # FIRST, there should be only one selected.
        set id [lindex [$htree selection get] 0]

        # NEXT, it has an ID
        set oid   [$htree item text $id {tag id}]

        # NEXT, it's a hook or a topic.
        if {"hook" in [$htree item tag names $id]} {
            app enter HOOK:UPDATE hook_id $oid
        } else {
            app enter HOOK:TOPIC:UPDATE id $oid
        }
    }

    # AddHook
    #
    # Allows the user to create a new semantic hook.
    
    method AddHook {} {
        app enter HOOK:CREATE 
    }


    # ToggleTopicState
    #
    # Toggles the topic's state from normal to disabled and back
    # again.

    method ToggleTopicState {} {
        # FIRST, there should be only one selected.
        set id [lindex [$htree selection get] 0]

        # NEXT, get its topic ID
        set id [$htree item text $id {tag id}]

        # NEXT, Get its state
        set state [hook topic get $id state]

        if {$state eq "normal"} {
            flunky senddict gui HOOK:TOPIC:STATE [list id $id state disabled]
        } elseif {$state eq "disabled"} {
            flunky senddict gui HOOK:TOPIC:STATE [list id $id state normal]
        } else {
            # Do nothing (this should never happen anyway)
        }
    }


    # DeleteItem
    #
    # Called when the htree's delete button is pressed.
    # Deletes the selected entity.

    method DeleteItem {} {
        # FIRST, there should be only one selected.
        set id [lindex [$htree selection get] 0]

        # NEXT, it's a hook or a topic.
        if {"hook" in [$htree item tag names $id]} {
            flunky senddict gui HOOK:DELETE \
                [list hook_id [$htree item text $id {tag id}]]
        } else {
            flunky senddict gui HOOK:TOPIC:DELETE \
                [list id [$htree item text $id {tag id}]]
        }
    }

    # DrawHook hdataVar
    #
    # hdataVar - Name of an array containing hook attributes
    #
    # Adds/updates a hitem in the htree.
    # TBD: Needs to document the hook!

    method DrawHook {hdataVar} {
        upvar $hdataVar hdata
        
        # FIRST, get the Hook item ID; if there is none,
        # create one.
        if {![info exists hitem($hdata(hook_id))]} {
            set id [$htree item create \
                        -parent root   \
                        -button auto   \
                        -tags   hook]

            $htree item expand $id

            set hitem($hdata(hook_id)) $id
        } else {
            set id $hitem($hdata(hook_id))
        }

        # NEXT, set the text.
        $htree item text $id                  \
            0               $hdata(longname)  \
            {tag id}        $hdata(hook_id)   

        # NEXT, sort items by IOM ID
        $htree item sort root -column {tag id}
    }

    # AddTopic
    #
    # Allows the user to add a semantic hook topic
    
    method AddTopic {} {
        set id [lindex [$htree selection get] 0]
        set oid [$htree item text $id {tag id}]

        if {"hook" in [$htree item tag names $id]} {
            set hook_id $oid
        } else {
            set hook_id [hook topic get $oid hook_id]
        }

        set longname [hook get $hook_id longname]

        app enter HOOK:TOPIC:CREATE hook_id $hook_id longname $longname
    }

    # DrawTopic tdataVar
    #
    # tdataVar - Name of an array containing topic attributes
    #
    # Adds/updates a topic item in the htree.


    method DrawTopic {tdataVar} {
        upvar $tdataVar tdata

        # FIRST, get the topic ID
        set tdata(id) [list $tdata(hook_id) $tdata(topic_id)]

        # NEXT, get the parent item ID
        set parent $hitem($tdata(hook_id))

        # NEXT, get the topic item ID; if there is none,
        # create one.
        if {![info exists titem($tdata(id))]} {
            set id [$htree item create     \
                        -parent $parent    \
                        -tags   topic]

            set titem($tdata(id)) $id
        } else {
            set id $titem($tdata(id))
        }

        # NEXT, set the text
        $htree item text $id                \
            0           $tdata(narrative)    \
            {tag id}    $tdata(id)           

        # NEXT, set the state
        $self TreeItemState $htree $id $tdata(state)

        # NEXT, sort topics by hook/topic ID.
        $htree item sort $parent -column {tag id}
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
    # tree     - The hooks tree
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
    # These methods are used in statecontroller -topics to control
    # the state of toolbar buttons and such-like.

    # htree single
    #
    # Returns 1 if a single item is selected in the htree, and 0 
    # otherwise.
    
    method {htree single} {} {
        expr {[llength [$htree selection get]] == 1}
    }

    # htree hook 
    #
    # Returns 1 if a hook is selected in the htree, and 0 
    # otherwise.
    
    method {htree hook} {} {
        if {[llength [$htree selection get]] != 1} {
            return 0
        }

        set id [lindex [$htree selection get] 0]
        
        return [expr {"hook" in [$htree item tag names $id]}]
    }

    # htree validtopic
    #
    # Returns 1 if a valid (state != invalid) topic is selected in the
    # htree, and 0 otherwise.
    
    method {htree validtopic} {} {
        if {[llength [$htree selection get]] != 1} {
            return 0
        }

        set id [lindex [$htree selection get] 0]
        
        if {"topic" in [$htree item tag names $id] &&
            ![$htree item state get $id invalid]
        } {
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



