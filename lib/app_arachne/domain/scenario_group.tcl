#-----------------------------------------------------------------------
# TITLE:
#   domain/scenario_group.tcl
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
#   smartdomain(n) and return data related to groups found within a
#   particular Arachne case.
#
#   Additional URLs are defined in domain/scenario_*.tcl.
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# General Content

smarturl /scenario /{case}/group/{g}/index.html {
    Displays data for a particular civilian group <i>g</i> in scenario
    <i>case</i>.
} {
    set g [my ValidateGroup $case $g]

    set gtype [case with $case group gtype $g]

    if {$gtype eq "CIV"} {
        set typestr "Civilian"
    } elseif {$gtype eq "ORG"} {
        set typestr "Organization"
    } elseif {$gtype eq "FRC"} {
        set typestr "Force"
    }

    hb page "Scenario '$case': $typestr Group: $g"
    my CaseNavBar $case 

    hb h1 "Scenario '$case': $typestr Group: $g"

    # NEXT, only content for now is a link to the JSON
    hb putln "Click for "
    hb iref /$case/group/$g/index.json "json"
    hb put "."

    hb para

    hb para
    return [hb /page]
}

smarturl /scenario /{case}/group/{g}/index.json {
    Returns JSON list of civilian group data for scenario <i>case</i> and 
    group <i>g</i>.
} {
    set g [my ValidateGroup $case $g]

    set gtype [case with $case group gtype $g]

    if {$gtype eq "CIV"} {
        set gdict [case with $case civgroup view $g web]
        set qid   [dict get $gdict url] 
        set n_qid [dict get $gdict n_qid]

        # NEXT, format URLs properly
        dict set gdict url   [my domain $case $qid   "index.json"]
        dict set gdict n_url [my domain $case $n_qid "index.json"]
    } elseif {$gtype eq "ORG"} {
        set gdict [case with $case orggroup view $g web]
        set qid   [dict get $gdict qid]
        set a_qid [dict get $gdict a_qid]

        # NEXT, format URLs properly
        dict set gdict url [my domain $case $qid "index.json"]
        if {$a_qid ne ""} {
            dict set gdict a_url [my domain $case $a_qid "index.json"]
        } 
    } elseif {$gtype eq "FRC"} {
        set gdict [case with $case frcgroup view $g web]
        set qid   [dict get $gdict qid]
        set a_qid [dict get $gdict a_qid]

        # NEXT, format URLs properly
        dict set gdict url [my domain $case $qid "index.json"]

        if {$a_qid ne ""} {
            dict set gdict a_url [my domain $case $a_qid "index.json"]
        } 
    }

    return [js dictab [list $gdict]]
}





