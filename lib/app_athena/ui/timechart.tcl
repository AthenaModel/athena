#-----------------------------------------------------------------------
# FILE: timechart.tcl
#
#   Athena Time Chart
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
# Widget: timechart
#
# The timechart(n) widget is a stripchart(n) that plots data for one or
# more time series variables.
#
#-----------------------------------------------------------------------

snit::widgetadaptor timechart {
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

    # Option: -from
    #
    # Start of time interval to display, in ticks, or "" for T0.

    option -from \
        -default         {}             \
        -configuremethod ConfigAndReset

    # Option: -to
    #
    # End of time interval to display, in ticks, or "" for NOW.

    option -to \
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
        installhull using stripchart     \
            -xtext       "Time"          \
            -xformatcmd  [myproc timestr] \
            -yformatcmd  moneyfmt
        
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
        notifier bind ::sim <Tick>      $win [mymethod update]
        notifier bind ::sim <DbSyncB>   $win [mymethod update]

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

        # Bookmarks not implemented
        if 0 {
            $mnu add separator

            $mnu add command \
                -state   disabled              \
                -label   "Bookmark this chart" \
                -command BookmarkChart
        }
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
        # FIRST, clear the content of the chart.
        $hull clear

        # NEXT, make sure the variables are still valid; strip out the
        # ones that aren't.
        set goodNames [list]

        foreach varname $options(-varnames) {
            if {[view t exists $varname]} {
                lappend goodNames $varname
            }
        }

        set options(-varnames) $goodNames


        # NEXT, get the view and the data.
        if {$options(-varnames) ne ""} {
            # FIRST, get the time interval.
            set conds [list]

            if {$options(-from) ne ""} {
                set ts $options(-from)
                lappend conds "t >= \$ts"
            } else {
                set ts 0
            }

            if {$options(-to) ne ""} {
                # Make sure that -to is greater than -from
                if {$options(-to) > $ts} {
                    set te $options(-to)
                } else {
                    let te {$ts + 1}
                }

                lappend conds "t <= \$te"
            }

            if {[llength $conds] > 0} {
                set where "WHERE [join $conds { AND }]"
            } else {
                set where ""
            }

            # NEXT, get the data
            foreach varname $options(-varnames) {
                set vdict($varname) [view t get $varname]
                set v [dict get $vdict($varname) view]

                set data($varname) [rdb eval "
                    SELECT t, x0 FROM $v $where ORDER BY t
                "]
            }
        }

        # NEXT, configure the chart and plot the data
        set unitList [list]

        set maxDecimals 0

        foreach varname $options(-varnames) {
            set vardict [dict get $vdict($varname) meta $varname]

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
            set ytext [join $unitList ", "]
        } else {
            set ytext "Right-click on chart to plot variables."

        }

        if {$maxDecimals > 2} {
            $hull configure \
                -ytext   $ytext              \
                -yformatcmd [list format %.${maxDecimals}f]
        } else {
            $hull configure \
                -ytext   $ytext              \
                -yformatcmd moneyfmt
        }
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
        # stripchart(n) widget; we need a way to query this.
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
                            time series variable to plot in this
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
        set varname [view t validate $varname]

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
                              time series chart.
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

    #-------------------------------------------------------------------
    # Group: Utility Procs


    proc timestr {t} {
        simclock toString [tcl::mathfunc::int $t]
    }
   

    #-------------------------------------------------------------------
    # Group: Public Methods

    delegate method *      to hull
    delegate method update to lu
}




