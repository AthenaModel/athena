#-----------------------------------------------------------------------
# TITLE:
#    ctexteditor.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Tklib text(n) widget in Snit wrapper, with additional
#    features as a text editor.
#
#    * Undo enabled by default
#    * <Tab> indents four spaces.
#
#    No doubt this list will grow over time.
#
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# The ctexteditor Widget Type

snit::widget ctexteditor {
    #-------------------------------------------------------------------
    # Components

    component ctext ;# The ctext(n) widget

    #-------------------------------------------------------------------
    # Options

    # Options delegated to hull
    delegate option * to ctext

    # -modifiedcmd cmd
    #
    # Called when the ctext widget sends <<Modified>>

    option -modifiedcmd

    # -messagecmd cmd
    #
    # The cmd is a command prefix taking one additional argument, a
    # text string to display to the user.

    option -messagecmd

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        install ctext using ctext $win.ctext \
            -borderwidth        0        \
            -highlightthickness 0        \
            -relief             flat     \
            -background         white    \
            -foreground         black    \
            -font               codefont \
            -width              80       \
            -height             24       \
            -wrap               char     \
            -undo               1        \
            -autoseparators     1        \
            -linemapfg          white    \
            -linemapbg          black    \
            -linemap_markable   no       \
            -yscrollcommand     [list $win.yscroll set] \
            -xscrollcommand     [list $win.xscroll set]

        scrollbar $win.yscroll \
            -command [list $win.ctext yview]
        scrollbar $win.xscroll \
            -orient  horizontal \
            -command [list $win.ctext xview]

        grid $ctext       -row 0 -column 0 -sticky nsew
        grid $win.yscroll -row 0 -column 1 -sticky ns
        grid $win.xscroll -row 1 -column 0 -sticky ew

        grid rowconfigure    $win 0 -weight 1
        grid columnconfigure $win 0 -weight 1

        # Set up isearch
        isearch enable $ctext.t
        isearch logger $ctext.t [mymethod Message]

        # Handle the command-line arguments
        $self configurelist $args
        
        # TBD: Perhaps we should create a new set of bindings.
        bind $ctext <Tab>         [mymethod EditorTab]
        bind $ctext <<SelectAll>> [mymethod EditorSelectAll]
        bind $ctext <<Modified>>  [mymethod EditorModified]
    }

    #-------------------------------------------------------------------
    # Private Methods
    
    # EditorTab
    #
    # Inserts a four-space tab into the text widget.
    
    method EditorTab {} {
        lassign [split [$win index insert] .] line column
        
        set num [expr {4 - $column % 4}]
        $win insert insert [string repeat " " $num]
        
        # Return break, to terminate the handling of the event.
        return -code break
    }
    
    # EditorSelectAll
    #
    # Selects the entire contents of the widget
    
    method EditorSelectAll {} {
        $win tag add sel 1.0 end
    }

    # EditorModified
    #
    # Sends -modifiedcmd when <<Modified>>

    method EditorModified {} {
        callwith $options(-modifiedcmd)
    }
    
    # Message text
    #
    # text   - A text string to tell the user
    #
    # Passes the text string to the -messagecmd.

    method Message {text} {
        callwith $options(-messagecmd) $text
    }

    #-------------------------------------------------------------------
    # Public Methods
    
    delegate method * to ctext

    delegate method {hclass keyword} to ctext \
        using {::ctext::addHighlightClass %c}
    
    delegate method {hclass startchar} to ctext \
        using {::ctext::addHighlightClassWithOnlyCharStart %c}
    
    delegate method {hclass chars} to ctext \
        using {::ctext::addHighlightClassForSpecialChars %c}
    
    delegate method {hclass regexp} to ctext \
        using {::ctext::addHighlightClassForRegexp %c}
    
    delegate method {hclass clear} to ctext \
        using {::ctext::clearHighlightClasses %c}
    
    delegate method {hclass get} to ctext \
        using {::ctext::getHighlightClasses %c}

    delegate method {hclass delete} to ctext \
        using {::ctext::deleteHighlightClass %c}

    # focus
    #
    # The underlying text widget takes the focus.

    method focus {} {
        focus $ctext.t
    }

    # mode cellmodel
    #
    # Sets the syntax highlighting for cellmodel(5) files.

    method {mode cellmodel} {} {
        $self hclass clear

        $self hclass chars     braces   #009900 {{}}
        $self hclass regexp    macro    #9900FF {<:[^:]*:>}
        $self hclass keyword   keywords #3300CC {
            copypage define -except forall foreach function
            index initfrom let letsym page -value
        }
        $self hclass regexp    cell     #558822 {\[[[:alnum:]_.:$]+\]}
        $self hclass startchar var      #9900FF \$
        $self hclass regexp    comments #BB0000 {#[^\n\r]*}
    }

    # mode tcl
    #
    # Sets the syntax highlighting for tcl(5) files.

    method {mode executive} {} {
        $self hclass clear 

        $self hclass chars     braces   #009900 {{}}
        $self hclass keyword   keywords #3300CC {
            proc return while foreach for if set expr
        }

        $self hclass keyword   exec     #3300CC {
            lock log rdb save send sigevent unlock 
        }

        $self hclass startchar var      #9900FF \$
        $self hclass regexp    orders   #0F8203 {[A-Z]+:[A-Z:]+}
        $self hclass startchar option   #0F8203 -

        $self hclass regexp    strings  red {"(\\"|[^"])*"}
        $self hclass regexp    comments #BB0000 {#[^\n\r]*}
    }
}




