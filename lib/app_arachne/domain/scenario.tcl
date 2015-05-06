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

    # ScenarioTable ?-radio name?
    #
    # Adds a table of the existing scenarios to the page.
    # If -radio is given, the first column contains radio buttons
    # with the given name.

    method ScenarioTable {args} {
        # FIRST, get the options
        set rparm     ""
        set omissions {}

        foroption opt args -all {
            -radio { set rparm [lshift args] }
            -omit  { set omissions [lshift args]}
        }

        # NEXT, get the list of scenarios.
        # TBD: Need a filter method
        set cases [list]

        foreach case [case names] {
            if {$case ni $omissions} {
                lappend cases $case
            }
        }

        if {[llength $cases] == 0} {
            hb putln "There are no available scenarios."
            hb para
            return
        }

        # NEXT, get the headers.
        set headers {
            "ID" "Name" "Original Source" "State" "Tick" "Week"
        }

        if {$rparm ne ""} {
            set headers [linsert $headers 0 ""]
        }

        # NEXT, format the table.

        hb table -headers $headers {
            foreach case $cases {
                set cdict [case metadata $case]
                hb tr {
                    if {$rparm ne ""} {
                        hb td-with { hb radio $rparm $case }
                    }
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

    # FileTable ?-radio name?
    #
    # Adds a table of files in the -scenariodir to the page.
    # If -radio is given, the first column contains radio buttons
    # with the given name.

    method FileTable {args} {
        # FIRST, get the options
        set rparm ""

        foroption opt args -all {
            -radio { set rparm [lshift args] }
        }

        # NEXT, get the headers.
        set headers {
            "File Name" "Size" "Last Modified"
        }

        if {$rparm ne ""} {
            set headers [linsert $headers 0 ""]
        }

        # NEXT, get the files from the -scenariodir.
        set filenames [glob \
                        -nocomplain \
                        -tails      \
                        -directory [case scenariodir] \
                        *.adb *.tcl]

        # NEXT, format the table.
        if {[llength $filenames] == 0} {
            hb putln "No files found."
        } else {
            hb table -headers $headers {
                foreach name $filenames {
                    set fullname [case scenariodir $name]
                    hb tr {
                        if {$rparm ne ""} {
                            hb td-with {hb radio $rparm $name}
                        }
                        hb td $name
                        hb td [file size $fullname]
                        hb td [clock format [file mtime $fullname]]
                    }
                }
            }
        }
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
    hb iref /new.html "New"
    hb put " | "
    hb iref /clone.html "Clone"
    hb put " | "
    hb iref /import.html "Import"
    hb put " | "
    hb iref /export.html "Export"
    hb put " | "
    hb iref /remove.html "Remove"
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
    Presents a page that allows the user to create a new, empty 
    scenario.<p>

    If {op} is "new", then a new scenario is created and assigned
    an ID and long name, and the server redirects to the scenario
    index.  If {id} is given, it must be an existing scenario; the 
    scenario's contents will be reset to the empty state.
    If {longname} is given, the scenario will be given the new
    name.<p>

    If {op} is "", the page displays the information and form needed
    to create a new scenario.  The parameters may be submitted to the
    same page, or to the JSON interface.<p>
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

smarturl /scenario /clone.html {
    Presents a page that allows the user to clone a scenario.<p>

    If {op} is "clone", then scenario {source} is cloned as a new scenario
    and assigned an ID and long name, and the server redirects to the 
    scenario index.  If {target} is given, it must be the ID of an
    existing scenario; the scenario's contents will be replaced with the 
    cloned data.  If {longname} is given, the cloned scenario will be given 
    the new long name.<p>

    If {op} is "", the page displays the information and form needed
    to clone a scenario, including a list of the available scenario. 
    The parameters may be submitted to the same page, or to 
    the JSON interface.<p>
} {
    # FIRST, get the query parameters
    qdict prepare op -in {clone}
    qdict prepare source -required -tolower -in [case names]
    qdict prepare target -tolower -in [case names]
    qdict prepare longname
    qdict assign op source target longname

    qdict checkon target {
        if {$target eq $source} {
            qdict reject target "Cannot clone scenario to itself"
        }            
    }


    # NEXT, clone the scenario if the parms are OK and we were 
    # so requested.
    if {$op eq "clone" && [qdict ok]} {
        case clone $source $target $longname
        my redirect /scenario/index.html
    }

    # NEXT, set up a form
    hb page "Clone Scenario"
    hb h1 "Clone Scenario"

    if {$op eq "clone" && ![qdict ok]} {
        my ErrorList "Could not clone a scenario:"
        hb hr
    }

    hb form
    hb hidden op clone
    hb label longname "Long Name:"
    hb entry longname -size 15
    hb label target "Replacing:"
    hb enumlong target [linsert [case namedict] 0 "" ""]
    hb submit "Clone"
    hb submit -formaction [my domain]/clone.json "JSON"

    hb para
    hb putln "Available for Cloning:"
    hb para

    my ScenarioTable -radio source
    hb /form

    return [hb /page]
}


smarturl /scenario /clone.json {
    Clones existing scenario {source} as a new scenario, assigning
    it an id and longname.  If {target} is given, it must be an 
    existing scenario other than {source}; the clone will replace
    the previous state of scenario {target}.  Otherwise, a 
    {target} will be chosen automatically.
    If {longname} is given, the scenario will be given the new
    name.  On success, returns a list ["OK", "{target}"].
} {
    qdict prepare source    -required -tolower -in [case names]
    qdict prepare target    -tolower -in [case names]
    qdict prepare longname

    qdict assign source target longname

    qdict checkon target {
        if {$target eq $source} {
            qdict reject target "Cannot clone scenario to itself"
        }            
    }

    if {![qdict ok]} {
        return [js reject [qdict errors]]
    }


    # NEXT, create it.
    return [js ok [case clone $source $target $longname]]
}

smarturl /scenario /import.html {
    Presents a page that allows the user to import a scenario
    from disk.<p>

    If {op} is "import", then {filename} is imported as a new scenario
    and assigned an ID and long name, and the server redirects to the 
    scenario index.  If {id} is given, it must be an existing scenario; the 
    scenario's contents will be replaced with the imported data.
    If {longname} is given, the scenario will be given the new
    name.<p>

    If {op} is "", the page displays the information and form needed
    to import a scenario, including a list of the available scenario
    files. The parameters may be submitted to the same page, or to 
    the JSON interface.<p>
} {
    # FIRST, get the query parameters
    qdict prepare op -in {import}
    qdict prepare filename -required
    qdict prepare id -tolower -in [case names]
    qdict prepare longname
    qdict assign op filename id longname

    # NEXT, create a new scenario if the parms are OK and we were 
    # so requested.
    if {$op eq "import" && [qdict ok]} {
        try {
            set theID [case import $filename $id $longname]
            set status ok
        } trap {SCENARIO IMPORT} {result} {
            qdict reject filename $result
            set status error
        }

        # Note: exits the method.
        if {$status eq "ok"} {
            my redirect /scenario/index.html
        }
    }

    # NEXT, set up a form
    hb page "Import Scenario"
    hb h1 "Import Scenario"

    if {$op eq "import" && ![qdict ok]} {
        my ErrorList "Could not import a scenario:"
        hb hr
    }

    hb form
    hb hidden op import
    hb label longname "Long Name:"
    hb entry longname -size 15
    hb label id "Replacing:"
    hb enumlong id [linsert [case namedict] 0 "" ""]
    hb submit "Import"
    hb submit -formaction [my domain]/import.json "JSON"

    hb para
    hb putln "Available for Import:"
    hb para

    my FileTable -radio filename

    hb /form
    hb para

    hb hr

    hb h2 "Existing Scenarios"

    my ScenarioTable

    return [hb /page]
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

smarturl /scenario /export.html {
    Presents a page that allows the user to export a scenario.<p>

    If {op} is "export", then scenario {id} is exported to the given
    {filename} in the -scenariodir.<p>

    The page displays the information and form needed
    to export a scenario, including a list of the available scenarios
    and a list of the files in the -scenariodir.
    The parameters may be submitted to the same page, or to 
    the JSON interface.<p>
} {
    # FIRST, get the query parameters
    qdict prepare op -in {export}
    qdict prepare id -required -tolower -in [case names]
    qdict prepare filename -required 
    qdict assign op id filename


    # NEXT, clone the scenario if the parms are OK and we were 
    # so requested.
    if {$op eq "export" && [qdict ok]} {
        try {
            set theFileName [case export $id $filename]
        } trap {SCENARIO EXPORT} {result} {
            qdict reject filename $result
        }
    }

    # NEXT, set up a form
    hb page "Export Scenario"
    hb h1 "Export Scenario"

    if {$op eq "export"} {
        if {[qdict ok]} {
            hb putln "Exported scenario $id to the scenario directory" \
                " as '$filename'."
        } else {
            my ErrorList "Could not export the scenario:"
        }
        hb para
        hb hr
        hb para
    }

    hb form
    hb hidden op export
    hb label filename "File Name:"
    hb entry filename -size 20
    hb put " (.adb or .tcl) "
    hb submit "Export"
    hb submit -formaction [my domain]/export.json "JSON"

    hb para
    hb putln "Select a Scenario to Export:"
    hb para

    my ScenarioTable -radio id
    hb /form

    hb para

    hb h2 "Saved Scenarios:"

    my FileTable

    return [hb /page]
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

smarturl /scenario /remove.html {
    Presents a page that allows the user to remove a scenario from
    the session.<p>

    If {op} is "remove", then scenario {id} is removed from the 
    session.<p>

    The page displays the information and form needed
    to remove a loaded scenario, including a list of the 
    available scenarios.
    The parameters may be submitted to the same page, or to 
    the JSON interface.<p>
} {
    # FIRST, get the query parameters
    qdict prepare op -in {remove}
    qdict prepare id -required -tolower -in [case names]
    qdict assign op id 

    if {$id eq "case00"} {
        qdict reject id "Cannot remove the base case"
    }


    # NEXT, remove the scenario if the parms are OK and we were 
    # so requested.
    if {$op eq "remove" && [qdict ok]} {
        case remove $id
    }

    # NEXT, set up a form
    hb page "Remove Scenario"
    hb h1 "Remove Scenario"

    if {$op eq "remove"} {
        if {[qdict ok]} {
            hb putln "Removed scenario $id from the session."
        } else {
            my ErrorList "Could not remove the scenario:"
        }
        hb para
        hb hr
        hb para
    }

    if {[llength [case names]] == 1} {
        hb putln {
            <b>There are no remaining scenarios that can be
            removed.</b>
        }
    } else {
        hb form
        hb hidden op remove
        hb submit "Remove"
        hb submit -formaction [my domain]/remove.json "JSON"

        hb para
        hb putln "Select a Scenario to Remove:"
        hb para

        my ScenarioTable -radio id -omit case00
        hb /form
    }


    return [hb /page]
}


smarturl /scenario /remove.json {
    Removes scenario {id} from the current session; export it first
    if you wish to keep the data.  On success, returns a list ["OK", "{message}"].
} {
    qdict prepare id -required -tolower -in [case names]

    qdict assign id
   
    if {$id eq "case00"} {
        qdict reject id "Cannot remove the base case"
    }


    if {![qdict ok]} {
        return [js reject [qdict errors]]
    }

    # NEXT, create it.
    case remove $id
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


