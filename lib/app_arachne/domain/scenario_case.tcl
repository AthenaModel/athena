#-----------------------------------------------------------------------
# TITLE:
#   domain/scenario_case.tcl
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
#   /scenario/{case}: /scenario handlers for top-level {case} pages.
#
#-----------------------------------------------------------------------


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
# Sanity Checking

smarturl /scenario /{case}/sanity/onlock.html {
    Displays a sanity check for scenario {case}.  
} {
    set case [my ValidateCase $case]

    hb page "Scenario '$case': Sanity Check, On Lock"
    hb h1 "Scenario '$case': Sanity Check, On Lock"

    my CaseNavBar $case

    hb putln {
        Athena checks the scenario's sanity before
        allowing the user to lock the scenario and begin
        simulation.
    }

    hb put "("
    hb iref /$case/sanity/onlock.json json
    hb put ")"

    hb para
    
    lassign [case with $case sanity onlock] severity flist

    switch -- $severity {
        OK {
            hb putln {
                No problems were found; the scenario may be
                locked and time may be advanced.
            }
        }
        WARNING {
            hb putln {
                The scenario may be locked and time may be advanced,
                but the following problems were found and should
                be ultimately be fixed.
            }

            hb para

            my FormatFailureList $case $flist
        }
        ERROR {
            hb putln "<b>The scenario cannot be locked.</b>"
            hb putln {
                Entries marked "Error" in the following list must
                be fixed before the scenario can be locked.  Entries
                marked "Warning" will not affect the run, but 
                should be resolved in the long run. 
            }

            hb para

            my FormatFailureList $case $flist
        }
        default { error "Unknown severity: \"$severity\""}
    }

    hb para


    return [hb /page]
}

smarturl /scenario /{case}/sanity/onlock.json {
    Performs an on-lock sanity check for the scenario, and returns the 
    list of failure records.  If the list is empty, there were no 
    problems.  If the list contains a record with a "severity" of
    "error", then the scenario cannot be locked.  The JSON result
    is a list of failure objects.
} {
    set case [my ValidateCase $case]

    # FIRST, do the check.
    lassign [case with $case sanity onlock] severity flist

    # NEXT, send it out!
    return [js dictab $flist]
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

    qdict prepare op -in {send}
    qdict prepare order_ -toupper
    qdict assign op order_

    hb form
    hb enum order_ -selected $order_ [lsort [athena::orders names]]
    hb submit "Select"
    hb /form
    hb para


    if {$order_ ne "" && $order_ in [athena::orders names]} {
        hb h2 $order_

        # FIRST, fill in the default values.
        set o [case with $case order make $order_]
        set defaults [$o defaults]
        $o destroy

        set currentParms [dict keys [qdict parms]]
        dict for {parm def} $defaults {
            qdict prepare $parm -default $def
        }

        # NEXT, send the order and let's see what happens.
        try {
            if {$op eq "send"} {
                set result [case send $case [namespace current]::qdict]
                hb putln "Order $order_ was accepted."
                hb para

                if {$result ne ""} {
                    hb putln "Result:"
                    hb pre $result
                    hb para
                }
                set result ""
            } else {
                qdict remove order_
                case with $case order check $order_ {*}[qdict parms] 
                set result ""
            }
        } trap REJECT {result} {
            if {[dict exists $result *]} {
                hb span "Error, [dict get $result *]"
                hb para
            }
        }

        # NEXT, set up the form. 
        hb form 
        hb hidden op send
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

        # TBD: It would be nice to have a Check button, or to check
        # automatically on change.
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


