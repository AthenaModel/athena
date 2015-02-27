#-----------------------------------------------------------------------
# TITLE:
#    appserver_firing.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: firings
#
#    my://app/firings
#    my://app/firing/{id}
#
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# appserver module

appserver module firing {

    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /firings {firings/?}          \
            tcl/linkdict [myproc /firings:linkdict]      \
            text/html    [myproc /firings:html]          \
            "Links to all of the rule firings to date, with filtering."

        appserver register /firings/{dtype} {firings/(\w+)/?}  \
            text/html    [myproc /firings:html]                \
            "Links to all of the rule firings by rule set, with filtering."

        appserver register /firing/{id} {firing/(\w+)/?} \
            text/html [myproc /firing:html]            \
            "Detail page for rule firing {id}."
    }



    #-------------------------------------------------------------------
    # /firings:           All rule firings
    # /firings/{dtype}:   Firings by rule set
    #
    # Match Parameters:
    #
    # {dtype} ==> $(1)     - Driver type, i.e., rule set (optional)

    # /firings:linkdict udict matcharray
    #
    # Returns a /firings resource as a tcl/linkdict.  Only rule sets
    # for which rules have fired are included.  Does not handle
    # subsets or queries.

    proc /firings:linkdict {udict matchArray} {
        set result [dict create]

        adb eval {
            SELECT DISTINCT ruleset
            FROM rule_firings
            ORDER BY ruleset
        } {
            set url /firings/$ruleset

            dict set result $url label $ruleset
            dict set result $url listIcon ::projectgui::icon::orangeheart12
        }

        return $result
    }


    # /firings:html udict matchArray
    #
    # Tabular display of firing data; content depends on 
    # simulation state.
    #
    # The udict query is a "parm=value[+parm=value]" string with the
    # following parameters:
    #
    #    start       - Start time in ticks
    #    end         - End time in ticks
    #    page_size   - The number of items on a single page, or ALL.
    #    page        - The page number, 1 to N
    #
    # Unknown query parameters and invalid query values are ignored.


    proc /firings:html {udict matchArray} {
        upvar 1 $matchArray ""

        # FIRST, get the rule set, if any.
        set vars(ruleset) [string trim [string toupper $(1)]]

        if {$vars(ruleset) ne ""} {
            if {$vars(ruleset) ni [::athena::ruleset names]} {
                throw NOTFOUND "Unknown rule set: \"$vars(ruleset)\""
            }

            set label "$vars(ruleset)"
            set where {ruleset = $vars(ruleset)}
        } else {
            set label "All Rule Sets"
            set where ""
        }

        # Begin the page
        ht page "DAM Rule Firings ($label)"
        ht title "DAM Rule Firings ($label)"

        # NEXT, if we're not locked we're done.
        if {![locked -disclaimer]} {
            ht /page
            return [ht get]
        }

        appserver::firing query $udict vars $where

        ht /page

        return [ht get]
    }

    # query qdict whereArray expr
    #
    # udict       - The udict dictionary
    # varsArray   - The name of an array of variables required by the whereExpr.
    # expr        - An SQL expression to be ANDed into the WHERE clause.
    #
    # Writes a paged table of rule firings into the htools buffer.  The
    # firings will be limited by the where expression.
    #
    # The udict query is a "parm=value[+parm=value]" string with the
    # following parameters:
    #
    #    start       - Start time in ticks
    #    end         - End time in ticks
    #    page_size   - The number of items on a single page, or ALL.
    #    page        - The page number, 1 to N
    #
    # Unknown query parameters and invalid query values are ignored.

    typemethod query {udict varsArray expr} {
        upvar 1 $varsArray vars

        # NEXT, get the query parameters and bring them into scope.
        set qdict [GetFiringParms $udict]
        dict with qdict {}
        
        # NEXT, insert the control form.
        ht hr
        ht form -autosubmit 1
        ht label page_size "Page Size:"
        ht input page_size enum $page_size -src enum/pagesize -content tcl/enumdict
        ht label start 
        ht put "Time Interval &mdash; "
        ht link my://help/term/timespec "From:"
        ht /label
        ht input start text $start -size 12
        ht label end
        ht link my://help/term/timespec "To:"
        ht /label
        ht input end text $end -size 12
        ht submit
        ht /form
        ht hr
        ht para

        # NEXT, determine the WHERE clause for queries.
        set where {
            WHERE t >= $start_ AND t <= $end_
        }

        if {$expr ne ""} {
            append where "AND $expr\n"
        }


        # NEXT, get output stats
        set query {
            SELECT count(*) FROM gui_firings
        }

        append query $where

        set items [adb onecolumn $query]

        if {$page_size eq "ALL"} {
            set page_size $items
        }

        let pages {entier(ceil(double($items)/$page_size))}

        if {$page > $pages} {
            set page 1
        }

        let offset {($page - 1)*$page_size}

        ht putln "The selected time interval contains the following rule firings:"
        ht para

        # NEXT, show the page navigation
        ht pager [dict remove $qdict start_ end_] $page $pages

        set query {
            SELECT F.link                     AS "ID",
                   F.t                        AS "Tick",
                   timestr(F.t)               AS "Week",
                   D.link                     AS "Driver",
                   F.rule                     AS "Rule",
                   F.narrative                AS "Narrative"
            FROM gui_firings AS F
            JOIN gui_drivers AS D USING (driver_id)
        }

        append query $where
  
        append query {
            ORDER BY firing_id
            LIMIT $page_size OFFSET $offset
        }

        ht query $query -default "None." -align RRLRLL

        ht para

        ht pager [dict remove $qdict start_ end_] $page $pages
    }

    # GetFiringParms udict
    #
    # udict    - The URL dictionary, as passed to the handler
    #
    # Retrieves the parameter names using [querydict]; then
    # does the required validation and processing.
    # Where appropriate, cooked parameter values appear in the output
    # with a "_" suffix.
    
    proc GetFiringParms {udict} {
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

            restrict start_ {simclock timespec} [simclock cget -tick0]
            restrict end_   {simclock timespec} [simclock now]

            # If they picked the defaults, clear their entries.
            if {$start_ == [simclock cget -tick0]} { set start "" }
            if {$end_   == [simclock now]} { set end   "" }

            # NEXT, end_ can't be later than mystart.
            let end_ {max($start_,$end_)}
        }

        return $qdict
    }


    #-------------------------------------------------------------------
    # /firing/{id}: A single firing {id}
    #
    # Match Parameters:
    #
    # {id} => $(1)    - The firing's short name

    # /firing:html udict matchArray
    #
    # Detail page for a single firing {id}

    proc /firing:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Accumulate data
        set id $(1)

        if {![adb exists {SELECT * FROM rule_firings WHERE firing_id=$id}]} {
            return -code error -errorcode NOTFOUND \
                "Unknown entity: [dict get $udict url]."
        }

        # Begin the page
        adb eval {SELECT * FROM gui_firings WHERE firing_id=$id} data {}
        adb eval {
            SELECT * FROM gui_drivers
            WHERE driver_id = $data(driver_id)
        } ddata {}

        ht page "Rule Firing: $id"
        ht title "Rule Firing: $id" 

        set ruleTitle [ruleset $data(ruleset) rulename $data(rule)]

        ht record {
            ht field "Rule:" {
                ht put "<b>$data(rule)</b> -- $ruleTitle"
            }
            ht field "Detail:" {
                ht put $data(narrative)
            }
            ht field "Driver:" { 
                ht put "$ddata(link) -- $ddata(sigline)"
            }
            ht field "Week:"   { 
                ht put "[simclock toString $data(t)] (Tick $data(t))"
            }
        }

        ht para

        set ruleset [dict get $data(fdict) dtype]
        ruleset $ruleset detail $data(fdict) [namespace origin ht]

        ht para

        ht putln "The rule firing produced the following inputs:"
        ht para

        ht query {
            SELECT input_id AS "ID",
                   curve    AS "Curve",
                   mode     AS "P/T",
                   mag      AS "Mag",
                   note     AS "Note",
                   cause    AS "Cause",
                   s        AS "Here",
                   p        AS "Near",
                   q        AS "Far"
            FROM gui_inputs
            WHERE firing_id = $id
            ORDER BY input_id;
        } -align RLLRLLRRR

        ht /page

        return [ht get]
    }
}



