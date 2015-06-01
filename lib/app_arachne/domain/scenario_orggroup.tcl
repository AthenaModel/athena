#-----------------------------------------------------------------------
# TITLE:
#   domain/scenario_orggroup.tcl
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
#   smartdomain(n) and return data related to ORG groups found within a
#   particular Arachne case.
#
#   Additional URLs are defined in domain/scenario_*.tcl.
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# General Content

smarturl /scenario /{case}/orggroup/index.html {
    Displays a list of organization group entities for <i>case</i>, with links 
    to the actual groups.
} {
    # FIRST, validate scenario
    set case [my ValidateCase $case]

    hb page "Scenario '$case': Organization Groups"
    hb h1 "Scenario '$case': Organization Groups"

    set orggroups [case with $case orggroup names]

    if {[llength $orggroups] == 0} {
        hb h2 "<b>None defined.</b>"
        hb para
        return [hb /page]
    }

    hb putln "The following organization groups are in this scenario ("
    hb iref /$case/orggroup/index.json json
    hb put )

    hb para

    hb table -headers {
        "ID" "Name" "Owner" "Personnel"
    } {
        foreach orggroup $orggroups {
            set odict [case with $case orggroup view $orggroup web]
            dict with odict {}
            hb tr {
                hb td-with {
                    hb iref "/$case/$url" "$id"
                }
                hb td $longname
                hb td-with {
                    if {$a_url ne ""} {
                        hb iref "/$case/$a_url" "$a"
                    } else {
                        hb put ""
                    }
                }
                hb td $personnel 
            }
        }
    }

    hb para

    return [hb /page]
}

smarturl /scenario /{case}/orggroup/index.json {
    Returns a JSON list of organization group entities in the <i>case</i> 
    specified.
} {
    set case [my ValidateCase $case]

    set table [list]

    foreach g [case with $case orggroup names] {
        set odict [case with $case orggroup view $g web]
        set qid   [dict get $odict qid]
        set a_qid [dict get $odict a_qid]

        # NEXT, format URLs properly
        dict set odict url [my domain $case $qid "index.json"]
        if {$a_qid ne ""} {
            dict set odict a_url [my domain $case $a_qid "index.json"]
        }

        lappend table $odict
    }

    return [js dictab $table]
}

smarturl /scenario /{case}/orggroup/{g}/index.html {
    Displays data for a particular organization group <i>g</i> in scenario 
    <i>case</i>.
} {
    set g [my ValidateGroup $case $g ORG]

    set name [case with $case orggroup get $g longname]

    hb page "Scenario '$case': Organization Group: $g"
    my CaseNavBar $case

    hb h1 "Scenario '$case': Organization Group: $g"

    hb putln "Click for "
    hb iref /$case/orggroup/$g/index.json "json"
    hb put "."

    hb para

    hb para
    return [hb /page]
}

smarturl /scenario /{case}/orggroup/{g}/index.json {
    Returns JSON list of organization group data for scenario <i>case</i> and 
    group <i>g</i>.
} {
    set g [my ValidateGroup $case $g ORG]

    set odict [case with $case orggroup view $g web]
    set qid   [dict get $odict qid]
    set a_qid [dict get $odict a_qid]

    # NEXT, format URLs properly
    dict set odict url [my domain $case $qid "index.json"]
    if {$a_qid ne ""} {
        dict set odict a_url [my domain $case $a_qid "index.json"]
    } 

    return [js dictab [list $odict]]
}





