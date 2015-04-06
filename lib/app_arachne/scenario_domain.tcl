#-----------------------------------------------------------------------
# TITLE:
#   scenario_domain.tcl
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
#   scenario_domain: The smartdomain(n) for scenario data.
#
#-----------------------------------------------------------------------

oo::class create scenario_domain {
    superclass ::projectlib::smartdomain

    #-------------------------------------------------------------------
    # Constructor

    constructor {} {
        next /scenario

        # FIRST, define helpers
        htools ht \
            -cssfile   "/athena.css"         \
            -headercmd [mymethod htmlHeader] \
            -footercmd [mymethod htmlFooter]

        # NEXT, define content.  All urls are prefixed with /scenario.
        my url /index.html [mymethod index.html] {List of open scenarios}
        my url /index.json [mymethod index.json] {List of open scenarios}

        my url /{name}/order.html [mymethod order.html] {
            Accepts an order and its parameters as a PUT query.
            The query parameters are the order name as <tt>order_</tt>
            and the order-specific parameters as indicated in the on-line
            help.  The result of the order is returned as HTML text.<p>
        }
        my url /{name}/order.json [mymethod order.json] {
            Accepts an order and its parameters as a PUT query.
            The query parameters are the order name as <tt>order_</tt>
            and the order-specific parameters as indicated in the on-line
            help.  The result of the order is returned as a JSON list 
            indicating the success of the request with related 
            information.<p>
        }

        my url /{name}/script.html [mymethod script.html] {
            Accepts a Tcl script and attempts to
            execute it in the named scenario's executive interpreter.
            The result of running the script is returned.  The
            script should be the value of the <tt>script</tt> 
            query parameter, and should be URL-encoded.
        }

        my url /{name}/script.json [mymethod script.json] {
            Accepts a Tcl script as a POST query, and attempts to
            execute it in the named scenario's executive interpreter.
            The query data should be just the script itself with a
            content-type of text/plain.  The result of running the script 
            is returned in JSON format.
        }
    }            

    #-------------------------------------------------------------------
    # Header and Footer

    method htmlHeader {title} {
        # TBD
    }

    method htmlFooter {} {
        # TBD
    }

    

    #-------------------------------------------------------------------
    # General Content

    method index.html {datavar qdict} {
        ht page "Scenarios"
        ht title "Scenarios"

        ht putln "The following scenarios are loaded:"
        ht para

        ht table {"ID" "State" "Tick" "Week"} {
            foreach case [app case names] {
                ht tr {
                    ht td left { 
                        ht putln <b>
                        ht link /scenario/$case $case
                        ht put </b>
                    }
                    ht td left { ht putln [app sdb $case state]          }
                    ht td left { ht putln [app sdb $case clock now]      }
                    ht td left { ht putln [app sdb $case clock asString] }
                }
            }
        }

        ht para
        ht putln (
        ht link /scenario/index.json json
        ht put )

        return [ht /page]
    }

    method index.json {datavar qdict} {
        set hud [huddle list]

        foreach case [app case names] {
            dict set dict id $case
            dict set dict url   "/scenario/$case/index.json"
            dict set dict state [app sdb $case state]
            dict set dict tick  [app sdb $case clock now]
            dict set dict week  [app sdb $case clock asString]

            huddle append hud [huddle compile dict $dict]
        }

        return [huddle jsondump $hud]
    }

    #-------------------------------------------------------------------
    # Order Handling

    # order.html
    #
    # name     - The scenario name
    # datavar  - ahttpd state array
    # qdict    - Query dictionary
    #
    # Attempts to send an order specified as a query; returns results
    # as HTML.

    method order.html {name datavar qdict} {
        # FIRST, do we have the scenario?
        set name [string tolower $name]

        if {$name ni [app case names]} {
            throw NOTFOUND "No such scenario: \"$name\""
        }

        # NEXT, do we have the order?
        if {![dict exist $qdict order_]} {
            ht page "Order Result"
            ht title "Order Result"
            ht putln "Error, no <tt>order_</tt> specified in query.<p>"
            return [ht /page]
        }

        # NEXT, get the parameters
        set order [dict get $qdict order_]
        set qdict [dict remove $qdict order_]

        # NEXT, send the order.
        try {
            ht page "Order Result: '$name' scenario"
            ht title "Order Result: '$name' scenario"

            ht para
            ht h3 [string toupper $order]
            my HtmlDictFields $qdict
            ht para
            ht hr

            set result [app sdb $name order senddict normal $order $qdict]
        } trap REJECT {result} {
            ht h3 "Rejected"
            my HtmlDictFields $result
            return [ht /page]
        } on error {result eopts} {
            ht h3 "Unexpected Application Error:"
            ht putln $result
            ht para
            ht pre [dict get $eopts -errorinfo]

            return [ht /page]
        }

        # NEXT, we were successful!

        if {$result eq ""} {
            ht h3 "Accepted"
        } else {
            ht h3 "Accepted"
            ht pre $result
        }

        return [ht /page]
    }

    # order.json
    #
    # name     - The scenario name
    # datavar  - ahttpd state array
    # qdict    - Query dictionary
    #
    # Attempts to send an order specified as a query; returns results
    # as JSON.

    method order.json {name datavar qdict} {
        set hud [huddle list]

        # FIRST, do we have the scenario?
        set name [string tolower $name]

        if {$name ni [app case names]} {
            throw NOTFOUND "No such scenario: \"$name\""
        }

        # NEXT, do we have the order?
        if {![dict exist $qdict order_]} {
            huddle append hud "REJECT"
            huddle append hud "No order_ in query"
            return [huddle jsondump $hud]
        }

        # NEXT, get the parameters
        set order [dict get $qdict order_]
        set qdict [dict remove $qdict order_]

        # NEXT, send the order.
        try {
            set result [app sdb $name order senddict normal $order $qdict]
        } trap REJECT {result} {
            huddle append hud "REJECT"
            huddle append hud [huddle compile dict $result]
            return [huddle jsondump $hud]
        } on error {result eopts} {
            huddle append hud "ERROR"
            huddle append hud $result
            huddle append hud [dict get $eopts -errorinfo] 
            return [huddle jsondump $hud]
        }

        # NEXT, we were successful!
        huddle append hud "OK"
        huddle append hud $result
        return [huddle jsondump $hud]
    }

    #-------------------------------------------------------------------
    # Script Handling

    # script.html
    #
    # name     - The scenario name
    # datavar  - ahttpd state array
    # qdict    - Query dictionary
    #
    # Attempts to execute a script specified as a query; returns results
    # as JSON.  The script is presumed to be text/plain in $data(query).

    method script.html {name datavar qdict} {
        upvar 1 $datavar data

        ht page "Script Entry: '$name' scenario"
        ht title "Script Entry: '$name' scenario"

        # FIRST, do we have the scenario?
        set name [string tolower $name]

        if {$name ni [app case names]} {
            throw NOTFOUND "No such scenario: \"$name\""
        }

        # NEXT, set up the entry form.
        ht form -action "/scenario/$name/script.html" -method post
        ht putln "<textarea rows=10 cols=60 name=\"script\"></textarea><br>"
        ht putln "<input type=\"submit\" value=\"Execute\">"
        ht /form

        set script ""

        if {[dict exists $qdict script]} {
            set script [dict get $qdict script]
        }

        ht h3 "Script:"

        if {$script ne ""} {
            ht pre $script
        } else {
            ht putln "Enter a script in the text area, above."
        }

        # NEXT, send the order.
        if {$script ne ""} {
            try {
                set result [app sdb $name executive eval $script]
            } on error {result eopts} {
                ht h3 "Error in Script:"

                ht putln $result
                ht para
                ht pre [dict get $eopts -errorinfo]

                return [ht /page]
            }

            ht h3 "Result:"

            if {$result ne ""} {
                ht pre $result
            } else {
                ht putln "The script had no return value."
            }
        }


        return [ht /page]
    }

    
    # script.json
    #
    # name     - The scenario name
    # datavar  - ahttpd state array
    # qdict    - Query dictionary
    #
    # Attempts to execute a script specified as a query; returns results
    # as JSON.  The script is presumed to be text/plain in $data(query),
    # as the result of a POST request.
    #
    # TBD: We might modify this after discussion with the web guys.

    method script.json {name datavar qdict} {
        upvar 1 $datavar data

        set hud [huddle list]

        # FIRST, do we have the scenario?
        set name [string tolower $name]

        if {$name ni [app case names]} {
            throw NOTFOUND "No such scenario: \"$name\""
        }

        set script $data(query)

        # NEXT, evaluate the script.
        try {
            set result [app sdb $name executive eval $script]
        } on error {result eopts} {
            huddle append hud "ERROR"
            huddle append hud $result
            huddle append hud [dict get $eopts -errorinfo] 
            return [huddle jsondump $hud]
        }

        # NEXT, we were successful!
        huddle append hud "OK"
        huddle append hud $result
        return [huddle jsondump $hud]
    }

    #-------------------------------------------------------------------
    # Utility Methods.
    
    # HtmlDictFields qdict
    #
    # Formats a dictionary as a list of fields in a record.

    method HtmlDictFields {qdict} {
        ht record
        dict for {key value} $qdict {
            ht field "<b>$key</b>:" { ht pre $value }
        }
        ht /record
    }
}

