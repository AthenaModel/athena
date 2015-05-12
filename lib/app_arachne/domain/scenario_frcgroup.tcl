#-----------------------------------------------------------------------
# TITLE:
#   domain/scenario_frcgroup.tcl
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
#   smartdomain(n) and return data related to FRC groups found within a
#   particular Arachne case.
#
#   Additional URLs are defined in domain/scenario_*.tcl.
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# General Content

smarturl /scenario /{case}/frcgroup/index.html {
    Displays a list of force group entities for <i>case</i>, with links 
    to the actual groups.
} {
    # FIRST, validate scenario
    set case [my ValidateCase $case]

    hb page "Scenario '$case': Force Groups"
    hb h1 "Scenario '$case': Force Groups"

    my CaseNavBar $case

    hb table -headers {
        "<br>ID" "<br>Name"
    } {
        foreach frcgroup [case with $case frcgroup names] {
            set fdict [case with $case frcgroup view $frcgroup]
            dict with fdict {}
            hb tr {
                hb td-with {
                    hb iref /$case/frcgroup/$id/index.html "$id"
                }
                hb td $longname
            }
        }
    }

    hb para

    return [hb /page]
}

smarturl /scenario /{case}/frcgroup/index.json {
    Returns a JSON list of force group entities in the <i>case</i> specified.
} {
    set case [my ValidateCase $case]

    set table [list]

    foreach g [case with $case frcgroup names] {
        set fdict [case with $case frcgroup view $g]
        dict set fdict url "/scenario/$case/frcgroup/$g/index.json"

        lappend table $fdict
    }

    return [js dictab $table]
}

smarturl /scenario /{case}/frcgroup/{g}/index.html {
    Displays data for a particular force group <i>g</i> in scenario 
    <i>case</i>.
} {
    set case [my ValidateCase $case]

    
    if {$g ni [case with $case frcgroup names]} {
        throw NOTFOUND "No such FRC group: \"$a\""
    }

    set name [case with $case frcgroup get $g longname]

    hb page "Scenario '$case': Force Group: $g"
    hb h1 "Scenario '$case': Force Group: $g"

    my CaseNavBar $case 

    hb para
    return [hb /page]
}

smarturl /scenario /{case}/frcgroup/{g}/index.json {
    Returns JSON list of force group data for scenario <i>case</i> and 
    group <i>g</i>.
} {
    set case [my ValidateCase $case]

    if {$g ni [case with $case frcgroup names]} {
        throw NOTFOUND "No such FRC group: \"$g\""
    }

    set fdict [case with $case frcgroup view $g]

    return [js dictab [list $fdict]]
}





