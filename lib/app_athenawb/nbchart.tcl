#-----------------------------------------------------------------------
# FILE: nbchart.tcl
#
#   Athena Neighborhood Bar Chart
#
# PACKAGE:
#   app_sim(n) -- athena_sim(1) implementation package
#
# PROJECT:
#   Athena S&RO Simulation
#
# AUTHOR:
#    Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

#-----------------------------------------------------------------------
# Widget: nbchart
#
# The nbchart(n) widget is an hbarchart(n) that plots data for one or
# more neighborhood variables.
#
#-----------------------------------------------------------------------

snit::widgetadaptor nbchart {
    #-------------------------------------------------------------------
    # Components

    # Component: lu
    #
    # Lazy updater; makes sure that the widget doesn't update itself
    # too often.
    
    component lu

    #-------------------------------------------------------------------
    # Group: Options
    # 
    # Unknown options are delegated to the hull

    delegate option * to hull

    # Option: -varnames
    #
    # List of variable names to plot.
    
    option -varnames \
        -default         {}             \
        -configuremethod ConfigAndReset

    # Method: ConfigAndReset
    #
    # Option configuration method; saves the option value, and 
    # reconfigures the underlying hbarchart.
    #
    # Syntax:
    #   ConfigAndReset _opt val_
    #
    #   opt - The option name
    #   val - The new value
   
    method ConfigAndReset {opt val} {
        # FIRST, save the option value.
        set options($opt) $val

        # NEXT, Reset the bar chart.
        $lu update
    }

    #-------------------------------------------------------------------
    # Group: Instance Variables

    # Variable: trans
    #
    # This is an array of transient data values
    #
    #  context - The %d value from the context click.

    variable trans -array {
        context {}
    }


 
    #--------------------------------------------------------------------
    # Group: Constructor/Destructor

    # Constructor: constructor
    #
    # Creates the widget given the options.

    constructor {args} {
        # FIRST, Install the hull
        installhull using hbarchart \
            -ylabels [list "no data"] \
            -ytext   "Neighborhoods"

        # NEXT, create the lazy updater
        install lu using lazyupdater ${selfns}::lu \
            -window   $win                         \
            -command  [mymethod Reset]
        
        # NEXT, get the options.
        $self configurelist $args

        # NEXT, create the context menu
        $self CreateContextMenu

        # NEXT, Tk bindings
        bind $win <<Context>> [mymethod ContextMenu %X %Y %d]

        # NEXT, bind to receive updates.
        # TBD: Do we want a new notifier event, to indicate that
        # neighborhood data in general might have changed?
        notifier bind ::adb       <Tick>    $win [mymethod UpdateEvent]
        notifier bind ::adb       <Sync> $win [mymethod UpdateEvent]
        notifier bind ::adb.demog <Update>  $win [mymethod UpdateEvent]
        notifier bind ::adb       <nbhoods> $win [mymethod UpdateEvent]
        notifier bind ::adb       <econ_n>  $win [mymethod UpdateEvent]
        notifier bind ::adb       <sat_gc>  $win [mymethod UpdateEvent]
        notifier bind ::adb       <coop_fg> $win [mymethod UpdateEvent]

        # NEXT, draw the chart.
        $lu update
    }

    # Method: CreateContextMenu
    #
    # Creates a context menu for the chart.

    method CreateContextMenu {} {
        set mnu [menu $win.context]
        set rem [menu $win.context.remvar]

        $mnu add command \
            -label   "Add Variable..." \
            -command [mymethod AddVariable]

        $mnu add cascade \
            -state   disabled                  \
            -label   "Remove Variable"         \
            -menu    $rem

        $mnu add command \
            -label   "Set Title..." \
            -command [mymethod SetTitle]

    }

    # Constructor: destructor
    #
    # Cancels all notifier(n) bindings.

    destructor {
        notifier forget $win
    }

    #-------------------------------------------------------------------
    # Private Methods

    # Method: Reset
    #
    # Reconfigures the hbarchart given the current options.  Sets
    # the xtext, ytext, min, max, and plots the data.

    method Reset {} {
        # FIRST, initialize the ylabels
        set ylabels [list]

        # NEXT, make sure the variables are still valid; strip out the
        # ones that aren't.
        set goodNames [list]

        foreach varname $options(-varnames) {
            if {[view n exists $varname]} {
                lappend goodNames $varname
            }
        }

        set options(-varnames) $goodNames

        # NEXT, get the view and the data.
        if {$options(-varnames) ne ""} {
            array set vdict [view n get $options(-varnames)]

            # NEXT, get the data
            foreach varname $options(-varnames) {
                set data($varname) [list]
            }

            adb eval "SELECT * FROM $vdict(view) ORDER BY n" row {
                lappend ylabels $row(n)
                
                for {set i 0} {$i < $vdict(count)} {incr i} {
                    lappend data([lindex $options(-varnames) $i]) $row(x$i)
                }
            }
        }

        if {[llength $ylabels] == 0} {
            set ylabels [list "no data"]
        }

        # NEXT, configure the chart and plot the data
        $hull configure \
            -ylabels $ylabels

        set unitList [list]

        set maxDecimals 0

        foreach varname $options(-varnames) {
            set vardict [dict get $vdict(meta) $varname]

            dict with vardict {
                ladd unitList $units
                
                if {$decimals > $maxDecimals} {
                    set maxDecimals $decimals
                }

                $hull plot $varname \
                    -data $data($varname) \
                    -rmin $rmin           \
                    -rmax $rmax
            }
        }

        if {[llength $unitList] > 0} {
            set xtext [join $unitList ", "]
        } else {
            set xtext "Right-click on chart to plot variables."

        }

        $hull configure \
            -xtext   $xtext              \
            -xformat "%.${maxDecimals}f"
    }

    # Method: ContextMenu
    #
    # Pops up the context menu at the current location.
    #
    # Syntax:
    #    ContextMenu X Y d
    #
    #    X,Y - Root window coordinates of click location (%X, %Y)
    #    d   - Context data (%d)
    
    method ContextMenu {X Y d} {
        # FIRST, save the context data
        set trans(context) $d

        # NEXT, enable/disable the Add Variable item based on the
        # number of plotted series.
        #
        # TBD: The limit is currently 10, as implemented by the
        # hbarchart(n) widget; we need a way to query this.
        if {[llength $options(-varnames)] < 10} {
            $win.context entryconfigure "Add*" -state normal
        } else {
            $win.context entryconfigure "Add*" -state disabled
        }

        # NEXT, enable/disable the Remove Variable item, and populate
        # the submenu.
        if {[llength $options(-varnames)] > 0} {
            $win.context entryconfigure "Remove *" \
                -state normal

            $win.context.remvar delete 0 end
            
            foreach varname $options(-varnames) {
                $win.context.remvar add command                 \
                    -label   $varname                           \
                    -command [mymethod RemoveVariable $varname]
            }
        } else {
            $win.context entryconfigure "Remove *" \
                -state disabled
        }

        tk_popup $win.context $X $Y
    }

    # Method: AddVariable
    #
    # Prompts the user to add a new variable to the 
    # plot.

    method AddVariable {} {
        set newVar [messagebox gets \
                        -oktext        "Add"                  \
                        -parent        $win                   \
                        -title         "Add Variable"         \
                        -validatecmd   [mymethod ValidateVar] \
                        -message       [normalize {
                            Please enter the name of a 
                            neighborhood variable to plot in this
                            chart.
                        }]]

        if {$newVar ne ""} {
            set varnames [$win cget -varnames]
            lappend varnames $newVar
            $win configure -varnames $varnames

            app puts "Added variable: $newVar"
        }
    }

    # Method: RemoveVariable
    #
    # Removes the selected variable from the chart.
    #
    # Syntax:
    #   RemoveVariable _varname_

    method RemoveVariable {varname} {
        # TBD: confirm?

        set varnames [$win cget -varnames]
        ldelete varnames $varname
        $win configure -varnames $varnames

        app puts "Removed variable: $varname"
    }

    # Method: ValidateVar
    #
    # Validates a neighborhood variable.  Returns the valid name
    #
    # Syntax:
    #   ValidateVar _varname_
    #
    #   varname - The variable name to validate
    
    method ValidateVar {varname} {
        # FIRST, is it a valid varname?
        set varname [view n validate $varname]

        # NEXT, is it already in use?
        if {$varname in [$win cget -varnames]} {
            return -code error -errorcode INVALID \
                "This variable is already plotted on this chart."
        }

        return $varname
    }

    # Method: SetTitle
    #
    # Prompts the user to enter a new title.

    method SetTitle {} {
        set newTitle [messagebox gets \
                          -oktext        "Set Title"              \
                          -initvalue     [$win cget -title]       \
                          -parent        $win                     \
                          -title         "Set Chart Title"        \
                          -validatecmd   [mymethod ValidateTitle] \
                          -message       [normalize {
                              Please enter a new title for this 
                              neighborhood bar chart.
                          }]]

        if {$newTitle ne ""} {
            $win configure -title $newTitle
        }
    }

    # Method: ValidateTitle
    #
    # Validates a chart title, which must contain at least one 
    # non-white-space character.  Returns the valid title.
    #
    # Syntax:
    #   ValidateTitle _text_
    #
    #   text - The title to validate
    
    method ValidateTitle {text} {
        if {$text eq ""} {
            return -code error -errorcode INVALID \
                "The title must contain at least one non-whitespace character."
        }

        return $text
    }

    # Method: UpdateEvent
    #
    # Calls update when an event is received.  Any arguments are ignored.

    method UpdateEvent {args} {
        $self update
    }
    

    #-------------------------------------------------------------------
    # Public Methods

    delegate method *      to hull
    delegate method update to lu
}


