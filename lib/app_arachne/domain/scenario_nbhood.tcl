#-----------------------------------------------------------------------
# TITLE:
#   domain/scenario_nbhood.tcl
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
#   smartdomain(n) and return data related to nbhoods found within a
#   particular Arachne case.
#
#   Additional URLs are defined in domain/scenario_*.tcl.
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# General Content

smarturl /scenario /{case}/nbhood/index.html {
    Displays a list of neighborhood entities for <i>case</i>, with links to 
    the actual neighborhoods.
} {
    # FIRST, validate scenario
    set case [my ValidateCase $case]

    hb page "Scenario '$case': Neighborhoods"
    hb h1 "Scenario '$case': Neighborhoods"

    my CaseNavBar $case

    set nbhoods [case with $case nbhood names]

    if {[llength $nbhoods] == 0} {
        hb h2 "<b>None defined.</b>"
        hb para
        return [hb /page]
    }

    hb putln "The following neighborhoods are in this scenario ("
    hb iref /$case/nbhood/index.json json
    hb put )

    hb para

    hb table -headers {
        "ID" "Name" "Local" "Controller" "Urbanization" "Population"
        "Subsistence" "Consumers" "Labor Force" "Unemployed"
    } {
        foreach nbhood $nbhoods {
            set ndict [case with $case nbhood view $nbhood]
            dict with ndict {}
            hb tr {
                hb td-with {
                    hb iref /$case/nbhood/$id/index.html "$id"
                }
                hb td $longname
                hb td $local 
                hb td $controller
                hb td $urbanization
                hb td $population
                hb td $subsistence 
                hb td $consumers 
                hb td $labor_force
                hb td $unemployed 
            }
        }
    }

    hb para

    return [hb /page]
}

smarturl /scenario /{case}/nbhood/index.json {
    Returns a JSON list of nbhood entities in the <i>case</i> specified.
} {
    set case [my ValidateCase $case]

    set table [list]

    foreach n [case with $case nbhood names] {
        set ndict [case with $case nbhood view $n]
        dict set ndict url "/scenario/$case/nbhood/$n/index.json"
        set controller [dict get $ndict controller]
        if {$controller ne "NONE"} {
            dict set ndict controller_link \
                "/scenario/$case/actor/$controller/index" 
        } else {
            dict set ndict controller_link ""
        }

        lappend table $ndict
    }

    return [js dictab $table]
}

smarturl /scenario /{case}/nbhood/{n}/index.html {
    Displays data for a particular actor <i>a</i> in scenario <i>case</i>.
} {
    set case [my ValidateCase $case]

    
    if {$n ni [case with $case nbhood names]} {
        throw NOTFOUND "No such neighborhood: \"$n\""
    }

    set name [case with $case nbhood get $n longname]

    hb page "Scenario '$case': Neighborhood: $n"
    hb h1 "Scenario '$case': Neighborhood: $n"

    hb putln "Click for "
    hb iref /$case/nbhood/$n/index.json "json"
    hb put "."

    hb para

    my CaseNavBar $case 

    hb para
    return [hb /page]
}

smarturl /scenario /{case}/nbhood/{n}/index.json {
    Returns JSON list of actor data for scenario <i>case</i> and neighborhood 
    <i>n</i>.
} {
    set case [my ValidateCase $case]

    if {$n ni [case with $case nbhood names]} {
        throw NOTFOUND "No such neighborhood: \"$n\""
    }

    set ndict [case with $case nbhood view $n]

    set controller [dict get $ndict controller]
    if {$controller != "NONE"} {
        dict set ndict controller_link "/scenario/$case/actor/$controller/index"
    } else {
        dict set ndict controller_link ""
    }

    return [js dictab [list $ndict]]
}





