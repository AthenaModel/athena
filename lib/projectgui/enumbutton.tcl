#-----------------------------------------------------------------------
# TITLE:
#    enumbutton.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    enumbutton(n) package: button that pops up an enumerated
#    choice as a menu.
#
#-----------------------------------------------------------------------

namespace eval ::projectgui:: {
    namespace export enumbutton
}


#-----------------------------------------------------------------------
# Widget Definition

snit::widget ::projectgui::enumbutton {
    #-------------------------------------------------------------------
    # Type Constructor

    #-------------------------------------------------------------------
    # Options

    # Options delegated to the hull
    delegate option * to hull

    # -command cmd
    #
    # Command called when enum value is chosen; the selected value
    # is passed as an additional argument.

    option -command 

    # -enumlist list
    #
    # A list of enumerated values to choose from.  Sets -enumdict.

    option -enumlist \
        -configuremethod ConfigureEnumList \
        -readonly        yes

    method ConfigureEnumList {opt val} {
        set options($opt) $val

        set dict [dict create]

        foreach item $val {
            dict set dict $item $item
        }

        set options(-enumdict) $dict
    }

    # -enumdict dict
    # 
    # A dict of enumerated values and labels to choose from.

    option -enumdict \
        -readonly yes


    #-------------------------------------------------------------------
    # Components

    component btn   ;# The menubutton
    component menu  ;# The menu

    #-------------------------------------------------------------------
    # Instance Variables

    variable choice ""

    #--------------------------------------------------------------------
    # Constructor


    constructor {args} {
        $self configurelist $args

        install btn using ttk::button $win.button  \
            -style   Toolbutton               \
            -image   ::marsgui::icon::tridown \
            -command [mymethod PopupMenu]
    
        install menu using menu $win.button.menu

        dict for {symbol label} $options(-enumdict) {
            puts "Adding <$label> for $symbol"
            $menu add command \
                -label $label \
                -command [mymethod GotItem $symbol]
        }

        pack $btn -fill both
    }

    #-------------------------------------------------------------------
    # Private Methods

    # PopupMenu
    #
    # Pops up the menu.  Shouldn't have to do this, but menubuttons
    # are causing crashes.

    method PopupMenu {} {
        set  x [winfo rootx $btn]
        incr x [winfo width $btn]
        incr x -[winfo reqwidth $menu]
        set  y [winfo rooty $btn]
        incr y [winfo height $btn]
        tk_popup $menu $x $y
    }

    # GotItem symbol
    #
    # symbol   - One of the enumerated symbols
    #
    # Calls the user's callback with the given symbol.

    method GotItem {symbol} {
        set choice [dict get $options(-enumdict) $symbol]
        callwith $options(-command) $symbol
    }
}
