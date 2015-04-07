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
        ::projectlib::htmlbuffer create hb   \
            -domain    /scenario             \
            -cssfile   "/athena.css"         \
            -headercmd [mymethod htmlHeader] \
            -footercmd [mymethod htmlFooter]

        # NEXT, define content.  All urls are prefixed with /scenario.
        my url /index.html [mymethod index.html] {List of open scenarios}
        my url /index.json [mymethod index.json] {List of open scenarios}

        my url /load.html  [mymethod load.html]  {
            Load a scenario into memory given the <tt>id</tt> and 
            <tt>filename</tt>.  The <tt>id</tt> must be unused, and the
            <tt>filename</tt> must name a file in the <tt>-scenariodir</tt>.
        }

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

    method htmlHeader {hb title} {
        # TBD
    }

    method htmlFooter {hb} {
        $hb hr
        $hb putln "Athena Arachne [app version] - [clock format [clock seconds]]"
        $hb para
    }

    

    #-------------------------------------------------------------------
    # General Content

    method index.html {datavar qdict} {
        hb page "Scenarios"
        hb h1 "Scenarios"

        hb putln "The following scenarios are loaded ("
        hb iref /index.json json
        hb put )

        hb para

        hb table -headers {"ID" "State" "Tick" "Week"} {
            foreach case [app case names] {
                hb tr {
                    hb td-with { 
                        hb putln <b>
                        hb iref /$case $case
                        hb put </b>
                    }
                    hb td [app sdb $case state]
                    hb td [app sdb $case clock now]
                    hb td [app sdb $case clock asString]
                }
            }
        }
        hb para

        hb h3 "Available Scenarios"

        set pattern [file join [app scenariodir] *.adb]
        set names [glob -nocomplain $pattern]

        if {[llength $names] == 0} {
            hb putln "None available."
        } else {
            hb table {
                foreach name $names {
                    set name [file tail $name]
                    set id [file root $name]

                    if {$id in [app case names]} {
                        set id ""
                    }

                    hb tr {
                        hb td <tt>$name</tt>
                        hb td-with {
                            hb form -action /scenario/load.html
                            hb submit "Load"
                            hb label id "As:"
                            hb entry id -max 20 -value $id
                            hb hidden filename $name
                            hb /form
                        }
                    }
                }
            }
        }

        hb para


        return [hb /page]
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
    # Scenario Management

    # load.html
    #
    # datavar  - ahttpd state array
    # qdict    - Query Dictionary
    #
    # Attempts to load a scenario into memory.

    method load.html {datavar qdict} {
        hb page "Load Scenario"

        hb record {
            hb field "ID:"        <tt>$id</tt>
            hb field "File Name:" <tt>$filename</tt>
        }

        hb para

        if {$id eq ""} {
            hb putln "Error, no ID specified."
            return [hb /page]
        }

        if {$id in [app case names]} {
            hb putln "Error, duplicate ID."
            return [hb /page]
        }

        if {$filename eq ""} {
            hb putln "Error, no filename specified."
            return [hb /page]
        }

        if {![file isfile [file join [app scenariodir] $filename]]} {
            hb putln "Error, no such scenario is available."
            return [hb /page]
        }

        hb putln "Found scenario."

        return [hb /page]
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
            hb page "Order Result"
            hb h1 "Order Result"
            hb putln "Error, no <tt>order_</tt> specified in query.<p>"
            return [hb /page]
        }

        # NEXT, get the parameters
        set order [dict get $qdict order_]
        set qdict [dict remove $qdict order_]

        # NEXT, send the order.
        try {
            hb page "Order Result: '$name' scenario"
            hb h1 "Order Result: '$name' scenario"

            hb para
            hb h3 [string toupper $order]
            my PreDict $qdict
            hb para
            hb hr

            set result [app sdb $name order senddict normal $order $qdict]
        } trap REJECT {result} {
            hb h3 "Rejected"
            my PreDict $result
            return [hb /page]
        } on error {result eopts} {
            hb h3 "Unexpected Application Error:"
            hb putln $result
            hb para
            hb pre [dict get $eopts -errorinfo]

            return [hb /page]
        }

        # NEXT, we were successful!

        if {$result eq ""} {
            hb h3 "Accepted"
        } else {
            hb h3 "Accepted"
            hb pre $result
        }

        return [hb /page]
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

        hb page "Script Entry: '$name' scenario"
        hb h1 "Script Entry: '$name' scenario"

        # FIRST, do we have the scenario?
        set name [string tolower $name]

        if {$name ni [app case names]} {
            throw NOTFOUND "No such scenario: \"$name\""
        }

        # NEXT, set up the entry form.
        hb form -method post
        hb textarea -name script -rows 10 -cols 60
        hb para
        hb submit "Execute"
        hb /form

        set script ""

        if {[dict exists $qdict script]} {
            set script [dict get $qdict script]
        }

        hb h3 "Script:"

        if {$script ne ""} {
            hb pre $script
        } else {
            hb putln "Enter a script in the text area, above."
        }

        # NEXT, send the order.
        if {$script ne ""} {
            try {
                set result [app sdb $name executive eval $script]
            } on error {result eopts} {
                hb h3 "Error in Script:"

                hb putln $result
                hb para
                hb pre [dict get $eopts -errorinfo]

                return [hb /page]
            }

            hb h3 "Result:"

            if {$result ne ""} {
                hb pre $result
            } else {
                hb putln "The script had no return value."
            }
        }


        return [hb /page]
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
    # TBD: We mighb modify this after discussion with the web guys.

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
    
    # PreDict qdict
    #
    # Formats a dictionary as a record of preformatted fields.

    method PreDict {qdict} {
        hb record
        dict for {key value} $qdict {
            hb field-with "<b>$key</b>:" { hb pre $value }
        }
        hb /record
    }
}

