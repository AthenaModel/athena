#-----------------------------------------------------------------------
# TITLE:
#   domain/scenario.tcl
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
#   /scenario: The smartdomain(n) for scenario data.
#
#   Additional URLs are defined in domain/scenario_*.tcl.
#
#-----------------------------------------------------------------------

oo::class create /scenario {
    superclass ::projectlib::smartdomain

    #-------------------------------------------------------------------
    # Constructor

    constructor {} {
        next /scenario

        # FIRST, configure the HTML buffer
        hb configure \
            -cssfile   "/athena.css"         \
            -headercmd [mymethod htmlHeader] \
            -footercmd [mymethod htmlFooter]
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
    # Utility Methods.

    # qdictdump
    #
    # Outputs the qdict contents and OK flag to stdout, for debugging.

    method qdictdump {} {
        puts "qdict ok? [qdict ok]: <[qdict parms]>"
    }
    
    # dictpre dict
    #
    # Formats a dictionary as a record of preformatted fields.

    method dictpre {dict} {
        hb record
        dict for {key value} $dict {
            hb field-with "<b>$key</b>:" { hb pre $value }
        }
        hb /record
    }

    # ErrorList message
    #
    # message - An overall error message
    #
    # Formats the qdict errors under the overall message.

    method ErrorList {message} {
        hb putln ""
        hb span -class error $message
        hb para

        hb ul

        foreach {parm msg} [qdict errors] {
            set value [dict get [qdict parms] $parm]
            hb li
            hb put $parm: 
            hb span -class error " $msg, \"$value\""
            hb /li
        }

        hb /ul
    }

    # ScenarioTable
    #
    # Adds a table of the existing scenarios to the page.

    method ScenarioTable {} {
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
    }

}
    

#-------------------------------------------------------------------
# General Content

smarturl /scenario /index.html {
    Displays a list of loaded scenarios, with various interactive
    controls.
} {
    hb page "Scenarios"
    hb h1 "Scenarios"
    hb para

    hb hr
    hb iref /new.html "New Scenario"
    hb put " | "
    hb iref /import.html "Import Scenario"
    hb hr

    hb putln "The following scenarios are loaded ("
    hb iref /index.json json
    hb put )

    hb para

    my ScenarioTable


    return [hb /page]
}

