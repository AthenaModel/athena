#-----------------------------------------------------------------------
# TITLE:
#    linktree.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectgui(n) package: URL-driven Link Tree
#
#    This is a scrolled tree control that displays a tree of links
#    gotten from a my:// server given a URL.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::projectgui:: {
    namespace export linktree
}

#-----------------------------------------------------------------------
# Widget Definition

snit::widget ::projectgui::linktree {
    #-------------------------------------------------------------------
    # Options

    delegate option * to hull

    delegate option -height        to tree
    delegate option -width         to tree

    # -url    
    #
    # The URL to read entity types from

    option -url -readonly yes

    # -lazy
    #
    # If true, retrieves lower branches of the tree in a lazy fashion.
    # Otherwise, the entire tree if retrieved all at once.  Defaults
    # to false.

    option -lazy \
        -type    snit::boolean \
        -default false

    # -changecmd
    #
    # A callback when the selection changes.

    option -changecmd

    # -errorcmd
    #
    # Called if there's an error with the -url.  Takes one argument,
    # a string.

    option -errorcmd


    #-------------------------------------------------------------------
    # Components

    component agent     ;# The myagent(n).
    component tree      ;# The treectrl(n) widget

    #-------------------------------------------------------------------
    # Instance Variables

    # info Array: Miscellaneous data
    #
    # inRefresh        - 1 if we're doing a refresh, and 0 otherwise.
    # lastItem         - URI of last selected item, or ""

    variable info -array {
        inRefresh 0
        lastItem  {}
    }

    # uri2id Array: Tree item ID by entity uri.
    # id2uri Array: Entity uri by tree item ID

    variable uri2id -array { }
    variable id2uri -array { }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the tree
        install tree using treectrl $win.tree       \
            -width          1.25i                   \
            -borderwidth    1                       \
            -relief         sunken                  \
            -background     white                   \
            -usetheme       1                       \
            -showroot       0                       \
            -showheader     0                       \
            -showbuttons    1                       \
            -selectmode     single                  \
            -itemwidthequal 1                       \
            -indent         14                      \
            -yscrollcommand [list $win.yscroll set]

        $tree element create elemText text \
            -font codefont \
            -fill black
        $tree element create elemIcon image

        $tree element create elemRect rect -fill {gray {selected}}
        $tree style create style1
        $tree style elements style1 {elemRect elemIcon elemText}
        $tree style layout style1 elemText -iexpand nse -padx 4
        $tree style layout style1 elemRect -union {elemIcon elemText}

        $tree column create                            \
            -borderwidth 1                             \
            -expand      yes                           \
            -resize      no                            \
            -background  $::marsgui::defaultBackground \
            -font        TkDefaultFont                 \
            -itemstyle   style1 
        $tree configure -treecolumn 0

        $tree column configure tail \
            -borderwidth 0         \
            -squeeze     yes

        # NEXT, prepare to add items when folders are opened.
        $tree notify bind $tree <Expand-before> [mymethod ExpandBefore %I]

        # NEXT, create the scrollbar
        ttk::scrollbar $win.yscroll     \
            -orient  vertical           \
            -command [list $tree yview]

        # NEXT, grid them in
        grid $tree        -row 0 -column 0 -sticky nsew
        grid $win.yscroll -row 0 -column 1 -sticky ns   -pady {1 0}

        grid columnconfigure $win 0 -weight 1
        grid rowconfigure    $win 0 -weight 1

        # NEXT, get selection events
        $tree notify bind $tree <Selection> \
            [mymethod ItemSelected]

        # NEXT, save the options
        $self configurelist $args

        # NEXT, create the agent
        install agent using myagent ${selfns}::agent \
            -contenttypes tcl/linkdict
    }

    # ItemSelected
    #
    # Calls the -changecmd event, when needed.
    
    method ItemSelected {} {
        # FIRST, if we're in a refresh call, do nothing.
        if {$info(inRefresh)} {
            return
        }

        # NEXT, get the selected item.
        set thisItem [$self get]

        if {$info(lastItem) eq $thisItem} {
            return
        }

        # NEXT, call the -changecmd with the item URL
        set info(lastItem) $thisItem
        callwith $options(-changecmd) $thisItem
    }

    #-------------------------------------------------------------------
    # Public methods

    # refresh
    #
    # Reloads the entities from the server

    method refresh {} {
        set info(inRefresh) 1

        try {
            # FIRST, get the selected entity, if any.
            set currentSelection [$self get]

            # NEXT, get the list of open items
            set openURLs [list]

            foreach url [array names uri2id] {
                if {[$tree item isopen $uri2id($url)]} {
                    lappend openURLs $url
                }
            }

            # NEXT, clear all content from the tree
            $tree item delete 0 end
            array unset uri2id
            array unset id2uri

            # NEXT, refresh the content
            $self RefreshLinks root $options(-url)

            # NEXT, re-open the open URLs
            foreach url $openURLs {
                if {[info exists uri2id($url)]} {
                    $tree item expand $uri2id($url)
                }
            }

            # NEXT, set the current selection, if there is one.
            if {$currentSelection ne ""} {
                $self set $currentSelection
            }
        } finally {
            set info(inRefresh) 0
        }

    }

    # RefreshLinks parent url
    #
    # parent - Parent item ID
    # url    - A URL that returns a tcl/linkdict.
    #
    # Adds the URL's links to the tree.  Returns the number of 
    # links found.

    method RefreshLinks {parent url} {
        # FIRST, get the linkdict
        if {[catch {
            $agent get $url
        } result eopts]} {
            # NOTFOUND is an error only if this is the -url;
            # otherwise, it just means there's no children.
            # Unexpected errors should be rethrown.
            if {[dict get $eopts -errorcode] ne "NOTFOUND"} {
                return {*}$eopts $result
            }

            if {$url eq $options(-url)} {
                callwith $options(-errorcmd) \
                    "Error getting \"$url\": $result"
            }

            return 0
        }

        set linkdict [dict get $result content]

        dict for {child cdict} $linkdict {
            # FIRST, add the child
            set id [$tree item create   \
                        -parent $parent \
                        -open   false   \
                        -button false]
            
            dict with cdict {
                $tree item text $id 0 $label
                $tree item element configure $id 0 elemIcon \
                    -image $listIcon
            }

            # Resolve the child URL, so that we have a complete URL
            set child [$agent resolve $url $child]
            
            set uri2id($child) $id
            set id2uri($id)    $child

            # NEXT, are we recursing immediately, or lazily?
            if {$options(-lazy)} {
                # FIRST, if the child has children, make it a button.
                if {[catch {
                    $agent get $child
                } result eopts]} {
                    # NOTFOUND just means there's no children;
                    # other errors are rethrown.
                    if {[dict get $eopts -errorcode] ne "NOTFOUND"} {
                        return {*}$eopts $result
                    }

                    continue
                }

                set numKids [dict size [dict get $result content]]
            } else {
                set numKids [$self RefreshLinks $id $child]
            }

            
            if {$numKids > 0} {
                $tree item configure $id \
                    -button yes
            }
        }

        return [dict size $linkdict]
    }

    # ExpandBefore id
    #
    # id     - A folder item ID
    #
    # Retrieves the children of the given item.

    method ExpandBefore {id} {
        if {[llength [$tree item children $id]] == 0} {
            $self RefreshLinks $id $id2uri($id)
        }
    }

    # set
    #
    # Sets the displayed uri; does not send <<Selection>>

    method set {uri} {
        # FIRST, get the URI in fully resolved form.
        set uri [$agent resolve $options(-url) $uri]

        # NEXT, clear selection on unknown uris
        if {![info exists uri2id($uri)]} {
            $tree selection clear
            return
        }

        # NEXT, make sure the item is visible
        set id $uri2id($uri)

        if {[$tree item parent $id] != 0} {
            $tree expand [list $id parent]
        }

        $tree see $id
        
        # NEXT, select the ID
        $tree selection modify $id all
    }

    
    # get
    #
    # Returns the displayed uri

    method get {} {
        set id [lindex [$tree selection get] 0]

        if {[info exists id2uri($id)]} {
            return $id2uri($id)
        } else {
            return ""
        }
    }
}


