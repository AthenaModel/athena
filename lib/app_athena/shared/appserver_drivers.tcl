#-----------------------------------------------------------------------
# TITLE:
#    appserver_drivers.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Attitude Drivers
#
#    my://app/drivers/...
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module DRIVERS {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /drivers {drivers/?}     \
            tcl/linkdict [myproc /drivers:linkdict] \
            text/html    [myproc /drivers:html]     {
                A table displaying all of the attitude drivers to date.
            }

        appserver register /drivers/{dtype} {drivers/(\w+)/?} \
            text/html [myproc /drivers:html] {
                A table displaying all of the attitude drivers of
                the specified type.
            }

        appserver register /driver/{id} {driver/(\w+)/?} \
            text/html [myproc /driver:html] \
            "Details on the given driver and its rule firings"
    }

    #-------------------------------------------------------------------
    # /drivers:          All defined drivers
    # /drivers/{dtype}:  Drivers of a particular type 
    #
    # Match Parameters:
    #
    # {dtype} ==> $(1)     - Driver type (optional)


    # /drivers:linkdict udict matcharray
    #
    # Returns a /drivers resource as a tcl/linkdict.  Only driver
    # types for which rules have fired are included.  Does not handle
    # subsets or queries.

    proc /drivers:linkdict {udict matchArray} {
        set result [dict create]

        rdb eval {
            SELECT DISTINCT dtype
            FROM drivers
            JOIN rule_firings USING (driver_id)
            GROUP BY dtype
            ORDER BY dtype
        } {
            set url /drivers/$dtype

            dict set result $url label $dtype
            dict set result $url listIcon ::projectgui::icon::blackheart12
        }

        return $result
    }

    # /drivers:html udict matchArray
    #
    # Returns a page that lists the current attitude
    # drivers, possibly by driver type.

    proc /drivers:html {udict matchArray} {
        upvar 1 $matchArray ""

        # FIRST, get the driver type
        set dtype [string trim [string toupper $(1)]]

        if {$dtype ne ""} {
            if {$dtype ni [edamruleset names]} {
                throw NOTFOUND "Unknown driver type: \"$dtype\""
            }

            set label $dtype
        } else {
            set label "All"
        }

        # NEXT, set the page title
        ht page "Attitude Drivers ($label)"
        ht title "Attitude Drivers ($label)"

        # NEXT, get summary statistics
        rdb eval {
            DROP TABLE IF EXISTS temp_report_driver_contribs;

            CREATE TEMPORARY TABLE temp_report_driver_contribs AS
            SELECT driver_id                                        AS driver_id, 
                   CASE WHEN min(t) NOT NULL    
                        THEN timestr(min(t)) 
                        ELSE '' END                                 AS ts,
                   CASE WHEN max(t) NOT NULL    
                        THEN timestr(max(t)) 
                        ELSE '' END                                 AS te
            FROM drivers LEFT OUTER JOIN ucurve_contribs_t USING (driver_id)
            GROUP BY driver_id;
        }

        # NEXT, produce the query.
        set query {
            SELECT D.link       AS "Driver",
                   D.dtype      AS "Type",
                   D.sigline    AS "Signature",
                   T.ts         AS "Start Time",
                   T.te         AS "End Time"
            FROM gui_drivers AS D
            JOIN temp_report_driver_contribs AS T USING (driver_id)
        }

        if {$dtype ne ""} {
            append query "WHERE D.dtype=\$dtype\n"
        }

        append query "ORDER BY driver_id ASC"

        # NEXT, generate the report text
        ht query $query \
            -default "No drivers found." \
            -align   RLLRLL

        rdb eval {
            DROP TABLE temp_report_driver_contribs;
        }

        ht /page

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /driver/{id}: A single driver {id}
    #
    # Match Parameters:
    #
    # {id} => $(1)    - The driver's id

    # /driver:html udict matchArray
    #
    # Detail page for a single driver {id}

    proc /driver:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Accumulate data
        set id $(1)

        if {![rdb exists {SELECT * FROM drivers WHERE driver_id=$id}]} {
            return -code error -errorcode NOTFOUND \
                "Unknown entity: [dict get $udict url]."
        }

        # Begin the page
        rdb eval {SELECT * FROM gui_drivers WHERE driver_id=$id} data {}

        ht page "Driver: $id"
        ht title "Driver: $id, $data(dtype) -- $data(sigline)"

        # NEXT, if we're not locked we're done.
        if {![locked -disclaimer]} {
            ht /page
            return [ht get]
        }

        set vars(driver_id) $id
        set where {driver_id=$vars(driver_id)}

        appserver::firing query $udict vars $where

        ht para

        ht /page

        return [ht get]
    }
}




