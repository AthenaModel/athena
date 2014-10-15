#-----------------------------------------------------------------------
# TITLE:
#    detailbrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    detailbrowser(cell) package: Detail browser.
#
#    This widget displays a web-like browser for examining
#    model entities in detail.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widget detailbrowser {
    #-------------------------------------------------------------------
    # Type Variables
    
    # browserStyles: CSS for use in this browser and application.

    typevariable browserStyles {
        /* A paragraph with a box around it. */
        DIV.warning {
            border-style: solid;
            border-width: 1px;
            border-color: black;
            background-color: #ffcf57;
        }
    }

    #-------------------------------------------------------------------
    # Options

    # Options delegated to the hull
    delegate option * to browser

    #-------------------------------------------------------------------
    # Components

    component browser ;# The mybrowser(n)
    component ltree   ;# The linktree(n)
    component lazy    ;# The lazyupdater(n)
    component context ;# The context menu

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Install the browser
        install browser using mybrowser $win.browser  \
            -home         my://app/                   \
            -unknowncmd   [mymethod GuiLinkCmd]       \
            -messagecmd   {app puts}                  \
            -styles       $browserStyles 

        # NEXT, create the sidebar
        set sidebar [$browser sidebar]

        ttk::notebook $sidebar.tabs \
            -takefocus 0 \
            -padding   2

        install ltree using linktree $sidebar.tabs.ltree \
            -url       my://app/links      \
            -lazy      yes                 \
            -width     150                 \
            -height    400                 \
            -changecmd [mymethod ShowLink] \
            -errorcmd  [list app error]

        $sidebar.tabs add $sidebar.tabs.ltree    \
            -sticky  nsew                        \
            -padding 2                           \
            -text "Links"

        $browser configure \
            -reloadcmd [mymethod RefreshLinks]

        pack $sidebar.tabs -fill both -expand yes

        # NEXT, create the lazy updater
        install lazy using lazyupdater ${selfns}::lazy \
            -window   $win \
            -command  [list $browser reload]

        pack $browser -fill both -expand yes

        # NEXT, get the options.
        $self configurelist $args

        # NEXT, bind to events that are likely to cause reloads.
        notifier bind ::cmscript <New>    $win [mymethod reload]
        notifier bind ::cmscript <Open>   $win [mymethod reload]
        notifier bind ::cmscript <Check>  $win [mymethod reload]
        notifier bind ::cmscript <Solve>  $win [mymethod reload]
        notifier bind ::snapshot <Import> $win [mymethod reload]

        # NEXT, create the browser context menu
        bind $win.browser <3>         [mymethod MainContextMenu %X %Y]
        bind $win.browser <Control-1> [mymethod MainContextMenu %X %Y]

        set context [menu $win.context]

        # NEXT, schedule the first reload
        $self reload
    }

    destructor {
        notifier forget $win
    }

    # MainContextMenu rx ry
    #
    # rx,ry   - Root window coordinates.
    #
    # Populates and pops up the context menu.
    
    method MainContextMenu {rx ry} {
        # FIRST, get the current content data
        set data [$browser data]

        # NEXT, delete any existing menu items.
        $context delete 0 end

        # NEXT, we can only deal with text/*
        dict with data {
            if {[string match "text/*" $contentType]} {
                set state normal
            } else {
                set state disabled
            }
        }

        # NEXT, add the relevant menu items.
        $context add command \
            -label "Save to Disk..."       \
            -state $state                  \
            -command [mymethod SaveToDisk]

        $context add command \
            -label    "View Source..."            \
            -state    $state                      \
            -command  [mymethod ViewSource]

        # NEXT, pop it up.
        tk_popup $win.context $rx $ry 
    }

    # ViewSource
    #
    # Loads the current page's HTML source into a viewer window.

    method ViewSource {} {
        # FIRST, get the data
        set data [$browser data]

        dict with data {
            textwin .tw_%AUTO%        \
                -title "Source: $url" \
                -text  $content
        }
    }

    # SaveToDisk
    #
    # Saves the current page to disk.

    method SaveToDisk {} {
        # FIRST, get the data.
        set data [$browser data]

        dict with data {
            # FIRST, get the file type.
            if {$contentType eq "text/html"} {
                set initfile  save.html
                set filetypes { {{HTML File} {.html}} }
            } else {
                set initfile  save.txt
                set filetypes { {{Text File} {.txt}} }
            }

            # NEXT, ask for the file name.
            set filename [tk_getSaveFile                  \
                              -parent      [app topwin]   \
                              -title       "Save Page As" \
                              -initialfile $initfile      \
                              -filetypes   $filetypes]

            # NEXT, if none they cancelled.
            if {$filename eq ""} {
                return 0
            }

            # NEXT, Save the file
            if {[catch {
                $self WriteFile $filename $content
            } result]} {
                messagebox popup \
                    -title    "Could Not Save Page" \
                    -icon     error                 \
                    -buttons  {cancel "Cancel"}     \
                    -parent   [app topwin]          \
                    -message  [normalize "
                        Athena was unable to save the page to the
                        requested file:  $result
                    "]
            } else {
                app puts "Page saved to $filename"
            }
        }
    }

    # WriteFile filename text
    #
    # filename  - The filename
    # text      - The text file
    #
    # Writes the text to the file.

    method WriteFile {filename text} {
        set f [open $filename w]

        try {
            puts $f $text
        } finally {
            close $f
        }
    }

    # GuiLinkCmd scheme url
    #
    # scheme - A URL scheme
    # url    - A URL with a scheme other than "my:".
    #
    # Checks the URL scheme; if it's known, passes it to 
    # "app show".  Otherwise, lets mybrowser handle it.

    method GuiLinkCmd {scheme url} {
        if {$scheme ne "gui"} {
            return 0
        }

        app show $url
        return 1
    }

    # RefreshLinks
    #
    # Called on browser reload; refreshes the links tree
    
    method RefreshLinks {} {
        $ltree refresh
    }

    # ShowLink url
    #
    # Shows whatever is selected in the tree, if it's different than
    # what we already have.

    method ShowLink {url} {
        if {$url ne ""} {
            $browser show $url
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to browser

    # reload
    #
    # Causes the widget to reload itself.  In particular,
    #
    # * This call triggers the lazy updater.
    # * The lazy updater will ask the mybrowser to reload itself after
    #   1 millisecond, or when the window is next mapped.
    # * The mybrowser will reload the currently displayed resource and
    #   ask the tree to refresh itself via its -reloadcmd.

    method reload {} {
        $lazy update
    }
}


