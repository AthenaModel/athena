#-----------------------------------------------------------------------
# TITLE:
#   domain/scenario_sigevent.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# PACKAGE:
#   app_arachne(n): Arachne Implementation Package
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   /scenario/{case}/sigevent/*: /scenario handlers for significant
#   events data.
#
#-----------------------------------------------------------------------

#=======================================================================
# Helpers

oo::define /scenario {
    # SigeventsTable case start end
    #
    # case  - The validated case name
    # start - The start time in ticks
    # end   - The end time in ticks
    #
    # Formats a paged table of significant events based on the qdicts.
    # Assumes it has the following validated query parameters:
    #
    # * pagesize
    # * page

    method SigeventsTable {case start end} {
        # FIRST, get the query parms.
        qdict assign pagesize page

        # NEXT, constrain the time.
        if {$end < $start} {
            set end $start
        }

        set whereClause {WHERE t >= $start AND t <= $end}


        # NEXT, get the page statistics
        set items [case with $case onecolumn "
            SELECT count(*) FROM fmt_sigevents $whereClause
        "]

        lassign [hb pagestats $items $pagesize $page] \
            page pages offset limitClause

        # NEXT, get the real query


        set query "
            SELECT level, t, week, component, narrative 
            FROM fmt_sigevents
            $whereClause
            ORDER BY t DESC, event_id
            $limitClause
        "

        # NEXT, insert the pager
        hb pager $page $pages [qdict parms]

        hb push

        hb table -headers {"Week" "Date" "Model" "Narrative"} {
            case with $case eval $query {
                set narrative [my withlinks $case $narrative]

                # TBD: Consider defining CSS classes
                switch -- $level {
                    -1      { set bgcolor orange    }
                    0       { set bgcolor yellow    }
                    1       { set bgcolor white     }
                    default { set bgcolor lightgray }
                }

                hb tr {
                    hb td -align right $t
                    hb td $week
                    hb td $component
                    hb td -bgcolor $bgcolor $narrative
                }
            }
        }

        set text [hb pop]

        if {[hb rowcount] > 0} {
            hb putln $text
        } else {
            hb putln "No significant events occurred."
        }

        hb para

        hb pager $page $pages [qdict parms]

        hb para
    }
}

#=======================================================================
# URL Handlers

smarturl /scenario /{case}/sigevent/index.html {
    Displays information about scenario <i case>.
} {
    # FIRST, get the URL placeholder variables
    set case [my ValidateCase $case]

    # NEXT, get the query parameters.
    qdict prepare pagesize -default 20  -type epagesize
    qdict prepare page     -default 1   -type ipositive
    qdict prepare start    -default 0   -type [list case with $case clock timespec]
    qdict prepare end      -default NOW -type [list case with $case clock timespec]
    qdict assign pagesize page start end

    # NEXT, begin the page
    hb page "Significant Events: $case"
    my CaseNavBar $case

    hb h1 "Significant Events: $case"

    hb form -id pageform {
        hb enumlong pagesize       \
            -selected $pagesize    \
            -autosubmit pageform   \
            [epagesize deflist]
        my enumtick start $case    \
            -label    "From Week:" \
            -selected $start
        my enumtick end $case      \
            -extras   NOW          \
            -label    "To Week:"   \
            -selected $end
        hb submit
    }

    hb hr
    hb para

    hb putln {
        The following significant events occurred during the
        specified time interval. Events are sorted by descending time tick, 
        and then by order of occurrence within that time tick.
    }
    hb para

    my SigeventsTable $case $start $end

    return [hb /page]
}




