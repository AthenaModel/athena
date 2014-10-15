#-----------------------------------------------------------------------
# TITLE:
#    mapicon_situation.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    This module defines a generic situation icon for use with
#    mapcanvas(n).  It adheres to the mapicon(i) interface.
#
#-----------------------------------------------------------------------


snit::type ::mapicon::situation {
    #-------------------------------------------------------------------
    # Type Methods

    typemethod typename {} {
        return "situation"
    }

    #-------------------------------------------------------------------
    # Type Variables

    # Font to use for symbol text
    typevariable symfont {"Luxi Sans" -10}
    
    # Padding around text
    typevariable pad 2 

    #-------------------------------------------------------------------
    # Components

    component can         ;# The mapcanvas

    #-------------------------------------------------------------------
    # Instance variables

    variable drawn 0      ;# 1 if the icon has ever been drawn, 0 o.w.
    variable me           ;# The icon name in the mapcanvas: the 
                           # tail of the command name.
    variable tags {}      ;# Tags for all components of the icon

    #-------------------------------------------------------------------
    # Options

    # -text text
    #
    # Determines the text of the icon, typically the situation type.

    option -text \
        -default         ABSIT                   \
        -configuremethod ConfigureText

    method ConfigureText {opt val} {
        set options($opt) $val

        if {$drawn} {
            # Redraw the icon
            $self draw {*}[$self origin]
        }
    }

    # -foreground color

    option -foreground                        \
        -default         red                  \
        -configuremethod ConfigureForeground

    method ConfigureForeground {opt val} {
        set options($opt) $val

        if {$drawn} {
            $can itemconfigure $me&&shape  -outline $val
            $can itemconfigure $me&&symbol -fill    $val
        }
    }

    # -background color

    option -background                        \
        -default         yellow               \
        -configuremethod ConfigureBackground

    method ConfigureBackground {opt val} {
        set options($opt) $val

        if {$drawn} {
            $can itemconfigure $me&&shape -fill $val
        }
    }

    # -tags taglist
    #
    # Additional tags the icon should receive.

    option -tags \
        -configuremethod ConfigureTags

    method ConfigureTags {opt val} {
        set options($opt) $val

        set tags [list $me [$type typename] icon {*}$val]
    }




    #-------------------------------------------------------------------
    # Constructor

    constructor {mapcanvas cx cy args} {
        # FIRST, save the canvas and the name
        set can $mapcanvas
        set me [namespace tail $self]

        # NEXT, configure the options.  Force configuration of the tags.
        $self configure -tags {} {*}$args

        # NEXT, draw the icon.
        $self draw $cx $cy
    }

    destructor {
        catch {$can delete $me}
    }

    #-------------------------------------------------------------------
    # Public Methods

    # draw cx cy
    #
    # cx,cy      A location in canvas coordinates
    #
    # Draws the icon at the specified location using the current
    # option settings

    method draw {cx cy} {
        # FIRST, we've now drawn the icon at least once.
        set drawn 1

        # NEXT, delete the icon from its current location
        $can delete $me

        # NEXT, draw the icon
        if {$options(-text) ne ""} {
            set item [$can create text 0 0                \
                          -anchor sw                      \
                          -font $symfont                  \
                          -text $options(-text)           \
                          -fill $options(-foreground)     \
                          -tags [concat $tags symbol]]

            lassign [$can bbox $item] x1 y1 x2 y2

            set x1 [expr {$x1 - $pad}]
            set y1 [expr {$y1 - $pad}]
            set x2 [expr {$x2 + $pad}]
            set y2 [expr {$y2 + $pad}]
        } else {
            set x1   0
            set x2  10
            set y1 -10
            set y2   0
        }


        $can create rectangle $x1 $y1 $x2 $y2 \
            -width   2                        \
            -outline $options(-foreground)    \
            -fill    $options(-background)    \
            -tags    [concat $tags shape]

        if {$options(-text) ne ""} {
            $can raise $item
        }

        # NEXT, move it into place
        $can move $me $cx $cy
    }

    
    #-------------------------------------------------------------------
    # Public Meetings

    # origin
    #
    # Returns the current origin of the icon: the lower left point.

    method origin {} {
        set coords [$can coords $me&&shape]

        return [list [lindex $coords 0] [lindex $coords 3]]
    }
}

::marsgui::mapcanvas icon register ::mapicon::situation

