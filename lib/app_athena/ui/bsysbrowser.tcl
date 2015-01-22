#-----------------------------------------------------------------------
# TITLE:
#    bsysbrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    bsysbrowser(sim) package: Belief System Browser
#    for bsys(app). 
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widget bsysbrowser {
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # Affinity Flag enum, for GUI
        enum eaffinity {
            0 No
            1 Yes
        }
    }

    #-------------------------------------------------------------------
    # Options

    # Options delegated to the hull
    delegate option * to hull


    #-------------------------------------------------------------------
    # Components

    component lazy          ;# lazyupdater(n) that reloads content
    component toolbar       ;# The main toolbar

    component slist         ;# System List
    component slist_add     ;# Add button
    component slist_edit    ;# Edit button
    component slist_common  ;# Commonality slider
    component slist_delete  ;# Delete button
     
    component alist         ;# Affinity List
    component alist_gamma   ;# Playbox gamma slider

    component tlist         ;# Topic/Belief list
    component tlist_bar     ;# TB Table toolbar
    component tlist_add     ;# Add button
    component tlist_edit    ;# Edit Topic button
    component tlist_editb   ;# Edit Belief button
    component tlist_aflag   ;# Affinity Flag pulldown
    component tlist_pos     ;# Position pulldown
    component tlist_emph    ;# Emphasis pulldown
    component tlist_delete  ;# Delete button


    #-------------------------------------------------------------------
    # Instance Variables

    # info array
    #
    #   sid   - ID of currently displayed belief system, or ""
    #   tid   - ID of currently selected topic, or ""
    
    variable info -array {
        sid         ""
        tid         ""
    }

    #--------------------------------------------------------------------
    # Constructor
    #
    # The layout of widgets looks like this:
    #
    # +--------------------------------------------------------+
    # | toolbar                                                |
    # +-vpaner 0-----------------------------------------------+
    # | +-hpaner 0--------+-hpaner 1-------------------------+ |
    # | | slist           | alist                            | |
    # | +-----------------+----------------------------------+ |
    # +-vpaner 1-----------------------------------------------+
    # | +----------------------------------------------------+ |
    # | | tlist                                              | |
    # | +----------------------------------------------------+ |
    # +--------------------------------------------------------+


    constructor {args} {
        # FIRST, create the lazy updater
        install lazy using lazyupdater ${selfns}::lazy \
            -window   $win \
            -command  [mymethod ReloadContent lazy]

        # NEXT, create the GUI containers

        # vpaner
        ttk::panedwindow $win.vpaner \
            -orient vertical

        # hpaner
        ttk::panedwindow $win.vpaner.hpaner \
            -orient horizontal

        # NEXT, create the content components.
        $self SListCreate $win.vpaner.hpaner.slist
        $self AListCreate $win.vpaner.hpaner.alist
        $self TListCreate $win.vpaner.tlist

        # NEXT, manage geometry

        $win.vpaner.hpaner add $slist -weight 1
        $win.vpaner.hpaner add $alist -weight 2

        $win.vpaner add $win.vpaner.hpaner -weight 1
        $win.vpaner add $win.vpaner.tlist  -weight 1

        pack $win.vpaner -fill both -expand yes 

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
        notifier bind ::sim <DbSyncB> $self [mymethod ReloadNow]
        notifier bind ::sim <State>   $self [mymethod ReloadNow]

        notifier bind ::bsys <playbox> $self [mymethod Mon_Playbox] 
        notifier bind ::bsys <system>  $self [mymethod Mon_System] 
        notifier bind ::bsys <topic>   $self [mymethod Mon_Topic] 
        notifier bind ::bsys <belief>  $self [mymethod Mon_Belief] 
    }

    # Mon_Playbox op id
    #
    # op   - update 
    # id   - Ignored

    method Mon_Playbox {op id} {
        $self AListReload
    }

    # Mon_System op sid
    #
    # op   - add | update | delete
    # sid  - The belief system ID.

    method Mon_System {op sid} {
        if {$op eq "add"} {
            $self SListReload -force
        } elseif {$op eq "delete"} {
            $slist uid delete $sid
        } else {
            $self SListUpdate $sid
        }

        # NEXT, if the selected system was deleted, then the other
        # components will need to be refreshed.  In this case,
        # reload everything.
        if {$info(sid) ne "" && [$self SListGet] eq ""} {
            $self reload
        } else {
            # Otherwise, at least the affinities will have changed.
            $self AListReload
        }
    }
    
    # Mon_Topic op tid
    #
    # op   - add | update | delete
    # tid  - The topic ID.

    method Mon_Topic {op tid} {
        if {$op eq "add"} {
            $self TListReload -force
        } elseif {$op eq "delete"} {
            $tlist uid delete $tid
        } else {
            $self TListUpdate $tid
        }


        # NEXT, if the selected topic was deleted, then the other
        # components will need to be refreshed.  In this case,
        # reload everything.
        if {$info(tid) ne "" && [$self TListGet] eq ""} {
            $self reload
        } else {
            # Otherwise, at least the affinities will have changed.
            $self AListReload
        }

    }

    # Mon_Belief op bid
    #
    # op   - update
    # bid  - The belief ID, {sid tid}.

    method Mon_Belief {op bid} {
        # FIRST, get the sid and tid.
        lassign $bid sid tid

        # NEXT, if it isn't the currently selected system, we're done.
        if {$sid ne $info(sid)} {
            return
        }

        # NEXT, this belief is displayed with the topic, so refresh
        # the tlist.
        $self TListUpdate $tid

        # NEXT, affinities have changed.
            $self AListReload
    }

    #-------------------------------------------------------------------
    # Reloading the Content    

    # ReloadOnEvent
    #
    # Reloads the widget when various notifier events are received.
    # The "args" parameter is so that any event can be handled.
    
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
    # Reloads the current data.  Has no effect if the window is
    # not mapped.
    
    method ReloadContent {args} {
        # FIRST, clear the sid and tid; we're starting over.
        set info(sid) ""
        set info(tid) ""

        # NEXT, Reload the SList.  This will retain the 
        # current selection, if possible.
        $self SListReload -force
        $self AListReload -force
        $self TListReload -force

        # NEXT, if the currently selected agent no longer 
        # exists, select the first actor.

        if {$info(sid) ni [bsys system ids]} {
            set info(sid) [lindex [bsys system ids] 0]

            $slist uid select $info(sid)
        }
    }

    #-------------------------------------------------------------------
    # System List

    # SListCreate pane
    #
    # pane - The name of the window
    #
    # Creates the "slist" component, which lists the belief systems.

    method SListCreate {pane} {
        # FIRST, create the list widget
        install slist using databrowser $pane     \
            -sourcecmd        [list bsys system ids]         \
            -dictcmd          [list bsys system view]        \
            -width            40                             \
            -height           15                             \
            -relief           flat                           \
            -borderwidth      1                              \
            -filterbox        off                            \
            -selectmode       browse                         \
            -selectioncmd     [mymethod SListSelect]         \
            -layout {
                {sid         "ID"            -sortmode integer}
                {name        "Belief System" -stretchable yes}
                {commonality "Commonality"   -sortmode real}
            }

        # NEXT, fill in the toolbar
        set bar [$slist toolbar]

        ttk::label $bar.title \
            -text "Systems:"

        # Add
        install slist_add using mktoolbutton $bar.slist_addbtn \
            ::marsgui::icon::plus22                            \
            "Add Belief System"                                \
            -state   normal                                    \
            -command [mymethod SListAdd]

        cond::simIsPrep control $slist_add

        # Edit
        install slist_edit using mkeditbutton $bar.edit \
            "Edit System Metadata"                      \
            -state   disabled                           \
            -command [mymethod SListEdit]

        cond::simPrepPredicate control $slist_edit  \
            browser $win                              \
            predicate {slist canedit}


        # Commonality Slider
        ttk::label $bar.clabel \
            -text "Commonality"

        install slist_common using rangefield $bar.common  \
            -state       disabled                     \
            -scalelength 100                          \
            -changemode  onrelease                    \
            -resolution  0.05                         \
            -type        ::rfraction                  \
            -changecmd   [mymethod SListCommonChanged]

        cond::simPrepPredicate control $slist_common  \
            browser $win                              \
            predicate {slist canedit}


        # Delete
        install slist_delete using mktoolbutton $bar.slist_delete \
            ::marsgui::icon::trash22                              \
            "Delete Belief System"                                \
            -state   disabled                                     \
            -command [mymethod SListDelete]

        cond::simPrepPredicate control $slist_delete             \
            browser $win                                         \
            predicate {slist canedit}

        pack $bar.title    -side left
        pack $slist_add    -side left
        pack $slist_edit   -side left
        pack $slist_delete -side right
        pack $slist_common -side right
        pack $bar.clabel   -side right
    }

    # SlistUpdate sid
    #
    # A system ID
    #
    # Updates the table row and the toolbar.

    method SListUpdate {sid} {
        $slist uid update $sid
        $self SListReloadToolbar
    }

    # SListAdd
    #
    # Call when the SList's add button is pressed.
    # Creates a new belief system.
    
    method SListAdd {} {
        set sid [flunky senddict gui BSYS:SYSTEM:ADD]

        $slist uid select $sid
        $self SListEdit
    }

    # SListEdit
    #
    # Called when the user wants to edit the system metadata.

    method SListEdit {} {
        # FIRST, there should be only one selected.
        set sid [lindex [$slist uid curselection] 0]

        # NEXT, Edit the system
        app enter BSYS:SYSTEM:UPDATE sid $sid
    }


    # SListCommonChanged newValue
    #
    # newValue  - New commonality value
    #
    # Called when the SList's commonality slider is changed.

    method SListCommonChanged {newValue} {
        if {$newValue == [bsys system cget $info(sid) -commonality]} {
            return
        }

        flunky senddict gui BSYS:SYSTEM:UPDATE   \
            [list sid $info(sid) commonality $newValue]
    }

    # SListDelete
    #
    # Called when the SList's delete button is pressed.
    # Deletes the selected system.

    method SListDelete {} {
        flunky senddict gui BSYS:SYSTEM:DELETE [list sid [$self SListGet]]
    }


    # SListSelect
    #
    # Called when a belief system is selected in the slist.  
    # Updates the rest of the browser to display that system's data.

    method SListSelect {} {
        # FIRST, update state controllers
        ::cond::simPrepPredicate update \
            [list $slist_edit $slist_common $slist_delete $tlist_editb \
                  $tlist_pos $tlist_emph]

        # NEXT, Skip it if there's no change.
        if {$info(sid) eq [$self SListGet]} {
            return
        }

        # NEXT, save the sid and reload the beliefs and affinities.
        set info(sid) [$self SListGet]

        $self SListReloadToolbar
        $self TListReloadToolbar
        $self TListReloadBeliefs
        $self AListReload
    }

    # SListGet
    #
    # Returns the ID of the selected system or "" if none.

    method SListGet {} {
        # At most one can be selected.
        return [lindex [$slist uid curselection] 0]
    }

    # SListReload ?-force?
    #
    # Reloads the system list and related controls

    method SListReload {{opt ""}} {
        $slist reload {*}$opt

        $self SListReloadToolbar
    }

    # SListReloadToolbar
    #
    # Reloads data into the controls on the toolbar.

    method SListReloadToolbar {} {
        if {$info(sid) ne ""} {
            $slist_common set [bsys system cget $info(sid) -commonality]
        }
    }



    #-------------------------------------------------------------------
    # Affinity List

    # AListCreate pane
    #
    # pane - The name of the window
    #
    # Creates the "alist" component, which displays the selected
    # system's affinities

    method AListCreate {pane} {
        # FIRST, create the list widget
        install alist using databrowser $pane     \
            -sourcecmd        [mymethod AListSource]         \
            -dictcmd          [mymethod AListView]           \
            -width            35                             \
            -height           15                             \
            -relief           flat                           \
            -borderwidth      1                              \
            -filterbox        off                            \
            -selectmode       browse                         \
            -layout {
                { b     "System B"    -width 25                }
                { aforb "Of A with B" -sortmode real -width 10 }
                { bfora "Of B with A" -sortmode real -width 10 }
            }

        # NEXT, fill in the toolbar
        set bar [$alist toolbar]

        # We have no buttons here, so make sure that this toolbar is
        # as high as the SList's toolbar.
        pack propagate $bar no
        $bar configure -height 30


        ttk::label $bar.title \
            -text   "Affinities for selected system A:"

        # Gamma
        ttk::label $bar.gammalab \
            -text "Gamma"

        install alist_gamma using rangefield $bar.gamma    \
            -state       disabled                     \
            -scalelength 100                          \
            -changemode  onrelease                    \
            -resolution  0.1                          \
            -type        ::rgamma                     \
            -changecmd   [mymethod AListGammaChanged]

        cond::availablex control $alist_gamma \
            order BSYS:PLAYBOX:UPDATE

        pack $bar.title -side left

        pack $alist_gamma    -side right
        pack $bar.gammalab   -side right
    }

    # AListSource
    #
    # databrowser(n) -sourcecmd for displaying affinities.
    # It returns the IDs of all systems other than info(sid).

    method AListSource {} {
        if {$info(sid) eq ""} {
            return [list]
        }

        set ids [bsys system ids]
        ldelete ids $info(sid)

        return $ids 
    }

    # AListView b
    #
    # b   - ID of belief system b
    #
    # databrowser(n) -dictcmd for displaying affinities.
    # Given sid B, it returns a dictionary containing 
    # sid A (the selected sid), sid B, A's affinity for B
    # and B's affinity for A.

    method AListView {b} {
        set a $info(sid)

        dict set dict a     "[bsys system cget $a -name] ($a)"
        dict set dict b     "[bsys system cget $b -name] ($b)"
        dict set dict aforb [format %.2f [bsys affinity $a $b]]
        dict set dict bfora [format %.2f [bsys affinity $b $a]]

        return $dict
    }

    # AListReload ?-force?
    #
    # Reloads the topic list and related controls

    method AListReload {{opt ""}} {
        $alist reload {*}$opt
        $alist_gamma set [bsys playbox cget -gamma]
    }

    # AListGammaChanged newGamma
    #
    # Sends the BSYS:PLAYBOX:UPDATE order.

    method AListGammaChanged {newGamma} {
        if {$newGamma != [bsys playbox cget -gamma]} {
            flunky senddict gui BSYS:PLAYBOX:UPDATE [list gamma $newGamma]
        }
    }


    #-------------------------------------------------------------------
    # Topic/Belief Tab

    # TListCreate pane
    #
    # pane - The name of the window
    #
    # Creates the "tlist" component, which displays the topics and
    # the selected belief system's affinities

    method TListCreate {pane} {
        # FIRST, create the list widget
        install tlist using databrowser $pane     \
            -sourcecmd        [list bsys topic ids]          \
            -dictcmd          [mymethod TListView]           \
            -width            40                             \
            -height           15                             \
            -relief           flat                           \
            -borderwidth      1                              \
            -filterbox        off                            \
            -selectmode       browse                         \
            -selectioncmd     [mymethod TListSelect]         \
            -titlecolumns     3                              \
            -layout {
                { tid      "ID"             -sortmode integer }
                { name     "Topic"          -stretchable yes  }
                { aflag    "Affinity?"                        }
                { textpos  "Position"       -width 24         }
                { textemph "Emphasis is On" -width 30         }
            }

        # NEXT, fill in the toolbar
        set bar [$tlist toolbar]

        ttk::label $bar.title \
            -text "Topics:"

        # Add
        install tlist_add using mktoolbutton $bar.tlist_addbtn \
            ::marsgui::icon::plus22                            \
            "Add Belief Topic"                                 \
            -state   normal                                    \
            -command [mymethod TListAdd]

        cond::simIsPrep control $tlist_add

        # Edit Topic
        install tlist_edit using mktoolbutton $bar.tlist_edit \
            ::marsgui::icon::pencilt22                        \
            "Edit Topic Metadata"                             \
            -state   disabled                                 \
            -command [mymethod TListEditTopic]

        cond::simPrepPredicate control $tlist_edit  \
            browser $win                            \
            predicate {tlist canEditTopic}

        # Edit Belief
        install tlist_editb using mktoolbutton $bar.tlist_editb \
            ::marsgui::icon::pencilb22                          \
            "Edit Belief"                                       \
            -state   disabled                                   \
            -command [mymethod TListEditBelief]

        cond::simPrepPredicate control $tlist_editb  \
            browser $win                             \
            predicate {tlist canEditBelief}

        # Affinity Flag
        ttk::label $bar.aflaglabel \
            -text "Affinity?"

        install tlist_aflag using enumfield $bar.aflag   \
            -enumtype    ::bsysbrowser::eaffinity        \
            -displaylong yes                             \
            -width       5                               \
            -changecmd   [mymethod TListAffinityChanged]

        cond::simPrepPredicate control $tlist_aflag  \
            browser $win                             \
            predicate {tlist canEditTopic}

        # Position
        ttk::label $bar.poslab \
            -text "Position"

        install tlist_pos using enumfield $bar.pos       \
            -enumtype    ::simlib::qposition             \
            -displaylong yes                             \
            -width       18                              \
            -changecmd   [mymethod TListBeliefChanged position]

        cond::simPrepPredicate control $tlist_pos  \
            browser $win                             \
            predicate {tlist canEditBelief}

        # Emphasis
        ttk::label $bar.emphlab \
            -text "Emphasis"

        install tlist_emph using enumfield $bar.emph     \
            -enumtype    ::simlib::qemphasis             \
            -displaylong yes                             \
            -width       21                              \
            -changecmd   [mymethod TListBeliefChanged emphasis]

        cond::simPrepPredicate control $tlist_emph   \
            browser $win                             \
            predicate {tlist canEditBelief}


        # Delete
        install tlist_delete using mktoolbutton $bar.tlist_delete \
            ::marsgui::icon::trash22                              \
            "Delete Belief Topic"                                 \
            -state   disabled                                     \
            -command [mymethod TListDelete]

        cond::simPrepPredicate control $tlist_delete             \
            browser $win                                         \
            predicate {tlist canEditTopic}


        pack $bar.title      -side left
        pack $tlist_add      -side left
        pack $tlist_edit     -side left
        pack $tlist_editb    -side left

        pack $tlist_delete   -side right

        pack $tlist_emph     -side right -padx {0 5}
        pack $bar.emphlab    -side right

        pack $tlist_pos      -side right -padx {0 5}
        pack $bar.poslab     -side right

        pack $tlist_aflag    -side right -padx {0 5}
        pack $bar.aflaglabel -side right
    }

    # TListView tid
    #
    # tid - A topic ID
    #
    # Retrieves data about the current topic, including the current
    # system's beliefs.

    method TListView {tid} {
        set view [bsys topic view $tid]

        if {$info(sid) ne ""} {
            set view [dict merge $view [bsys belief view $info(sid) $tid]]
        } else {
            dict set view position ""
            dict set view emphasis ""
            dict set view textpos  ""
            dict set view textemph ""
        }

        return $view
    }


    # TListReload ?-force?
    #
    # Reloads the topic list and related controls

    method TListReload {{opt ""}} {
        $tlist reload {*}$opt

        $self TListReloadToolbar
    }

    # TListReloadToolbar
    #
    # Reloads data into the controls on the toolbar.

    method TListReloadToolbar {} {
        if {$info(tid) ne ""} {
            set view [$self TListView $info(tid)]

            $tlist_aflag set [dict get $view affinity] -silent
            $tlist_pos   set [dict get $view position] -silent
            $tlist_emph  set [dict get $view emphasis] -silent
        } else {
            $tlist_aflag set "" -silent
            $tlist_pos   set "" -silent
            $tlist_emph  set "" -silent
        }
    }

    # TListReloadBeliefs
    #
    # Reloads beliefs for each displayed topic.

    method TListReloadBeliefs {} {
        foreach tid [bsys topic ids] {
            set view [$self TListView $tid]

            set r [$tlist uid2rindex $tid]

            # If the topic isn't currently displayed, ignore it.
            if {$r eq ""} {
                continue
            }

            # position
            set c [$tlist cname2cindex textpos]
            $tlist cellconfigure $r,$c -text [dict get $view textpos]
            incr c
            $tlist cellconfigure $r,$c -text [dict get $view textemph]
        }
    }

    # TListUpdate tid
    #
    # tid  - A topic ID
    #
    # The topic's data has been updated.

    method TListUpdate {tid} {
        $tlist uid update $tid
        $self TListReloadToolbar
    }

    # TListSelect
    #
    # Called when a topic is selected in the tlist.  
    # Updates the rest of the browser to display that topic's data.

    method TListSelect {} {
        # FIRST, update state controllers
        ::cond::simPrepPredicate update \
            [list $tlist_edit $tlist_editb $tlist_aflag $tlist_pos \
                  $tlist_emph $tlist_delete]

        # NEXT, Skip it if there's no change.
        if {$info(tid) eq [$self TListGet]} {
            return
        }

        # NEXT, save the tid.
        set info(tid) [$self TListGet]

        $self TListReloadToolbar
    }

    # TListAdd
    #
    # Call when the TList's add button is pressed.
    # Creates a new belief topic
    
    method TListAdd {} {
        set tid [flunky senddict gui BSYS:TOPIC:ADD]

        $tlist uid select $tid
        $self TListEditTopic
    }

    # TListEditTopic
    #
    # Called when the user wants to edit the topic metadata.

    method TListEditTopic {} {
        app enter BSYS:TOPIC:UPDATE tid [$self TListGet]
    }

    # TListEditBelief
    #
    # Called when the user wants to edit the belief data.

    method TListEditBelief {} {
        set bid [list [$self SListGet] [$self TListGet]]
        app enter BSYS:BELIEF:UPDATE bid $bid
    }

    # TListAffinityChanged newValue
    #
    # Sends the BSYS:TOPIC:UPDATE order.

    method TListAffinityChanged {newValue} {
        if {$newValue != [bsys topic cget $info(tid) -affinity]} {
            flunky senddict gui BSYS:TOPIC:UPDATE \
                [list tid $info(tid) affinity $newValue]
        }
    }

    # TListBeliefChanged parm newValue
    #
    # Sends the BSYS:BELIEF:UPDATE order.

    method TListBeliefChanged {parm newValue} {
        set bid [list $info(sid) $info(tid)]

        if {$newValue != [bsys belief cget {*}$bid -$parm]} {
            flunky senddict gui BSYS:BELIEF:UPDATE \
                [list bid $bid $parm $newValue]
        }
    }

    # TListGammaChanged newGamma
    #
    # Sends the BSYS:PLAYBOX:UPDATE order.

    method TListGammaChanged {newGamma} {
        if {$newGamma != [bsys playbox cget -gamma]} {
            flunky senddict gui BSYS:PLAYBOX:UPDATE [list gamma $newGamma]
        }
    }

    # TListDelete
    #
    # Called when the TList's delete button is pressed.
    # Deletes the selected topic.

    method TListDelete {} {
        flunky senddict gui BSYS:TOPIC:DELETE [list tid [$self TListGet]]
    }


    # TListGet
    #
    # Returns the ID of the selected topic or "" if none.

    method TListGet {} {
        # At most one can be selected.
        return [lindex [$tlist uid curselection] 0]
    }


    #-------------------------------------------------------------------
    # Predicates for state control

    # slist canedit
    #
    # Returns 1 if a single editable belief system is selected in the
    # SList.  Belief System 1 (the "Neutral" system) cannot be edited.

    method {slist canedit} {} {
        set ids [$slist uid curselection]

        expr {[llength $ids] == 1 && [lindex $ids 0] != 1}

    }
    
    # tlist canEditTopic
    #
    # Returns 1 if a single topic is selected in the
    # TList.

    method {tlist canEditTopic} {} {
        set ids [$tlist uid curselection]

        expr {[llength $ids] == 1}

    }

    # tlist canEditBelief
    #
    # Returns 1 if both the topic and the system can
    # be edited.

    method {tlist canEditBelief} {} {
        expr {[$self slist canedit] && [$self tlist canEditTopic]}
    }


    #-------------------------------------------------------------------
    # Public Methods

    
    # reload
    #
    # Schedules a reload of the content.  Note that the reload will
    # be ignored if the window isn't mapped.
    
    method reload {} {
        $lazy update
    }
}



