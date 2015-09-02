#-----------------------------------------------------------------------
# TITLE:
#    mybrowser.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectgui(n) package: URI-driven Browser
#
#    This is a web-browser-like widget that browses resources found
#    via  URI server.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::projectgui:: {
    namespace export mybrowser
}

#-----------------------------------------------------------------------
# Widget Definition

snit::widget ::projectgui::mybrowser {
    #-------------------------------------------------------------------
    # Type constructor

    typeconstructor {
        namespace import ::marsutil::* ::marsgui::*
    }

    #-------------------------------------------------------------------
    # Components

    component agent     ;# The myagent(n)
    component bar       ;# The tool bar
    component sidebar   ;# The sidebar ttk::frame(n)
    component hv        ;# The htmlviewer(n)
    component backbtn   ;# Back one page button
    component fwdbtn    ;# Forward one page button
    component homebtn   ;# Home button
    component helpbtn   ;# Help button
    component reloadbtn ;# Reload button
    component bookbtn   ;# Bookmark Button
    component address   ;# Address box
    component searchbox ;# Search box
    component lazy      ;# Lazy updater

    #-------------------------------------------------------------------
    # Options

    # Delegate all options to the hull frame
    delegate option * to hull

    delegate option -width  to hv
    delegate option -height to hv
    delegate option -styles to hv
    delegate option -shrink to hv
    delegate option -zoom   to hv

    # -home
    #
    # The home URL

    option -home \
        -configuremethod ConfigureHome

    method ConfigureHome {opt val} {
        set options($opt) $val

        if {$options(-toolbar)} {
            if {$val ne ""} {
                $homebtn configure -state normal
            } else {
                $homebtn configure -state disabled
            }
        }
    }

    # -help
    #
    # The help URL

    option -help \
        -readonly yes

    # -messagecmd
    #
    # A command to pass messages to, to put on the app's message line.

    option -messagecmd

    # -reloadcmd
    #
    # A command to call when the widget is reloaded.

    option -reloadcmd

    # -hyperlinkcmd
    #
    # A command to call when a hyperlink is selected.  By default,
    # hyperlinks are simply passed to [$self show]; clients can use this
    # option to circumvent that.

    option -hyperlinkcmd

    # -unknowncmd
    #
    # A command to call when [$self show] is given a URL with an
    # unknown scheme (i.e., a scheme other than "my:").  If the
    # -unknowncmd can handle it, it should return 1; otherwise,
    # it should return 0, and mybrowser will handle it by
    # displaying an error.

    option -unknowncmd

    # -loadedcmd
    #
    # A command to call when a page has been shown.  It is called
    # with one additional argument, the URL just loaded.

    option -loadedcmd

    # -bookmarkcmd
    #
    # A command to call when the "bookmark this page" button is
    # pushed.  The button only exists if the command is defined.

    option -bookmarkcmd \
        -readonly yes

    # -searchcmd
    #
    # A command that returns a search URL given one additional
    # argument, search string.  If this option is not "", the
    # widget will be created with a search box in the toolbar.

    option -searchcmd \
        -readonly yes

    # -toolbar
    #
    # Flag; if true, add the toolbar, and if false do not.

    option -toolbar \
        -default  yes \
        -readonly yes

    # -sidebar
    #
    # Flag; if true, creates a sidebar widget to be filled in by
    # the client.  If not, not.

    option -sidebar \
        -default  yes \
        -readonly no
    
    # -reloadon
    #
    # A dictionary of notifier events on which the content should be
    # reloaded.

    option -reloadon \
        -readonly yes

    #-------------------------------------------------------------------
    # Instance Variables

    # Browser Info
    #
    # address     - The URI in the address bar, which might or might not
    #               be the current page.
    # uri         - The URI of the current page, including any anchor
    # page        - The page name from the current URI
    # anchor      - The anchor from the current URI
    # title       - The title of the current page, or "".
    # data        - The data dict for the current page, or "".
    # history     - The history stack: a list of page refs
    # future      - The future stack: a list of page refs
    # mouseover   - Last mouse-over string
    # base        - Base URL, used for resolving links

    variable info -array {
        address   ""
        uri       ""
        page      ""
        anchor    ""
        data      "" 
        history   {}
        future    {}
        mouseover ""
        base      ""
    }

    # Transient Data
    #
    # This array contains data used by handlers while parsing the
    # HTML input:
    #
    #     form    - The form currently being processed.

    variable trans -array {
        form ""
    }

    # Form Info: Dictionary of form data:
    #
    # <formNode> -> autosubmit                 - auto-submit flag
    #            -> inputs                     - Inputs in this form
    #            -> inputs -> <name>           - Input widget
    #
    
    variable forms 
    
    # Viewed: array of counts by page name.

    variable viewed -array { }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, set the default hull size
        $hull configure \
            -width  8i  \
            -height 6i

        # NEXT, get the read-only construction options.
        set options(-toolbar)     [from args -toolbar yes]
        set options(-searchcmd)   [from args -searchcmd]
        set options(-bookmarkcmd) [from args -bookmarkcmd]
        set options(-sidebar)     [from args -sidebar yes]

        # NEXT, create the widgets

        if {$options(-toolbar)} {
            # Toolbar
            install bar using ttk::frame $win.bar

            install backbtn using ttk::button $bar.back         \
                -style   Toolbutton                             \
                -image   [list                                  \
                                       ::marsgui::icon::back    \
                              disabled ::marsgui::icon::backd]  \
                -command [mymethod back]

            DynamicHelp::add $backbtn -text "Go back one page"


            install fwdbtn using ttk::button $bar.forward         \
                -style   Toolbutton                               \
                -image   [list                                    \
                                       ::marsgui::icon::forward   \
                              disabled ::marsgui::icon::forwardd] \
                -command [mymethod forward]

            DynamicHelp::add $fwdbtn -text "Go forward one page"

            install homebtn using ttk::button $bar.home          \
                -style   Toolbutton                              \
                -state   disabled                                \
                -image   [list                                   \
                                       ::marsgui::icon::home22   \
                              disabled ::marsgui::icon::home22d] \
                -command [mymethod home]

            DynamicHelp::add $homebtn -text "Display home page"

            install reloadbtn using ttk::button $bar.reload      \
                -style   Toolbutton                              \
                -image   [list                                   \
                                       ::marsgui::icon::reload   \
                              disabled ::marsgui::icon::reloadd] \
                -command [mymethod reload]

            DynamicHelp::add $reloadbtn -text "Reload current page"

            if {$options(-bookmarkcmd) ne ""} {
                install bookbtn using ttk::button $bar.bookmark      \
                    -style   Toolbutton                              \
                    -image   [list                                   \
                                           ::marsgui::icon::plus22   \
                                  disabled ::marsgui::icon::plus22d] \
                    -command [mymethod BookmarkCmd]
                DynamicHelp::add $bookbtn -text "Bookmark current page"
            }

            install address using ttk::entry $bar.address \
                -textvariable [myvar info(address)]

            bind $address <Return> [mymethod ShowAddress]

            if {$options(-searchcmd) ne ""} {
                ttk::label $bar.searchlab \
                    -text "Search:"

                install searchbox using commandentry $bar.searchbox \
                    -relief    sunken                               \
                    -clearbtn  yes                                  \
                    -returncmd [mymethod DoSearch]
            }

            set options(-help) [from args -help]
            if {$options(-help) ne ""} {
                install helpbtn using ttk::button $bar.help          \
                    -style   Toolbutton                              \
                    -image   ::marsgui::icon::question22             \
                    -command [mymethod help]

                DynamicHelp::add $helpbtn -text "Display application help page"
            }


            pack $backbtn   -side left -padx 1 -pady 1
            pack $fwdbtn    -side left -padx 1 -pady 1
            pack $homebtn   -side left -padx 1 -pady 1
            pack $reloadbtn -side left -padx 1 -pady 1

            if {$options(-help) ne ""} {
                pack $helpbtn -side right  -padx 1 -pady 1
            }

            if {$options(-bookmarkcmd) ne ""} {
                pack $bookbtn -side left -padx 1 -pady 1
            }
            pack $address   -side left -fill x -expand yes  -padx 1 -pady {1 3}

            # NEXT, display the searchbox if we have a search command
            if {$options(-searchcmd) ne ""} {
                pack $searchbox     -side right -padx 1 -pady {1 3}
                pack $bar.searchlab -side right -padx 1 -pady 1
            }

            # Separator
            ttk::separator $win.sep -orient horizontal  
        }


        # NEXT, do we have a sidebar or not?
        if {$options(-sidebar)} {
            ttk::panedwindow $win.paner -orient horizontal
            ttk::frame $win.paner.frm
            install sidebar using ttk::frame $win.paner.sidebar

            $win.paner add $win.paner.sidebar
            $win.paner add $win.paner.frm -weight 1

            set content $win.paner.frm
            grid $win.paner -row 2 -column 0 -sticky nsew
        } else {
            ttk::frame $win.frm
            set content $win.frm
            grid $win.frm -row 2 -column 0 -sticky nsew
        }

        # HTML Viewer
        set styles [readfile [file join $::projectgui::library mybrowser.css]]

        install hv using htmlviewer $content.hv              \
            -styles              $styles                     \
            -hovercmd            [mymethod HoverCmd]         \
            -hyperlinkcmd        [mymethod HyperlinkCmd]     \
            -imagecmd            [mymethod ImageCmd]         \
            -isvisitedcmd        [mymethod IsVisitedCmd]     \
            -xscrollcommand      [list $content.xscroll set] \
            -yscrollcommand      [list $content.yscroll set]

        ttk::scrollbar $content.xscroll \
            -orient  horizontal               \
            -command [list $hv xview]

        ttk::scrollbar $content.yscroll \
            -command [list $hv yview]

        grid $content.hv      -row 0 -column 0 -sticky nsew
        grid $content.yscroll -row 0 -column 1 -sticky ns
        grid $content.xscroll -row 1 -column 0 -sticky ew

        grid rowconfigure    $content 0 -weight 1
        grid columnconfigure $content 0 -weight 1

        if {$options(-toolbar)} {
            grid $win.bar   -row 0 -column 0 -sticky ew
            grid $win.sep   -row 1 -column 0 -sticky ew -pady 1
        }

        grid rowconfigure    $win 2 -weight 1
        grid columnconfigure $win 0 -weight 1

        grid propagate $win no

        # NEXT, update the htmlviewer's bindtags,
        # so that users can bind mouse events to $win.
        bindtags $hv [list $win {*}[bindtags $hv]]

        # NEXT, create the agent.
        install agent using myagent ${selfns}::agent \
            -contenttypes {text/html text/plain tk/image}

        # NEXT, create the lazy updater
        install lazy using lazyupdater ${selfns}::lazy \
            -window   $win \
            -command  [mymethod ReloadNow]

        # NEXT, add node handlers
        $hv handler node  object [mymethod ObjectCmd]
        $hv handler node  input  [mymethod InputCmd]
        $hv handler parse form   [mymethod FormCmd]

        # NEXT, get the options
        $self configurelist $args

        # NEXT, prepare to reload on notifier events
        foreach {subject event} $options(-reloadon) {
            notifier bind $subject $event $win [mymethod ReloadOnEvent]
        }


        # NEXT, reload the browser and show the home page
        $self reload
        $self home
    }

    destructor {
        notifier forget $win
    }


    # HoverCmd otype text
    #
    # otype   - Object type, either "href" or "image"
    # text    - Text describing thing we're over.
    #
    # Called as the mouse moves; calls -messagecmd with the URI.

    method HoverCmd {otype text} {
        if {$otype eq "href"} {
            set text [$agent resolve $info(base) $text]
            callwith $options(-messagecmd) "Link: $text"
        }
    }

    # HyperlinkCmd uri
    #
    # uri   - A URI of the form "<resource>#<anchor>"
    #
    # Displays the URI in the html viewer.  Note that either the
    # <resource> or the <anchor> can be empty, but not both.

    method HyperlinkCmd {uri} {
        # FIRST, get the URI
        set uri [$agent resolve $info(base) $uri]

        # NEXT, show it.  By default, just show it normally; but
        # allow the user to handle it if desired.
        if {$options(-hyperlinkcmd) ne ""} {
            callwith $options(-hyperlinkcmd) $uri
        } else {
            $self show $uri
        }
    }

    # IsVisitedCmd uri
    #
    # uri     A URI of the form "<page>#<anchor>"
    #
    # Returns 1 if the URI has been visited.

    method IsVisitedCmd {uri} {
        set uri [$agent resolve $info(base) $uri]

        if {[string index $uri 0] eq "#"} {
            # TBD: This shouldn't be necessary
            set uri "$info(page)$uri"
        }

        if {[info exists viewed($uri)]} {
            return 1
        } else {
            return 0
        }
    }

    # BookmarkCmd
    #
    # Calls the user's -bookmarkcmd when the bookmark button is pressed.

    method BookmarkCmd {} {
        callwith $options(-bookmarkcmd)
    }

    # ImageCmd src
    #
    # src     The image source
    #
    # Returns the Tk image relating to the src.

    method ImageCmd {src} {
        set src [$agent resolve $info(base) $src]

        if {[catch {$agent get $src} cdict]              ||
            [dict get $cdict contentType] ne "tk/image"
        } {
            set img ::marsgui::icon::question22
        } else {
            set img [dict get $cdict content]
        }

        # NEXT, make a copy of the image, since htmlviewer will delete
        # it when it is done with it.
        set copy [image create photo]
        $copy copy $img

        return $copy
    }

    # ObjectCmd node
    # 
    # node    - htmlviewer node handle
    #
    # An <object> tag was found in the input.  The data attribute is
    # assumed to name a resource with content-type tk/widget.  The size of
    # the widget can be controlled using width and height attributes with
    # the usual HTML length units, e.g., "100%" for full width.

    method ObjectCmd {node} {
        # FIRST, get the attributes of the object.
        set data [$node attribute -default "" data]

        # NEXT, get the Tk widget command for the object.  This will throw
        # NOTFOUND if the object is not found.

        if {[catch {
            set udict [$agent get $data tk/widget]
            set cmd [dict get $udict content]
        } result]} {
            set cmd [list ttk::label %W -image ::marsgui::icon::question22]
        }

        # NEXT, replace the node with the widget.
        $self ReplaceNode $node $cmd
    }

    # FormCmd node offset
    #
    # node   - a <form> node
    # offset - Unused
    #
    # Retrieves data about a form.

    method FormCmd {node offset} {
        # FIRST, clear the form.
        set trans(form) ""

        # NEXT, if this is an end tag, we're done.
        if {$node eq ""} {
            return
        }

        # NEXT, It's a start tag.  Get the action attribute.  If
        # action="", we'll simply reload the current page on submit.
        set action [$node attribute -default "" action]

        # NEXT, save the form's node ID, so that inputs know what
        # form they are associated with.
        set trans(form) $node

        # NEXT, set up the form dictionary.
        dict set forms $node autosubmit 0
        dict set forms $node inputs [dict create]
        dict set forms $node action $action

        # NEXT, Look for an "autosubmit" attribute.
        set autosubmit [$node attribute -default "" autosubmit]
        restrict autosubmit snit::boolean no

        if {$autosubmit} {
            dict set forms $node autosubmit 1
        }
    }
    

    # FormSubmit node args...
    #
    # The form's submit button has been pressed, or autosubmit is
    # enabled, and an enum widget has been changed.
    
    method FormSubmit {node args} {
        dict with forms $node {}

        set pdict ""
        dict for {name w} $inputs {
            dict set pdict $name [$w get]
        }

        # NEXT, The action is the URL of the page to load on submit.
        # It's most likely a relative URL (and probably ""), and so
        # it needs to be resolved.  BUT: if the base URL includes a
        # query we need to replace it with the proper query.
        set url [$agent resolve $info(base) $action]

        array set parts [uri::split $url]
        set parts(query) [urlquery fromdict $pdict]
        set url [uri::join {*}[array get parts]]

        $self show $url
    }

    # InputCmd node
    # 
    # node    - htmlviewer node handle
    #
    # An <input> tag was found in the input.  If the type= attribute
    # corresponds to a supported type and has all of the required
    # attributes, it will be replaced by the relevant kind of 
    # Tk widget.

    method InputCmd {node} {
        # FIRST, get the type of the input.
        array set attrs [$node attribute]

        # NEXT, if the type and name are not defined, we're done.
        if {$trans(form) eq ""         ||
            ![info exists attrs(type)]
        } {
            $self HideNode $node
            return
        }

        if {$attrs(type) ne "submit" &&
            ![info exists attrs(name)]
        } {
            $self HideNode $node
            return
        }

        # NEXT, handle it by type.
        switch -exact -- $attrs(type) {
            enum {
                # src is required.
                if {![info exists attrs(src)]} {
                    $self HideNode $node
                    return
                }

                # get the content type
                if {![info exists attrs(content)]} {
                    set attrs(content) tcl/enumlist
                }

                switch -exact -- $attrs(content) {
                    tcl/enumdict { set longFlag yes }
                    tcl/enumlist { set longFlag no  }
                    default      { 
                        set attrs(content) tcl/enumlist
                        set longFlag no  
                    }
                }

                # get the values
                if {[catch {
                    set udict [$agent get $attrs(src) $attrs(content)]
                    set values [dict get $udict content]
                }]} {
                    $self HideNode $node
                    return
                }

                set cmd [list enumfield %W \
                    -values      $values   \
                    -autowidth   yes       \
                    -displaylong $longFlag]

                set w [$self ReplaceNode $node $cmd]

                if {[info exists attrs(value)]} {
                    $w set $attrs(value)
                }

                dict set forms $trans(form) inputs $attrs(name) $w

                if {[dict get $forms $trans(form) autosubmit]} {
                    $w configure -changecmd [mymethod FormSubmit $trans(form)]
                }
                return
            }

            text {
                set cmd [list textfield %W]

                set w [$self ReplaceNode $node $cmd]

                if {[info exists attrs(value)]} {
                    $w set $attrs(value)
                }

                dict set forms $trans(form) inputs $attrs(name) $w
            }

            submit {
                if {$attrs(value) eq ""} {
                    set attrs(value) "Submit"
                }

                set cmd [list ttk::button %W -text $attrs(value)]
                set w [$self ReplaceNode $node $cmd]

                $w configure -command [mymethod FormSubmit $trans(form)]
            }

            default {
                # Unsupported type
                $self HideNode $node
                return
            }
        }
    }

    # ReplaceNode node wcommand
    #
    # node      - An htmlviewer node
    # wcommand  - A widget command with %W for the widget name.
    #
    # Creates the widget and replaces the node with it.  

    method ReplaceNode {node wcommand} {
        # FIRST, get a unique widget name
        set owin "$hv.o[incr info(counter)]"

        # NEXT, create the widget
        set cmd [string map [list %W $owin] $wcommand]

        namespace eval :: $cmd

        # NEXT, replace the node with the widget; destroy the widget
        # when the browser is reset.
        $node replace $owin -deletecmd [list destroy $owin] 
    }

    # Hide node
    #
    # node      - An htmlviewer node
    #
    # Hides the node.

    method HideNode {node} {
        $node attribute style "display:none"
    }

    # ShowAddress
    #
    # Shows the page entered manually in the address bar.

    method ShowAddress {} {
        $self show $info(address)
    }

    # DoSearch text
    #
    # text    - The text from the searchbox
    #
    # Calls the -searchcmd to get the search URL, and then shows it.

    method DoSearch {text} {
        if {$text ne ""} {
            set url [callwith $options(-searchcmd) $text]

            if {$url ne ""} {
                $self show $url
            }
        }
    }
    
    #-------------------------------------------------------------------
    # Public Methods

    # url
    #
    # Returns the URL of the currently displayed page.

    method url {} {
        return $info(address)
    }

    # title
    #
    # Returns the title fo the currently displayed page.

    method title {} {
        return $info(title)
    }

    # data 
    #
    # Returns the data for the currently displayed page.

    method data {} {
        return $info(data)
    }

    # sidebar
    #
    # Returns the sidebar widget, into which the client can place any
    # desired content.  It's an error if the browser was created without
    # a sidebar.

    method sidebar {} {
        if {$options(-sidebar)} {
            return $sidebar
        }

        error "Error, -sidebar is false"
    }

    # home
    #
    # Go to the home page

    method home {} {
        $self show $options(-home)
    }

    # help
    #
    # Go to the help page

    method help {} {
        $self show $options(-help)
    }

    # show uri
    #
    # uri  - A resource URI, possibly with an anchor
    #
    # Shows the specified URI in htmlviewer.  If both resource and
    # anchor are "", nothing happens.  If resource is not "", the resource
    # is loaded; if anchor is not "", the htmlviewer is scrolled to
    # display the related text.

    method show {uri} {
        # FIRST, handle unknown URL schemes.
        if {[$self HandleUnknownSchemes $uri]} {
            return
        }

        # NEXT, parse the URI and its components
        lassign [split $uri "#"] page anchor

        # NEXT, if page and anchor are both "", then just clear the
        # html viewer; there's nothing else to do.
        if {$page eq "" && $anchor eq ""} {
            set forms [dict create]
            $hv set ""
            set info(page) ""
            set info(anchor) ""
            return
        }

        # NEXT, push the current page ref onto the history stack
        $self Push history

        # NEXT, save the information about the new current page.
        if {$page ne "" && $page ne $info(page)} {
            set info(page) $page
            set gotNewPage 1
        } else {
            set page $info(page)
            set gotNewPage 0
        }

        if {$anchor eq ""} {
            $self SaveUri $page
        } else {
            $self SaveUri "$page#$anchor"
        }

        # NEXT, clear the future stack
        set info(future) [list]

        # NEXT, display the current page.
        $self ShowPageRef $page

        # NEXT, scroll to the anchor, if any.
        if {$anchor ne ""} {
            $hv setanchor $anchor
        }            

        # NEXT, remember that we've been here.
        incr viewed($info(uri))

        # NEXT, update the button state.
        $self UpdateButtonState
    }

    # HandleUnknownSchemes uri 
    #
    # uri   - A resource URI
    #
    # Looks for the scheme, and attempts to handle unknown schemes
    # (i.e., other than "my:").  Returns 1 on success and 0 on
    # failure.

    method HandleUnknownSchemes {uri} {
        # FIRST, if there's no unknown command, we *have* to handle it
        # normally.
        if {$options(-unknowncmd) eq ""} {
            return 0
        }

        # NEXT, try to get its scheme
        if {[catch {
            array set parts [uri::split $uri]
        } result]} {
            # Couldn't get it; punt to normal handling
            return 0
        }

        # NEXT, if it's a "my:" URL, it's not an unknown scheme.
        if {$parts(scheme) eq "my"} {
            return 0
        }

        # NEXT, let the -unknowncmd decide whether it can handle it or not.
        return [callwith $options(-unknowncmd) $parts(scheme) $uri]
    }

    # ShowPageRef page ?frac?
    #
    # page      A page URI
    # frac      A scroll fraction, 0.0 to 1.0; defaults to 0.
    #
    # Loads the named page into the htmlviewer, and scrolls to the
    # specified fraction.  If the page is not known, a pseudo-page
    # is created.

    method ShowPageRef {page {frac 0.0}} {
        # FIRST, get the page data.
        if {[catch {
            set result [$agent get $page]
        } result opts]} {
            set ecode [dict get $opts -errorcode]
            set einfo [dict get $opts -errorinfo]
            set etext $result

            set result [dict create url $page contentType text/html]

            if {$ecode eq "NOTFOUND"} {
                dict set result content [$self PageNotFound $page $etext]
            } else {
                dict set result content [$self PageError $page $einfo]
            }
        }
        
        dict with result {
            # FIRST, handle special content.
            switch -exact -- $contentType {
                text/plain {
                    set content \
                  "<pre>[string map {& &amp; < &lt; > &gt;} $content]</pre>"
                }

                tk/image {
                    set content "<img src=\"$url\">"
                }
            }

            # NEXT, show the page.
            set info(base) $url
            set forms [dict create]
            $hv set $content
            callwith $options(-loadedcmd) $url
        }

        # NEXT, save the content, so that it can be queried.
        set info(data) $result

        # NEXT, extract the title.
        set info(title) ""

        set titleElement [lindex [$hv search title] 0]
        if {$titleElement ne ""} {
            set textNode [lindex [$titleElement children] 0]

            if {$textNode ne ""} {
                set info(title) [$textNode text] 
            }
        }

        # NEXT, update idle tasks; otherwise scrolling to anchors,
        # etc., won't work.
        update idletasks
        
        # NEXT, scroll to the fraction.
        $hv yview moveto $frac
    }

    # PageNotFound uri
    #
    # uri     The name of an unknown resource
    #
    # Creates a "Not Found" pseudo-page body.

    method PageNotFound {uri result} {
        set result [htools escape $result]
        return [tsubst {
            |<--
            <h1>Not Found</h1>

            The data you requested could not be found:<p>
            $result
        }]
    }

    # PageError uri einfo
    #
    # uri     - The name of an resource
    # einfo   - The error stack trace
    #
    # Creates an "Unexpected Error" pseudo-page body.

    method PageError {uri einfo} {
        set einfo [htools escape $einfo]
        return [tsubst {
            |<--
            <h1>Unexpected Error</h1>
            
            The page at <tt>$uri</tt> returned an unexpected error.
            Please report this to the development team.<p>
            
            <pre>
            $einfo
            </pre>
        }]
    }

    # reload ?-force?
    #
    # Causes the widget to reload itself.  In particular,
    #
    # * This call triggers the lazy updater.
    # * The lazy updater will ask the widget to reload itself after
    #   1 millisecond, or when the window is next mapped.

    method reload {{opt ""}} {
        if {$opt eq "-force"} {
            $self ReloadNow
        } else {
            $lazy update
        }
    }

    # ReloadNow
    #
    # Reloads the current page

    method ReloadNow {} {
        if {$info(page) ne ""} {
            $self ShowPageRef $info(page) [lindex [$hv yview] 0]
        } else {
            $hv set ""
        }
        callwith $options(-reloadcmd)
    }

    # ReloadOnEvent dummy...
    #
    # Reloads the content on an arbitrary notifier event.

    method ReloadOnEvent {args} {
        $self reload
    }

    # back
    #
    # Go back one page

    method back {} {
        # FIRST, pop the top page ref from the history stack.  If none,
        # there's nothing to do.
        lassign [$self Pop history] uri frac

        if {$uri eq ""} {
            return
        }

        # NEXT, push the current page onto the future stack.
        $self Push future

        # NEXT, make the new page current
        $self SaveUri $uri

        # NEXT, display the page.
        $self ShowPageRef $info(page) $frac

        # NEXT, Update the button state
        $self UpdateButtonState
    }


    # forward
    #
    # Go forward one page

    method forward {} {
        # FIRST, pop the top page ref from the future stack.  If none,
        # there's nothing to do.
        lassign [$self Pop future] uri frac

        if {$uri eq ""} {
            return
        }

        # NEXT, push the current page onto the history stack.
        $self Push history

        # NEXT, make the new page current
        $self SaveUri $uri

        # NEXT, display the page.
        $self ShowPageRef $info(page) $frac

        # NEXT, Update the button state
        $self UpdateButtonState
    }

    # SaveUri uri
    #
    # uri   - The current URI
    #
    # Saves the current URI and its components.

    method SaveUri {uri} {
        lassign [split $uri "#"] page anchor
        set info(uri)     $uri
        set info(address) $uri
        set info(page)    $page
        set info(anchor)  $anchor
    }


    # UpdateButtonState
    #
    # Enables/disables the toolbar buttons based on the state of the 
    # browser.

    method UpdateButtonState {} {
        # Skip if there's no toolbar
        if {!$options(-toolbar)} {
            return
        }

        if {[llength $info(history)] > 0} {
            $backbtn configure -state normal
        } else {
            $backbtn configure -state disabled
        }

        if {[llength $info(future)] > 0} {
            $fwdbtn configure -state normal
        } else {
            $fwdbtn configure -state disabled
        }
    }

    # Push stack
    #
    # Pushes the current URI and fraction onto the named
    # stack (presuming that they are different from what's
    # already there.

    method Push {stack} {
        # FIRST, If there's no current URI to push, don't push it.
        if {$info(uri) eq ""} {
            return
        }

        # NEXT, get the current page ref.
        set ref [list $info(uri) [lindex [$hv yview] 0]]

        # NEXT, if it's the same as the top of the stack, we're done.
        # Otherwise, push it on the stack.
        if {$ref ne [lindex $info($stack) end]} {
            lappend info($stack) $ref
        }

        return
    }

    # Pop stack
    #
    # Pops the top entry off of the named stack, and returns it.
    # If the stack is entry, returns "".

    method Pop {stack} {
        set ref [lindex $info($stack) end]
        set info($stack) [lrange $info($stack) 0 end-1]

        return $ref
    }
}



