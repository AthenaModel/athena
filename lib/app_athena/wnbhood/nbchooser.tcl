#-----------------------------------------------------------------------
# TITLE:
#    nbchooser.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    nbchooser(n): A widget for selecting neighborhoods
# from a hierarchical tree.
#
# This widget has two main areas: a tablelist(n) for displaying the 
# hierarchy of neighborhoods and a mapcanvas(n) for displaying the
# neighborhood boundaries.  As the user clicks to choose which 
# polygons should be included as part of a scenario the polygon display
# changes accordingly indicating the currently selected set of polygons
# and greying out the set of deselected polygons.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported Commands

namespace eval ::wnbhood:: {
    namespace export nbchooser
}

#-----------------------------------------------------------------------
# nbchooser widget

snit::widget ::wnbhood::nbchooser {
    #-------------------------------------------------------------------
    # Components

    component paner   ;# Paned window containing mapcanvas and tablelist
    component nblist  ;# tablelist of neighborhoods
    component map     ;# mapcanvas(n) to display neighborhood polygons
    component geo     ;# geoset(n) that contains the polygons
    component popup   ;# popup menu for selecting/deselecting all children

    #-------------------------------------------------------------------
    # Options

    # -projection proj
    #
    # The map projection to use when displaying nbhood polygons

    option -projection

    # -map map
    #
    # A map image to display behind any neighborhoods

    option -map

    #-------------------------------------------------------------------
    # Variables
    
    # info array
    #
    # active    - the current selection in nblist
    # maxdepth  - maximum depth of the tree structure
    #
    # neighborhood relationships
    #
    # key-$n      - the tablelist key for neighborhood n
    # nb-$key     - the neighborhood name for the tablelist key
    # pkey-$n     - the tablelist parent key for neighborhood n
    # children-$n - list of the children of neighborhood n and of "root"
    # parent-$n   - the name of the neighborhoods parent or "root"
    # depth-$key  - depth in the hierarchy of neighborhood with 
    #               tablelist key
    #
    # neighborhood display
    #
    # refpt-$n    - computed reference point for neighborhood n
    # color-$n    - the display color of neighborhood n
    # selected-$n - flag indicating whether n is selected for output
    # btnidx-$key - the index of the checkbutton in nblist expressed as
    #               "$row,$col" for the tablelist key

    variable info -array {
        active  0
        maxdepth 0
    }
    
    # Transient array to keep track of a right clicked parent nbhood
    variable trans -array {
        active_parent ""
        leaf_descendants ""
    }

    variable gradients -array {
        0 "#004C1A #009933 #80CC99"
        1 "#003D99 #0066FF #80B2FF"
        2 "#990099 #FF00FF #FF66FF"
        3 "#663300 #CC6600 #EBC299"
        4 "#990000 #FF0000 #FF8080"
        5 "#997A00 #FFCC00 #FFE680"
        6 "#3D0099 #6600FF #B280FF"
        7 "#003D3D #006666 #80B2B2"
    }

    variable colors -array {}
    variable pbbox

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, get the options
        $self configurelist $args

        assert {$options(-projection) ne ""}

        # NEXT, configure colors for polygons
        foreach {id levels} [array get gradients]  {
            set colors($id) \
                [::marsutil::gradient %AUTO% \
                    -mincolor [lindex $levels 0] -minlevel 0 \
                    -midcolor [lindex $levels 1] -midlevel 3 \
                    -maxcolor [lindex $levels 2] -maxlevel 7]
        }

        # NEXT, create geoset(n) to hold polygons
        set geo [::marsutil::geoset %AUTO%]

        # NEXT, create content
        ttk::panedwindow $win.paner -orient horizontal
        ttk::frame $win.paner.f
        ttk::frame $win.paner.m

        $self MakeNbhoodList $win.paner.f
        $self MakeMapCanvas  $win.paner.m

        ttk::label $win.loc -textvariable [myvar info(locvar)] \
            -justify right -anchor e -width 60

        # NEXT, configure and layout content in the window
        grid columnconfigure $win.paner.f 0 -weight 1
        grid rowconfigure    $win.paner.f 0 -weight 1

        $win.paner add $win.paner.f
        $win.paner add $win.paner.m

        grid columnconfigure $win 0 -weight 1
        grid rowconfigure    $win 1 -weight 1

        grid $win.loc   -row 0 -column 1 -sticky w
        grid $win.paner -row 1 -column 0 -columnspan 2 -sticky nsew

        # NEXT, mouse behavior
        bind [$nblist bodytag] <Button-1> [mymethod ActivateNbhood %W %x %y]
        bind [$nblist bodytag] <Button-3> [mymethod ParentPopup %W %x %y %X %Y]
        bind $map <<Nbhood-1>> [mymethod NbhoodClicked %d]
        bind $map <<Nbhood-3>> [mymethod ToggleNbhood %d]

        # NEXT, create the popup menu for selecting/deselecting children
        # of a neighborhood
        set popup [menu .p_%AUTO%]
        $popup add command \
            -label "Select All Children" \
            -command [mymethod ChildrenState 1]

        $popup add command \
            -label "Deselect All Children" \
            -command [mymethod ChildrenState 0]

        adb eval {
            SELECT ulat,ulon,llat,llon FROM maps WHERE id=1
        } {
            set pbbox [list $llat $ulon $ulat $llon]
        }
    }

    destructor {
        destroy $popup
    }

    # MakeMapCanvas w
    #
    # w  - a pathname to the window that contains the mapcanvas(n)
    #
    # This method creates a mapcanvas(n) with vertical and horizontal
    # scroll bars.

    method MakeMapCanvas {w} {
        install map using mapcanvas $w.map        \
            -locvariable    [myvar info(locvar)]  \
            -background     white                 \
            -yscrollcommand [list $w.yscroll set] \
            -xscrollcommand [list $w.xscroll set] 

        # Configure projection and, optionally, map image
        $map configure -projection $options(-projection)

        if {$options(-map) ne ""} {
            $map configure -map $options(-map)
        }
        
        ttk::scrollbar $w.yscroll \
            -orient  vertical     \
            -command [list $w.map yview]

        ttk::scrollbar $w.xscroll \
            -orient  horizontal   \
            -command [list $w.map xview]

        grid columnconfigure $w 0 -weight 1 
        grid rowconfigure    $w 0 -weight 1

        grid $w.map     -row 0 -column 0 -sticky nsew
        grid $w.yscroll -row 0 -column 1 -sticky ns   -pady {1 0}
        grid $w.xscroll -row 1 -column 0 -sticky ew   -padx {1 0}

        $map refresh
    }

    # MakeNbhoodList w
    #
    # w   - a window containing the tablelist 
    #
    # This method creates and embeds the tablelist in the supplied
    # window.

    method MakeNbhoodList {w} {
        install nblist using tablelist::tablelist $w.browser   \
            -columns          {20 Nbhoods left 10 Use? center} \
            -width            35                               \
            -background       white                            \
            -foreground       black                            \
            -selectmode       browse                           \
            -selecttype       row                              \
            -selectbackground white                            \
            -selectforeground black                            \
            -yscrollcommand   [list $w.yscroll set]            \
            -treecolumn       0

        ttk::scrollbar $w.yscroll \
            -orient  vertical     \
            -command [list $w.browser yview]

        $w.browser columnconfigure 0             -stretchable yes
        $w.browser columnconfigure 1 -editable 0 -stretchable no

        grid $w.browser -row 0 -column 0 -sticky nsew
        grid $w.yscroll -row 0 -column 1 -sticky ns   -pady {1 0}

    }

    # InsertToggle w row col btn
    #
    # w    - The tablelist widget
    # row  - a row in the tablelist
    # col  - a column in the tablelist
    # btn  - a path for a new checkbutton widget
    #
    # This method adds a checkbutton widget to the tablelist at
    # the row,col position provided.  The info array is updated
    # so that we have the button index by key for manipulation of
    # that cell in the tablelist widget.

    method InsertToggle {w row col btn} {
        # FIRST get the key
        set key [$w getfullkeys $row]

        # NEXT, create the checkbutton linked to a variable
        # in the info array and store it's index
        checkbutton $btn                            \
            -variable   [myvar info(selected-$key)] \
            -background white                       \
            -command    [mymethod ToggleKey $key]        

        # NEXT, if the neighborhood is already in the RDB
        # then show it disabled
        if {$info(inrdb-$info(nb-$key))} {
            $btn configure -state disabled -background #CCCCCC
        }

        # NEXT, references to the cell that contains the button
        set info(btnidx-$key) "$row,$col"
    }

    #--------------------------------------------------------------------
    # Event Handlers
    #

    # ParentPopup w x y X Y
    #
    # w   - the tablelist widget
    # x   - the window x coord
    # y   - the window y coord
    # X   - the absolute X coord
    # Y   - the absolute Y coord
    #
    # This handler pops up a menu that allows the user to activate or
    # deactivate all the children neighborhoods of a parent

    method ParentPopup {w x y X Y} {
        # FIRST, translate mouse location to tablelist entry
        foreach {tbl x y} [tablelist::convEventFields $w $x $y] {}
        set key [$tbl getfullkeys [$tbl containing $y]]

        # NEXT, make sure that the location is on a neighborhood and that
        # the neighborhood has children
        if {[info exists info(nb-$key)]} {
            if {[llength $info(children-$info(nb-$key))]} {
                set trans(active_parent) $info(nb-$key)
                # Popup on absolute coords
                tk_popup $popup $X $Y
            }
        } 
    }

    # ChildrenState  state
    #
    # state   - display state of the child neighborhoods of a parent
    #
    # This method selects/deselects all the child neighborhoods of a parent
    # for inclusion or exclusion in a scenario.

    method ChildrenState {state} {
        # FIRST, go through all the children of the parent setting their
        # selected state
        foreach n $info(children-$trans(active_parent)) {

            # If the children of this neighborhood are already all 
            # selected, then do not show it as selected
            if {$state && [$self AllChildrenSelected $n]} {
                continue
            }

            if {$info(inrdb-$n)} {
                continue
            }

            set info(selected-$info(key-$n)) $state
        }

        # NEXT, using the parents key, collapse or expand the tree
        set key $info(key-$trans(active_parent))
        set btn [$nblist windowpath $info(btnidx-$key)]
        
        if {$state} {
            $nblist expand $key -partly

            # NEXT, if all children are selected, deselect parent, but
            # only if it isn't already in the RDB
            if {!$info(inrdb-$info(nb-$key))} {
                $btn configure -state disabled
                let info(selected-$key) 0
            }
        } else {
            $nblist collapse $key -partly

            if {!$info(inrdb-$info(nb-$key))} {
                $btn configure -state normal
            }
        }

        # NEXT, redraw the map
        $self UpdateMap 
    }

    # ActivateNbhood  w x y
    #
    # w   - a window
    # x,y - mouse click location
    #
    # This method converts the event arguments to a key in the tablelist's
    # list of neighborhoods. A flag is set for that neighborhood to indicate
    # that it is the active one and the map updated.

    method ActivateNbhood {w x y} {
        foreach {tbl x y} [tablelist::convEventFields $w $x $y] {}
    
        set key [$tbl getfullkeys [$tbl containing $y]]
        if {[info exists info(id-$key)]} {
            set info(active) $info(id-$key)
        } 
    
        $self UpdateMap
    }

    # NbhoodClicked id 
    #
    # id    - The mapcanvas(n) ID of a neighborhood polygon
    #
    # This callback happens when the user clicks in a neighborhood polygon
    # so the row containing that neighborhood in the tablelist can be 
    # activated and seen.

    method NbhoodClicked {id} {
        $nblist activate $info(key-$id)
        $nblist see $info(key-$id)
        set info(active) $id
        $self UpdateMap
    }

    # ToggleKey  key
    #
    # key  - the row key for a checkbutton in the tablelist
    #
    # For the neighborhood toggled with the given key, this method 
    # checks if it's parent now has all it's children selected. If so,
    # the parent is deselected, under the assumption that when all
    # children are selected, the parent is completely covered with polygons
    # and cannot, therefore, be selected for output.

    method ToggleKey {key} {
        # FIRST, get parent
        set nbhood $info(nb-$key)
        set parent $info(parent-$nbhood)

        # NEXT, if the parent is not root and all children are now
        # selected, deselect the parent
        if {$parent ne "root"} {
            set pkey $info(key-$parent)
            set btn [$nblist windowpath $info(btnidx-$pkey)]
            if {[$self AllChildrenSelected $parent]} {
                set info(selected-$pkey) 0
                $btn configure -state disabled
            } else {
                $btn configure -state normal
            }
        } 

        $self UpdateMap
    }

    # ToggleNbhood id
    #
    # id   - The mapcanvas(n) ID of a neighborhood polygon
    #
    # This callback toggles the selected state of a neighborhood
    # and redraws the map.

    method ToggleNbhood {id} {
        set key    $info(key-$id)
        set nb     $info(nb-$key)
        set parent $info(parent-$nb)

        # FIRST, cannot toggle neighborhoods that have all
        # children selected
        if {[$self AllChildrenSelected $nb]} {
            return
        }

        # NEXT, if the neighborhood is already in the scenario
        # then its a no-op
        if {$info(inrdb-$nb)} {
            return
        }

        # NEXT, toggle the selection and update
        set info(selected-$key) [expr {!$info(selected-$key)}]

        # NEXT, selection (or deselection) of this neighborhood may
        # have resulted in all children being selected (or not selected)
        # so configure the parent if there is one
        if {$parent ne "root"} {
            set pkey $info(key-$parent)
            set btn [$nblist windowpath $info(btnidx-$pkey)]
            if {[$self AllChildrenSelected $parent]} {
                set info(selected-$pkey) 0
                $btn configure -state disabled
            } else {
                $btn configure -state normal
            }
        } 

        $self UpdateMap 
    }

    #----------------------------------------------------------------
    # Private methods

    # AddToTree  polys pkey
    #
    # polys    A list of neighborhood polygons to display
    # pkey     The key of the parent or 'root'
    #
    # This method traverses the WDB extracting polygons that
    # have the given parent and sets up the tablelist widget
    # to display them in their proper hierarchy.
    #
    # If a polygon has descendants, the method is called recursively
    # until all descendants have been added.

    method AddToTree {polys pkey} {
        # FIRST, determine the name of the parent, special case is
        # "root"
        if {$pkey eq "root"} {
            set parent "root"
        } else {
            set parent $info(nb-$pkey)
        }

        # NEXT, set the list of children in the parent
        set info(children-$parent) $polys

        # NEXT, go through the list of children and add them
        # to the parent
        foreach name $polys {
            set key [$nblist insertchild $pkey end $name]

            # NEXT, by default, the neighborhood is deselected
            set info(selected-$key) 0

            # NEXT, the depth of the children in the
            # tree will determine thier color 
            set info(depth-$key) [$nblist depth $key]
            set info(maxdepth) \
                [expr {max($info(maxdepth), $info(depth-$key))}]

            # NEXT, cross reference information
            set info(key-$name)    $key
            set info(pkey-$name)   $pkey
            set info(nb-$key)      $name
            set info(parent-$name) $parent

            # NEXT, initialze the list of children for this
            # neighborhood, this may remain an empty list
            set info(children-$name) [list]

            # NEXT, by default we assume that this polygon
            # does not already reside in the scenario RDB
            set info(inrdb-$name) 0

            # NEXT, collapse neighborhoods with "root" as the parent
            if {$parent eq "root"} {
                $nblist collapse $key -fully
            }

            # NEXT, if there are children to this polygon
            # add them to the tree
            set children [wdb onecolumn {
                SELECT children FROM polygons 
                WHERE dispname = $name
            }]

            if {[llength $children] > 0} {
                $self AddToTree $children $key
            }
        }
    }

    # Configure Tree
    #
    # This method is called after the geoset(n) is created from the
    # polygons read in by the user.  It configure all elements of the
    # tree based upon what is in the geoset(n) and what neighborhoods may
    # already exist in the Athena scenario.  Note that the set of polygons
    # loaded may be a subset of what is in the tree, so that must be taken 
    # into account.

    method ConfigureTree {} {
        # FIRST, get the neighborhood names in the tree
        set nbhoods [$nblist getcolumns 0]

        foreach n $nbhoods {
            # NEXT, assume it is in the geoset and extract key
            set info(geo-$n) 1
            set key $info(key-$n)

            # NEXT, there may not be a polygon for the neighborhood
            if {![$geo exists $n]} {
                # NEXT, mark it as not being in the geoset
                set info(geo-$n) 0

                # NEXT, if no children hide it, otherwise display it, but
                # disable selection
                if {[llength $info(children-$n)] == 0} {
                    $nblist rowconfigure $info(key-$n) -hide 1
                } else {
                    set btn [$nblist windowpath $info(btnidx-$key)]
                    $btn configure -state disabled
                    set info(selected-$key) 0
                }

            } else {
                # NEXT, a polygon exists, but it may not be in the selected
                # maps field of view
                if {![$self NbhoodInView $n]} {
                    $nblist rowconfigure $info(key-$n) -hide 1
                }
                
                # NEXT, compare the polygon to neighborhoods that already
                # exist and mark them.
                set poly [$geo coords $n]
                if {[adb exists {SELECT n FROM nbhoods WHERE polygon=$poly}]} {
                    set info(inrdb-$n) 1
                    set info(selected-$key) 1
                    set btn [$nblist windowpath $info(btnidx-$key)]
                    $btn configure -state disabled
                }

                # NEXT, if it's parent is "root" then it is selected by
                # default
                if {$info(parent-$n) eq "root"} {
                    set info(selected-$key) 1
                }
            }
        }

        # NEXT, now that all neighborhoods have been configured, check
        # parent neighborhoods for state
        foreach n $nbhoods {
            set key $info(key-$n)
            if {$info(parent-$n) eq "root" &&
                [$self AllChildrenSelected $n]} {
                    set btn [$nblist windowpath $info(btnidx-$key)]
                    $btn configure -state disabled
                    set info(selected-$key) 0
            }
        }
    }

    # NbhoodInView  nb
    #
    # nb   - The name of a neighborhood in the geoset(n)
    #
    # This method determines if a neighborhood in the geoset should be
    # displayed in the tree and, consequently, on the map. 
    #
    # Returns 1 if any part of the neighborhood is inside the playbox
    # and 0 otherwise.

    method NbhoodInView {nb} {
        # FIRST, get the neighborhood's bounding box
        set nbbox [$geo bbox $nb]

        # NEXT, if the neighborhood is entirely contained within the playbox
        # it is in view
        if {[$self IsInside $nbbox $pbbox]} {
            return 1
        }

        # NEXT, if the playbox is entirely contained within the neighborhood
        # it is in view
        if {[$self IsInside $pbbox $nbbox]} {
            return 1
        }

        # NEXT, if at least two bbox coords are inside the playbox, it is
        # in view
        lassign $nbbox minlat minlon maxlat maxlon
        set pbpoly [MakePolyFromBbox $pbbox]

        set ctr 0
        if {[ptinpoly $pbpoly [list $minlat $minlon]]} {incr ctr}
        if {[ptinpoly $pbpoly [list $minlat $maxlon]]} {incr ctr}
        if {[ptinpoly $pbpoly [list $maxlat $maxlon]]} {incr ctr}
        if {[ptinpoly $pbpoly [list $maxlat $minlon]]} {incr ctr}
        if {$ctr >= 2} {
            return 1
        }

        # NEXT, hopefully we've exhausted almost all the neighborhoods
        # before the brute force, point by point check
        foreach {lat lon} [$geo coords $nb] {
            if {[ptinpoly $pbpoly [list $lat $lon]]} {
                return 1
            }
        }

        # NEXT, it must be outside the playbox and not in view
        return 0
    }

    # AddToggles
    #
    # Given the tree structure created, add the toggles to the "Use?"
    # column in the table list.

    method AddToggles {} {
        # FIRST, add a toggle to each row in the second column 
        foreach key [$nblist getfullkeys 0 end] {
            set row [$nblist index $key]
            $nblist cellconfigure $row,1 -window [mymethod InsertToggle]
        }

    }

    # SetColors
    #
    # Given the tree hierarchy loaded into the nbchooser determine the
    # color scheme.  A max depth of 8 tree levels is supported.

    method SetColors {} {
        # NEXT, determine color.
        if {$info(maxdepth) > 8} {
            error "Too many levels in the hierarchy."
        }

        # NEXT, based on max depth determine the delta between colors
        # in the gradient.
        set delta [expr {round(8.0/$info(maxdepth))}]
        
        # NEXT, set color 
        set cid -1
        foreach key [$nblist getfullkeys 0 end] {
            set nb $info(nb-$key)

            # NEXT, if the parent is the root, bump the color scheme to
            # the next gradient, making sure not to run off the end
            if {$info(pkey-$nb) eq "root"} {
                if {$cid >= 7} {
                    set cid 0
                } else {
                    incr cid
                }

                set gradient $colors($cid)
            }

            # NEXT, if the nbhood exists already, grey it out
            if {$info(inrdb-$nb)} {
                set info(color-$info(nb-$key)) #CCCCCC
                continue
            } 

            # NEXT, set color based on depth in tree
            set idx [expr {($info(depth-$key)-1) * $delta}]
            set info(color-$nb) [$gradient color $idx]
        }
    }

    # UpdateMap
    #
    # This method draws the maps given the current state of neighborhood
    # selections made.  If the map does not have a neighborhood with 
    # the given tablelist key, it is created. 

    method UpdateMap {} {
        # FIRST, get nbhoods from the tree
        set nbhoods [$nblist getcolumns 0]
    
        # NEXT, go through and draw them based on nbhood selection state
        foreach n $nbhoods {
            # NEXT, neighborhood not in geoset, can't draw it
            if {!$info(geo-$n)} {
                continue
            }

            # NEXT, extract the nbhood key from the info array
            set key $info(key-$n)
    
            # NEXT, if nbhood has not been created, create it
            if {![info exists info(id-$key)]} {
                set poly [$geo coords $n]
                set id [$map nbhood create $info(ref-$n) $poly]
                set info(id-$key) $id
                set info(key-$id) $key
            }
    
            # NEXT, assign default attributes to nbhood
            $map nbhood configure $info(id-$key) \
                -fill       $info(color-$n) \
                -polycolor  black           \
                -pointcolor black           \
                -linewidth  1
    
            $nblist cellconfigure $info(btnidx-$key) \
                -bg $info(color-$n) -selectbackground $info(color-$n)
    
            # NEXT, if this is the active nbhood, draw a thicker line
            if {$info(active) eq $info(id-$key)} {
                $map nbhood configure $info(id-$key) -linewidth 3
            }
    
            # NEXT, configure the look of deselected neighborhoods
            if {!$info(selected-$key) && !$info(inrdb-$n)} {
    
                # The nbhood is not selected, determine if any parent is
                # selected and adopt that color
                set nb $n
                set color ""
    
                # Traverse up the tree looking for a selected parent until
                # we get to a neighborhood whose parent is "root", which is
                # a top level neighborhood
                while {$info(pkey-$nb) ne "root"} {
                    set pkey $info(pkey-$nb)
                    if {$info(selected-$pkey)} {
                        # This nbhood is selected; adopt the color
                        set color $info(color-$info(nb-$pkey))
                        break
                    } else {
                        # It is not selected; get it's parent
                        set nb $info(nb-$pkey)
                    }
                }
    
                # Configure the look of the deselected nbhood
                $map nbhood configure $info(id-$key) \
                    -fill $color -polycolor #808080 -pointcolor #CCCCCC
    
                 # Configure background of the checkbutton to be the same
                 # as the deselected nbhood
                 $nblist cellconfigure $info(btnidx-$key) \
                    -bg $color -selectbackground $color

            }
        }
    
        # NEXT, get the stacking of neighborhoods right based on the
        # hierarchy of the tree and whether a polygon is selected or not.
        set tree [linsert $nbhoods 0 root]
    
        foreach n $tree {
            # NEXT, if no children, nothing to do
            if {![info exists info(children-$n)] || 
                [llength $info(children-$n)] == 0} {
                continue
            }
    
            # NEXT, separate selected polygons from unselected ones
            set selected [list]
            set unselected [list]
    
            foreach child $info(children-$n) {
                set key $info(key-$child)
    
                if {$info(selected-$key) || $info(inrdb-$child)} {
                    lappend selected $child
                } else {
                    lappend unselected $child
                }
            }

            # NEXT, raise unselected ones first, we want the selected
            # ones to appear on top
            foreach uchild $unselected {
                if {!$info(geo-$uchild)} {
                    continue
                }
                set key $info(key-$uchild)
                set id $info(id-$key)
                $map raise $id
            }
    
            # NEXT, finally raise the selected ones
            foreach schild $selected {
                if {!$info(geo-$schild)} {
                    continue
                }
                set key $info(key-$schild)
                set id $info(id-$key)
                $map raise $id
            }
        }
    }

    #---------------------------------------------------------------------
    # Public methods

    # clear
    #
    # Clears the geoset(n) and tablelist(n) of all content
    # unsets the info array

    method clear {} {
        $geo clear
        $map clear
        $nblist delete 0 end
        array unset info
        set info(active) ""
        set info(maxdepth) 1
    }

    # refresh
    #
    # Reads the loaded polygons and thier metadata from the WDB and sets 
    # up the GUI with the loaded polygons.

    method refresh {} {
        # FIRST, clear the GUI
        $self clear

        # NEXT, extract all polygons from the WDB that have
        # "root" as a parent, we will build each part of the 
        # tree from there.
        set polys [wdb eval {
            SELECT dispname FROM polygons 
            WHERE parent = 'root'
        }]

        # NEXT, add the polygons to the tree starting at the root
        $self AddToTree $polys root

        # NEXT, fill in the geoset(n)
        wdb eval {
            SELECT dispname, polygon 
            FROM polygons
        } {
            $geo create polygon $dispname $polygon nbhood
            set info(ref-$dispname) [$self GetRefPt $dispname]
        }
        
        # NEXT, finish building the GUI components and configuring
        # them
        $self AddToggles
        $self ConfigureTree 

        $self SetColors
        $self UpdateMap

    }

    # visible
    #
    # Returns the number of visible rows in the tablelist widget

    method visible {} {
        set keys [$nblist getkeys 0 end]
        set count 0
        foreach key $keys {
            if {![$nblist rowcget $key -hide]} {
                incr count
            }
        }

        return $count
    }

    # getpolys 
    #
    # This method returns the currently selected set of polygons
    # and their reference points as a dictionary.  The dictionary
    # is a name/list pair where the list is, in order, the reference
    # point followed by the coordinates of the polygon:
    #
    #     name  -> [list refpt polygon]

    method getpolys {} {
        # FIRST, get ready to send neighborhood dictionary
        set ndict [dict create]
        set trans(leaf_descendants) [list]

        # NEXT, go through the geoset and include polygons that have
        # been selected for output
        foreach n [$geo list] {
            set key $info(key-$n)

            # NEXT, if it's not selected, already exists or is hidden, 
            # it is not included
            if {!$info(selected-$key) || 
                $info(inrdb-$n)       ||
                [$nblist rowcget $key -hide]} {
                continue
            }

            # NEXT, set polygon. 
            set poly [$geo coords $n]

            # NEXT, determine ref point. If there's no children then
            # use it's own refpoint otherwise, find a descendant that
            # we can use to determine ref point
            if {[llength $info(children-$n)] == 0} {
                set refpt [$map nbhood point $info(id-$key)]
            } else {
                set refpt [$self FindDescendantRefPoint $n]
            }

            # NEXT, check for serious error condition
            if {$refpt eq ""} {
                error "No viable descendant of $n to determine a ref. point."
            } 

            dict set ndict $n [list $refpt $poly]
        }

        return $ndict
    }

    # pbbox
    #
    # Returns the playbox bounding box

    method pbbox {} {
        return $pbbox
    }

    #--------------------------------------------------------------------
    # Delegated Methods

    delegate method bbox to geo
    delegate method size to nblist

    #--------------------------------------------------------------------
    # Helper Methods

    # FindDescendantRefPoint   n
    #
    # n  - a neighborhood that has children
    #
    # This method traverses the tree of neighborhoods starting with the
    # supplied neighborhood and finds all descendants that do not have
    # any children (the leaves of the tree starting with n). Then it
    # uses that list of leaves to find an appropriate child that can be
    # used to determine a reference point, which is returned to the caller.

    method FindDescendantRefPoint {n} {
        # FIRST, initialize transient data
        set trans(leaf_descendants) [list]

        # NEXT, accumulate transient data
        $self GetLeafDescendants $n

        # NEXT, go through the leaves finding an appropriate descendant
        foreach child $trans(leaf_descendants) {
            set ckey $info(key-$child)

            if {$info(selected-$ckey) || $info(inrdb-$child)} {
                continue
            }

            # NEXT, got one, extract a random point from within it
            # and, in an act of wanton paranoia, make sure there's no way
            # it could match exactly the refpoint the child was created
            # with.
            set randpt [$self RandPt $child]
            set childpt [$map nbhood point $info(id-$ckey)]

            while {$randpt eq $childpt} {
                set randpt [$self RandPt $child]
            }

            return $randpt
        }
    }

    # GetLeafDescendants  n
    #
    # n   - a neighborhood with children
    #
    # This method recursively traverses the tree of polygons starting with
    # n to find and accumulate all the leaves of the tree from that 
    # neighborhood (ie. all childless descendants).

    method GetLeafDescendants {n} {
        foreach child $info(children-$n) {
            if {[llength $info(children-$child)] == 0} {
                lappend trans(leaf_descendants) $child
            } else {
                $self GetLeafDescendants $child
            }
        }
    }

    # GetRefPt  n
    #
    # n   - A neighborhood polygon in the geoset(n)
    #
    # This method computes a reference point for a neighborhood
    # polygon.  It's possible that one is not found if, for example,
    # a national polygon is completely covered by provincial polygons.
    # Upon output, that is treated as a special case.

    method GetRefPt {n} {
        foreach {x1 y1 x2 y2} [$geo bbox $n] {}
    
        # FIRST, try right in the center of the bounding box
        set x [expr {double($x2 - $x1) / 2.0 + $x1}]
        set y [expr {double($y2 - $y1) / 2.0 + $y1}]
    
        set pt [list $x $y]
    
        if {[$geo find $pt] eq $n} {
            return $pt
        }
    
        # NEXT, traverse a diagonal across the bounding box
        for {set i 0} {$i < 100} {incr i} {
            set x [expr {($x2 - $x1)*((double($i)+1.0)/100.0) + $x1}]
            set y [expr {($y2 - $y1)*((double($i)+1.0)/100.0) + $y1}]
    
            # Is it in the neighborhood (taking stacking order
            # into account)?
            set pt [list $x $y]
    
            if {[$geo find $pt] eq $n} {
                return $pt
            }
        }
    }

    # RandPt  n
    #
    # n   - A neighborhood polygon in the geoset(n)
    #
    # This method tries to find a random point inside the neighborhood
    # supplied. If it fails, it returns the empty string, which must
    # be dealt with by the caller.

    method RandPt {n} {
        # FIRST, get the neighborhood polygon's bounding box
        foreach {x1 y1 x2 y2} [$geo bbox $n] {}

        # NEXT, no more than 100 tries
        for {set i 0} {$i < 100} {incr i} {
            # Get a random lat/lon
            let x {($x2 - $x1)*rand() + $x1}
            let y {($y2 - $y1)*rand() + $y1}

            # Is it in the neighborhood (taking stacking order
            # into account)?
            set pt [list $x $y]

            if {[$geo find $pt] eq $n} {
                return $pt
            }
        }

        return ""
    }

    # AllChildrenSelected  n
    #
    # n   - the name of a neighborhood in the hierarchy
    #
    # This method checks if the supplied neighborhood has all of it's 
    # children selected for output or already exists in the scenario
    # and returns an appropriate flag.

    method AllChildrenSelected {n} {
        set flag 1

        # FIRST, no children means not all selected, by convention
        if {[llength $info(children-$n)] == 0} {
            return 0
        }

        # NEXT, go through the list of children and see if they are
        # all selected 
        foreach child $info(children-$n) {
            set key $info(key-$child)
            let flag {$flag * $info(selected-$key)}
        }

        return $flag
    }

    # IsInside  ibox obox
    #
    # ibox   - a bounding box asserted as the inner bounding box
    # obox   - a bounding box asserted as the outer bounding box
    #
    # This method returns 1 if the inner bounding box is entirely
    # contained within the outer bounding box and 0 otherwise

    method IsInside {ibox obox} {
        lassign $obox ominlat ominlon omaxlat omaxlon
        lassign $ibox iminlat iminlon imaxlat imaxlon

        if {$iminlat >= $ominlat && $iminlon >= $ominlon &&
            $imaxlat <= $omaxlat && $imaxlon <= $omaxlon} {
            return 1
        }

        return 0
    }

    #---------------------------------------------------------------------
    # Helper procs
    
    # MakePolyFromBbox bbox
    #
    # bbox  - a bounding box
    #
    # Takes the coords of a bounding box and returns a list of counter-
    # clockwise coords that make up the bounding box.

    proc MakePolyFromBbox {bbox} {
        lassign $bbox minlat minlon maxlat maxlon

        return [list $minlat $minlon $minlat $maxlon \
                     $maxlat $maxlon $maxlat $minlon]
    }
}

