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

    set frcgroups [case with $case frcgroup names]

    if {[llength $frcgroups] == 0} {
        hb h2 "<b>None defined.</b>"
        hb para
        return [hb /page]
    }

    hb putln "The following force groups are in this scenario ("
    hb iref /$case/frcgroup/index.json json
    hb put )

    hb para

    hb table -headers {
        "<br>ID" "<br>Name" "<br>Owner" "Force<br>Type" "<br>Local"
        "Training<br>Level" "Equipment<br>Level" "Base<br>Personnel"
        "<br>Demeanor" "Cost,<br>\$/person/week" 
    } {
        foreach frcgroup $frcgroups {
            set fdict [case with $case frcgroup view $frcgroup]
            dict with fdict {}
            hb tr {
                hb td-with {
                    hb iref /$case/frcgroup/$id/index.html "$id"
                }
                hb td $longname
                hb td-with {
                    hb iref /$case/actor/$a/index.html "$a"
                }
                hb td $forcetype
                hb td $pretty_local
                hb td $training 
                hb td $equip_level
                hb td $base_personnel
                hb td $demeanor 
                hb td $cost
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
        set a [dict get $fdict a]
        dict set fdict a_link "/scenario/$case/actor/$a/index"

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
        throw NOTFOUND "No such FRC group: \"$g\""
    }

    set name [case with $case frcgroup get $g longname]

    hb page "Scenario '$case': Force Group: $g"
    hb h1 "Scenario '$case': Force Group: $g"

    hb putln "Click for "
    hb iref /$case/frcgroup/$g/index.json "json"
    hb put "."

    hb para

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

    set a [dict get $fdict a]
    dict set fdict a_link /$case/actor/$a/index

    return [js dictab [list $fdict]]
}





