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
    # Variables

    variable statusCache  ;# Array of status strings by URL.
    variable fcounter     ;# File counter for temp files 
    

    #-------------------------------------------------------------------
    # Constructor

    constructor {} {
        next /scenario

        set fcounter 0

        # FIRST, configure the HTML buffer
        hb configure \
            -cssfiles  {/athena.css}         \
            -headercmd [mymethod htmlHeader] \
            -footercmd [mymethod htmlFooter]
    }            

    #-------------------------------------------------------------------
    # Header and Footer

    method htmlHeader {hb title} {
        hb putln [athena::element header Arachne]
    }

    method htmlFooter {hb} {
        hb putln [athena::element footer]
    }

    #-------------------------------------------------------------------
    # Status Methods
    
    # status ?body?
    #
    # body   - A Tcl script.
    #
    # If body is given, the command calls it and accumulates operation 
    # status HTML in the buffer, and saving it for this URL.  
    # If the body is the single word "clear", clears the saved
    # status instead.  If the body is not given, outputs the saved
    # status to the buffer.

    method status {{body ""}} {
        # FIRST, handle special cases.
        if {$body eq ""} {
            if {[info exists statusCache([req url])]} {
                hb putln $statusCache([req url])
            }
            return
        } elseif {$body eq "clear"} {
            unset -nocomplain statusCache([req url])
            return
        }

        # NEXT, accumulate status
        try {
            hb push
            uplevel 1 $body
            set statusCache([req url]) [hb get]
        } finally {
            hb pop
        }
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

    # TimeSpanForm var case
    #
    # var   - a history variable that has a smarturl defined 
    # case  - an Arachne case
    #
    # Thie method puts start and end time entries (which are common to
    # all history queries) into a form along with a "JSON" button with
    # a form action to retrieve the history as JSON.

    method TimeSpanForm {case var} {
        hb putln "Select start and end times or leave blank for all history."
        hb para
        hb label t1 "Start Time:"
        hb entry t1 -size 8
        hb label t2 "End Time:"
        hb entry t2 -size 8
        hb para 
        hb submit -formaction [my domain]/$case/history/$var/index.json "JSON"
    }

    # NbhoodForm case
    #
    # case   - an Arachne case
    #
    # This method creates a dropdown menu containing all the Neighborhoods
    # defined in the case provided.  It prepends "ALL" to the list and
    # sets that as the default.

    method NbhoodForm {case} {
        set nbhoods [lsort [case with $case nbhood names]]

        hb putln "Select a neighborhood or 'ALL'."
        hb para

        hb enum n -selected ALL [list ALL {*}$nbhoods]
    }

    # GroupForm case ?args?
    #
    # case   - an Arachne case
    # args   - optional arguments
    #
    # This method creates a dropdown menu containing groups defined in
    # the case provided. The options are as follows:
    #
    #    -var      Variable to associate with the selection, defaults to 'g'
    #    -gtypes   List of group types to include, defaults to all types 

    method GroupForm {case args} {
        # FIRST get the options
        set gtypes {CIV FRC ORG}
        set var    g

        foroption opt args -all {
            -gtypes { set gtypes [lshift args] }
            -var    { set var    [lshift args] }
        }         

        set glist [case with $case group names $gtypes]
        set lbl [join $gtypes " or "]

        hb putln "Select a $lbl group or 'ALL'."
        hb para

        hb enum $var -selected ALL [list ALL {*}$glist]
    }

    # ActorForm   case
    #
    # case   - an Arachne case
    #
    # This method creates a dropdown menu containing actors defined in
    # the case provided.

    method ActorForm {case} {
        set alist [case with $case actor names]

        hb putln "Select an actor or 'ALL'."
        hb para

        hb enum a -selected ALL [list ALL {*}$alist]
    }

    # ConcernForm  
    #
    # Creates a dropdown menu of concerns, it's the same for all cases.

    method ConcernForm {} {
        hb putln "Select a concern or 'ALL'."
        hb para

        hb enum c -selected ALL [list ALL AUT CUL SFT QOL]        
    }

    # ValidateTimes
    #
    # This method validates two qdict time parameters (t1 and t2) that are
    # assumed to be present.  

    method ValidateTimes {} {
        # FIRST, basic validations
        set t1 [qdict prepare t1 -toupper -default 0 -with {iticks validate}]
        set t2 [qdict prepare t2 -toupper -default end]
        
        # NEXT t2 must be greater than or equal to t1 if it is not "end"
        qdict checkon t2 {
            if {[qdict badparm t1]} {
                return
            }

            if {$t2 ne "end"} {
                iticks validate $t2

                if {$t2 < $t1} {
                    qdict reject t2 "t2 must be >= t1"
                }
            }
        }
    }

    # RefreshIfBusy ?case?
    #
    # case   - A case name
    #
    # Returns the auto-refresh interval if the given case is busy,
    # and "" otherwise. If no case is given, returns the auto-refresh
    # interval if any loaded case is busy.

    method RefreshIfBusy {{case ""}} {
        set interval 1 ;# Interval in seconds

        # FIRST, handle the specified case
        if {$case ne ""} {
            if {[case with $case is busy]} {
                return $interval
            } else {
                return ""
            }
        }

        # NEXT, handle all cases.
        foreach case [case names] {
            if {[case with $case is busy]} {
                return $interval
            }
        }

        return ""

    }

    # ErrorList message errdict
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
        set autoReload 0

        hb table -headers $headers {
            foreach case $cases {
                set cdict [case metadata $case]

                if {[case with $case is busy]} {
                    set progress [case with $case progress]
                    if {[string is double -strict $progress]} {
                        set progress \
                            [format "%.1f%%" [expr {100*$progress}]]
                    }
                } else {
                    set progress ""
                }


                hb tr {
                    if {$rparm ne ""} {
                        hb td-with { hb radio $rparm $case }
                    }
                    hb td-with { 
                        hb putln <b>
                        hb iref /$case/index.html $case
                        hb put </b>
                    }
                    hb td [dict get $cdict longname]
                    hb td [dict get $cdict source]
                    hb td-with {
                        set state [dict get $cdict state]
                        hb put "$state $progress"
                    }
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

    # ValidateActor case a 
    #
    # Validates that a is a valid actor in the case, throws not
    # found if case or actor is invalid.

    method ValidateActor {case a} {
        # FIRST, validate case
        set case [my ValidateCase $case]

        set a [string toupper $a]

        if {$a ni [case with $case actor names]} {
            throw NOTFOUND "No such actor: \"$a\""
        }

        return $a
    }

    # ValidateNbhood case n
    #
    # Validate that n is a valid neighborhood in the case, throws not
    # found if case or n is invalid.

    method ValidateNbhood {case n} {
        # FIRST, validate case
        set case [my ValidateCase $case]

        set n [string toupper $n]

        if {$n ni [case with $case nbhood names]} {
            throw NOTFOUND "No such nbhood: \"$n\""
        }

        return $n
    }

    # ValidateGroup case g
    #
    # Validates that g is a valid CIV, FRC or ORG group in the case,
    # throws not found if the case or g is invalid.

    method ValidateGroup {case g} {
        # FIRST, validate case
        set case [my ValidateCase $case]

        set g [string toupper $g]

        if {![case with $case group exists $g]} {
            throw NOTFOUND "No such group: \"$g\""
        }
    
        return $g
    }

    # MainNavBar
    #
    # Returns a navigation bar for the toplevel pages

    method MainNavBar {} {
        hb linkbar {
            hb xref /index.html "Home"
            hb iref /index.html "Scenarios"
            hb xref /help/index.html "Help"
        }
    }

    # CaseNavBar
    #
    # Returns a navigation bar for the scenario pages

    method CaseNavBar {case} {
        hb linkbar {
            hb xref /index.html "Home"
            hb iref /index.html "Scenarios"
            hb iref /$case/index.html "Case"
            hb iref /$case/sanity/onlock.html "Sanity"
            hb iref /$case/order.html "Orders"
            hb iref /$case/history/index.html "History"
            hb iref /$case/script.html "Scripts"
            hb xref /help/index.html "Help"
            hb br
            hb iref /$case/sigevent/index.html "Sig Events"
        }
        hb para
    }

    # FormatFailureList case flist
    #
    # flist  - A list of sanity failure dictionaries.
    #
    # Formats the failure list as a table.

    method FormatFailureList {case flist} {
        hb table -headers {"Severity" "Code" "Entity" "Message"} {
            foreach dict $flist {
                dict with dict {}
                set elink [my GetEntityLink $case $entity]

                hb tr {
                    hb td-with { 
                        if {$severity eq "error"} {
                            set cls error
                        } else {
                            set cls ""
                        }

                        hb span -class $cls [esanity longname $severity]
                    }
                    hb td      $code
                    hb td-with { hb iref $elink $entity }
                    hb td      $message
                }
            }
        }
    }

    # GetEntityLink case entity
    #
    # case    - A scenario case ID
    # entity  - An entity reference
    #
    # Returns an appropriate iref link for the named entity.

    method GetEntityLink {case entity} {
        return  /$case/$entity/index.html
    }

    # withlinks case text
    #
    # Looks for links of the form '{etype:name}' and replaces them
    # with entity links.

    method withlinks {case text} {
        regsub -all -- {{(\w+):(\w+)}} $text \
            [format {<a href="%s/\1/\2/index.html">\2</a>} [my domain $case]] \
            text

        return $text
    }

    # enumtick name case ?options...?
    #
    # name    - The input name
    # case    - The scenario ID
    # options - Attribute options
    # label   - The label to precede the control or "".
    #
    # Adds an enum input for a time tick.
    #
    # -extras list       - Extra values to add to the beginning of 
    #                      the list of ticks.
    # -selected value    - The initially selected value
    # -label text        - Text for a label to precede the control.

    method enumtick {name case args} {
        set label    [optval args -label    ""]
        set selected [optval args -selected ""]
        set extras   [optval args -extras   {}]

        if {$label ne ""} {
            hb label $name $label
            hb put " "
        }

        set items $extras
        set start [case with $case clock cget -tick0]
        set end   [case with $case clock now]
        for {set t $start} {$t <= $end} {incr t} {
            lappend items $t
        }

        hb enum $name -selected $selected {*}$args $items

    }

    # jsonbutton request backto
    #
    # request   - The iref of a JSON request URL
    # backto    - The iref of another /scenario URL to return to.
    #
    # Adds hidden form fields jsonurl and backto to the current form,
    # followed by a JSON button that loads json.html.

    method jsonbutton {request backto} {
        hb hidden jsonurl [my domain]$request
        hb hidden backto  [my domain]$backto
        hb submit -formaction [my domain]/json.html "JSON"
    }
    
}

#-------------------------------------------------------------------
# General Content

smarturl /scenario /index.html {
    Displays a list of loaded scenarios, with various interactive
    controls.
} {
    hb page "Scenarios"
    my MainNavBar

    hb h1 "Scenarios"
    hb para


    hb putln "The following scenarios are loaded."

    hb para

    my ScenarioTable


    return [hb /page]
}

smarturl /scenario /index.json {
    Returns a JSON list of scenario metadata objects.
    (<link "/arachne.html#/scenario/index.json" spec>)
} {
    set table [list]

    foreach case [case names] {
        set cdict [case metadata $case]
        dict set cdict url   "/scenario/$case/index.json"

        lappend table $cdict
    }

    return [js dictab $table]
}

smarturl /scenario /files.json {
    Returns a JSON array of scenario file objects.
    (<link "/arachne.html#/scenario/files.json" spec>)
} {
    set table [dictlist new {id size mtime}]

    set filenames [glob \
                        -nocomplain \
                        -directory [case scenariodir] \
                        *.adb *.tcl]

    foreach filename [lsort -dictionary $filenames] {
        $table add \
            [file tail $filename] \
            [file size $filename] \
            [expr {1000*[file mtime $filename]}]
    }

    try {
        return [js dictab [$table dicts]]
    } finally {
        $table destroy        
    }
}

#-----------------------------------------------------------------------
# New Scenario

smarturl /scenario /new.json {
    Creates a new, empty scenario, assigning it an id and longname.
    (<link "/arachne.html#/scenario/new.json" spec>)    
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


smarturl /scenario /clone.json { 
    Clones existing scenario <i>source</i> as a new scenario, assigning
    it an id and longname. (<link "/arachne.html#/scenario/clone.json" spec>)
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

smarturl /scenario /import.json {
    Imports a scenario from disk and loads it into memory.
    The file must be a file in the <tt>-scenariodir</tt>. 
    (<link "/arachne.html#/scenario/import.json" spec>) 
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
    } trap ARACHNE {result} {
        qdict reject filename "Could not import \"$filename\": $result"
        return [js reject [qdict errors]]
    }

    return [js ok $theID]
}

#-----------------------------------------------------------------------
# Export Scenario




smarturl /scenario /export.json {  
    Exports scenario <i>case</i> to the <tt>-scenariodir</tt> as
    <i>filename</i>. (<link "/arachne.html#/scenario/export.json" spec>)
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
    } trap ARACHNE {result} {
        qdict reject filename "Could not export to \"$filename\": $result"
        return [js reject [qdict errors]]
    }

    return [js ok $theFileName]
}

#-----------------------------------------------------------------------
# Remove Scenario

smarturl /scenario /remove.json {
    Removes a scenario from the current session.
    (<link "/arachne.html#/scenario/remove.json" spec>)
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
# JSON Url Display

smarturl /scenario /json.html {
    Given query parameter "jsonurl", retrieves the data at the URL
    and displays it in a textarea.  "backto" is the URL to return to.
    This URL is for use by the Athena development team.
} {
    qdict prepare jsonurl -required
    qdict prepare backto 
    qdict assign jsonurl backto
    qdict remove jsonurl
    qdict remove backto


    hb page "JSON Result"
    hb linkbar {
        hb xref "/" "Home"
        if {$backto ne ""} {
            hb xref $backto "Finish"
        }
    }

    hb h1 "JSON Result"

    if {![qdict ok]} {
        my ErrorList "Could not retrieve JSON data"
    } else {
        hb putln "Do not use the back arrow; instead, click 'Finish'."
        hb para

        hb putln "Request:"

        if {[dict size [qdict parms]] > 0} {
            append jsonurl [hb asquery [qdict parms]]
        }
        hb pre -class example $jsonurl

        hb putln "Query Parameters:"

        if {[dict size [qdict parms]] == 0} {
            hb put " None"
            hb para
        } else {
            hb pre -class example 
            hb putln [qdict parms]
            hb /pre
        }

        hb hr

        hb putln "JSON Result:"
        hb pre -class example -id jsonresult {
            Waiting for response....
        }

        hb tag script
        hb putln [format {
            var url = "%s";
            var xmlhttp = new XMLHttpRequest();

            xmlhttp.onreadystatechange = function() {
                if (xmlhttp.readyState == 4 && xmlhttp.status == 200) {
                    document.getElementById("jsonresult").innerHTML =
                        xmlhttp.responseText;
                }            
            }
            xmlhttp.open("GET", url, true);
            xmlhttp.send();
        } $jsonurl]
        hb tag /script
    }

    return [hb /page]
}



