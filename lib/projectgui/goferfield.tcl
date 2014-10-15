#-----------------------------------------------------------------------
# TITLE:
#    goferfield.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectgui(n) package: Smart type data entry field
#
#    A goferfield is a data entry field that displays the narrative for
#    a gofer type value, and has an Edit button popping up a dynabox for
#    the gofer type.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::projectgui:: {
    namespace export goferfield
}

#-------------------------------------------------------------------
# goferfield

snit::widget ::projectgui::goferfield {
    #-------------------------------------------------------------------
    # Components

    component nlabel   ;# ttk::label; displays narrative text
    component editbtn  ;# Edit button

    #-------------------------------------------------------------------
    # Options

    delegate option -background  to hull
    delegate option -borderwidth to hull
    delegate option *               to nlabel

    # -typename gofer_type
    #
    # Name of the gofer type being edited.

    option -typename

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
    # value  - The current value of the widget

    variable info -array {
        value ""
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
            -takefocus  yes \
            -width      -30 \
            -wraplength 300

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
        set info(value) [$options(-typename) blank]
    }

    #-------------------------------------------------------------------
    # Private Methods

    # Edit
    #
    # Called when the Edit button is pressed

    method Edit {} {
        # FIRST, give focus to this field
        focus $win

        # NEXT, get the dynaform name.
        set form [{*}$options(-typename) dynaform]

        # NEXT, call the dynabox given the current data value
        set value [dynabox popup             \
            -formtype    $form               \
            -initvalue   $info(value)        \
            -parent      $win                \
            -title       "Edit Field Value"  \
            -validatecmd [mymethod Validate]]

        # NEXT, if the value is not "", set it.
        if {$value ne ""} {
            $self set $value
        }
    }

    # Validate value
    #
    # value   - The value of the dynaform
    #
    # Validates the value; when valid, returns a preview.

    method Validate {value} {
        # FIRST, validate it; the validate command will throw INVALID
        # on error.
        $options(-typename) validate $value

        # NEXT, return the preview
        return [$self Preview $value]
    }

    # Preview value
    #
    # value  - The form value
    #
    # Returns a preview string of the narrative text.

    method Preview {value} {
        return [$options(-typename) narrative $value -brief]
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
        # FIRST, if it's empty, give it the real blank value.
        if {$value eq ""} {
            set value [$options(-typename) blank]
        }

        # NEXT, Do nothing if the value didn't change.
        if {$value eq $info(value)} {
            return
        }

        # NEXT, if it doesn't begin with _rule, assume it's a raw value.
        if {[lindex $value 0] ne "_type"} {
            set value [dict create \
                _type     [$options(-typename) name] \
                _rule     BY_VALUE                   \
                raw_value $value]
        }

        # NEXT, if gofer type has changed, blank out the value it will
        # need a new rule.
        if {[dict get $value _type] ne [$options(-typename) name]} {
            set value [$options(-typename) blank]
        }

        # NEXT, save the value
        set info(value) $value

        # NEXT, save the narrative
        $nlabel configure -text [$self Preview $value]

        callwith $options(-changecmd) $value
    }
}


