#-----------------------------------------------------------------------
# TITLE:
#    sorter.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectgui(n), sorter(n): A widget for sorting items into bins.
#    The widget implements most of the "field(i)" interface.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported Commands

namespace eval ::projectgui:: {
    namespace export \
        sorter 
}

#-----------------------------------------------------------------------
# sorter widget


snit::widget ::projectgui::sorter {
    #-------------------------------------------------------------------
    # Components

    component toolbar    ;# Toolbar for the widget
    component binset     ;# Frame containing the set of bins
    component itemlist   ;# Data browser of items to be sorted
    component detail     ;# htmlviewer to display details.
    component resetbtn   ;# Reset Button
    component ignorebtn  ;# Ignore Remaining Items button
    component binmenu    ;# Bin widget context menu
    component listmenu   ;# Itemlist context menu

    
    #-------------------------------------------------------------------
    # Options

    # -bincols num
    #
    # Bins can be displayed in 1 or more columns.        
    option -bincols \
        -default 2

    # -binspec dict
    #
    # A dictionary of bin IDs and labels.  There are two predefined
    # bins, "unsorted" and "ignored", which are handled specially.

    option -binspec \
        -readonly yes

    # -changecmd cmd
    #
    # Calls $cmd when the value of the widget (i.e., the sorting) changes,
    # whether it is programmatic or through user action.

    option -changecmd

    # -detailcmd cmd
    #
    # Calls $cmd with one additional argument, the ID of an item.
    # The command should return the HTML text to display in the
    # detail pane.

    option -detailcmd

    # -helptext html
    #
    # Help information to be displayed in the detail pane when
    # no report is selected.

    option -helptext

    # -itemcmd cmd
    #
    # Command called to retrieve an item's data dictionary given 
    # its ID.

    option -itemcmd

    # -itemlabel text
    #
    # A label for the count in each bin.  Defaults to "Items".

    option -itemlabel \
        -readonly yes     \
        -default  "Items" 

    # -itemlayout spec
    #
    # databrowser(n) layout spec for the itemlist.

    option -itemlayout \
        -readonly yes


    #-------------------------------------------------------------------
    # Variables

    # Array of bin IDs by bin widget, and vice versa
    variable win2bin -array {}
    variable bin2win -array {}

    # Array of bin contents by bin ID
    variable bins -array {}

    # info array
    #
    # bin       - The currently selected bin.
    # binTitle  - The title of the currently selected bin.
    # binIds    - The canonical list of bin IDs.
    # sortset   - The set of IDs to be sorted; the initial content of
    #             the unsorted bin.
    #
    # title-$bin   - The bin's title
    # size-$bin    - The number of items in the bin

    variable info -array {
        bin       unsorted
        binTitle  "Unsorted"
        binIds    {}
        sortset   {}

        title-unsorted "Unsorted"
        size-unsorted  0

        title-ignored  "Ignored"
        size-ignored   0
    }

    #-------------------------------------------------------------------
    # Constructor
    #
    #   +------------------------------+
    #   | toolbar                      |
    #   +------------------------------+
    #   | separator1                   |
    #   +-------+-----------+----------+
    #   | bins  | itemlist  | detail   |
    #   +-------+-----------+----------+

    constructor {args} {
        # FIRST, get the options.
        $self configurelist $args

        # NEXT, initialize the data structures
        $self InitializeDataStructures

        # NEXT, create the major components
        $self MakeToolbar    $win.toolbar   ;# toolbar
        ttk::separator       $win.sep1
        $self MakeBinSet     $win.binset    ;# binset
        $self MakeItemList   $win.itemlist  ;# itemlist
        $self MakeDetailPane $win.detail    ;# detail

        # NEXT, grid the major components.
        grid $toolbar      -row 0 -column 0 -columnspan 3 -sticky ew
        grid $win.sep1     -row 1 -column 0 -columnspan 3 -sticky ew
        grid $binset       -row 2 -column 0 -sticky ns
        grid $itemlist     -row 2 -column 1 -sticky ns
        grid $win.detail   -row 2 -column 2 -sticky nsew

        grid rowconfigure    $win 2 -weight 1
        grid columnconfigure $win 2 -weight 1

        # NEXT, create the pop up menus
        $self MakeListMenu $itemlist.menu   ;# listmenu
        $self MakeBinMenu  $binset.menu     ;# binmenu

        # NEXT, put in initial detail.
        $detail set $options(-helptext)

        $self SelectBin unsorted
    }

    # MakeToolbar w
    #
    # Creates the toolbar component with the given widget name.

    method MakeToolbar {w} {
        # FIRST, create the Widget
        install toolbar using ttk::frame $w

        # NEXT, fill in the toolbar
        ttk::label $toolbar.lab \
            -text "Unsorted $options(-itemlabel):"

        ttk::label $toolbar.count \
            -textvariable [myvar info(size-unsorted)]

        install resetbtn using mktoolbutton $toolbar.reset \
            ::projectgui::icon::reset22                    \
            "Return all items to the unsorted list."       \
            -command [mymethod OnReset]

        install ignorebtn using mkdeletebutton $toolbar.ignore \
            "Ignore all remaining unsorted items."             \
            -command [mymethod OnIgnoreRemaining]

        pack $toolbar.lab   -side left
        pack $toolbar.count -side left

        pack $ignorebtn     -side right
        pack $resetbtn      -side right
    }

    # MakeBinSet w
    #
    # Creates the set of sorterbin widgets.

    method MakeBinSet {w} {
        # FIRST, create the binset frame.
        install binset using ttk::frame $w

        # NEXT, we may have multiple columns; we want all columns
        # to have the same width.
        for {set i 0} {$i < $options(-bincols)} {incr i} {
            grid columnconfigure $binset $i -weight 1 -uniform 1
        }

        # NEXT, create the "Unsorted" bin.
        set bw [$self MakeBin unsorted \
                -normalbackground #FF8585 \
                -emptybackground  #9FC4A4]

        grid $bw -row 0 -column 0 -columnspan $options(-bincols) \
            -sticky nsew -padx 1 -pady 1

        # NEXT, create the caller's bins.
        set r 0
        set c -1

        foreach bin [dict keys $options(-binspec)] {
            # FIRST, create the bin widget
            set bw [$self MakeBin $bin]

            # NEXT, grid it widget
            let c {($c + 1) % $options(-bincols)}

            if {$c == 0} {
                incr r
            }

            grid $bw -row $r -column $c -sticky nsew -padx 1 -pady 1
        }

        # NEXT, create the ignored bin widget
        set bw [$self MakeBin ignored \
                -normalbackground #80C489 \
                -emptybackground  #9FC4A4]

        incr r
        grid $bw -row $r -column 0 -columnspan $options(-bincols) \
            -sticky nsew -padx 1 -pady 1
    }

    # MakeBin bin ?options...?
    #
    # bin     - The bin ID
    # options - Options to pass along to the sorterbin widget
    #
    # Creates a bin and registers it as a drop site.

    method MakeBin {bin args} {
        # FIRST, get the widget name
        set w $binset.[string tolower $bin]

        # NEXT, create the widget
        sorterbin $w \
            -bin        $bin                      \
            -title      $info(title-$bin)         \
            -variable   [myvar info(bin)]         \
            -countlabel $options(-itemlabel)      \
            -command    [mymethod SelectBin $bin] \
            {*}$args


        # NEXT, prepare for lookups from bin to win and back again.
        set win2bin($w)   $bin
        set bin2win($bin) $w

        # NEXT, register it as a drop site.
        DropSite::register $w \
            -dropcmd     [mymethod ItemDrop $bin] \
            -dropovercmd [mymethod ItemDropOver $bin] \
            -droptypes {ITEMS {{default move} none copy shift}}

        # NEXT, bind a context menu to it.
        # TBD: Should get event from platform object.
        if {[tk windowingsystem] eq "aqua"} {
            # Right-click on OS X is button 2 (what's up with that?)
            set bevent <ButtonPress-2>
        } else {
            # This is right for Windows
            set bevent <ButtonPress-3>
        }

        bind $w $bevent [mymethod OnPopupBinMenu $bin %X %Y]

        return $w
    }


    # MakeItemList w
    #
    # Creates the itemlist widget, a databrowser displaying a list
    # of items.

    method MakeItemList {w} {
        # FIRST, create the itemlist widget
        install itemlist using databrowser $w                  \
            -selectmode         extended                       \
            -height             15                             \
            -width              60                             \
            -autoscan           0                              \
            -filterbox          no                             \
            -sourcecmd          [mymethod ItemListSourceCmd]   \
            -dictcmd            $options(-itemcmd)             \
            -layout             $options(-itemlayout)

        # NEXT, Prepare to drag from the itemlist.
        DragSite::register [$itemlist tlistbody]  \
            -dragevent    1                       \
            -draginitcmd  [mymethod ItemDragInit] \
            -dragendcmd   [mymethod ItemDragEnd]

        # NEXT, display the currently selected bin's title on the 
        # toolbar.
        set bar [$itemlist toolbar]
        ttk::label $bar.lab1 \
            -text "$options(-itemlabel) in bin:"

        ttk::label $bar.bintitle \
            -textvariable [myvar info(bintitle)] 

        pack $bar.lab1     -side left
        pack $bar.bintitle -side left

        # NEXT, prepare to display report detail in the detail pane.
        bind [$itemlist tlist] <<TablelistSelect>> [mymethod ItemListSelectCmd]
    }

    # MakeDetailPane w
    #
    # The name of the frame window.

    method MakeDetailPane {w} {
        frame $w

        install detail using htmlviewer $w.hv \
            -height         300                   \
            -width          300                   \
            -xscrollcommand [list $w.xscroll set] \
            -yscrollcommand [list $w.yscroll set]

        ttk::scrollbar $w.xscroll \
            -orient horizontal \
            -command [list $detail xview]

        ttk::scrollbar $w.yscroll \
            -orient vertical \
            -command [list $detail yview]

        grid $w.hv      -row 0 -column 0 -sticky nsew
        grid $w.yscroll -row 0 -column 1 -sticky ns
        grid $w.xscroll -row 1 -column 0 -sticky ew

        grid rowconfigure    $w 0 -weight 1
        grid columnconfigure $w 0 -weight 1
    }

    # MakeListMenu w
    #
    # w   - The menu widget name
    #
    # Creates the itemlist popup menu.

    method MakeListMenu {w} {
        # FIRST, create the menu
        install listmenu using menu $w

        # NEXT, prepare to pop up the menu, as described in the 
        # Tablelist Programmer's Guide
        set bodytag [$itemlist.tlist bodytag]

        if {[tk windowingsystem] eq "aqua"} {
            # Right-click on OS X is button 2 (what's up with that?)
            set bevent <ButtonPress-2>
        } else {
            # This is right for Tablelist
            set bevent <<Button3>>
        }

        bind $bodytag $bevent [bind TablelistBody <Button-1>]
        bind $bodytag $bevent +[bind TablelistBody <ButtonRelease-1>]
        bind $bodytag $bevent +[mymethod OnPopupListMenu %X %Y]
    }

    # MakeBinMenu w
    #
    # w   - The menu widget name
    #
    # Creates the bin popup menu.  Note that it will be populated
    # with items when it is popped up.

    method MakeBinMenu {w} {
        install binmenu using menu $w
    }

    #-------------------------------------------------------------------
    # Data Structures
    
    # InitializeDataStructures
    #
    # Sets up the bin data structures and so forth, given the
    # options.

    method InitializeDataStructures {} {
        # FIRST, prepare the bin datastructures
        set bins(unsorted) [list]
        set info(binIds)   [list unsorted]

        dict for {bin title} $options(-binspec) {
            set bins($bin) [list]
            lappend info(binIds) $bin
            set info(title-$bin) $title
            set info(size-$bin)  0
        }

        set bins(ignored) [list]
        lappend info(binIds) ignored

    }

    # ShiftState source target
    #
    # Returns "normal" if we can move items from the source
    # bin to the target bin, and disabled otherwise. 
    # We can do this is if the source is not empty, and is not
    # the target.

    method ShiftState {source target} {
        if {$source eq $target || $info(size-$source) == 0} {
            return "disabled"
        } else {
            return "normal"
        }
    }

    # ShiftItems op source target idlist
    #
    # op     - move | copy
    # source - The bin containing the items
    # target - The bin to receive the items
    # idlist - The IDs of the items to shift.
    #
    # Moves/copies items from the source bin to the target bin.
    # Updates all bin statistics and GUI counters.  If no idlist
    # is given, shifts all items in the source bin.

    method ShiftItems {op source target idlist} {
        # FIRST, put the items in the target bin, if they aren't
        # already there.
        foreach id $idlist {
            ladd bins($target) $id
        }

        # NEXT, if this is a move, remove the items from the
        # source bin.
        if {$op eq "move" && $source ne $target} {
            foreach id $idlist {
                $itemlist uid delete $id
                ldelete bins($source) $id
            }
        }

        # NEXT, update the bin counts and the detail pane.
        $self UpdateBinCounts
        $detail set $options(-helptext)
        callwith $options(-changecmd) [$self get]

        return
    }

    # SelectedToBin op bin
    #
    # op     - move | copy
    # bin    - The bin to receive the items
    #
    # Moves/copies the selected items from the current bin to the named
    # bin.

    method SelectedToBin {op bin} {
        # FIRST, get the items to shift
        set idlist [$itemlist uid curselection]

        puts "$op <$idlist> to $bin"

        $self ShiftItems $op $info(bin) $bin $idlist

        return
    }

    # AllToBin op source target
    #
    # op      - move | copy
    # source  - The bin containing the items
    # target  - The bin to receive the items
    #
    # Moves/copies all items in the source bin to the target bin.

    method AllToBin {op source target} {
        $self ShiftItems $op $source $target $bins($source)
        $itemlist reload
    }

    # UpdateBinCounts
    #
    # Updates all bin counters.

    method UpdateBinCounts {} {
        foreach bin $info(binIds) {
            set info(size-$bin) [llength $bins($bin)] 
            $bin2win($bin) configure \
                -count $info(size-$bin)
        }
    }

    #-------------------------------------------------------------------
    # Private Handlers

    # ItemListSelectCmd
    #
    # Called when an item is selected in the ITEM list.  Calls
    # the -detailcmd to get the detailed HTML to display.

    method ItemListSelectCmd {} {
        set id [lindex [$itemlist uid curselection] 0]

        if {$id eq ""} {
            $detail set $options(-helptext)
        } else {
            $detail set [callwith $options(-detailcmd) $id]
        }
    }

    # SelectBin bin
    #
    # This is called when the user left-clicks on a bin.

    method SelectBin {bin} {
        set info(bin) $bin
        set info(bintitle) $info(title-$bin)
        $itemlist reload
        $detail set $options(-helptext)
    }

    # OnReset
    #
    # The Reset button was pressed; return all items to the unsorted
    # bin.

    method OnReset {} {
        $self sortset $info(sortset)
    }

    # OnIgnoreRemaining
    #
    # The Ignore button was pressed; all unsorted items should be
    # ignored.

    method OnIgnoreRemaining {} {
        $self AllToBin move unsorted ignored
    }

    # OnPopupListMenu rx ry
    #
    # rx,ry   - Root window coordinate of right-click
    #
    # Pops up the context menu for the itemlist.

    method OnPopupListMenu {rx ry} {
        # FIRST, delete the existing content of the menu; we'll rebuild it.
        $listmenu delete 0 end
        
        # NEXT, add a label, explaining what choosing an item
        # does:
        $listmenu add command \
            -label "Move selected item to:"
        $listmenu add separator

        # NEXT, add an item for each bin.
        foreach bin $info(binIds) {
            $listmenu add command \
                -label "$info(title-$bin)" \
                -state   [$self ShiftState $info(bin) $bin]         \
                -command [mymethod SelectedToBin move $bin]
        }


        tk_popup $listmenu $rx $ry 2
    }

    # OnPopupBinMenu bin rx ry
    #
    # bin     - The bin on which the user right-clicked.
    # rx,ry   - Root window coordinate of right-click
    #
    # Pops up the context menu for the bin

    method OnPopupBinMenu {bin rx ry} {
        $binmenu delete 0 end

        $binmenu add command \
            -label "Move all items to:"
        $binmenu add separator

        $binmenu add command                                    \
            -label   $info(title-$info(bin))                    \
            -state   [$self ShiftState $bin $info(bin)]         \
            -command [mymethod AlltoBin move $bin $info(bin)]

        $binmenu add separator

        # NEXT, add an item for each bin.
        foreach b $info(binIds) {
            $binmenu add command                              \
                -label   "$info(title-$b)"                    \
                -state   [$self ShiftState $bin $b]           \
                -command [mymethod AllToBin move $bin $b]
        }

        tk_popup $binmenu $rx $ry 2
    }



    # ItemListSourceCmd
    #
    # Retrieves the item IDs for the itemlist, based on the selected
    # bin.

    method ItemListSourceCmd {} {
        return $bins($info(bin))
    }

    #-------------------------------------------------------------------
    # Drag and Drop Handlers
    #
    # The sequence of execution is like this:
    #
    # 1. The user begins to drag from the item list.
    #
    # 2. ItemDragInit is called, and prepares the selected ITEMS for
    #    dropping.  If there are no selected items, there will be no 
    #    drop.
    #
    # 3. The drag ends, dropping the data on the widget under the 
    #    mouse pointer.
    #
    # 4. If there is no drop site for ITEMS under the
    #    mouse pointer, the drop fails.
    #
    # 5. Otherwise, ItemDrop is called, and determines whether the 
    #    items can be dropped.  If yes, it returns 1, if no it returns 0.
    #    The operation is determined by the modifier keys at the start
    #    of the drag.
    #
    # 6. ItemDragEnd is called with all data needed to completed the
    #    transaction.  The "result" parameter indicates the success
    #    or failure of the interaction.
    #
    # 7. On success, ItemDragEnd actually moves or copies the items to the 
    #    bin. 

    # ItemDragInit source rx ry top
    #
    # source   - Always the itemlist
    # rx,ry    - Root coordinates of the start of the drag
    # top      - A toplevel window, if we want to put some stuff in 
    #            it.
    #
    # Called when the user begins to drag from the itemlist.  Returns
    # nothing if there's no selection in the itemlist; otherwise, 
    # returns a value indicating that the selected items can be
    # moved or copied.

    method ItemDragInit {source rx ry top} {
        set data [$itemlist uid curselection]

        if {[llength $data] == 0} {
            return
        }

        return [list ITEMS {move copy} $data]
    }

    # ItemDrop bin target source rx ry op dtype data
    #
    # bin    - The bin ID receiving the drop.
    # target - The bin widget receiving the drop
    # source - Always the itemlist
    # rx,ry  - Root coordinates of the pointer
    # op     - default | copy.  In this case, "default" == "move".
    # dtype  - Always ITEMS
    # data   - The list of items to drop.
    #
    # This command is called when a dropsite (i.e., a bin widget)
    # receives a drag-and-drop.  Its job is to determined whether 
    # the dropsite can actually receive the data in question.  If
    # so, it returns 1; if not, it returns 0.

    method ItemDrop {bin target source rx ry op dtype data} {
        # FIRST, you can't drag to the current bin.
        if {$bin eq $info(bin)} {
            return 0
        }

        # OTHERWISE, presume that it's OK
        return 1
    }

    # ItemDropOver bin target source event rx ry op dtype data
    #
    # bin    - The bin ID receiving the drop.
    # target - The bin widget receiving the drop
    # source - Always the itemlist
    # event  - enter, motion, leave
    # rx,ry  - Root coordinates of the pointer
    # op     - default | copy.  In this case, "default" == "move".
    # dtype  - Always ITEMS
    # data   - The list of items to drop.
    
    method ItemDropOver {bin target source event rx ry op dtype data} {
        # FIRST, you can't drag to the current bin.
        if {$bin eq $info(bin)} {
            return 2
        }

        # NEXT, highlight the bin.
        if {$event eq "enter"} {
            $target configure -hover yes
        } elseif {$event eq "leave"} {
            $target configure -hover no
        }

        # FINALLY, presume that it's OK
        return 3
    }
    
    # ItemDragEnd source target op dtype data result
    #
    # source   - The itemlist's body
    # target   - A sorterbin widget
    # op       - move | copy
    # dtype    - The datatype; always ITEMS.
    # data     - A list of item IDs
    # result   - 1 on success, 0 otherwise
    #
    # Called when drag-and-drop is complete.  If result is 0, then 
    # the drop was unsuccessful.

    method ItemDragEnd {source target op dtype data result} {
        # FIRST, ignore incomplete drags.
        if {$result == 0} {
            return
        }

        # NEXT, get the target bin
        $target configure -hover no
        set target $win2bin($target)

        $self ShiftItems $op $info(bin) $target $data
    }

    #-------------------------------------------------------------------
    # Public Methods

    # clear
    #
    # Clears all bins, and calls the -changecmd.

    method clear {} {
        $self ClearAll
        callwith $options(-changecmd) [$self get]
    }

    # ClearAll
    #
    # Clears all bins.

    method ClearAll {} {
        foreach bin [array names bins] {
            set bins($bin) [list]
        }
    }

    # set bindict
    #
    # bindict - A dictionary of lists of IDs by bin
    #
    # Clears and sets the value of the widget, i.e., the bin contents.
    
    method set {bindict} {
        $self ClearAll

        foreach bin [array names bins] {
            if {[dict exists $bindict $bin]} {
                set bins($bin) [dict get $bindict $bin]
            }
        }

        $self UpdateBinCount

        callwith $options(-changecmd) [$self get]
        return
    }

    # get ?bin?
    #
    # bin     - A bin ID
    #
    # Retrieves the bin/id list directory, or the IDs in one bin.
    
    method get {{bin ""}} {
        if {$bin eq ""} {
            return [array get bins]
        } else {
            return $bins($bin)
        }
    }

    # sortset ids
    #
    # ids    - A list of IDs to sort into bins
    #
    # Specifies the set of IDs to sort.

    method sortset {ids} {
        set info(sortset) $ids
        $self ClearAll
        set bins(unsorted) $ids

        $self UpdateBinCounts
        $itemlist reload
        $detail set $options(-helptext)

        callwith $options(-changecmd) [$self get]
    }

}