#-----------------------------------------------------------------------
# TITLE:
#    cmscripteditor.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    cmscripteditor(cell) package: Editor for cellmodel(5) scripts.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widget cmscripteditor {
    #-------------------------------------------------------------------
    # Options

    # Options delegated to the hull
    delegate option * to editor

    #-------------------------------------------------------------------
    # Components

    component editor  ;# The ctexteditor widget

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, install the editor
        install editor using ctexteditor $win.editor \
            -width       80              \
            -height      40              \
            -background  white           \
            -borderwidth 1               \
            -relief      sunken          \
            -messagecmd  [list app puts]

        $editor mode cellmodel
        pack $win.editor -fill both -expand yes

        # NEXT, get the options.
        $self configurelist $args
    }

    destructor {
        notifier forget $win
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to editor

    # new ?text?
    #
    # text   - New text for the widget
    #
    # Puts a new document in the widget with the given text, replacing
    # any previous content, and scrolls to the top.  Clears the undo 
    # stack, and marks the content unmodified.

    method new {{text ""}} {
        $editor fastdelete 1.0 end

        if {$text ne ""} {
            $editor fastinsert 1.0 $text
            $editor highlight 1.0 end
            $editor yview moveto 0.0
        }

        $editor edit reset
        $editor edit modified no
    }

    # getall
    #
    # Gets all text from the widget.

    method getall {} {
        return [$editor get 1.0 "end - 1 char"]
    }
}


