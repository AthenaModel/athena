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

        my url /new.html [mymethod new.html]  {
            Creates a new, empty scenario, assigning it an id and longname.
            If {id} is given, it must be an existing scenario; the 
            scenario's contents will be reset to the empty state.
            If {longname} is given, the scenario will be given the new
            name.  On success, redirects to scenario index.
        }

        my url /new.json [mymethod new.json]  {
            Creates a new, empty scenario, assigning it an id and longname.
            If {id} is given, it must be an existing scenario; the 
            scenario's contents will be reset to the empty state.
            If {longname} is given, the scenario will be given the new
            name.  On success, returns a list ["OK", "{id}"].
        }

        my url /clone.json [mymethod clone.json]  {
            Clones existing scenario {id} as a new scenario, assigning
            it an id and longname.  If {newid} is given, it must be an 
            existing scenario other than {id}; the clone will replace
            the previous state of scenario {newid}.  Otherwise, a 
            {newid} will be chosen automatically.
            If {longname} is given, the scenario will be given the new
            name.  On success, returns a list ["OK", "{newid}"].
        }

        my url /import.json [mymethod import.json]  {
            Imports scenario {filename} and loads it into memory.
            The {filename} must name a file in the 
            <tt>-scenariodir</tt>.  If the {id} is given,
            the scenario will replace the existing scenario with that 
            ID; otherwise a new ID will be assigned.  
            If the {longname} is given, the scenario will
            be assigned that name.  On success, returns a list
            ["OK", "{id}"].
        }

        my url /export.json [mymethod export.json]  {
            Exports scenario {id} to the <tt>-scenariodir</tt> as
            {filename}.  The file type may be "<tt>.adb</tt>" for a
            standard Athena scenario file or "<tt>.tcl</tt>" for a
            scenario script.  If no file type is given, "<tt>.adb</tt>"
            is assumed.  On success, returns a list
            ["OK", "{filename}"].
        }

        my url /delete.json [mymethod delete.json]  {
            Deletes scenario {id} from the current session.
            On success, returns a list ["OK", "{message}"].
        }

        my url /diff.json [mymethod diff.json]  {
            Compares scenario {id2} with scenario {id1} looking 
            for significant differents in the outputs.  If {id2} is
            omitted, compares scenario {id1} at time 0 with itself
            at its latest time.  The scenarios must be comparable, 
            i.e., contain the same basic entities (groups, actors,
            etc.).  Returns ["ERROR", "{message}"] on error, and 
            and ["OK",{comparison}] otherwise.  See the 
            Arachne interface specification for a description of 
            the {comparison} object.<p>
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
        $hb h1 -style "background: red;" \
            "&nbsp;Arachne: Athena Regional Stability Simulation"   
    }

    method htmlFooter {hb} {
        $hb hr
        $hb putln "Athena Arachne [app version] - [clock format [clock seconds]]"
        $hb para
    }

    

    #-------------------------------------------------------------------
    # General Content

    # index.html
    #
    # sd       - The smartdomain object (e.g., [self])
    # qdict    - Query Dictionary
    #
    # Displays a list of the loaded scenarios.

    method index.html {sd qdict} {
        hb page "Scenarios"
        hb h1 "Scenarios"

        hb putln "The following scenarios are loaded ("
        hb iref /index.json json
        hb put )

        hb para

        hb table -headers {
            "ID" "Name" "Original Source" "State" "Tick" "Week"
        } {
            foreach case [case names] {
                set cdict [case metadata $case]
                hb tr {
                    hb td-with { 
                        hb putln <b>
                        hb iref /$case $case
                        hb put </b>
                    }
                    hb td [dict get $cdict longname]
                    hb td [dict get $cdict source]
                    hb td [dict get $cdict state]
                    hb td [dict get $cdict tick]
                    hb td [dict get $cdict week]
                }
            }
        }
        hb para

        return [hb /page]
    }

    # index.html
    #
    # sd       - The smartdomain object (e.g., [self])
    # qdict    - Query Dictionary
    #
    # Returns a JSON list of scenario metadata objects.

    method index.json {sd qdict} {
        set table [list]

        foreach case [case names] {
            set cdict [case metadata $case]
            dict set cdict url   "/scenario/$case/index.json"

            lappend table $cdict
        }

        return [js dictab $table]
    }

    #-------------------------------------------------------------------
    # Scenario Management

    # new.html
    #
    # sd       - The smartdomain object (e.g., [self])
    # qdict    - Query Dictionary
    #
    # Creates a new scenario (or resets an existing one), optionally
    # setting the longname.

    method new.html {sd qdict} {
        $qdict prepare id -tolower -in [case names]
        $qdict prepare longname
        $qdict assign id longname

        if {![$qdict ok]} {
            hb page "New Scenario"
            hb h1 "New Scenario"

            my dictpre [$qdict parms]

            hb putln "Cannot create a new scenario:"
            hb para
            my dictpre [$qdict errors]
            return [hb /page]
        }

        # NEXT, create it.
        case new $id $longname

        my redirect /scenario/index.html
        return
    }


    # new.json
    #
    # sd       - The smartdomain object (e.g., [self])
    # qdict    - Query Dictionary
    #
    # Creates a new scenario (or resets an existing one), optionally
    # setting the longname.  On success returns [OK,$theID] where 
    # $theID is the actual scenario ID, whether specified or generated.

    method new.json {sd qdict} {
        $qdict prepare id -tolower -in [case names]
        $qdict prepare longname
        $qdict assign id longname

        if {![$qdict ok]} {
            return [js reject [$qdict errors]]
        }

        # NEXT, create it.
        return [js ok [case new $id $longname]]
    }

    # clone.json
    #
    # sd       - The smartdomain object (e.g., [self])
    # qdict    - Query Dictionary
    #
    # Clones an existing scenario, possibly replacing an existing
    # scenario.  On success returns [OK,$theID] where 
    # $theID is the new scenario ID, whether specified or generated.

    method clone.json {sd qdict} {
        $qdict prepare id       -required -tolower -in [case names]
        $qdict prepare newid    -tolower -in [case names]
        $qdict prepare longname

        $qdict assign id newid longname

        $qdict checkon newid {
            if {$newid eq $id} {
                $qdict reject newid "Cannot clone scenario to itself"
            }            
        }

        if {![$qdict ok]} {
            return [js reject [$qdict errors]]
        }


        # NEXT, create it.
        return [js ok [case clone $id $newid $longname]]
    }

    # import.json
    #
    # sd       - The smartdomain object (e.g., [self])
    # qdict    - Query Dictionary
    #
    # Attempts to import a scenario into memory from an .adb or .tcl
    # $filename in -scenariodir, optionally overriding the $id and 
    # setting a $longname.  On success returns [OK,$theID] where 
    # $theID is the actual scenario ID, whether specified or generated.

    method import.json {sd qdict} {
        $qdict prepare filename -required
        $qdict prepare id -tolower -in [case names]
        $qdict prepare longname

        $qdict assign filename id longname

        if {![$qdict ok]} {
            return [js reject [$qdict errors]]
        }

        # NEXT, try to import it.
        try {
            set theID [case import $filename $id $longname]
        } trap {SCENARIO IMPORT} {result} {
            $qdict reject filename $result
            return [js reject [$qdict errors]]
        }

        return [js ok $theID]
    }
    
    # export.json
    #
    # sd       - The smartdomain object (e.g., [self])
    # qdict    - Query Dictionary
    #
    # Attempts to export a scenario to an .adb or .tcl
    # $filename in -scenariodir, defaulting to .adb.  On success returns 
    # [OK,$filename] where is the filename in -scenariodir.

    method export.json {sd qdict} {
        $qdict prepare id -required -tolower -in [case names]
        $qdict prepare filename -required
        $qdict assign id filename

        if {![$qdict ok]} {
            return [js reject [$qdict errors]]
        }

        # NEXT, try to export it.
        try {
            set theFileName [case export $id $filename]
        } trap {SCENARIO EXPORT} {result} {
            $qdict reject filename $result
            return [js reject [$qdict errors]]
        }

        return [js ok $theFileName]
    }

    # delete.json
    #
    # sd       - The smartdomain object (e.g., [self])
    # qdict    - Query Dictionary
    #
    # Creates a new scenario (or resets an existing one), optionally
    # setting the longname.  On success returns [OK,$theID] where 
    # $theID is the actual scenario ID, whether specified or generated.

    method delete.json {sd qdict} {
        $qdict prepare id -required -tolower -in [case names]

        $qdict assign id
       
        if {$id eq "case00"} {
            $qdict reject id "Cannot delete the base case"
        }


        if {![$qdict ok]} {
            return [js reject [$qdict errors]]
        }

        # NEXT, create it.
        case delete $id
        return [js ok "Deleted $id"]
    }

    # diff.json
    #
    # sd       - The smartdomain object (e.g., [self])
    # qdict    - Query Dictionary
    #
    # Compares scenario outputs and returns a list of significant 
    # differences.  If two scenarios are given, compares them at
    # the latest common time.  If one scenario is given, compares its
    # state at time 0 to its final state.  The scenarios must be
    # locked and idle with time advanced.
    #
    # On success, returns ["OK",{comparison}]

    method diff.json {sd qdict} {
        $qdict prepare id1 -required -tolower -in [case names]
        $qdict prepare id2           -tolower -in [case names]

        $qdict assign id1 id2
       
        if {![$qdict ok]} {
            return [js reject [$qdict errors]]
        }

        # Check for advanced time.
        # TBD: Add "case diff"?

        set s1 [case get $id1]

        if {![$s1 is advanced]} {
            $qdict reject id1 "Time has not been advanced"
        } elseif {[$s1 isbusy]} {
            $qdict reject id1 "Scenario is busy; please wait."
        }

        if {$id2 ne ""} {
            set s2 [case get $id2]

            if {![$s2 is advanced]} {
                $qdict reject id2 "Time has not been advanced"
            } elseif {[$s2 isbusy]} {
                $qdict reject id2 "Scenario is busy; please wait."
            }
        } else {
            set id2 $id1
            set s2 $s1
        }

        if {![$qdict ok]} {
            return [js reject [$qdict errors]]
        }

        # NEXT, do the comparison
        try {
            set comp [athena diff $s1 $s2]
        } trap {SCENARIO INCOMPARABLE} {result} {
            return [js error $result]
        }

        # NEXT, build the response.
        dict set result id1 $id1
        dict set result t1  [$comp t1]
        dict set result id2 $id2
        dict set result t2  [$comp t2]

        set hud [huddle compile dict $result]
        huddle set hud diffs [$comp diffs huddle]

        $comp destroy
        
        return [js ok $hud]
    }

    #-------------------------------------------------------------------
    # Order Handling

    # order.html
    #
    # name     - The scenario name
    # sd       - The smartdomain object (e.g., [self])
    # qdict    - Query dictionary
    #
    # Attempts to send an order specified as a query; returns results
    # as HTML.

    method order.html {name sd qdict} {
        # FIRST, do we have the scenario?
        set name [string tolower $name]

        if {$name ni [case names]} {
            throw NOTFOUND "No such scenario: \"$name\""
        }

        hb page "Order Result: '$name' scenario"
        hb h1 "Order Result: '$name' scenario"

        hb para

        # NEXT, send the order.
        try {
            my dictpre [$qdict parms]
            hb para
            hb hr
            set result [case send $name $qdict]
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
    # sd       - The smartdomain object (e.g., [self])
    # qdict    - Query dictionary
    #
    # Attempts to send an order specified as a query; returns results
    # as JSON.

    method order.json {name sd qdict} {
        # FIRST, do we have the scenario?
        set name [string tolower $name]

        if {$name ni [case names]} {
            throw NOTFOUND "No such scenario: \"$name\""
        }

        # NEXT, send the order.
        try {
            set result [case send $name $qdict]
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
    # sd       - The smartdomain object (e.g., [self])
    # qdict    - Query dictionary
    #
    # Attempts to execute a script specified as a query; returns results
    # as JSON.  The script is presumed to be text/plain in $data(query).

    method script.html {name sd qdict} {
        hb page "Script Entry: '$name' scenario"
        hb h1 "Script Entry: '$name' scenario"

        # FIRST, do we have the scenario?
        set name [string tolower $name]

        if {$name ni [case names]} {
            throw NOTFOUND "No such scenario: \"$name\""
        }

        # NEXT, set up the entry form.
        hb form -method post
        hb textarea script -rows 10 -cols 60
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
                set result [case with $name executive eval $script]
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
    # sd       - The smartdomain object (e.g., [self])
    # qdict    - Query dictionary
    #
    # Attempts to execute a script specified as a query; returns results
    # as JSON.  The script is presumed to be text/plain in $data(query),
    # as the result of a POST request.
    #
    # TBD: We might modify this after discussion with the web guys.

    method script.json {name sd qdict} {
        # FIRST, do we have the scenario?
        set name [string tolower $name]

        if {$name ni [case names]} {
            throw NOTFOUND "No such scenario: \"$name\""
        }

        set script [$sd query]

        # NEXT, evaluate the script.
        try {
            set result [case with $name executive eval $script]
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

