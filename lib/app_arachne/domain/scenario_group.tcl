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

smarturl /scenario /{case}/group/index.html {
    Displays data for all groups in scenario <i>case</i>.
} {
    set case [my ValidateCase $case]

    hb page "Scenario '$case': Groups"
    my CaseNavBar $case

    hb h1 "Scenario '$case': Groups"

    set groups [case with $case group names]

    if {[llength $groups] == 0} {
        hb h2 "<b>None defined.</b>"
        hb para
        return [hb /page]
    }

    hb putln "The following groups are in this scenario ("
    hb iref /$case/group/index.json json
    hb put )

    hb para

    # NEXT, a minimal amount of data, the JSON URL return will have it all
    hb table -headers {
        "ID" "Name" "Group Type" 
    } {
        foreach group $groups {
            set gdict [case with $case group view $group web]
            dict with gdict {}
            hb tr {
                hb td-with {
                    hb iref "/$case/$url" "$id"
                }
                hb td $longname
                hb td $gtype
            }
        }
    }

    hb para

    return [hb /page]
}

smarturl /scenario /{case}/group/index.json {
    Returns JSON data for all groups in scenario <i>case</i>.
} {
    set case [my ValidateCase $case]

    set table [list]

    foreach g [case with $case group names] {
        set gdict [case with $case group view $g web]
        set qid   [dict get $gdict qid]
        set a_qid [dict get $gdict a_qid]

        # NEXT, format URLs properly
        dict set gdict url [my domain $case $qid "index.json"]
        if {$a_qid ne ""} {
            dict set gdict a_url [my domain $case $a_qid "index.json"]
        } 
        
        lappend table $gdict
    }

    return [js dictab $table]
}

smarturl /scenario /{case}/group/{g}/index.html {
    Displays data for a particular group <i>g</i> in scenario
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
        set qid   [dict get $gdict qid] 
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

#----------------------------------------------------------------------
# CIV group content

smarturl /scenario /{case}/group/civ.html {
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
    hb iref /$case/group/civ.json json
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

smarturl /scenario /{case}/group/civ.json {
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

#----------------------------------------------------------------------
# FRC group content

smarturl /scenario /{case}/group/frc.html {
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
        hb h2 "<b>None defined.</b>"
        hb para
        return [hb /page]
    }

    hb putln "The following force groups are in this scenario ("
    hb iref /$case/group/frc.json json
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

smarturl /scenario /{case}/group/frc.json {
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

#--------------------------------------------------------------------------
# ORG group content

smarturl /scenario /{case}/group/org.html {
    Displays a list of organization group entities for <i>case</i>, with links 
    to the actual groups.
} {
    # FIRST, validate scenario
    set case [my ValidateCase $case]

    hb page "Scenario '$case': Organization Groups"
    my CaseNavBar $case
    
    hb h1 "Scenario '$case': Organization Groups"

    set orggroups [case with $case orggroup names]

    if {[llength $orggroups] == 0} {
        hb h2 "<b>None defined.</b>"
        hb para
        return [hb /page]
    }

    hb putln "The following organization groups are in this scenario ("
    hb iref /$case/group/org.json json
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

smarturl /scenario /{case}/group/org.json {
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

