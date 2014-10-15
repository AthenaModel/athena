#-----------------------------------------------------------------------
# TITLE:
#    appserver_plot.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Tk plots and bar charts
#
#    my://app/plot/...
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module plot {
    #-------------------------------------------------------------------
    # Type Variables

    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /plot/time {plot/time/?}  \
            tk/widget [myproc /plot/time:widget] { Time Plot }
    }

    #-------------------------------------------------------------------
    # /plot/time?{query}:  Tk timecharts
    #
    # No match parameters

    # /plot/time:widget udict matcharray
    #
    # Returns a timechart widget displaying one or more time series
    # variables over a given time interval.  The plot to display is
    # determined by the query, which is a standard "parm=value+..."
    # query string:
    #
    #    start    - Time spec of start of interval; defaults to 0.
    #    end      - Time spec of end of interval; defaults to NOW.
    #    vars     - Comma-delimited list of variable names.

    proc /plot/time:widget {udict matchArray} {
        # FIRST, get the query parameters, and bring them into scope.
        set qdict [querydict $udict {start end vars}]
        dict with qdict {}

        # NEXT, validate the time interval
        restrict start {simclock timespec} [simclock cget -tick0]
        restrict end   {simclock timespec} [simclock now]

        let end {max($start,$end)}

        # NEXT, validate the variables
        set goodvars [list]

        foreach var [split $vars ","] {
            set name $var
            restrict var {view t} "" 
            if {$var eq ""} {
                return [list ttk::label %W \
                        -text "Unknown time series variable: $name"]
            }

            lappend goodvars $var
        }

        list ::timechart %W -from $start -to $end -varnames $goodvars
    }
}



