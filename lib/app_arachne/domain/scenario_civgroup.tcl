#-----------------------------------------------------------------------
# TITLE:
#   domain/scenario_civgroup.tcl
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
#   smartdomain(n) and return data related to CIV groups found within a
#   particular Arachne case.
#
#   Additional URLs are defined in domain/scenario_*.tcl.
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# General Content

smarturl /scenario /{case}/groups/civ/index.html {
    Displays a list of civilian group entities for <i>case</i>, with links 
    to the actual groups.
} {
    # FIRST, validate scenario
    set case [my ValidateCase $case]

    hb page "Scenario '$case': Civilian Groups"
    my CaseNavBar $case

    hb h1 "Scenario '$case': Civilian Groups"

    set civgroups [case with $case civgroup names]

    if {[llength $civgroups] == 0} {
        hb h2 "<b>None defined.</b>"
        hb para
        return [hb /page]
    }

    hb putln "The following civilian groups are in this scenario ("
    hb iref /$case/groups/civ/index.json json
    hb put )

    hb para

    # NEXT, a minimal amount of data, the JSON URL return will have it all
    hb table -headers {
        "<br>ID" "<br>Name" "<br>Neighborhood" "<br>Population" 
        "Subsistence<br>Agriculture"
    } {
        foreach civgroup $civgroups {
            set cdict [case with $case civgroup view $civgroup web]
            dict with cdict {}
            hb tr {
                hb td-with {
                    hb iref "/$case/$url" "$id"
                }
                hb td $longname
                hb td-with {
                    hb iref "/$case/$n_url" "$n"
                }
                hb td $population 
                hb td $pretty_sa_flag
            }
        }
    }

    hb para

    return [hb /page]
}

smarturl /scenario /{case}/groups/civ/index.json {
    Returns a JSON list of civilian group entities in the <i>case</i> 
    specified.
} {
    set case [my ValidateCase $case]

    set table [list]

    foreach g [case with $case civgroup names] {
        set cdict [case with $case civgroup view $g web]
        set qid   [dict get $cdict qid]
        set n_qid [dict get $cdict n_qid]

        # NEXT, format URLs properly
        dict set cdict url    [my domain $case $qid "index.json"]
        dict set cdict n_url  [my domain $case $n_qid "index.json"]

        lappend table $cdict
    }

    return [js dictab $table]
}



