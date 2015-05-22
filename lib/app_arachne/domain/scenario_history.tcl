#-----------------------------------------------------------------------
# TITLE:
#   domain/scenario_history.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# PACKAGE:
#   app_arachne(n): Arachne Implementation Package
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   /scenario/{case}/history: /scenario handlers for handling history requests
#   for specific cases.
#
#-----------------------------------------------------------------------

smarturl /scenario /{case}/history/index.html {
    Test URL for displaying history variables/keys as HTML
} {
    set case [my ValidateCase $case]

    # FIRST, begin the page
    hb page "Scenario '$case': History Variables"
    hb h1 "Scenario '$case': History Variables"

    my CaseNavBar $case

    hb putln "Select a history variable and press 'Select'."
    hb para

    qdict prepare op -in {get}
    qdict prepare histvar_ -tolower
    qdict assign op histvar_

    set hvars [case with $case hist vars]
    hb form
    hb enum histvar_ -selected $histvar_ [lsort [dict keys $hvars]]
    hb submit "Select"
    hb /form
    hb para

    if {$histvar_ ne "" && $histvar_ in $hvars} {
        my redirect [my domain $case history $histvar_ index.html]
    }

    return [hb /page]
}

smarturl /scenario /{case}/history/index.json {
    Returns a list of history variables and keys to be used when 
    requesting data for a particular history variable.   
} {
    set case [my ValidateCase $case]

    set hud [huddle compile dict [case with $case hist vars]]

    return [js ok $hud]
}

smarturl /scenario /{case}/history/{var}/index.html {
    Retrieves history from {case} for neighborhood control.
} {
    switch -exact -- $var {
        control    -
        nbmood     -
        volatility -
        plant_n    -
        npop       -
        nbur {
            return [my NbhoodVarHtml $case $var]
        }

        default {
            return [my UnsupportedVarHtml $case $var]
        }        
    }
}

smarturl /scenario /{case}/history/{var}/index.json {
    Retrieves history from {case} for history variable {var}.
} {
    switch -exact -- $var {
        control    -
        nbmood     -
        volatility -
        plant_n    -
        npop       -
        nbur {
            my NbhoodVarJson $case $var
        }

        default {
            return [js error "$var not supported" ""]
        }
    }
}