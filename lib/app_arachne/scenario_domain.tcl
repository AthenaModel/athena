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

        my url /load.json  [mymethod load.json]  {
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

    method index.html {sd datavar qdict} {
        hb page "Scenarios"
        hb h1 "Scenarios"

        hb putln "The following scenarios are loaded ("
        hb iref /index.json json
        hb put )

        hb para

        hb table -headers {"ID" "Name" "State" "Tick" "Week"} {
            foreach case [case names] {
                set cdict [case getdict $case]
                hb tr {
                    hb td-with { 
                        hb putln <b>
                        hb iref /$case $case
                        hb put </b>
                    }
                    hb td [dict get $cdict longname]
                    hb td [dict get $cdict state]
                    hb td [dict get $cdict tick]
                    hb td [dict get $cdict week]
                }
            }
        }
        hb para

        hb h3 "Available Scenarios"

        set pattern [file join [case scenariodir] *.adb]
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

    method index.json {sd datavar qdict} {
        set table [list]

        foreach case [case names] {
            set cdict [case getdict $case]
            dict set cdict url   "/scenario/$case/index.json"

            lappend table $cdict
        }

        return [js dictab $table]
    }

    #-------------------------------------------------------------------
    # Scenario Management

    # load.json
    #
    # datavar  - ahttpd state array
    # qdict    - Query Dictionary
    #
    # Attempts to load a scenario into memory as scenario $id from
    # .adb or .tcl file $filename.

    method load.json {sd datavar qdict} {
        $qdict prepare id -required -tolower -ident -notin [app case names]
        $qdict prepare filename -required

        $qdict assign filename
        $qdict checkon filename {
            if {![file isfile [file join [app scenariodir] $filename]]} {
                $qdict reject filename "No such scenario is available."
            }
        }

        if {![$qdict ok]} {
            return [js reject [$qdict errors]]
        }

        return [js ok "Parms are valid!"]
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

    method order.html {sd name datavar qdict} {
        # FIRST, do we have the scenario?
        set name [string tolower $name]

        if {$name ni [app case names]} {
            throw NOTFOUND "No such scenario: \"$name\""
        }

        hb page "Order Result: '$name' scenario"
        hb h1 "Order Result: '$name' scenario"

        hb para

        # NEXT, get the parameters
        set order [$qdict prepare order_ -required -remove]

        if {$order eq ""} {
            hb h3 "Rejected"
            my dictpre [$qdict errors]
            return [hb /page]
        }

        # NEXT, send the order.
        try {
            hb h3 [string toupper $order]
            my dictpre [$qdict getdict]
            hb para
            hb hr

            set result \
                [app sdb $name order senddict normal $order [$qdict getdict]]
        } trap REJECT {result} {
            hb h3 "Rejected"
            my dictpre $result
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

    method order.json {sd name datavar qdict} {
        # FIRST, do we have the scenario?
        set name [string tolower $name]

        if {$name ni [app case names]} {
            throw NOTFOUND "No such scenario: \"$name\""
        }

        # NEXT, do we have the order?
        set order [$qdict prepare order_ -required -remove]

        if {![$qdict ok]} {
            return [js reject [$qdict errors]]
        }

        # NEXT, send the order.
        try {
            set result \
                [app sdb $name order senddict normal $order [$qdict getdict]]
        } trap REJECT {result} {
            return [js reject $result]
        } on error {result eopts} {
            return [js error $result [dict get $eopts -errorinfo]]
        }

        # NEXT, we were successful!
        return [js ok $result]
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

    method script.html {sd name datavar qdict} {
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

        set script [$qdict prepare script -required]

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

    method script.json {sd name datavar qdict} {
        upvar 1 $datavar data

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
            return [js error $result [dict get $eopts -errorinfo]]
        }

        # NEXT, we were successful!
        return [js ok $result]
    }

    #-------------------------------------------------------------------
    # Utility Methods.
    
    # dictpre qdict
    #
    # Formats a dictionary as a record of preformatted fields.

    method dictpre {qdict} {
        hb record
        dict for {key value} $qdict {
            hb field-with "<b>$key</b>:" { hb pre $value }
        }
        hb /record
    }

}

