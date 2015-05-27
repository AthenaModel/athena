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
    Retrieves history request form for {case} for history 
    variable {var}.
} {
    switch -exact -- $var {
        control    -
        nbmood     -
        nbur       -
        npop       -
        plant_n    -
        volatility {
            return [my NbhoodHistHtml $case $var]
        }

        mood -
        pop    {
            return [my GroupHistHtml $case $var -gtypes CIV]
        }

        plant_na -
        support  {
            return [my NbhoodActorHistHtml $case $var]
        } 

        aam_battle {
            return [my BattleHistHtml $case]
        }

        activity_nga {
            return [my ActivityHistHtml $case]
        }

        coop {
            return [my GroupsHistHtml $case $var -gtypes1 CIV -gtypes2 FRC]
        }

        deploy_ng {
            return [my NbhoodGroupHistHtml $case $var -gtypes {FRC ORG}]
        }

        econ {
            return [my EconHistHtml $case]
        }

        flow {
            return [my GroupsHistHtml $case $var -gtypes1 CIV -gtypes2 CIV]
        }

        hrel {
            return [my GroupsHistHtml $case $var]
        }

        nbcoop {
            return [my NbhoodGroupHistHtml $case $var -gtypes FRC]
        }

        nbsat {
            return [my NbhoodHistHtml $case $var -concerns 1]
        }

        plant_a {
            return [my ActorHistHtml $case $var]
        }

        sat {
            return [my GroupHistHtml $case $var -gtypes CIV -concerns 1]
        }

        security {
            return [my NbhoodGroupHistHtml $case $var]
        }

        service_sg {
            return [my ServiceHistHtml $case]
        }

        vrel {
            return [my VrelHistHtml $case]
        }

        default {
            return [my UnsupportedHistHtml $case $var]
        }        
    }
}

smarturl /scenario /{case}/history/{var}/index.json {
    Retrieves history from {case} for history variable {var}.
} {
    switch -exact -- $var {
        control    -
        nbmood     -
        nbur       -
        npop       -
        plant_n    -
        volatility {
            my NbhoodHistJson $case $var
        }

        mood -
        pop    {
            my NbhoodGroupHistJson $case $var -gtypes CIV
        }

        plant_na -
        support  {
            my NbhoodActorHistJson $case $var
        }

        aam_battle {
            my BattleHistJson $case
        }

        activity_nga {
            my ActivityHistJson $case
        }

        coop {
            my GroupsHistJson $case $var -gtypes1 CIV -gtypes2 FRC
        }

        deploy_ng {
            my NbhoodGroupHistJson $case $var -gtypes {FRC ORG}
        }

        econ {
            my EconHistJson $case
        }

        flow {
            my GroupsHistJson $case $var -gtypes1 CIV -gtypes2 CIV
        }

        hrel {
            my GroupsHistJson $case $var
        }

        nbcoop {
            my NbhoodGroupHistJson $case $var -gtypes FRC
        }

        nbsat {
            my NbhoodHistJson $case $var -concerns 1
        }

        plant_a {
            my ActorHistJson $case $var
        }

        sat {
            my GroupHistJson $case $var -gtypes CIV -concerns 1
        }

        security {
            my NbhoodGroupHistJson $case $var
        }

        service_sg {
            my ServiceHistJson $case
        }

        vrel {
            my VrelHistJson $case
        }

        default {
            return [js error "$var not supported" ""]
        }
    }
}