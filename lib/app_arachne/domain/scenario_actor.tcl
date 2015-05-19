#-----------------------------------------------------------------------
# TITLE:
#   domain/scenario_actor.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# PACKAGE:
#   app_arachne(n): Arachne Implementation Package
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   This set of URLs are defined with the context of the /scenario 
#   smartdomain(n) and return data related to actors found within a
#   particular Arachne case.
#
#   Additional URLs are defined in domain/scenario_*.tcl.
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# General Content

smarturl /scenario /{case}/actor/index.html {
    Displays a list of actor entities for <i>case</i>, with links to 
    the actual actors.
} {
    # FIRST, validate actor
    set case [my ValidateCase $case]

    hb page "Scenario '$case': Actors"
    hb h1 "Scenario '$case': Actors"

    my CaseNavBar $case

    set actors [case with $case actor names]

    if {[llength $actors] == 0} {
        hb h2 "<b>None defined.</b>"
        hb para
        return [hb /page]
    }

    hb putln "The following actors are in this scenario ("
    hb iref /$case/actor/index.json json
    hb put )

    hb para

    # NEXT, build a table of minimal information, it's more important
    # to have robust information in the JSON return.
    hb table -headers {
        "<br>ID" "<br>Name" "Belief<br>System" "<br>Supports" 
        "Income,<br>$/week" "Funding<br>Type" "Cash<br>On Hand, $"
    } {
        foreach actor $actors {
            set adict [case with $case actor view $actor web]
            dict with adict {}
            hb tr {
                hb td-with {
                    hb iref "/$case/$url" "$id"
                }
                hb td $longname
                hb td $bsysname
                hb td-with {
                    if {$supports_url ne ""} {
                        hb iref "/$case/$supports_url" "$supports"
                    } else {
                        hb put $supports
                    }
                }
                hb td $income
                hb td $atype
                hb td $cash_on_hand
            }
        }
    }

    hb para

    return [hb /page]
}

smarturl /scenario /{case}/actor/index.json {
    Returns a JSON list of actor entities in the <i>case</i> specified.
} {
    set case [my ValidateCase $case]

    set table [list]

    foreach a [case with $case actor names] {
        set adict [case with $case actor view $a web]

        dict with adict {}

        # NEXT, format URLs properly
        dict set adict url [my domain $case $qid "index.json"]
        if {$supports_qid ne ""} {
            dict set adict supports_url \
                [my domain $case $supports_qid "index.json"]
        }

        lappend table $adict
    }

    return [js dictab $table]
}

smarturl /scenario /{case}/actor/{a}/index.html {
    Displays data for a particular actor <i>a</i> in scenario <i>case</i>.
} {
    # FIRST, validate case and actor
    set a [my ValidateActor $case $a]

    set name [case with $case actor get $a longname]

    hb page "Scenario '$case': Actor: $a"
    hb h1 "Scenario '$case': Actor: $a"

    # NEXT, the only content for now is a link to the JSON
    hb putln "Click for "
    hb iref /$case/actor/$a/index.json "json"
    hb put "."

    hb para

    my CaseNavBar $case 

    hb para
    return [hb /page]
}

smarturl /scenario /{case}/actor/{a}/index.json {
    Returns JSON list of actor data for scenario <i>case</i> and actor 
    <i>a</i>.
} {
    # FIRST, validate case and actor 
    set a [my ValidateActor $case $a]

    set adict [case with $case actor view $a web]

    set qid          [dict get $adict qid]
    set supports_qid [dict get $adict supports_qid]

    # NEXT, format URLs properly
    dict set adict url [my domain $case $qid "index.json"]
    if {$supports_qid ne ""} {
        dict set adict supports_url \
            [my domain $case $supports_qid "index.json"]
    }


    return [js dictab [list $adict]]
}





