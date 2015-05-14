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

smarturl /scenario /{case}/civgroup/index.html {
    Displays a list of civilian group entities for <i>case</i>, with links 
    to the actual groups.
} {
    # FIRST, validate scenario
    set case [my ValidateCase $case]

    hb page "Scenario '$case': Civilian Groups"
    hb h1 "Scenario '$case': Civilian Groups"

    my CaseNavBar $case

    set civgroups [case with $case civgroup names]

    if {[llength $civgroups] == 0} {
        hb h2 "<b>None defined.</b>"
        hb para
        return [hb /page]
    }

    hb putln "The following civilian groups are in this scenario ("
    hb iref /$case/civgroup/index.json json
    hb put )

    hb para

    hb table -headers {
        "<br>ID" "<br>Name" "<br>Neighborhood" "<br>Population" 
        "Subsistence<br>Agriculture"
    } {
        foreach civgroup $civgroups {
            set cdict [case with $case civgroup view $civgroup]
            dict with cdict {}
            hb tr {
                hb td-with {
                    hb iref /$case/civgroup/$id/index.html "$id"
                }
                hb td $longname
                hb td-with {
                    hb iref /$case/nbhood/$n/index.html "$n"
                }
                hb td $population 
                hb td $pretty_sa_flag
            }
        }
    }

    hb para

    return [hb /page]
}

smarturl /scenario /{case}/civgroup/index.json {
    Returns a JSON list of civilian group entities in the <i>case</i> 
    specified.
} {
    set case [my ValidateCase $case]

    set table [list]

    foreach g [case with $case civgroup names] {
        set cdict [case with $case civgroup view $g]
        dict set cdict url "/scenario/$case/civgroup/$g/index.json"

        set n [dict get $cdict n]
        dict set cdict n_link "/scenario/$case/nbhood/$n/index"

        lappend table $cdict
    }

    return [js dictab $table]
}

smarturl /scenario /{case}/civgroup/{g}/index.html {
    Displays data for a particular civilian group <i>g</i> in scenario
    <i>case</i>.
} {
    set case [my ValidateCase $case]

    
    if {$g ni [case with $case civgroup names]} {
        throw NOTFOUND "No such CIV group: \"$a\""
    }

    set name [case with $case civgroup get $g longname]

    hb page "Scenario '$case': Civilian Group: $g"
    hb h1 "Scenario '$case': Civilian Group: $g"

    hb putln "Click for "
    hb iref /$case/civgroup/$g/index.json "json"
    hb put "."

    hb para

    my CaseNavBar $case 

    hb para
    return [hb /page]
}

smarturl /scenario /{case}/civgroup/{g}/index.json {
    Returns JSON list of civilian group data for scenario <i>case</i> and 
    group <i>g</i>.
} {
    set case [my ValidateCase $case]

    if {$g ni [case with $case civgroup names]} {
        throw NOTFOUND "No such CIV group: \"$g\""
    }

    set cdict [case with $case civgroup view $g]

    set n [dict get $cdict n]
    dict set cdict n_link "/scenario/$case/nbhood/$n/index"

    return [js dictab [list $cdict]]
}





