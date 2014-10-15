#-----------------------------------------------------------------------
# TITLE:
#    rolemapfield.tcl
#
# AUTHORS:
#    Will Duquette
#    Dave Hanks
#
# DESCRIPTION:
#    projectgui(n) package: Role map editing widget
#
#    A rolemapfield is a data entry field that allows the user to
#    selects list of entities for multiple roles.  The field value
#    is a dictionary, <role> -> <gofer type>.  This is intended
#    for editing roles for the CURSE tactic, but it is really a 
#    generic dictionary of gofer types editor, where the collection of 
#    roles and gofer types is dynamically configurable.
#
#    See the gofer(n) man page for a discussion of what gofers are and
#    how to use them.
#
#    The field contains a form(n) containing one label and one
#    goferfield(n) for each role; these are configured when the -rolespec
#    is changed. See goferfield(n) for more.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::projectgui:: {
    namespace export rolemapfield
}

#-------------------------------------------------------------------
# rolemapfield

snit::widget ::projectgui::rolemapfield {
    hulltype ttk::frame

    #-------------------------------------------------------------------
    # Components

    component form       ;# a form(n) containing the labels and goferfields
                          # for each specific role.

    #-------------------------------------------------------------------
    # Options

    delegate option * to hull

    delegate option -state to form

    # -changecmd cmd
    #
    # cmd is called when the field's value changes; the new value is appended
    # to the field as an argument.

    option -changecmd

    # -rolespec spec
    #
    # This option fully configures the data to be edited.  The spec is a
    # dictionary <rolename> -> <gofer type>.  The form will be set to 
    # contain set of labels and goferfields, where the <rolename> is the
    # label string, and the goferfield is defined when the user selects
    # the type of gofer(n) to use.
    option -rolespec \
        -configuremethod ConfigRoleSpec

    method ConfigRoleSpec {opt val} {
        if {$val ne $options($opt)} {
            set options($opt) $val
        
            $self UpdateDisplay
        }
    }

    # -textwidth num
    #
    # Width of the textfields in characters

    option -textwidth \
        -default 30

    # -listheight num
    #
    # Number of rows to display in the listselect box.
    
    option -listheight \
        -default         10

    # -liststripe flag
    #
    # If 1, the lists in the listselect box are striped; otherwise not.

    option -liststripe \
        -default         1


    # -listwidth num
    #
    # Width in characters of the listselect box's lists.
    
    option -listwidth \
        -default         10

    #-------------------------------------------------------------------
    # Instance Variables

    # TBD

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the components.  There's really only a form,
        # that we'll populate when -rolespec changes.
        install form using form $win.form \
            -changecmd [mymethod FormChangeCmd]

        pack $form -side top -fill both -expand yes
        
        # NEXT, configure options
        $self configurelist $args
    }        

    #-------------------------------------------------------------------
    # Private Methods

    # FormChangeCmd field
    #
    # field   A field in the form, i.e., a role name.
    #
    # Called when the form's content changes.  
    #
    # * Sets the invalid flag for roles with no entities selected.
    # * Calls the client's change command

    method FormChangeCmd {field} {
        set fields [list]

        foreach {role value} [$form get] {
            if {[catch {gofer validate $value} result]} {
                lappend fields $role
            }
        }

        $form invalid $fields

        callwith $options(-changecmd) [$form get]
    }

    # UpdateDisplay
    #
    # This method is called when a new -rolespec 
    # value is given.  It clears any included values, and resets the
    # display.

    method UpdateDisplay {} {
        # FIRST, delete any existing content.
        $form clear

        # NEXT, add goferfields for each role
        foreach {role gtype} $options(-rolespec) {
            # NEXT, create the textfield
            $form field create $role $role gofer \
                -typename $gtype
        }

        # NEXT, layout the widget.
        $form layout

        # NEXT, all roles are initially invalid (no items are selected)
        $form invalid [dict keys $options(-rolespec)]
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method get to form
    delegate method set to form
}

# Register the goferfield(n) type with marsgui form(n)
::marsgui::form register gofer ::projectgui::goferfield


