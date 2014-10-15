#-----------------------------------------------------------------------
# TITLE:
#    sorterbin.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectgui(n), sorterbin(n): "bin" widget used as component of
#    sorter(n) widget.
#
#    This widget is a Tk radiobutton configured to look like a bin
#    for sorting items.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported Commands

namespace eval ::projectgui:: {
    # None at present; this is used by sorter(n).
}

#-----------------------------------------------------------------------
# sorterbin widget

snit::widgetadaptor ::projectgui::sorterbin {
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # Class Bindings

        # FIRST, prepare to hover
        bind Sorterbin <Enter> {%W SetBackground -hover}
        bind Sorterbin <Leave> {%W SetBackground}

    }
        
    #-------------------------------------------------------------------
    # Options

    delegate option -bin      to hull as -value
    delegate option -variable to hull

    delegate option * to hull
    
    # -title
    #
    # The bin's title string

    option -title \
        -configuremethod ConfigureText

    # -count items
    #
    # Number of items in bin

    option -count        \
        -default 0       \
        -configuremethod ConfigureText

    # -hover flag
    #
    # True when ready to drop on bin; false otherwise.

    option -hover \
        -default         0 \
        -configuremethod ConfigureText

    # -countlabel text
    #
    # The label for the item counter

    option -countlabel \
        -default "Items"


    method ConfigureText {opt val} {
        set options($opt) $val

        $hull configure \
            -text "$options(-title)\n$options(-countlabel): $options(-count)"

        $self SetBackground 
    }

    # -emptybackground color
    #
    # Background color when empty

    option -emptybackground \
        -default #99CCFF

    # -normalbackground color
    #
    # Background color given items

    option -normalbackground \
        -default #99FFFF

    # -hoverbackground color
    #
    # Background color given items

    option -hoverbackground \
        -default #EEFFEE

    #-------------------------------------------------------------------
    # Variables

    # TBD    
    
    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the widget

        installhull using radiobutton \
            -borderwidth         2                             \
            -highlightthickness  0                             \
            -offrelief           ridge                         \
            -padx                10                            \
            -pady                10                            \
            -indicatoron         no

        # NEXT, get the option values.
        $self configurelist $args
    }


    #-------------------------------------------------------------------
    # Private Methods

    # SetBackground ?-hover?
    #
    # Sets the background of the widget.  If -hover, uses -hover color.

    method SetBackground {{opt ""}} {
        if {$options(-hover)} {
            set bg $options(-hoverbackground)
        } elseif {$options(-count) == 0} {
            set bg $options(-emptybackground)
        } else {
            set bg $options(-normalbackground)
        }

        $hull configure -background  $bg
        $hull configure -selectcolor $bg
    }    

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull
    
}