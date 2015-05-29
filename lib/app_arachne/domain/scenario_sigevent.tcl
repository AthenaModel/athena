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
    # SigeventsTable case
    #
    # case  - The validated case name
    #
    # Formats a paged table of significant events based on the qdicts.
    # Assumes it has the following validated query parameters:
    #
    # * pagesize
    # * page

    method SigeventsTable {case} {
        # FIRST, get the query parms.
        qdict assign pagesize page

        # NEXT, get the number of pages in the output
        set query "SELECT count(*) FROM fmt_sigevents"

        set items [case with $case onecolumn $query]

        # TBD: mighb want a maximum size for ALL.
        # TBD: the code for computing the number of pages and the
        # offset should probably go elsewhere.
        if {$pagesize eq "ALL"} {
            set pagesize $items
            let pages 1
        } else {
            let pages {entier(ceil(double($items)/$pagesize))}
        }

        # NEXT, don't ask for an invalid page
        if {$page > $pages} {
            set page 1
        }

        let offset {($page - 1)*$pagesize}

        # NEXT, get the real query
        set query {
            SELECT level, t, week, component, narrative 
            FROM fmt_sigevents
            ORDER BY t DESC, event_id
        }

        # TBD: This could be added automatically to a longer query.
        # Consider "pagedquery" command
        append query "LIMIT $pagesize OFFSET $offset"

        # NEXT, insert the pager
        # hb pager [qdict parms] $page $pages

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

        # hb pager [qdict parms] $page $pages

        hb para
    }
}

#=======================================================================
# URL Handlers

smarturl /scenario /{case}/sigevent/index.html {
    Displays information about scenario {case}.
} {
    # FIRST, get the URL placeholder variables
    set case [my ValidateCase $case]

    # NEXT, get the query parameters.
    qdict prepare pagesize -default 20 -type epagesize
    qdict prepare page     -default 1  -type ipositive
    qdict assign pagesize page

    # NEXT, begin the page
    hb page "Significant Events: $case"
    hb h1 "Significant Events: $case"

    my CaseNavBar $case

    hb form {
        hb enumlong pagesize -selected $pagesize [epagesize deflist]
        # TBD: Add time interval
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

    my SigeventsTable $case

    return [hb /page]
}




