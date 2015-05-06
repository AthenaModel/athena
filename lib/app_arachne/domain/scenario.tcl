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

    # ErrorList message ?errdict?
    #
    # message - An overall error message
    # errdict - A dictionary of parameter names and error messages.
    #
    # Formats the parameter errors under the overall message.  errdict
    # defaults to [qdict errors]

    method ErrorList {message {errdict ""}} {
        hb putln ""
        hb span -class error $message
        hb para

        hb ul

        if {[dict size $errdict] == 0} {
            set errdict [qdict errors]
        }

        foreach {parm msg} $errdict {
            hb li
            hb put $parm: 

            hb span -class error " $msg, \"[qdict get $parm]\""
            hb /li
        }

        hb /ul
    }

    # ScenarioTable ?-radio name? ?-cases list? ?-omit list?
    #
    # Adds a table of the existing scenarios to the page.
    # If -radio is given, the first column contains radio buttons
    # with the given name.

    method ScenarioTable {args} {
        # FIRST, get the options
        set rparm     ""
        set omissions {}
        set cases     [case names]

        foroption opt args -all {
            -radio { set rparm     [lshift args] }
            -cases { set cases     [lshift args] }
            -omit  { set omissions [lshift args] }
        }

        # NEXT, get the list of scenarios.
        # TBD: Need a filter method
        set caselist [list]

        foreach case $cases {
            if {$case ni $omissions} {
                lappend caselist $case
            }
        }

        set cases $caselist

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

    # ValidateCase case
    #
    # If case is not a valid case, throws NOTFOUND.

    method ValidateCase {case} {
        # FIRST, do we have the scenario?
        set case [string tolower $case]

        if {$case ni [case names]} {
            throw NOTFOUND "No such scenario: \"$case\""
        }

        return $case
    }

    # MainNavBar
    #
    # Returns a navigation bar for the toplevel pages

    method MainNavBar {} {
        hb hr
        hb xref /index.html "Home"
        hb put " | "
        hb iref /index.html "Scenarios"
        hb put " | "
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
        hb para
    }

    # CaseNavBar
    #
    # Returns a navigation bar for the scenario pages

    method CaseNavBar {case} {
        hb hr
        hb xref /index.html "Home"
        hb put " | "
        hb iref /index.html "Scenarios"
        hb put " | "
        hb iref /$case/index.html "Case"
        hb put " | "
        hb iref /$case/order.html "Orders"
        hb put " | "
        hb iref /$case/script.html "Scripts"
        hb hr
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

    my MainNavBar
    hb para

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

#-----------------------------------------------------------------------
# New Scenario

smarturl /scenario /new.html {
    Presents a page that allows the user to create a new, empty 
    scenario.<p>

    If {op} is "new", then a new scenario is created and assigned
    an ID and long name, and the server redirects to the scenario
    index.  If {target} is given, it must be an existing scenario; the 
    scenario's contents will be reset to the empty state.  Otherwise,
    a new scenario ID will be generated.
    If {longname} is given, the scenario will be given the new
    name.<p>

    If {op} is "", the page displays the information and form needed
    to create a new scenario.  The parameters may be submitted to the
    same page, or to the JSON interface.<p>
} {
    # FIRST, get the query parameters
    qdict prepare op -in {new}
    qdict prepare case -tolower -in [case names]
    qdict prepare longname
    qdict assign op case longname


    # NEXT, set up a form
    hb page "New Scenario"
    hb h1 "New Scenario"

    my MainNavBar

    if {$op eq "new"} {
        if {[qdict ok]} {
            set newcase [case new $case $longname]
            hb putln "Created scenario \"$newcase\": " \
                "\"[case metadata $newcase longname]\""
        } else {
            my ErrorList "Could not create a new scenario:"
        }
        hb hr
    }

    hb form
    hb hidden op new
    hb label longname "Long Name:"
    hb entry longname -size 15
    hb label case "Replacing:"
    hb enumlong case [linsert [case namedict] 0 "" ""]
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
    If {target} is given, it must be an existing scenario; the 
    scenario's contents will be reset to the empty state.
    If {longname} is given, the scenario will be given the new
    name.  On success, returns a list 
    <pre>["OK", "{case}"]</pre>, where the <i>case</i> is 
    either <i>target</i> or a newly generated case ID.
} {
    qdict prepare case -tolower -in [case names]
    qdict prepare longname
    qdict assign case longname

    if {![qdict ok]} {
        return [js reject [qdict errors]]
    }

    # NEXT, create it.
    return [js ok [case new $case $longname]]
}

#-----------------------------------------------------------------------
# Clone Scenario


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

    my MainNavBar

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

#-----------------------------------------------------------------------
# Import Scenario

smarturl /scenario /import.html {
    Presents a page that allows the user to import a scenario
    from disk.<p>

    If {op} is "import", then {filename} is imported as a new scenario
    and assigned an ID and long name, and the server redirects to the 
    scenario index.  If {case} is given, it must be an existing scenario; the 
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
    qdict prepare case -tolower -in [case names]
    qdict prepare longname
    qdict assign op filename case longname

    # NEXT, create a new scenario if the parms are OK and we were 
    # so requested.
    if {$op eq "import" && [qdict ok]} {
        try {
            set theID [case import $filename $case $longname]
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

    my MainNavBar

    if {$op eq "import" && ![qdict ok]} {
        my ErrorList "Could not import a scenario:"
        hb hr
    }

    hb form
    hb hidden op import
    hb label longname "Long Name:"
    hb entry longname -size 15
    hb label case "Replacing:"
    hb enumlong case [linsert [case namedict] 0 "" ""]
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
    <tt>-scenariodir</tt>.  If the {case} is given,
    the scenario will replace the existing scenario with that 
    ID; otherwise a new ID will be assigned.  
    If the {longname} is given, the scenario will
    be assigned that name.  On success, returns a list
    ["OK", "{case}"].
} {
    qdict prepare filename -required
    qdict prepare case -tolower -in [case names]
    qdict prepare longname

    qdict assign filename case longname

    if {![qdict ok]} {
        return [js reject [qdict errors]]
    }

    # NEXT, try to import it.
    try {
        set theID [case import $filename $case $longname]
    } trap {SCENARIO IMPORT} {result} {
        qdict reject filename $result
        return [js reject [qdict errors]]
    }

    return [js ok $theID]
}

#-----------------------------------------------------------------------
# Export Scenario

smarturl /scenario /export.html {
    Presents a page that allows the user to export a scenario.<p>

    If {op} is "export", then scenario {case} is exported to the given
    {filename} in the -scenariodir.<p>

    The page displays the information and form needed
    to export a scenario, including a list of the available scenarios
    and a list of the files in the -scenariodir.
    The parameters may be submitted to the same page, or to 
    the JSON interface.<p>
} {
    # FIRST, get the query parameters
    qdict prepare op -in {export}
    qdict prepare case -required -tolower -in [case names]
    qdict prepare filename -required 
    qdict assign op case filename


    # NEXT, clone the scenario if the parms are OK and we were 
    # so requested.
    if {$op eq "export" && [qdict ok]} {
        try {
            set theFileName [case export $case $filename]
        } trap {SCENARIO EXPORT} {result} {
            qdict reject filename $result
        }
    }

    # NEXT, set up a form
    hb page "Export Scenario"
    hb h1 "Export Scenario"

    my MainNavBar

    if {$op eq "export"} {
        if {[qdict ok]} {
            hb putln "Exported scenario $case to the scenario directory" \
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

    my ScenarioTable -radio case
    hb /form

    hb para

    hb h2 "Saved Scenarios:"

    my FileTable

    return [hb /page]
}


smarturl /scenario /export.json {
    Exports scenario {case} to the <tt>-scenariodir</tt> as
    {filename}.  The file type may be "<tt>.adb</tt>" for a
    standard Athena scenario file or "<tt>.tcl</tt>" for a
    scenario script.  If no file type is given, "<tt>.adb</tt>"
    is assumed.  On success, returns a list
    ["OK", "{filename}"].
} {
    qdict prepare case -required -tolower -in [case names]
    qdict prepare filename -required
    qdict assign case filename

    if {![qdict ok]} {
        return [js reject [qdict errors]]
    }

    # NEXT, try to export it.
    try {
        set theFileName [case export $case $filename]
    } trap {SCENARIO EXPORT} {result} {
        qdict reject filename $result
        return [js reject [qdict errors]]
    }

    return [js ok $theFileName]
}

#-----------------------------------------------------------------------
# Remove Scenario

smarturl /scenario /remove.html {
    Presents a page that allows the user to remove a scenario from
    the session.<p>

    If {op} is "remove", then scenario {case} is removed from the 
    session.<p>

    The page displays the information and form needed
    to remove a loaded scenario, including a list of the 
    available scenarios.
    The parameters may be submitted to the same page, or to 
    the JSON interface.<p>
} {
    # FIRST, get the query parameters
    qdict prepare op -in {remove}
    qdict prepare case -required -tolower -in [case names]
    qdict assign op case 

    if {$case eq "case00"} {
        qdict reject case "Cannot remove the base case"
    }


    # NEXT, remove the scenario if the parms are OK and we were 
    # so requested.
    if {$op eq "remove" && [qdict ok]} {
        case remove $case
    }

    # NEXT, set up a form
    hb page "Remove Scenario"
    hb h1 "Remove Scenario"

    my MainNavBar

    if {$op eq "remove"} {
        if {[qdict ok]} {
            hb putln "Removed scenario $case from the session."
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

        my ScenarioTable -radio case -omit case00
        hb /form
    }


    return [hb /page]
}


smarturl /scenario /remove.json {
    Removes scenario {case} from the current session; export it first
    if you wish to keep the data.  On success, returns a list ["OK", "{message}"].
} {
    qdict prepare case -required -tolower -in [case names]

    qdict assign case
   
    if {$case eq "case00"} {
        qdict reject case "Cannot remove the base case"
    }


    if {![qdict ok]} {
        return [js reject [qdict errors]]
    }

    # NEXT, create it.
    case remove $case
    return [js ok "Deleted $case"]
}

#-----------------------------------------------------------------------
# Compare scenarios (prototype)

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

#=======================================================================
# Scenario-specific pages
#
# Pages related to particular parts of a scenario will be in other
# files; this section has the general mechanism pages.

smarturl /scenario /{case}/index.html {
    Displays information about scenario {case}.  
} {
    # TBD: I'd like a better API for this.  
    #
    # * It's like what we do with qdict, but there's no general 
    #   instrastructure for it.
    # * It's like normal validation, but results in NOTFOUND.
    # * Should we add placeholder vars to the qdict?
    # * Should we add a "udict" for url placeholders only?
    #   * And then it could have a NOTFOUND option.
    set case [my ValidateCase $case]

    hb page "Scenario '$case': Overview"
    hb h1 "Scenario '$case': Overview"

    my CaseNavBar $case

    hb h2 "Scenario Metadata"
    my ScenarioTable -cases $case

    return [hb /page]
}

#-----------------------------------------------------------------------
# Order Handling

smarturl /scenario /{case}/order.html {
    Allows the user to select an order and view its order form.
    If {order_} is given, the page tries to send the order, and 
    displays an order form.  Error messages are displayed in the
    order form.  The other query parameters are the order parameters.<p>

    <b>TBD:</b> Ultimately, we should recast this as a page that 
    requires an {order_} and a {url} to redirect to on success.  Then
    an actor page (say) could have a button that goes to the order form
    for that URL and return afterwards.<p>
} {
    set case [my ValidateCase $case]

    # FIRST, begin the page
    hb page "Scenario '$case': Order Selection"
    hb h1 "Scenario '$case': Order Selection"

    my CaseNavBar $case

    # NEXT, set up the order form
    hb putln "Select an order and press 'Select' to see its order form."
    hb para

    set order_ [qdict prepare order_]

    hb form -action [my domain]/$case/order.html
    hb enum order_ -selected $order_ [lsort [athena::orders names]]
    hb submit "Select"
    hb /form
    hb para


    if {$order_ ne "" && $order_ in [athena::orders names]} {
        hb h2 $order_

        # FIRST, send the order and let's see what happens.
        try {
            set result [case send $case [namespace current]::qdict]
            hb putln "Order $order_ was accepted."
                hb para
            if {$result ne ""} {
                hb putln "Result:"
                hb pre $result
                hb para
            }
            set result ""
        } trap REJECT {result} {
            if {[dict exists $result *]} {
                hb span "Error, [dict get $result *]"
                hb para
            }
        }

        hb form 
        hb hidden order_ $order_
        hb table -headers {"Parameter" "Value"} {
            foreach parm [athena::orders parms $order_] {
                hb tr {
                    hb td-with { hb label $parm "$parm:" }
                    hb td-with {
                        hb entry $parm -size 40 -value [qdict get $parm]
                        if {[dict exists $result $parm]} {
                            hb br
                            hb span -class error [dict get $result $parm]
                        }
                    }
                }
            }
        }

        hb submit "Send"
        hb submit -formaction [my domain]/$case/order.json "JSON"
        hb /form

    }


    return [hb /page]
}


smarturl /scenario /{case}/order.json {
    Accepts an order and its parameters.
    The query parameters are the order name as <tt>order_</tt>
    and the order-specific parameters as indicated in the on-line
    help.  The result of the order is returned as a JSON list 
    indicating the success of the request with related 
    information.<p>
} {
    set case [my ValidateCase $case]

    # NEXT, send the order.
    try {
        set result [case send $case [namespace current]::qdict]
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

smarturl /scenario /{case}/script.html {
    Accepts a Tcl script and attempts to
    execute it in the named scenario's executive interpreter.
    The result of running the script is returned.  The
    script should be the value of the <tt>script</tt> 
    query parameter, and should be URL-encoded.
} {
    set case [my ValidateCase $case]

    # FIRST, begin the page
    hb page "Scenario '$case': Script Entry"
    hb h1 "Scenario '$case': Script Entry"

    my CaseNavBar $case

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
            set result [case with $case executive eval $script]
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


smarturl /scenario /{case}/script.json {
    Accepts a Tcl script as a POST query, and attempts to
    execute it in the named scenario's executive interpreter.
    The query data should be just the script itself with a
    content-type of text/plain.  The result of running the script 
    is returned in JSON format.
} {
    set case [my ValidateCase $case]

    set script [my query]

    # NEXT, evaluate the script.
    try {
        set result [case with $case executive eval $script]
    } on error {result eopts} {
        return [js error $result [dict get $eopts -errorinfo]]
    }

    # NEXT, we were successful!
    return [js ok $result]
}


