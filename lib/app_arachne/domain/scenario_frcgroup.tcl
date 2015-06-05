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

smarturl /scenario /{case}/groups/frc/index.html {
    Displays a list of force group entities for <i>case</i>, with links 
    to the actual groups.
} {
    # FIRST, validate scenario
    set case [my ValidateCase $case]

    hb page "Scenario '$case': Force Groups"
    my CaseNavBar $case 

    hb h1 "Scenario '$case': Force Groups"

    set frcgroups [case with $case frcgroup names]

    if {[llength $frcgroups] == 0} {
        hb putln "None defined."
        hb para
        return [hb /page]
    }

    hb putln "The following force groups are in this scenario ("
    hb iref /$case/groups/frc/index.json json
    hb put )

    hb para

    hb table -headers {
        "<br>ID" "<br>Name" "<br>Owner" "Force<br>Type" "<br>Local"
        "Training<br>Level" "Equipment<br>Level" "Base<br>Personnel"
        "<br>Demeanor" "Cost,<br>\$/person/week" 
    } {
        foreach frcgroup $frcgroups {
            set fdict [case with $case frcgroup view $frcgroup web]
            dict with fdict {}
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

smarturl /scenario /{case}/groups/frc/index.json {
    Returns a JSON list of force group entities in the <i>case</i> specified.
} {
    set case [my ValidateCase $case]

    set table [list]

    foreach g [case with $case frcgroup names] {
        set fdict [case with $case frcgroup view $g web]
        set qid   [dict get $fdict qid]
        set a_qid [dict get $fdict a_qid]

        # NEXT, format URLs properly
        dict set fdict url [my domain $case $qid "index.json"]
        if {$a_qid ne ""} {
            dict set fdict a_url [my domain $case $a_qid "index.json"]
        }

        lappend table $fdict
    }

    return [js dictab $table]
}


