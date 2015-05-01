#-----------------------------------------------------------------------
# TITLE:
#    appserver_sigevents.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Significant Events
#
#    /app/image/...
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module SIGEVENTS {
    #-------------------------------------------------------------------
    # Type Variables

    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /sigevents {sigevents/?} \
            text/html [myproc /sigevents:html] {
                Significant simulation events for all entities.
                Query parameters include "start", "end", "page", and
                "page_size".
            }

        appserver register /sigevents/{entity} {sigevents/(\w+)/?} \
            text/html [myproc /sigevents:html] {
                Significant simulation events for the specific entity
                (neighborhood, actor, group, etc).
                Query parameters include "start", "end", "page", and
                "page_size".
            }
    }




    #-------------------------------------------------------------------
    # /sigevents                 - Significant Simulation Events
    # /sigevents/{entity}
    #
    # Match Parameters
    #
    # {entity} ==> $(1)   - entity name or ""

    # /sigevents:html udict matchArray
    #
    # Returns a text/html of significant events.

    proc /sigevents:html {udict matchArray} {
        upvar 1 $matchArray ""

        # FIRST, get the entity name.
        set entity [string toupper $(1)]

        # NEXT, get the query parameters and bring them into scope.
        set qdict [GetParms $udict]
        dict with qdict {}
        
        # Begin the page
        if {$entity eq ""} {
            set title "Significant Events"
        } else {
            set title "Significant Events: $entity"
        }

        ht page $title
        ht title $title

        # NEXT, insert the control form.
        # NOTE: This is identical to the one used in /app/firings.
        # Should be be generalized?
        ht hr
        ht form -autosubmit 1
        ht label page_size "Page Size:"
        ht input page_size enum $page_size -src enum/pagesize -content tcl/enumdict
        ht label start 
        ht put "Time Interval &mdash; "
        ht link /help/term/timespec "From:"
        ht /label
        ht input start text $start -size 12
        ht label end
        ht link /help/term/timespec "To:"
        ht /label
        ht input end text $end -size 12
        ht submit
        ht /form
        ht hr
        ht para

        ht putln {
            The following significant events occurred during the
            specified time interval. Events are sorted by descending time tick, 
            and then by order of occurrence within that time tick.
        }

        ht para

        appserver::SIGEVENTS FormatEventsTable $qdict $entity

        return [ht /page] 
    }

    # GetParms udict
    #
    # udict    - The URL dictionary, as passed to the handler
    #
    # Retrieves the parameter names; then
    # does the required validation and processing.
    # Where appropriate, cooked parameter values appear in the output
    # with a "_" suffix.
    #
    # TBD: This is exactly what /app/firings uses; should it to be
    # generalized?
    
    proc GetParms {udict} {
        # FIRST, get the query parameter dictionary.
        set query [dict get $udict query]
        set qdict [urlquery get $query {page_size page start end}]

        # NEXT, do the standard validation.
        dict set qdict start_ ""
        dict set qdict end_ ""

        dict with qdict {
            restrict page_size epagesize 20
            restrict page      ipositive 1

            # NEXT, get the user's time specs in ticks, or "".
            set start_ $start
            set end_   $end

            restrict start_ {adb clock timespec} [adb clock cget -tick0]
            restrict end_   {adb clock timespec} [adb clock now]

            # If they picked the defaults, clear their entries.
            if {$start_ == [adb clock cget -tick0]} { set start "" }
            if {$end_   == [adb clock now]} { set end   "" }

            # NEXT, end_ can't be later than mystart.
            let end_ {max($start_,$end_)}
        }

        return $qdict
    }

    # recent ?entity?
    #
    # Formats a table of "recent" sigevents into the ht buffer, i.e,
    # sigevents for the last five ticks.  The table is not paged.
    # If the "entity" is given, only sigevents relating to that entity
    # will be included.

    typemethod recent {{entity ""}} {
        dict set qdict start_ [adb clock now -5]
        dict set qdict end_ [adb clock now]
        dict set qdict page_size ALL
        dict set qdict page 1

        ht putln "The following are the significant events"

        if {$entity ne ""} {
            ht putln "involving $entity"
            set base /app/sigevents/$entity
        } else {
            set base /app/sigevents
        }

        ht putln "that occurred during the last 5 weeks."



        ht linkbar [list $base            "All Events" \
                         $base?start=RUN  "Last Run"]
        
        ht para

        appserver::SIGEVENTS FormatEventsTable $qdict $entity
    }

    # FormatEventsTable qdict entity
    # 
    # qdict    - A sigevents query dictionary containing at least
    #            start_, end_, page_size, page.
    #
    # Formats up a table of sigevents using the given parameters.

    typemethod FormatEventsTable {qdict entity} {
        dict with qdict {}

        # FIRST, determine the details of the query.
        set where {
            WHERE t >= $start_ AND t <= $end_
        }

        if {$entity eq ""} {
            set table gui_sigevents
        } else {
            set table gui_sigevents_wtag
            append where {
                AND tag=$entity
            }
        }

        # NEXT, get the number of pages in the output
        set query "SELECT count(*) FROM $table\n"
        append query $where

        set items [adb onecolumn $query]

        if {$page_size eq "ALL"} {
            set page_size $items
            let pages 1
        } else {
            let pages {entier(ceil(double($items)/$page_size))}
        }

        if {$page > $pages} {
            set page 1
        }

        let offset {($page - 1)*$page_size}

        # NEXT, get the real query
        set query "SELECT level, t, week, component, narrative FROM $table"
        append query $where
        append query {
            ORDER BY t DESC, event_id
        }
        append query "LIMIT $page_size OFFSET $offset"

        # NEXT, insert the pager
        ht pager [dict remove $qdict start_ end_] $page $pages

        ht push

        ht table {"Week" "Date" "Model" "Narrative"} {
            adb eval $query {
                ht tr {
                    ht td right {
                        ht put $t
                    }

                    ht td left {
                        ht put $week
                    }

                    ht td left {
                        ht put $component
                    }

                    if {$level == -1} {
                        ht putln "<td bgcolor=orange>"
                    } elseif {$level == 0} {
                        ht putln "<td bgcolor=yellow>"
                    } elseif {$level == 1} {
                        ht putln "<td>"
                    } else {
                        ht putln "<td bgcolor=lightgray>"
                    }

                    ht put $narrative

                    ht put "</td>"
                }
            }
        }

        set text [ht pop]

        if {[ht rowcount] > 0} {
            ht putln $text
        } else {
            ht putln "No significant events occurred."
        }

        ht para

        ht pager [dict remove $qdict start_ end_] $page $pages

        ht para
    }

}