smarturl /scenario /index.json {
    Returns a JSON list of scenario metadata objects.
} {
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

smarturl /scenario /new.html {
    Creates a new, empty scenario, assigning it an id and longname.
    If {id} is given, it must be an existing scenario; the 
    scenario's contents will be reset to the empty state.
    If {longname} is given, the scenario will be given the new
    name.  On success, redirects to scenario index.
} {
    # FIRST, get the query parameters
    qdict prepare op -in {new}
    qdict prepare id -tolower -in [case names]
    qdict prepare longname
    qdict assign op id longname

    # NEXT, create a new scenario if the parms are OK and we were 
    # so requested.
    if {$op eq "new" && [qdict ok]} {
        case new $id $longname

        # Note: exits the method.
        my redirect /scenario/index.html
    }

    # NEXT, set up a form
    hb page "New Scenario"
    hb h1 "New Scenario"

    if {![qdict ok]} {
        my ErrorList "Could not create a new scenario:"
        hb hr
    }

    hb form
    hb hidden op new
    hb label longname "Long Name:"
    hb entry longname -size 15
    hb label id "Replacing:"
    hb enumlong id [linsert [case namedict] 0 "" ""]
    hb submit "New Scenario"
    hb submit -formaction [my domain]/new.json "JSON"
    hb /form
    hb para

    hb hr

    hb h2 "Existing Scenarios"

    my ScenarioTable

    return [hb /page]
}

smarturl /scenario /new.json {
    Creates a new, empty scenario, assigning it an id and longname.
    If {id} is given, it must be an existing scenario; the 
    scenario's contents will be reset to the empty state.
    If {longname} is given, the scenario will be given the new
    name.  On success, returns a list ["OK", "{id}"].
} {
    qdict prepare id -tolower -in [case names]
    qdict prepare longname
    qdict assign id longname

    if {![qdict ok]} {
        return [js reject [qdict errors]]
    }

    # NEXT, create it.
    return [js ok [case new $id $longname]]
}

smarturl /scenario /clone.json {
    Clones existing scenario {id} as a new scenario, assigning
    it an id and longname.  If {newid} is given, it must be an 
    existing scenario other than {id}; the clone will replace
    the previous state of scenario {newid}.  Otherwise, a 
    {newid} will be chosen automatically.
    If {longname} is given, the scenario will be given the new
    name.  On success, returns a list ["OK", "{newid}"].
} {
    qdict prepare id       -required -tolower -in [case names]
    qdict prepare newid    -tolower -in [case names]
    qdict prepare longname

    qdict assign id newid longname

    qdict checkon newid {
        if {$newid eq $id} {
            qdict reject newid "Cannot clone scenario to itself"
        }            
    }

    if {![qdict ok]} {
        return [js reject [qdict errors]]
    }


    # NEXT, create it.
    return [js ok [case clone $id $newid $longname]]
}

smarturl /scenario /import.json {
    Imports scenario {filename} and loads it into memory.
    The {filename} must name a file in the 
    <tt>-scenariodir</tt>.  If the {id} is given,
    the scenario will replace the existing scenario with that 
    ID; otherwise a new ID will be assigned.  
    If the {longname} is given, the scenario will
    be assigned that name.  On success, returns a list
    ["OK", "{id}"].
} {
    qdict prepare filename -required
    qdict prepare id -tolower -in [case names]
    qdict prepare longname

    qdict assign filename id longname

    if {![qdict ok]} {
        return [js reject [qdict errors]]
    }

    # NEXT, try to import it.
    try {
        set theID [case import $filename $id $longname]
    } trap {SCENARIO IMPORT} {result} {
        qdict reject filename $result
        return [js reject [qdict errors]]
    }

    return [js ok $theID]
}

smarturl /scenario /export.json {
    Exports scenario {id} to the <tt>-scenariodir</tt> as
    {filename}.  The file type may be "<tt>.adb</tt>" for a
    standard Athena scenario file or "<tt>.tcl</tt>" for a
    scenario script.  If no file type is given, "<tt>.adb</tt>"
    is assumed.  On success, returns a list
    ["OK", "{filename}"].
} {
    qdict prepare id -required -tolower -in [case names]
    qdict prepare filename -required
    qdict assign id filename

    if {![qdict ok]} {
        return [js reject [qdict errors]]
    }

    # NEXT, try to export it.
    try {
        set theFileName [case export $id $filename]
    } trap {SCENARIO EXPORT} {result} {
        qdict reject filename $result
        return [js reject [qdict errors]]
    }

    return [js ok $theFileName]
}

smarturl /scenario /delete.json {
    Deletes scenario {id} from the current session.
    On success, returns a list ["OK", "{message}"].
} {
    qdict prepare id -required -tolower -in [case names]

    qdict assign id
   
    if {$id eq "case00"} {
        qdict reject id "Cannot delete the base case"
    }


    if {![qdict ok]} {
        return [js reject [qdict errors]]
    }

    # NEXT, create it.
    case delete $id
    return [js ok "Deleted $id"]
}

smarturl /scenario /diff.json {
    Compares scenario {id2} with scenario {id1} looking 
    for significant differents in the outputs.  If {id2} is
    omitted, compares scenario {id1} at time 0 with itself
    at its latest time.  The scenarios must be comparable, 
    i.e., contain the same basic entities (groups, actors,
    etc.).  Returns ["ERROR", "{message}"] on error, and 
    and ["OK",{comparison}] otherwise.  See the 
    Arachne interface specification for a description of 
    the {comparison} object.<p>
} {
    qdict prepare id1 -required -tolower -in [case names]
    qdict prepare id2           -tolower -in [case names]

    qdict assign id1 id2
   
    if {![qdict ok]} {
        return [js reject [qdict errors]]
    }

    # Check for advanced time.
    # TBD: Add "case diff"?

    set s1 [case get $id1]

    if {![$s1 is advanced]} {
        qdict reject id1 "Time has not been advanced"
    } elseif {[$s1 isbusy]} {
        qdict reject id1 "Scenario is busy; please wait."
    }

    if {$id2 ne ""} {
        set s2 [case get $id2]

        if {![$s2 is advanced]} {
            qdict reject id2 "Time has not been advanced"
        } elseif {[$s2 isbusy]} {
            qdict reject id2 "Scenario is busy; please wait."
        }
    } else {
        set id2 $id1
        set s2 $s1
    }

    if {![qdict ok]} {
        return [js reject [qdict errors]]
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

smarturl /scenario /{name}/order.html {
    Accepts an order and its parameters.
    The query parameters are the order name as <tt>order_</tt>
    and the order-specific parameters as indicated in the on-line
    help.  The result of the order is returned as HTML text.<p>
} {
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
        my dictpre [qdict parms]
        hb para
        hb hr
        set result [case send $name [namespace current]::qdict]
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

smarturl /scenario /{name}/order.json {
    Accepts an order and its parameters.
    The query parameters are the order name as <tt>order_</tt>
    and the order-specific parameters as indicated in the on-line
    help.  The result of the order is returned as a JSON list 
    indicating the success of the request with related 
    information.<p>
} {
    # FIRST, do we have the scenario?
    set name [string tolower $name]

    if {$name ni [case names]} {
        throw NOTFOUND "No such scenario: \"$name\""
    }

    # NEXT, send the order.
    try {
        set result [case send $name [namespace current]::qdict]
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

smarturl /scenario /{name}/script.html {
    Accepts a Tcl script and attempts to
    execute it in the named scenario's executive interpreter.
    The result of running the script is returned.  The
    script should be the value of the <tt>script</tt> 
    query parameter, and should be URL-encoded.
} {
    hb page "Script Entry: '$name' scenario"
    hb h1 "Script Entry: '$name' scenario"

    # FIRST, do we have the scenario?
    set name [string tolower $name]

    if {$name ni [case names]} {
        throw NOTFOUND "No such scenario: \"$name\""
    }

    # NEXT, set up the entry form.
    hb form -smarturl /scenario /post
    hb textarea script -rows 10 -cols 60
    hb para
    hb submit "Execute"
    hb /form

    set script [qdict prepare script -required]

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


smarturl /scenario /{name}/script.json {
    Accepts a Tcl script as a POST query, and attempts to
    execute it in the named scenario's executive interpreter.
    The query data should be just the script itself with a
    content-type of text/plain.  The result of running the script 
    is returned in JSON format.
} {
    # FIRST, do we have the scenario?
    set name [string tolower $name]

    if {$name ni [case names]} {
        throw NOTFOUND "No such scenario: \"$name\""
    }

    set script [my query]

    # NEXT, evaluate the script.
    try {
        set result [case with $name executive eval $script]
    } on error {result eopts} {
        return [js error $result [dict get $eopts -errorinfo]]
    }

    # NEXT, we were successful!
    return [js ok $result]
}


