#-----------------------------------------------------------------------
# TITLE:
#    listbuttonfield.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectgui(n) package: data entry field
#
#    A listbuttonfield is a data entry field that displays the
#    (possibly abbreviated) narrative for a list of selected entities,
#    and has an edit button popping up a dialog for making the list
#    selection.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::projectgui:: {
    namespace export listbuttonfield
}

#-------------------------------------------------------------------
# listbuttonfield

snit::widget ::projectgui::listbuttonfield {
    #-------------------------------------------------------------------
    # Components

    component nlabel   ;# ttk::label; displays narrative text
    component editbtn  ;# Edit button

    #-------------------------------------------------------------------
    # Options

    delegate option -background  to hull
    delegate option -borderwidth to hull
    delegate option *               to nlabel

    # -itemdict dict
    #
    # Dictionary of keys and list values for display.

    option -itemdict

    # -showkeys flag
    #
    # If 1, show the keys in the listfield widget.

    option -showkeys \
        -default 1

    # -stripe flag
    #
    # If 1, the items in the listfield are striped; otherwise, not.

    option -stripe \
        -default 1

    # -message text
    #
    # The message to display in the listfield dialog.

    option -message \
        -default "Select items from the list:"

    # -showmaxitems
    #
    # The maximum number of items to show in the narrative label.

    option -showmaxitems \
        -default 10

    # -listrows rows
    #
    # The number of rows in the list select boxes in the dialog.

    option -listrows \
        -default 5

    # -listwidth chars
    #
    # The width of the selection lists in characters.

    option -listwidth \
        -default 20

    # -emptymessage text
    #
    # Message to display in empty field.

    option -emptymessage \
        -default "No items selected."


    # -state state
    #
    # state must be "normal" or "disabled".

    option -state                     \
        -default         "normal"     \
        -configuremethod ConfigState

    method ConfigState {opt val} {
        set options($opt) $val
        
        if {$val eq "normal"} {
            $editbtn configure -state normal
        } elseif {$val eq "disabled"} {
            $editbtn configure -state disabled
        } else {
            error "Invalid -state: \"$val\""
        }
    }

    # -changecmd command
    # 
    # Specifies a command to call whenever the field's content changes
    # for any reason.  The new value is appended to the command as a 
    # single argument.

    option -changecmd \
        -default ""

    #-------------------------------------------------------------------
    # Instance Variables

    # info array
    #
    # value     - The current value of the widget
    # narrative - The narrative equivalent

    variable info -array {
        value     ""
        narrative ""
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, configure the hull
        $hull configure                \
            -borderwidth        0      \
            -relief             flat   \
            -highlightthickness 0

        # NEXT, create a frame to be a border around the label.
        ttk::frame $win.nframe \
            -borderwidth        1      \
            -relief             sunken

        # NEXT, create the label to display the narrative.
        install nlabel using ::ttk::label $win.nframe.nlabel \
            -takefocus    yes \
            -width        -30 \
            -wraplength   300 \
            -textvariable [myvar info(narrative)]

        pack $nlabel -fill both -expand yes

        # NEXT, create the edit button
        install editbtn using button $win.edit \
            -state     normal                         \
            -font      tinyfont                       \
            -text      "Edit"                         \
            -takefocus 0                              \
            -command   [mymethod Edit]

        pack $editbtn    -side right -fill y -padx {2 0}
        pack $win.nframe -fill both

        # NEXT, configure the arguments
        $self configure -state normal {*}$args

        # NEXT, set the initial value
        set info(value) [list]
        set info(narrative) $options(-emptymessage)
    }

    #-------------------------------------------------------------------
    # Private Methods

    # Edit
    #
    # Called when the Edit button is pressed

    method Edit {} {
        # FIRST, give focus to this field
        focus $win

        # NEXT, ask the question.
        set result [messagebox listselect        \
            -initvalue $info(value)              \
            -message   $options(-message)        \
            -parent    $win                      \
            -title     "Select from the list..." \
            -itemdict  $options(-itemdict)       \
            -showkeys  $options(-showkeys)       \
            -stripe    $options(-stripe)         \
            -listrows  $options(-listrows)       \
            -listwidth $options(-listwidth)]

        if {[lindex $result 0] eq "cancel"} {
            return
        }

        # NEXT, save the new value.
        $self set [lindex $result 1]
    }


    #-------------------------------------------------------------------
    # Public Methods

    # get
    #
    # Retrieves the widget's value.

    method get {} {
        return $info(value)
    }

    # set value
    #
    # value  - A new value
    #
    # Sets the widget's value to the new value.

    method set {value} {
        # FIRST, Do nothing if the value didn't change.
        if {$value eq $info(value)} {
            return
        }

        # NEXT, save the value
        set info(value) $value

        # NEXT, save the narrative
        set nar [join $info(value) ", "]

        if {[llength $info(value)] == 0} {
            set info(narrative) $options(-emptymessage)
        } else {
            set info(narrative) \
                [joinlist $info(value) $options(-showmaxitems)]
        }

        # NEXT, notify the client
        callwith $options(-changecmd) $value
    }

    #-------------------------------------------------------------------
    # Helpers

    # joinlist list ?maxlen?
    #
    # list   - A list
    # maxlen - If given, the maximum number of list items to show.
    #          If "", the default, there is no maximum.
    #
    # Joins the elements of the list using the delimiter, 
    # replacing excess elements with "..." if maxlen is given.

    proc joinlist {list {maxlen ""}} {
        if {$maxlen ne "" && [llength $list] > $maxlen} {
            set list [lrange $list 0 $maxlen-1]
            lappend list ...
        }

        return [join $list ", "]
    }
}


