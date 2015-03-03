#-----------------------------------------------------------------------
# TITLE:
#    strategybrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    strategybrowser(sim) package: Mark II Strategy Browser
#
# NOTIFICATIONS:
#
#    This browser subscribes to a great many notifier events in order to
#    keep in sync with the state of the application.  See the 
#    MonitorApplication method for details and analysis.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widget strategybrowser {
    #-------------------------------------------------------------------
    # Options

    # Options delegated to the hull
    delegate option * to hull

    #-------------------------------------------------------------------
    # Components

    component lazy           ;# The lazyupdater(n)

    # AList: Agent List
    component alist          ;# Agent sqlbrowser(n)

    # BList: Block List
    component blist          ;# Block List
    component bl_bar         ;# Block toolbar
    component bl_addbtn      ;# Add Block button
    component bl_editbtn     ;# The "Edit" button
    component bl_topbtn      ;# The "Top Priority" button
    component bl_raisebtn    ;# The "Raise Priority" button
    component bl_lowerbtn    ;# The "Lower Priority" button
    component bl_bottombtn   ;# The "Bottom Priority" button
    component bl_togglebtn   ;# The state toggle button
    component bl_checkbtn    ;# The "Check" button
    component bl_deletebtn   ;# The Delete button

    # Tab: Content Tabbed Notebook; contains the block-specific tabs.
    component tabs

    # BMeta: frame containing block metadata fields
    component bmeta
    component bp_onlock      ;# On Lock checkbutton
    component bp_once        ;# Once checkbutton
    component bp_clock       ;# Time editing button
    component bp_timestr     ;# Time String

    # OTab: Block Overview Tab
    component otab

    # CTab: Conditions Tab
    component ctab
    component ct_bar         ;# Condition toolbar
    component ct_cmode       ;# Block cmode pulldown
    component ct_addbtn      ;# Add Condition button
    component ct_editbtn     ;# The "Edit" button
    component ct_togglebtn   ;# The state toggle button
    component ct_deletebtn   ;# The Delete button

    # TTab: Tactics Tab
    component ttab
    component tt_bar         ;# Tactic toolbar
    component tt_emode       ;# Block tmode pulldown
    component tt_addbtn      ;# Add Tactic button
    component tt_editbtn     ;# The "Edit" button
    component tt_topbtn      ;# The "Top Priority" button
    component tt_raisebtn    ;# The "Raise Priority" button
    component tt_lowerbtn    ;# The "Lower Priority" button
    component tt_bottombtn   ;# The "Bottom Priority" button
    component tt_togglebtn   ;# The state toggle button
    component tt_deletebtn   ;# The Delete button


    #-------------------------------------------------------------------
    # Instance Variables

    # info array
    #
    #   agent   - Name of currently displayed agent, or ""
    #   block   - Name of currently selected block, or ""
    
    variable info -array {
        agent  ""
        block  ""
    }

    #--------------------------------------------------------------------
    # Constructor
    #
    # The GUI appearance of this browser is as follows:
    # +-----------+-----------------------------------------------------+
    # | hpaner    | +-------------------------------------------------+ |
    # | +-------+ | | vpaner                                          | |
    # | | AList | | | +---------------------------------------------+ | |
    # | |       | | | | BList                                       | | |
    # | |       | | | |                                             | | |
    # | |       | | | +---------------------------------------------+ | |
    # | |       | | |                                                 | |
    # | |       | | +-------------------------------------------------+ |
    # | |       | | |                                                 | |
    # | |       | | | +---------------------------------------------+ | |
    # | |       | | | | bpane                                       | | |
    # | |       | | | | +-----------------------------------------+ | | |
    # | |       | | | | | BMeta                                   | | | |
    # | |       | | | | +-----------------------------------------+ | | |
    # | |       | | | | +-----------------------------------------+ | | |
    # | |       | | | | | tabs: OTab, CTab, TTab                  | | | |
    # | |       | | | | +-----------------------------------------+ | | |
    # | |       | | | +---------------------------------------------+ | |
    # | +-------+ | +-------------------------------------------------+ |
    # +-----------+-----------------------------------------------------+ 
    #
    # Names with an initial cap are major components containing application
    # data.  Names beginning with a lower case letter are purely for
    # geometry management.
    #
    # Containers:
    #     hpaner  - a panedwindow, split horizontally.
    #     vpaner  - a panedwindow, split vertically.
    #     bpane   - block pane: a frame containing information about the 
    #               selected block.
    #     tabs    - a tabbed notebook
    #
    # Content:
    #     AList   - An sqlbrowser listing the agents.
    #     BList   - A beanbrowser listing the blocks in the selected 
    #               agent's strategy.
    #     BMeta   - A frame containing block metadata fields
    #     OTab    - Overview Tab: a mybrowser displaying HTML content
    #               for the selected block.
    #     CTab    - Conditions Tab: a beanbrowser displaying the selected 
    #               block's conditions and cmode.
    #     TTab    - Tactics Tab: a beanbrowser displaying the selected 
    #               block's tactics and emode.

    constructor {args} {
        # FIRST, create the lazy updater
        install lazy using lazyupdater ${selfns}::lazy \
            -window   $win \
            -command  [mymethod ReloadContent lazy]

        # NEXT, create the GUI containers, as listed above.

        # hpaner
        ttk::panedwindow $win.hpaner \
            -orient horizontal

        # vpaner
        ttk::panedwindow $win.hpaner.vpaner \
            -orient vertical

        # bpane
        ttk::frame $win.hpaner.vpaner.bpane

        # tabs
        install tabs using ttk::notebook $win.hpaner.vpaner.bpane.tabs \
            -padding 2

        # NEXT, create the content components
        $self AListCreate $win.hpaner.alist
        $self BListCreate $win.hpaner.vpaner.blist
        $self BMetaCreate $win.hpaner.vpaner.bpane.bmeta
        $self OTabCreate  $win.hpaner.vpaner.bpane.tabs.otab
        $self CTabCreate  $win.hpaner.vpaner.bpane.tabs.ctab
        $self TTabCreate  $win.hpaner.vpaner.bpane.tabs.ttab

        # NEXT, manage geometry.
        #
        # Note: The tabs add themselves to $tabs on creation.

        # Pack BMeta and tabs in bpane
        pack $bmeta -side top -fill x
        pack $tabs  -fill both -expand yes

        # Place BList and bpane in vpaner
        $win.hpaner.vpaner add $win.hpaner.vpaner.blist   -weight 1
        $win.hpaner.vpaner add $win.hpaner.vpaner.bpane   -weight 2

        # Place AList and vpaner in hpaner
        $win.hpaner        add $win.hpaner.alist 
        $win.hpaner        add $win.hpaner.vpaner         -weight 1

        # Pack hpaner in hull
        pack $win.hpaner -fill both -expand yes ;# MOVE

        # NEXT, configure the command-line options
        $self configurelist $args

        # NEXT, Monitor the application so as to update properly as
        # external state changes.
        $self MonitorApplication

        # NEXT, schedule the first reload
        $self reload
    }

    destructor {
        notifier forget $self
    }


    #-------------------------------------------------------------------
    # Monitoring External Events

    # MonitorApplication
    #
    # Subscribes to various events, to update the browser as things change
    # in the simulation.

    method MonitorApplication {} {
        # GENERAL UPDATES
        #
        # These events indicate a gross change in application state,
        # and so the browser's data is reloaded from scratch.  A
        # lazyupdater(n) is used to guarantee that the data is reloaded only
        # once, at the last possible moment.
        notifier bind ::adb          <Sync> $self [mymethod ReloadNow]
        notifier bind ::adb          <Tick>    $self [mymethod ReloadOnEvent]
        notifier bind ::adb.strategy <Check>   $self [mymethod ReloadOnEvent]

        # ACTOR UPDATES
        #
        # When the set of actors changes, the list of names in the alist
        # can change.

        notifier bind ::adb <actors>  $self [mymethod RdbActors]

        # strategy UPDATES
        #
        # When blocks are added to or removed from or moved within the 
        # current strategy, update the bmenu.

        notifier bind ::adb.strategy <blocks>  $self [mymethod StrategyBlocks]

        # BLOCK UPDATES
        #
        # The following events indicate a change to a block.  All are 
        # ignored unless the block matches info(block).

        # Update to block metadata
        notifier bind ::adb.block <update>  $self [mymethod BlockUpdate]

        # Update to block conditions slot
        notifier bind ::adb.block <conditions> $self [mymethod BlockConditions]

        # Update to block tactics slot
        notifier bind ::adb.block <tactics> $self [mymethod BlockTactics]

        # TACTIC AND CONDITION UPDATES
        #
        # These events indicate that a tactic or condition has been edited.
        # The beanbrowser "uid update" method filters out irrelevant objects.
        # Note that beanbrowser(n)'s "uid update" is different than 
        # sqlbrowser(n)'s; sqlbrowser(n)'s handles new objects as well as
        # simple edits.  beanbrowser(n)'s only handles updates.  This is
        # OK, because adding or deleting a tactic or condition is properly
        # a change to the block, and is handled there.

        notifier bind ::adb.tactic    <update> $self [list $ttab uid update]
        notifier bind ::adb.condition <update> $self [list $ctab uid update]

    }

    # RdbActors op a
    #
    # op  - update | delete
    # a   - The actor ID
    #
    # An actor has been added, updated or deleted.  Refresh the browser
    # accordingly.

    method RdbActors {op a} {
        # FIRST, Update the AList; it knows what to do.
        $alist uid $op $a

        # NEXT, if the selected agent was deleted we need to handle that.
        # Simply reload the entire browser; we'll want to pick the first
        # remaining agent, and reloading will do what's needed.
        if {$info(agent) ne "" && [$self AListGet] eq ""} {
            $self reload
        }
    }

    # StrategyBlocks op strategy_id block_id
    #
    # op           - add, delete, move
    # strategy_id  - The ID of the strategy whose blocks were moved.
    # block_id     - The ID of the block that was added, moved, etc.
    #
    # Updates the bmenu when the strategy's list of blocks has been
    # modified.

    method StrategyBlocks {op strategy_id block_id} {
        # FIRST, if it's not our strategy we don't care.
        set s [adb bean get $strategy_id]

        if {$info(agent) eq "" || $info(agent) ne [$s agent]} {
            return
        }

        # NEXT, we need to update the display.  But if the window's not mapped 
        # just request a reload on <Map>.
        if {![winfo ismapped $win]} {
            $lazy update
            return
        }


        # NEXT, handle it by operation.
        switch -exact -- $op {
            add {
                # There's more in the blist, but info(block) won't change.
                $self ReloadBList
            }

            move {
                # The blist has been re-ordered, but info(block) won't change.
                $self ReloadBList
            }

            delete {
                set oldSelection [lindex [$blist uid curselection] 0]
                $blist uid delete $block_id

                if {$oldSelection == $block_id} {
                    $self ReloadFirstBlock
                }
            }

            default {
                error "Unknown beanslot operation: \"$op\""
            }
        }

    }

    # BlockUpdate id
    #
    # id    - A block ID
    #
    # Called on "::adb.block <update> $id", which indicates that the block's
    # metadata has been updated.

    method BlockUpdate {id} {
        # FIRST, update the blist; if it's one of this agent's blocks, 
        # that will update its entry, lazily if appropriate.
        $blist uid update $id

        # NEXT, if it's not the currently selected block there's no more
        # to do.
        if {$info(block) eq "" || $id != [$info(block) id]} {
            return
        }

        # NEXT, we need to update the display.  But if the window's not mapped 
        # just request a reload on <Map>.
        if {![winfo ismapped $win]} {
            $lazy update
            return
        }

        # NEXT, update the block metadata widgets.
        $self ReloadBlockMetadata
    }

    # BlockConditions op block_id condition_id
    #
    # op           - add | delete
    # block_id     - A block ID
    # condition_id - A condition ID
    #
    # Called on "::adb.block <conditions>", which indicates that a condition
    # has been added or deleted to the block's conditions slot.

    method BlockConditions {op block_id condition_id} {
        # FIRST, if it's not our block we don't care.
        if {$info(block) eq "" || $block_id != [$info(block) id]} {
            return
        }

        # NEXT, Update ctab.
        if {$op eq "delete"} {
            $ctab uid delete $condition_id
        } else {
            $ctab reload
        }
    }

    # BlockTactics op block_id tactic_id
    #
    # op         - add | delete
    # block_id   - A block ID
    # tactic_id  - A tactic ID
    #
    # Called on "::adb.block <tactics>", which indicates that a tactic
    # has been added or deleted to the block's tactics slot.

    method BlockTactics {op block_id tactic_id} {
        # FIRST, if it's not our block we don't care.
        if {$info(block) eq "" || $block_id != [$info(block) id]} {
            return
        }

        # NEXT, Update ttab.  Note that ttab already updates lazily, so we 
        # don't need to worry about it.
        if {$op eq "delete"} {
            $ttab uid delete $tactic_id
        } else {
            $ttab reload
        }
    }

    #-------------------------------------------------------------------
    # Reloading the Content

    # ReloadOnEvent
    #
    # Reloads the widget when various notifier events are received.
    # The "args" parameter is so that any event can be handled.
    # The reload is lazy.
    
    method ReloadOnEvent {args} {
        $self reload
    }
    
    # ReloadNow
    #
    # Reloads the widget immediately on DbSync.
    # The "args" parameter is so that any event can be handled.
    
    method ReloadNow {args} {
        $self ReloadContent
    }
    
    # ReloadContent
    #
    # The lazyupdater uses this to reload the current view.
    
    method ReloadContent {{tag ""}} {
        # FIRST, Reload the AList.  This will retain the 
        # current selection, if possible.
        $alist reload -force

        # NEXT, if the currently selected agent no longer 
        # exists, select the first actor.

        if {![adb agent exists $info(agent)]} {
            set info(agent) [lindex [adb agent names] 0]
            set info(block) ""

            $alist uid select $info(agent)
        }

        # NEXT, reload the blocks.
        $self ReloadBlocks
    }

    # ReloadBlocks
    #
    # Reload the BList, and select the first block (if any)

    method ReloadBlocks {} {
        $self ReloadBList
        $self ReloadFirstBlock
    }

    # ReloadFirstBlock
    #
    # Reloads all blocks, and sets info(block) if necessary.
    method ReloadFirstBlock {} {
        # FIRST, get the list of blocks.  We could get this from the 
        # BList, but it's easier to get it from the strategy.
        if {$info(agent) ne ""} {
            set s [strategy getname $info(agent)]
            set blocks [$s blocks]
        } else {
            set blocks [list]
        }

        # NEXT, if the last selected block is no longer in the list,
        # select the first one.

        if {[llength $blocks] == 0} {
            set info(block) ""
            $blist uid select {}
        } elseif {$info(block) ni $blocks} {
            set info(block) [lindex $blocks 0]
            $blist uid select [$info(block) id]
        }

        $self ReloadBlock
    }

    # ReloadBList
    #
    # Reloads the agent's blocks into the list.

    method ReloadBList {} {
        # FIRST, if no agent just clear it.
        if {$info(agent) eq ""} {
            $blist configure -beancmd ""
            $blist clear -silent
            return
        }

        # NEXT, configure the -beancmd and force a reload.
        $blist configure -beancmd [list [strategy getname $info(agent)] blocks]
        $blist reload -force
    }

    # ReloadBlock
    #
    # Reloads the currently selected block.

    method ReloadBlock {} {
        $self OTabReload
        $self ReloadBlockMetadata
        $self ReloadConditions
        $self ReloadTactics

        ::cond::simPrepPredicate update \
            [list $bl_editbtn $bl_deletebtn $bl_togglebtn \
                 $bl_topbtn $bl_raisebtn $bl_lowerbtn $bl_bottombtn \
                 $ct_cmode $ct_addbtn $tt_emode $tt_addbtn \
                 $bp_onlock $bp_once $bp_clock]
    }

    # ReloadBlockMetadata
    #
    # Reloads the block-related metadata fields.

    method ReloadBlockMetadata {} {
        if {$info(block) ne ""} {
            $bp_onlock set [$info(block) get onlock] -silent
            $bp_once set   [$info(block) get once] -silent
            $ct_cmode set  [$info(block) get cmode] -silent
            $tt_emode set  [$info(block) get emode] -silent

            $self SetBlockTime [$info(block) timestring]
        } else {
            $bp_onlock set 0
            $bp_once set 0
            $ct_cmode set ""
            $tt_emode set ""

            $self SetBlockTime ""
        }
    }

    # ReloadConditions
    #
    # Reloads the block's conditions into the list.

    method ReloadConditions {} {
        # FIRST, if no block we're done.
        if {$info(block) eq ""} {
            $ctab configure -beancmd ""
            $ctab clear
            return
        }

        # NEXT, get the new -beancmd.
        $ctab configure -beancmd [list $info(block) conditions]
        $ctab reload
    }

    # ReloadTactics
    #
    # Reloads the block's tactics into the list.

    method ReloadTactics {} {
        # FIRST, if no block we're done.
        if {$info(block) eq ""} {
            $ttab configure -beancmd ""
            $ttab clear
            return
        }

        # NEXT, get the new -beancmd.
        $ttab configure -beancmd [list $info(block) tactics]
        $ttab reload
    }

    #-------------------------------------------------------------------
    # Agent List Pane

    # AListCreate pane
    #
    # pane - The name of the agent list's pane widget
    #
    # Creates the "alist" component, which lists all of the
    # available agents.

    method AListCreate {pane} {
        # FIRST, create the list widget
        install alist using sqlbrowser $pane          \
            -height       10                          \
            -width        10                          \
            -relief       flat                        \
            -borderwidth  1                           \
            -stripeheight 0                           \
            -db           ::adb                       \
            -view         agents                      \
            -uid          agent_id                    \
            -filterbox    off                         \
            -selectmode   browse                      \
            -displaycmd   [mymethod AListDisplay]     \
            -selectioncmd [mymethod AListAgentSelect] \
            -layout {
                {agent_id "Agent" -stretchable yes} 
            } 
    }

    # AListDisplay rindex values
    # 
    # rindex    The row index
    # values    The values in the row's cells
    #
    # Sets the agent's color based on its known state.


    method AListDisplay {rindex values} {
        # FIRST, set color
        set agent [lindex $values 0]
        set state [[strategy getname $agent] state]

        $alist rowconfigure $rindex \
            -foreground [ebeanstate as color $state] \
            -font       [ebeanstate as font  $state]

    }


    # AListGet
    #
    # Returns the name of the selected agent or "" if none.

    method AListGet {} {
        # At most one can be selected.
        return [lindex [$alist uid curselection] 0]
    }

 
    # AListAgentSelect
    #
    # Called when an agent is selected in the alist.  Updates the
    # rest of the browser to display that agent's data.

    method AListAgentSelect {} {
        # FIRST, update state controllers
        ::cond::simPrepPredicate update [list $bl_addbtn]

        # NEXT, Skip it if there's no change.
        if {$info(agent) eq [$self AListGet]} {
            return
        }

        # Only trace if there was a change.
        set info(agent) [$self AListGet]
        set info(block) ""

        $self ReloadBlocks
    }


    #-------------------------------------------------------------------
    # BList: Block List Pane

    # BListCreate pane
    # 
    # pane - The name of the pane widget
    #
    # Creates the Block List pane, where blocks are viewed and edited.

    method BListCreate {pane} {
        # FIRST, create the pane
        install blist using beanbrowser $pane          \
            -beancmd        ""                         \
            -columnsorting 0                           \
            -titlecolumns  3                          \
            -displaycmd    [mymethod BListDisplay]     \
            -selectioncmd  [mymethod BListSelection]   \
            -cutcopycmd    [mymethod BListCutCopy]     \
            -pastecmd      [mymethod BListPaste]       \
            -layout [string map [list %D $::app::derivedfg] {
                { id              "ID"                              }
                { fullname        "Name"     -width 10              }
                { statusicon      "Exec"     -align center          }
                { state           "State"    -width 8               }
                { intent          "Intent"   -width 30 -wrap yes    }
                { timestring      "At Time"  -stretchable yes       }
                { pretty_onlock   "On Lock?"                        }
                { pretty_once     "Once?"                           }
                { pretty_exectime "Last"     -width 8               }
            }]


        # NEXT, create the toolbar
        set bl_bar [$blist toolbar]

        # Label, so they know what's listed.
        ttk::label $bl_bar.title \
            -text "Blocks:"

        # Add
        install bl_addbtn using mktoolbutton $bl_bar.bl_addbtn   \
            ::marsgui::icon::plus22                              \
            "Add Block"                                          \
            -state   normal                                      \
            -command [mymethod BListAdd]

        cond::simPrepPredicate control $bl_addbtn                 \
            browser   $win                                       \
            predicate {alist single}

        # Edit
        install bl_editbtn using mkeditbutton $bl_bar.edit       \
            "Edit Block Metadata"                                \
            -state   disabled                                    \
            -command [mymethod BListEdit]

        cond::simPrepPredicate control $bl_editbtn                \
            browser $win                                         \
            predicate {blist single}

        # Toggle State
        install bl_togglebtn using mktoolbutton $bl_bar.toggle   \
            ::marsgui::icon::onoff                               \
            "Toggle State"                                \
            -state   disabled                                    \
            -command [mymethod BListState]

        cond::simPrepPredicate control $bl_togglebtn              \
            browser $win                                         \
            predicate {blist single}

        # To Top
        install bl_topbtn using mktoolbutton $bl_bar.top         \
            ::marsgui::icon::totop                               \
            "Top Priority"                                       \
            -state   disabled                                    \
            -command [mymethod BListPriority top]

        cond::simPrepPredicate control $bl_topbtn                 \
            browser $win                                         \
            predicate {blist single}

        # Raise
        install bl_raisebtn using mktoolbutton $bl_bar.up        \
            ::marsgui::icon::raise                               \
            "Raise Priority"                                     \
            -state   disabled                                    \
            -command [mymethod BListPriority up]

        cond::simPrepPredicate control $bl_raisebtn               \
            browser $win                                         \
            predicate {blist single}

        # Lower
        install bl_lowerbtn using mktoolbutton $bl_bar.down      \
            ::marsgui::icon::lower                               \
            "Lower Priority"                                     \
            -state   disabled                                    \
            -command [mymethod BListPriority down]

        cond::simPrepPredicate control $bl_lowerbtn               \
            browser $win                                         \
            predicate {blist single}

        # To Bottom
        install bl_bottombtn using mktoolbutton $bl_bar.bottom   \
            ::marsgui::icon::tobottom                            \
            "Bottom Priority"                                    \
            -state   disabled                                    \
            -command [mymethod BListPriority bottom]

        cond::simPrepPredicate control $bl_bottombtn              \
            browser $win                                         \
            predicate {blist single}

        # vsep
        ttk::separator $bl_bar.vsep \
            -orient vertical

        # Check
        install bl_checkbtn using ttk::button $bl_bar.check       \
            -style   Toolbutton                                   \
            -text    "Check"                                      \
            -command [mymethod BListCheckStrategies]


        # Delete
        install bl_deletebtn using mkdeletebutton $bl_bar.delete \
            "Delete Block"                                       \
            -state   disabled                                    \
            -command [mymethod BListDelete]

        cond::simPrepPredicate control $bl_deletebtn              \
            browser $win                                         \
            predicate {blist multi}
            
        pack $bl_bar.title  -side left
        pack $bl_addbtn     -side left
        pack $bl_editbtn    -side left
        pack $bl_togglebtn  -side left
        pack $bl_topbtn     -side left
        pack $bl_raisebtn   -side left
        pack $bl_lowerbtn   -side left
        pack $bl_bottombtn  -side left
        pack $bl_bar.vsep   -side left -fill y -padx 5
        pack $bl_checkbtn   -side left

        pack $bl_deletebtn  -side right
    }

    # BListDisplay rindex values
    # 
    # rindex    The row index
    # values    The values in the row's cells
    #
    # Sets the block execution status icon.


    method BListDisplay {rindex values} {
        # FIRST, set flag icon
        set cindex [$blist cname2cindex statusicon]
        set icon [lindex $values $cindex]

        $blist cellconfigure $rindex,$cindex       \
            -image $icon \
            -text  ""

        # NEXT, set intent color
        set state [lindex $values [$blist cname2cindex state]]
        set cindex [$blist cname2cindex intent]
        $blist cellconfigure $rindex,$cindex \
            -foreground [ebeanstate as color $state] \
            -font       [ebeanstate as font  $state]

    }


    # BListSelection
    #
    # Called when the blist's selection has changed.

    method BListSelection {} {
        ::cond::simPrepPredicate update \
            [list $bl_editbtn $bl_deletebtn $bl_togglebtn \
                 $bl_topbtn $bl_raisebtn $bl_lowerbtn $bl_bottombtn \
                 $bp_onlock $bp_once $bp_clock]

        set id [lindex [$blist uid curselection] 0]

        if {$id ne ""} {
            set newBlock [adb bean get $id]
        } else {
            set newBlock ""
        }

        # Don't reload anything unless something really changed.
        if {$newBlock eq $info(block)} {
            return
        }

        set info(block) $newBlock

        $self ReloadBlock
    }

    # BListCutCopy mode
    #
    # mode   - cut|copy
    #
    # This command is called when the user cuts or copies from
    # the BList.  There will always be at least one item selected.

    method BListCutCopy {mode} {
        # FIRST, if the sim state is wrong, we're done.
        if {[sim state] ni {PREP PAUSED}} {
            bell
            return
        }

        # NEXT, copy the data to the clipboard.
        set ids [$blist uid curselection]

        set data [list]

        foreach id $ids {
            set bean [adb bean get $id]
            lappend copyData [$bean copydata]
        }

        clipboardx clear
        clipboardx set ::athena::block $copyData

        # NEXT, if the mode is cut delete the items.
        if {$mode eq "cut"} {
            adb order senddict gui STRATEGY:BLOCK:DELETE [ids $ids]
        }

        # NEXT, notify the user:
        if {$mode eq "copy"} {
            app puts "Copied [llength $ids] item(s)"
        } else {
            app puts "Cut [llength $ids] item(s)"
        }
    }

    # BListPaste
    #
    # This command is called when the user pastes into 
    # the BList.

    method BListPaste {} {
        # FIRST, if the sim state is wrong or there's no strategy loaded,
        # we're done.
        if {[sim state] ni {PREP PAUSED} ||
            $info(agent) eq ""
        } {
            bell
            return
        }

        # NEXT, get the blocks from the clipboard, if any.
        set copysets [clipboardx get ::athena::block]

        if {[llength $copysets] == 0} {
            bell
            return
        }

        # NEXT, paste!
        adb paste block $info(agent) $copysets

        app puts "Pasted [llength $copysets] item(s)"
    }

    # BListEdit
    #
    # Called when the BList's edit button is pressed.
    # Edits the selected block's metadata.

    method BListEdit {} {
        # FIRST, there should be only one selected.
        set id [lindex [$blist uid curselection] 0]

        # NEXT, allow editing.
        app enter BLOCK:UPDATE block_id $id
    }

    # BListAdd
    #
    # Creates a new block and adds it to the strategy.
    
    method BListAdd {} {
        set block_id [adb order senddict gui STRATEGY:BLOCK:ADD \
                        [list agent $info(agent)]]

        $blist uid select $block_id
        $self BListEdit
    }


    # BListPriority where
    #
    # where   - top, up, down, bottom
    #
    # Moves the block in the strategy's list.

    method BListPriority {where} {
        # FIRST, there should be only one selected.
        set id [lindex [$blist uid curselection] 0]

        # NEXT, Change its priority.
        adb order senddict gui STRATEGY:BLOCK:MOVE \
            [list block_id $id where $where]
    }


    # BListState
    #
    # Toggles the block's state from normal or invalid to disabled and back
    # again.

    method BListState {} {
        # FIRST, there should be only one selected.
        set id [lindex [$blist uid curselection] 0]

        # NEXT, get the block's state
        set block [adb bean get $id]
        set state [$block state]

        if {$state eq "disabled"} {
            adb order senddict gui BLOCK:STATE [list block_id $id state normal]
        } else {
            adb order senddict gui BLOCK:STATE [list block_id $id state disabled]
        }
    }

    # BListCheckStrategies
    #
    # Executes the sanity checks for all strategies, displaying the 
    # results.

    method BListCheckStrategies {} {
        set failed [strategy check]

        if {$failed} {
            set msg "at least one problem was found"
        } else {
            set msg "no problems found"
        }

        app puts "Performed strategy sanity check; $msg."
    }


    # BListDelete
    #
    # Called when the BList's delete button is pressed.
    # Deletes the selected block(s).

    method BListDelete {} {
        adb order senddict gui STRATEGY:BLOCK:DELETE \
            [list ids [$blist uid curselection]]
    }

    #-------------------------------------------------------------------
    # BMeta: Block Metadata Pane

    # BMetaCreate pane
    # 
    # pane - The name of the pane widget
    #
    # Creates the BMeta pane, where the selected block's metadata is 
    # displayed and can be edited.

    method BMetaCreate {pane} {
        install bmeta using ttk::frame $pane

        install bp_onlock using checkfield $bmeta.onlock \
            -text      "On Lock"                         \
            -changecmd [mymethod SetBlockParm onlock]

        cond::simPrepPredicate control $bp_onlock         \
            browser   $win                               \
            predicate {gotblock}

        install bp_once using checkfield $bmeta.once \
            -text      "Once Only"                   \
            -changecmd [mymethod SetBlockParm once]

        cond::simPrepPredicate control $bp_once           \
            browser   $win                               \
            predicate {gotblock}

        install bp_timestr using ttk::label $bmeta.timestr

        install bp_clock using mktoolbutton $bmeta.clock   \
            ::marsgui::icon::clock                         \
            "Edit Block Time Constraints"                  \
            -state   disabled                              \
            -command [mymethod BListEdit]

        cond::simPrepPredicate control $bp_clock                  \
            browser $win                                         \
            predicate {blist single}


        pack $bp_onlock  -side left
        pack $bp_once    -side left -padx {8 0}
        pack $bp_timestr -side left -padx {8 0}
        pack $bp_clock   -side left

        $self SetBlockTime ""
    }

    method SetBlockTime {text} {
        if {$text eq ""} {
            set text "----"
        }
        $bp_timestr configure -text "Time Constraint: $text"
    }

    #-------------------------------------------------------------------
    # OTab: Block Overview Pane

    # OTabCreate pane
    # 
    # pane - The name of the pane widget
    #
    # Creates the OTab pane, where the selected block's data is 
    # displayed as an HTML page.  Reload the data on <Monitor>, since
    # it might contain any bean data.

    method OTabCreate {pane} {
        # FIRST, create the pane
        install otab using mybrowser $pane     \
            -toolbar      no                   \
            -sidebar      no                   \
            -home         ""                   \
            -hyperlinkcmd {::app show}         \
            -messagecmd   {::app puts}         \
            -reloadon     {
                ::projectlib::bean <Monitor>
            }

        # NEXT, initialize it
        $otab show ""

        # NEXT, add it to the tabbed notebook.
        $tabs add $otab \
            -text    "Overview" \
            -sticky  nsew       \
            -padding 2          \
    }

    # OTabReload
    #
    # Loads the selected block's data into the pane.

    method OTabReload {} {
        if {$info(block) eq ""} {
            $otab show ""
        } else {
            $otab show "my://app/bean/[$info(block) id]"
        }
    }

    #-------------------------------------------------------------------
    # CTab: Conditions Tab

    # CTabCreate pane
    # 
    # pane - The name of the pane widget
    #
    # Creates the Condition List pane, where a block's conditions
    # are viewed and edited.

    method CTabCreate {pane} {
        # FIRST, create the pane
        # TBD: Display cflag using thumbup/thumbdown/dash
        #      Needs emetstatus value, "yes", "no", "unknown"
        install ctab using beanbrowser $pane          \
            -beancmd        ""                        \
            -columnsorting 0                          \
            -titlecolumns  3                          \
            -height        5                          \
            -displaycmd    [mymethod CTabDisplay]     \
            -selectioncmd  [mymethod CTabSelection]   \
            -cutcopycmd    [mymethod CTabCutCopy]     \
            -pastecmd      [mymethod CTabPaste]       \
            -layout [string map [list %D $::app::derivedfg] {
                { id              "ID"                               }
                { fullname        "Name"      -width 10              }
                { statusicon      "Flag"                             }
                { state           "State"     -width 8               }
                { narrative       "Narrative" -width 60 -wrap yes    }
                { typename        "Type"                             }
            }]

        # NEXT, add it to the tabbed notebook.
        $tabs add $ctab \
            -text    "Conditions" \
            -sticky  nsew       \
            -padding 2          \

        # NEXT, create the toolbar
        set ct_bar [$ctab toolbar]

        # Label, so they know what's listed.
        ttk::label $ct_bar.title \
            -text "WHEN"

        install ct_cmode using enumfield $ct_bar.cmode           \
            -width       8                                       \
            -displaylong yes                                     \
            -enumtype    eanyall                                 \
            -changecmd   [mymethod SetBlockParm cmode]

        cond::simPrepPredicate control $ct_cmode                  \
            browser   $win                                       \
            predicate {gotblock}

        ttk::label $ct_bar.title2 \
            -text "these conditions are met:"

        ttk::separator $ct_bar.sep \
            -orient vertical

        # Add button
        install ct_addbtn using ttk::menubutton $ct_bar.add       \
            -style Toolbutton                                     \
            -image ::marsgui::icon::plus22                        \
            -state normal

        DynamicHelp::add $ct_addbtn -text "Add Condition"

        cond::simPrepPredicate control $ct_addbtn                 \
            browser   $win                                       \
            predicate {gotblock}

        $self CTabPopulateAddMenu $ct_addbtn.menu

        # Edit Button
        install ct_editbtn using mkeditbutton $ct_bar.edit       \
            "Edit Condition"                                     \
            -state   disabled                                    \
            -command [mymethod CTabEdit]

        cond::simPrepPredicate control $ct_editbtn                \
            browser $win                                         \
            predicate {ctab single}

        # State button
        install ct_togglebtn using mktoolbutton $ct_bar.toggle   \
            ::marsgui::icon::onoff                               \
            "Toggle State"                                \
            -state   disabled                                    \
            -command [mymethod CTabState]

        cond::simPrepPredicate control $ct_togglebtn              \
            browser $win                                         \
            predicate {ctab single}

        # Delete button
        install ct_deletebtn using mkdeletebutton $ct_bar.delete \
            "Delete Condition"                                   \
            -state   disabled                                    \
            -command [mymethod CTabDelete]

        cond::simPrepPredicate control $ct_deletebtn              \
            browser $win                                         \
            predicate {ctab multi}
            
        # Pack all buttons
        pack $ct_bar.title  -side left
        pack $ct_bar.cmode  -side left -padx 2
        pack $ct_bar.title2 -side left
        pack $ct_bar.sep    -side left -fill y -padx 4
        pack $ct_addbtn     -side left
        pack $ct_editbtn    -side left
        pack $ct_togglebtn  -side left

        pack $ct_deletebtn  -side right
    }

    # CTabDisplay rindex values
    # 
    # rindex    The row index
    # values    The values in the row's cells
    #
    # Sets the condition status icon.

    method CTabDisplay {rindex values} {
        # FIRST, set flag icon
        set cindex [$ctab cname2cindex statusicon]
        set icon [lindex $values $cindex]

        $ctab cellconfigure $rindex,$cindex       \
            -image $icon \
            -text  ""

        # NEXT, set narrative color
        set state [lindex $values [$ctab cname2cindex state]]
        set cindex [$ctab cname2cindex narrative]
        $ctab cellconfigure $rindex,$cindex \
            -foreground [ebeanstate as color $state] \
            -font       [ebeanstate as font  $state]
    }


    # CTabSelection
    #
    # Called when the ctab's selection has changed.

    method CTabSelection {} {
        ::cond::simPrepPredicate update \
            [list $ct_editbtn $ct_deletebtn $ct_togglebtn]
    }

    # CTabCutCopy mode
    #
    # mode   - cut|copy
    #
    # This command is called when the user cuts or copies from
    # the CTab.  There will always be at least one item selected.

    method CTabCutCopy {mode} {
        # FIRST, if the sim state is wrong, we're done.
        if {[sim state] ni {PREP PAUSED}} {
            bell
            return
        }

        # NEXT, copy the data to the clipboard.
        set ids [$ctab uid curselection]

        set data [list]

        foreach id $ids {
            set bean [adb bean get $id]
            lappend copyData [$bean copydata]
        }

        clipboardx clear
        clipboardx set ::athena::condition $copyData

        # NEXT, if the mode is cut delete the items.
        if {$mode eq "cut"} {
            adb order senddict gui BLOCK:CONDITION:DELETE [list ids $ids]
        }

        # NEXT, notify the user:
        if {$mode eq "copy"} {
            app puts "Copied [llength $ids] item(s)"
        } else {
            app puts "Cut [llength $ids] item(s)"
        }
    }

    # CTabPaste
    #
    # This command is called when the user pastes into 
    # the CTab.

    method CTabPaste {} {
        # FIRST, if the sim state is wrong or there's no block loaded,
        # we're done.
        if {[sim state] ni {PREP PAUSED} ||
            ![$self gotblock]
        } {
            bell
            return
        }

        # NEXT, get the conditions from the clipboard, if any.
        set copysets [clipboardx get ::athena::condition]

        if {[llength $copysets] == 0} {
            bell
            return
        }

        # NEXT, paste!
        adb paste condition [$info(block) id] $copysets

        app puts "Pasted [llength $copysets] item(s)"
    }

    # CTabPopulateAddMenu mnu
    #
    # mnu  - the menu widget name.
    #
    # Creates and populates the popup menu associated with the addbutton.

    method CTabPopulateAddMenu {mnu} {
        menu $mnu
        $ct_addbtn configure -menu $mnu

        dict for {ctype title} [::athena::condition typedict] {
            $mnu add command \
                -label   $title \
                -command [mymethod CTabAdd [$ctype typename]]
        }
    }

    # CTabAdd typename
    #
    # typename - The typename of the condition to add.
    #
    # Creates a new condition and adds it to the strategy.
    
    method CTabAdd {typename} {
        # FIRST, create the condition.
        set condition_id [adb order senddict gui BLOCK:CONDITION:ADD \
            [list block_id [$info(block) id] \
                typename $typename]]

        # NEXT, force a reload of the list, so that we can select
        # the new condition.  Select it, and popup the edit dialog.
        $ctab reload -force
        $ctab uid select $condition_id
        $self CTabEdit
    }

    # CTabEdit
    #
    # Called when the CTab's edit button is pressed.
    # Edits the selected condition.

    method CTabEdit {} {
        # FIRST, there should be only one selected.
        set id [lindex [$ctab uid curselection] 0]
        set cond [adb bean get $id]

        # NEXT, allow editing.
        app enter CONDITION:[$cond typename] condition_id $id
    }

    # CTabState
    #
    # Toggles the conditions's state from normal or invalid to disabled
    # and back again.

    method CTabState {} {
        # FIRST, there should be only one selected.
        set id [lindex [$ctab uid curselection] 0]

        # NEXT, get the condition's state
        set cond [adb bean get $id]
        set state [$cond state]

        if {$state eq "disabled"} {
            adb order send gui CONDITION:STATE -condition_id $id -state normal
        } else {
            adb order send gui CONDITION:STATE -condition_id $id -state disabled
        }
    }


    # CTabDelete
    #
    # Called when the CTab's delete button is pressed.
    # Deletes the selected condition(s).

    method CTabDelete {} {
        # FIRST, delete all selected conditions.
        adb order senddict gui BLOCK:CONDITION:DELETE \
            [list ids [$ctab uid curselection]]
    }

    #-------------------------------------------------------------------
    # TTab: Tactic List Pane

    # TTabCreate pane
    # 
    # pane - The name of the pane widget
    #
    # Creates the Tactic List pane, where tactics are viewed and edited.

    method TTabCreate {pane} {
        # FIRST, create the pane
        install ttab using beanbrowser $pane          \
            -beancmd       ""                         \
            -columnsorting 0                          \
            -titlecolumns  3                          \
            -height        5                          \
            -displaycmd    [mymethod TTabDisplay]     \
            -selectioncmd  [mymethod TTabSelection]   \
            -cutcopycmd    [mymethod TTabCutCopy]     \
            -pastecmd      [mymethod TTabPaste]       \
            -layout [string map [list %D $::app::derivedfg] {
                { id              "ID"                               }
                { fullname        "Name"      -width 10              }
                { statusicon      "Exec"      -align center          }
                { state           "State"     -width 8               }
                { narrative       "Narrative" -width 60 -wrap yes    }
                { typename        "Type"                             }
            }]

        # NEXT, add it to the tabbed notebook.
        $tabs add $ttab \
            -text    "Tactics" \
            -sticky  nsew       \
            -padding 2          \

        # NEXT, create the toolbar
        set tt_bar [$ttab toolbar]

        # Label, so they know what's listed.
        ttk::label $tt_bar.title \
            -text "THEN execute"

        install tt_emode using enumfield $tt_bar.emode           \
            -width       25                                      \
            -displaylong yes                                     \
            -values      [eexecmode asdict longname]             \
            -changecmd   [mymethod SetBlockParm emode]

        cond::simPrepPredicate control $tt_emode                  \
            browser   $win                                       \
            predicate {gotblock}

        ttk::separator $tt_bar.sep \
            -orient vertical


        # Add Button
        install tt_addbtn using ttk::menubutton $tt_bar.add       \
            -style Toolbutton                                     \
            -image ::marsgui::icon::plus22                        \
            -state normal

        DynamicHelp::add $tt_addbtn -text "Add tactic"

        cond::simPrepPredicate control $tt_addbtn                 \
            browser   $win                                       \
            predicate {gotblock}

        $self TTabPopulateAddMenu $tt_addbtn.menu

        # Edit Button
        install tt_editbtn using mkeditbutton $tt_bar.edit       \
            "Edit Tactic"                                        \
            -state   disabled                                    \
            -command [mymethod TTabEdit]

        cond::simPrepPredicate control $tt_editbtn                \
            browser $win                                         \
            predicate {ttab single}

        # State Button
        install tt_togglebtn using mktoolbutton $tt_bar.toggle   \
            ::marsgui::icon::onoff                               \
            "Toggle State"                                \
            -state   disabled                                    \
            -command [mymethod TTabState]

        cond::simPrepPredicate control $tt_togglebtn              \
            browser $win                                         \
            predicate {ttab single}

        # Top Button
        install tt_topbtn using mktoolbutton $tt_bar.top         \
            ::marsgui::icon::totop                               \
            "Top Priority"                                       \
            -state   disabled                                    \
            -command [mymethod TTabPriority top]

        cond::simPrepPredicate control $tt_topbtn                 \
            browser $win                                         \
            predicate {ttab single}

        # Raise Button
        install tt_raisebtn using mktoolbutton $tt_bar.up        \
            ::marsgui::icon::raise                               \
            "Raise Priority"                                     \
            -state   disabled                                    \
            -command [mymethod TTabPriority up]

        cond::simPrepPredicate control $tt_raisebtn               \
            browser $win                                         \
            predicate {ttab single}

        # Lower Button
        install tt_lowerbtn using mktoolbutton $tt_bar.down      \
            ::marsgui::icon::lower                               \
            "Lower Priority"                                     \
            -state   disabled                                    \
            -command [mymethod TTabPriority down]

        cond::simPrepPredicate control $tt_lowerbtn               \
            browser $win                                         \
            predicate {ttab single}

        # Bottom Button
        install tt_bottombtn using mktoolbutton $tt_bar.bottom   \
            ::marsgui::icon::tobottom                            \
            "Bottom Priority"                                    \
            -state   disabled                                    \
            -command [mymethod TTabPriority bottom]

        cond::simPrepPredicate control $tt_bottombtn              \
            browser $win                                         \
            predicate {ttab single}

        # Delete Button
        install tt_deletebtn using mkdeletebutton $tt_bar.delete \
            "Delete Tactic"                                      \
            -state   disabled                                    \
            -command [mymethod TTabDelete]

        cond::simPrepPredicate control $tt_deletebtn              \
            browser $win                                         \
            predicate {ttab multi}
            
        # Pack all buttons
        pack $tt_bar.title  -side left
        pack $tt_emode      -side left -padx 2
        pack $tt_bar.sep    -side left -padx {2 4} -fill y
        pack $tt_addbtn     -side left
        pack $tt_editbtn    -side left
        pack $tt_togglebtn  -side left
        pack $tt_topbtn     -side left
        pack $tt_raisebtn   -side left
        pack $tt_lowerbtn   -side left
        pack $tt_bottombtn  -side left

        pack $tt_deletebtn  -side right
    }

    # TTabDisplay rindex values
    # 
    # rindex    The row index
    # values    The values in the row's cells
    #
    # Sets the tactic execution status icon.


    method TTabDisplay {rindex values} {
        # FIRST, set status icon
        set cindex [$ttab cname2cindex statusicon]
        set icon [lindex $values $cindex]

        $ttab cellconfigure $rindex,$cindex \
            -image $icon \
            -text  ""

        # NEXT, set narrative color
        set state [lindex $values [$ttab cname2cindex state]]
        set cindex [$ttab cname2cindex narrative]
        $ttab cellconfigure $rindex,$cindex \
            -foreground [ebeanstate as color $state] \
            -font       [ebeanstate as font  $state]

    }


    # TTabSelection
    #
    # Called when the ttab's selection has changed.

    method TTabSelection {} {
        ::cond::simPrepPredicate update \
            [list $tt_editbtn $tt_deletebtn $tt_togglebtn \
                 $tt_topbtn $tt_raisebtn $tt_lowerbtn $tt_bottombtn]
    }

    # TTabCutCopy mode
    #
    # mode   - cut|copy
    #
    # This command is called when the user cuts or copies from
    # the TTab.  There will always be at least one item selected.

    method TTabCutCopy {mode} {
        # FIRST, if the sim state is wrong, we're done.
        if {[sim state] ni {PREP PAUSED}} {
            bell
            return
        }

        # NEXT, copy the data to the clipboard.
        set ids [$ttab uid curselection]

        set data [list]

        foreach id $ids {
            set bean [adb bean get $id]
            lappend copyData [$bean copydata]
        }

        clipboardx clear
        clipboardx set ::athena::tactic $copyData

        # NEXT, if the mode is cut delete the items.
        if {$mode eq "cut"} {
            adb order senddict gui BLOCK:TACTIC:DELETE [list ids $ids]
        }

        # NEXT, notify the user:
        if {$mode eq "copy"} {
            app puts "Copied [llength $ids] item(s)"
        } else {
            app puts "Cut [llength $ids] item(s)"
        }
    }

    # TTabPaste
    #
    # This command is called when the user pastes into 
    # the TTab.

    method TTabPaste {} {
        # FIRST, if the sim state is wrong or there's no block loaded,
        # we're done.
        if {[sim state] ni {PREP PAUSED} ||
            ![$self gotblock]
        } {
            bell
            return
        }

        # NEXT, get the tactics from the clipboard, if any.
        set copysets [clipboardx get ::athena::tactic]

        if {[llength $copysets] == 0} {
            bell
            return
        }

        # NEXT, paste!
        adb paste tactic [$info(block) id] $copysets

        app puts "Pasted [llength $copysets] item(s)"
    }

    # TTabPopulateAddMenu mnu
    #
    # mnu  - the menu widget name.
    #
    # Creates and populates the popup menu associated with the addbutton.

    method TTabPopulateAddMenu {mnu} {
        # Update the cond::predicate statecontroller when the
        # menu is posted, so that the relevant items will be
        # enabled/disabled.
        menu $mnu \
            -postcommand [list ::cond::predicate update]

        $tt_addbtn configure -menu $mnu

        foreach ttype [::athena::tactic types] {
            cond::predicate control \
                [menuitem $mnu command [$ttype title] \
                    -command [mymethod TTabAdd [$ttype typename]]] \
                browser $self predicate [list usableByAgent [$ttype typename]]
        }
    }

    # TTabAdd typename
    #
    # typename - The typename of the tactic to add.
    #
    # Creates a new tactic and adds it to the strategy.
    
    method TTabAdd {typename} {
        # FIRST, create the tactic.
        set tactic_id [adb order senddict gui BLOCK:TACTIC:ADD \
            [list block_id [$info(block) id] \
                typename $typename]]

        # NEXT, force a reload of the list, so that we can select
        # the new tactic.  Select it, and popup the edit dialog.
        $ttab reload -force
        $ttab uid select $tactic_id
        $self TTabEdit
    }

    # TTabEdit
    #
    # Called when the TTab's edit button is pressed.
    # Edits the selected tactic.

    method TTabEdit {} {
        # FIRST, there should be only one selected.
        set id [lindex [$ttab uid curselection] 0]

        set tactic [adb bean get $id]

        # NEXT, allow editing.
        app enter TACTIC:[$tactic typename] tactic_id $id
    }


    # TTabState
    #
    # Toggles the tactic's state from normal or invalid to disabled and back
    # again.

    method TTabState {} {
        # FIRST, there should be only one selected.
        set id [lindex [$ttab uid curselection] 0]

        # NEXT, get the tactic's state
        set tactic [adb bean get $id]
        set state [$tactic state]

        if {$state eq "disabled"} {
            adb order send gui TACTIC:STATE -tactic_id $id -state normal
        } else {
            adb order send gui TACTIC:STATE -tactic_id $id -state disabled
        }
    }

    # TTabPriority where
    #
    # where   - top, up, down, bottom
    #
    # Moves the tactic in the block's list.

    method TTabPriority {where} {
        # FIRST, there should be only one selected.
        set id [lindex [$ttab uid curselection] 0]

        # NEXT, Change its priority.
        adb order send gui BLOCK:TACTIC:MOVE -tactic_id $id -where $where
    }



    # TTabDelete
    #
    # Called when the TTab's delete button is pressed.
    # Deletes the selected tactic.

    method TTabDelete {} {
        # FIRST, delete all selected tactics.
        adb order send gui BLOCK:TACTIC:DELETE -ids [$ttab uid curselection]
    }

    #-------------------------------------------------------------------
    # Helper Methods

    # SetBlockParm name value
    #
    # name    - A block parameter name
    # value   - A new value for the parameter.
    #
    # Uses BLOCK:UPDATE to update the parameter, only if there's a
    # block, the value is not empty, and the value has really changed.
    #
    # This is intended to be used as a -changecmd for block metadata
    # fields.

    method SetBlockParm {name value} {
        # FIRST, ignore this if there's no block, or there's no change.
        if {$value       eq "" || 
            $info(block) eq "" ||
            [$info(block) get $name] eq $value 
        } {
            return
        }

        # NEXT, set the block's parameter.
        adb order send gui BLOCK:UPDATE \
            -block_id  [$info(block) id] \
            -$name     $value
    }

    

    #-------------------------------------------------------------------
    # State Controller Predicates
    #
    # These methods are used in statecontroller -conditions to control
    # the state of toolbar buttons and such-like.

    # alist single
    #
    # Returns 1 if a single item is selected in the AList, and 0 
    # otherwise.
    
    method {alist single} {} {
        expr {[llength [$alist curselection]] == 1}
    }
    

    # blist single
    #
    # Returns 1 if a single item is selected in the BList, and 0 
    # otherwise.
    
    method {blist single} {} {
        expr {[llength [$blist curselection]] == 1}
    }

    # blist multi
    #
    # Returns 1 if at least one item is selected in the BList, and 0 
    # otherwise.
    
    method {blist multi} {} {
        expr {[llength [$blist curselection]] > 0}
    }

    # gotblock
    #
    # Returns 1 if a block's data is loaded, and 0 
    # otherwise.
    
    method gotblock {} {
        expr {$info(block) ne ""}
    }

    # ctab single
    #
    # Returns 1 if a single item is selected in the CTab, and 0 
    # otherwise.
    
    method {ctab single} {} {
        expr {[llength [$ctab curselection]] == 1}
    }

    # ctab multi
    #
    # Returns 1 if at least one item is selected in the CTab, and 0 
    # otherwise.
    
    method {ctab multi} {} {
        expr {[llength [$ctab curselection]] > 0}
    }

    # ttab single
    #
    # Returns 1 if a single item is selected in the TTab, and 0 
    # otherwise.
    
    method {ttab single} {} {
        expr {[llength [$ttab curselection]] == 1}
    }

    # ttab multi
    #
    # Returns 1 if at least one item is selected in the TTab, and 0 
    # otherwise.
    
    method {ttab multi} {} {
        expr {[llength [$ttab curselection]] > 0}
    }

    # usableByAgent typename
    #
    # typename  - A tactic type name
    #
    # Returns 1 if the named tactic type can be used by the current
    # agent, and 0 otherwise.

    method usableByAgent {typename} {
        if {$info(agent) eq ""} {
            return 0
        }

        expr {$typename in [adb agent tactictypes $info(agent)]}
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull

    # reload
    #
    # Schedules a reload of the content.  Note that the reload will
    # be ignored if the window isn't mapped.
    
    method reload {} {
        $lazy update
    }
}

