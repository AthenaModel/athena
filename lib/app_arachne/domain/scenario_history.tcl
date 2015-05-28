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
oo::define /scenario {

    # HistoryBanner case var
    #
    # case    - an Arachne case
    # var     - a history variable
    #
    # This method generate boilerplate common to all history request
    # pages.

    method HistoryBanner {case var} {
        set case [my ValidateCase $case]

        # FIRST, begin the page
        hb page "Scenario '$case': History for [string toupper $var]"
        hb h1 "Scenario '$case': History for [string toupper $var]"

        my CaseNavBar $case
    }

    # HistActorHtml case var
    #
    # case   - an Arachne case
    # var    - a history variable with an actor for the key
    #
    # This method generates a history request page for an Athena history
    # variable indexed by actor.

    method HistActorHtml {case var} {
        my HistoryBanner $case $var

        hb form 

        my ActorForm $case
        hb para
        my TimeSpanForm $case $var
               
        hb /form

        return [hb /page]        
    }

    # HistActorJson case var
    #
    # case   - an Arachne case
    # var    - a history variable with actor for the key
    #
    # This method extracts pertinent data from the qdict and validates it.
    # If it's valid, history data is extracted and returned as JSON.

    method HistActorJson {case var} {
        set actors [list  ALL {*}[case with $case actor names]]
        set a [qdict prepare a -toupper -default ALL -in $actors]

        # NEXT, validate time parms
        if {![my ValidateTimes]} {
            return [js reject [qdict errors]]
        }

        # NEXT, get JSON and redirect
        my JSONQuery $case $var {a}             
    }

    # HistNbhoodHtml case var ?args?
    #
    # case   - an Arachne case
    # var    - a history variable with nbhood for the key
    # args   - optional args
    #
    # This method generates a form for a nbhood history variable so the
    # user can pick a neighborhood (or ALL) and start and end times to
    # extract the data.  If the -concerns option is set to 1, a "concerns"
    # form is output.

    method HistNbhoodHtml {case var args} {
        set concerns 0

        foroption opt args -all {
            -concerns { set concerns [lshift args] }
        } 

        my HistoryBanner $case $var

        hb form

        my NbhoodForm $case
        hb para

        if {$concerns} {
            my ConcernForm
            hb para
        }

        my TimeSpanForm $case $var

        hb /form

        return [hb /page]        
    }

    # HistNbhoodJson case var args
    #
    # case   - an Arachne case
    # var    - a history variable with nbhood (and maybe concern) for key(s).
    # args   - optional arguments
    #
    # This method extracts pertinent data from the qdict and validates it.
    # If it's valid, history data is extracted and returned as JSON.
    #
    # Options:
    #   -concerns  - set to 1, concerns are part of the qdict 

    method HistNbhoodJson {case var args} {
        set concerns 0

        foroption opt args -all {
            -concerns { set concerns [lshift args] }
        }   

        # NEXT, validate nbhood
        set nbhoods [list ALL {*}[case with $case nbhood names]]
        set n [qdict prepare n -toupper -default ALL -in $nbhoods]
        lappend keys n

        # NEXT, validate concern, if needed
        if {$concerns} {
            set concerns [list ALL AUT CUL SFT QOL]
            set c [qdict prepare c -toupper -default ALL -in $concerns]
            lappend keys c
        }

        # NEXT, validate time parms
        if {![my ValidateTimes]} {
            return [js reject [qdict errors]]
        }

        # NEXT, construct the query
        my JSONQuery $case $var $keys        
    }

    # HistNbhoodGroupHtml case var ?args?
    #
    # case    - an Arachne case
    # var     - a history variable with nbhood and group for the key
    # args    - optional arguments
    #
    # This method generates a form for inputting data to retrieve history
    # for a variable that is keyed on nbhood and group.  For example, 
    # neighborhood security is a variable that would have this form to get
    # security by nbhood and group.  The -gtypes option can be used to
    # specify which group types should be included in the groups dropdown
    # menu. The default for -gtypes is all group types.

    method HistNbhoodGroupHtml {case var args} {
        # FIRST get the options
        set gtypes {CIV FRC ORG}

        foroption opt args -all {
            -gtypes   { set gtypes   [lshift args] }
        }

        my HistoryBanner $case $var

        hb form

        my NbhoodForm $case
        hb para
        my GroupForm $case -gtypes $gtypes
        hb para
        my TimeSpanForm $case $var

        hb /form

        return [hb /page]
    }

    # HistNbhoodGroupJson case var args
    #
    # case   - an Arachne case
    # var    - a history variable with nbhood and group for key(s).
    # args   - optional arguments
    #
    # This method extracts pertinent data from the qdict and validates it.
    # If it's valid, history data is extracted and returned as JSON.
    #
    # Options:
    #   -gtypes  - list of group types to validate agains, defaults to all types 

    method HistNbhoodGroupJson {case var args} {
        # FIRST get the options
        set gtypes {CIV FRC ORG}

        foroption opt args -all {
            -gtypes   { set gtypes   [lshift args] }
        }   

        # NEXT, validate nbhood and group
        set nbhoods [list ALL {*}[case with $case nbhood names]]
        set n [qdict prepare n -toupper -default ALL -in $nbhoods]

        set groups [list  ALL {*}[case with $case group names $gtypes]]
        set g [qdict prepare g -toupper -default ALL -in $groups]

        # NEXT, validate time parms
        if {![my ValidateTimes]} {
            return [js reject [qdict errors]]
        }

        # NEXT, get JSON and redirect
        my JSONQuery $case $var {n g}
    }

    # HistNbhoodActorHtml case var
    #
    # case    - an Arachne case
    # var     - a history variable 
    #
    # This method creates a history request page for history variables keyed
    # on neighborhood and actor.

    method HistNbhoodActorHtml {case var} {
        my HistoryBanner $case $var

        hb form

        my NbhoodForm $case
        hb para
        my ActorForm $case
        hb para
        my TimeSpanForm $case $var

        hb /form

        return [hb /page]   
    }

    # HistNbhoodActorJson case var args
    #
    # case   - an Arachne case
    # var    - a history variable with nbhood and actor for key(s).
    #
    # This method extracts pertinent data from the qdict and validates it.
    # If it's valid, history data is extracted and returned as JSON.

    method HistNbhoodActorJson {case var} {
        set actors [list  ALL {*}[case with $case actor names]]
        set a [qdict prepare a -toupper -default ALL -in $actors]

        # NEXT, validate nbhood
        set nbhoods [list ALL {*}[case with $case nbhood names]]
        set n [qdict prepare n -toupper -default ALL -in $nbhoods]

        # NEXT, validate time parms
        if {![my ValidateTimes]} {
            return [js reject [qdict errors]]
        }

        # NEXT, get JSON and redirect
        my JSONQuery $case $var {n a}            
    }

    # HistGroupHtml case var args
    #
    # case   - an Arachne case
    # var    - a history variable
    # args   - optional args
    #
    # This method creates a history request page for history variables keyed
    # on group.  If the -gtypes option is specified, only those group types
    # are included in the dropdown menu.  The default for -gtypes is all
    # group types.  If the -concerns option is set to 1, then a "concerns"
    # menu is included.

    method HistGroupHtml {case var args} {
        # FIRST get the options
        set gtypes   {CIV FRC ORG}
        set concerns 0

        foroption opt args -all {
            -gtypes   { set gtypes   [lshift args] }
            -concerns { set concerns [lshift args] }
        }      

        my HistoryBanner $case $var

        hb form
        my GroupForm $case -gtypes $gtypes
        hb para

        if {$concerns} {
            my ConcernForm
            hb para
        }

        my TimeSpanForm $case $var

        hb /form

        return [hb /page]        
    }

    # HistGroupJson case var args
    #
    # case   - an Arachne case
    # var    - a history variable with nbhood and group for key(s).
    # args   - optional arguments
    #
    # This method extracts pertinent data from the qdict and validates it.
    # If it's valid, history data is extracted and returned as JSON.
    #
    # Options:
    #   -gtypes   - list of group types, defaults to all types
    #   -concerns - flag indicating whether concerns are part of the request 

    method HistGroupJson {case var args} {
        # FIRST get the options
        set gtypes   {CIV FRC ORG}
        set concerns 0

        foroption opt args -all {
            -gtypes   { set gtypes   [lshift args] }
            -concerns { set concerns [lshift args] }
        }        

        set groups [list  ALL {*}[case with $case group names $gtypes]]
        set g [qdict prepare g -toupper -default ALL -in $groups]
        lappend keys g

        if {$concerns} {
            set concerns [list ALL AUT CUL SFT QOL]
            set c [qdict prepare c -toupper -default ALL -in $concerns]
            lappend keys c
        }

        # NEXT, validate time parms
        if {![my ValidateTimes]} {
            return [js reject [qdict errors]]
        }

        # NEXT, get JSON and redirect
        my JSONQuery $case $var $keys        
    }

    # HistGroupsHtml case var args
    #
    # case    - an Arachne case
    # var     - a history variable
    # args    - optional arguments
    #
    # This method creates two group dropdown menus.  Optional args specify
    # which group types should be included in the menus.  The default is
    # all group types.

    method HistGroupsHtml {case var args} {
        set gtypes1 {CIV FRC ORG}
        set gtypes2 {CIV FRC ORG}

        foroption opt args -all {
            -gtypes1 { set gtypes1 [lshift args] }
            -gtypes2 { set gtypes2 [lshift args] }
        } 

        my HistoryBanner $case $var

        hb form
        my GroupForm $case -var f -gtypes $gtypes1
        hb para
        my GroupForm $case -var g -gtypes $gtypes2
        hb para
        my TimeSpanForm $case $var

        hb /form

        return [hb /page] 
    }

    # HistGroupsJson case var args
    #
    # case   - an Arachne case
    # var    - a history variable with two groups as keys 
    # args   - optional arguments
    #
    # This method extracts pertinent data from the qdict and validates it.
    # If it's valid, history data is extracted and returned as JSON.
    #
    # Options:
    #   -gtypes1 - list of group types for first key, defaults to all types
    #   -gtypes2 - list of group types for second key, default to all types 

    method HistGroupsJson {case var args} {
        # FIRST get the options
        set gtypes1 {CIV FRC ORG}
        set gtypes2 {CIV FRC ORG}

        foroption opt args -all {
            -gtypes1   { set gtypes1 [lshift args] }
            -gtypes2   { set gtypes2 [lshift args] }
        }        

        set groups1 [list  ALL {*}[case with $case group names $gtypes1]]
        set f [qdict prepare f -toupper -default ALL -in $groups1]

        set groups2 [list  ALL {*}[case with $case group names $gtypes2]]
        set g [qdict prepare g -toupper -default ALL -in $groups2]

        # NEXT, validate time parms
        if {![my ValidateTimes]} {
            return [js reject [qdict errors]]
        }

        # NEXT, get JSON and redirect
        my JSONQuery $case $var {f g}       
    }

    # HistVrelHtml case
    #
    # case   - an Arachne case
    # 
    # This method returns a history request page for vertical relationship

    method HistVrelHtml {case} {
        my HistoryBanner $case "vrel"

        hb form

        my GroupForm $case
        hb para
        my ActorForm $case
        hb para
        my TimeSpanForm $case "vrel"

        hb /form

        return [hb /page]
    }

    # HistVrelJson case
    #
    # case  - an Arachne case
    #
    # This method extracts vertical relationship data from history and 
    # returns it as JSON.

    method HistVrelJson {case} {
        set gtypes {CIV FRC ORG}

        set groups [list  ALL {*}[case with $case group names $gtypes]]
        set g [qdict prepare g -toupper -default ALL -in $groups]

        set actors [list  ALL {*}[case with $case actor names]]
        set a [qdict prepare a -toupper -default ALL -in $actors]

        # NEXT, validate time parms
        if {![my ValidateTimes]} {
            return [js reject [qdict errors]]
        }

        # NEXT, get JSON and redirect
        my JSONQuery $case "vrel" {g a}  
    }

    # HistEconHtml case
    #
    # case  - an Arachne case
    #
    # This method returns a history request page for econ history

    method HistEconHtml {case} {
        my HistoryBanner $case "econ"

        hb form

        my TimeSpanForm $case "econ"

        hb /form

        return [hb /page]        
    }

    # HistEconJson case
    #
    # case  - an Arachne case
    #
    # This method extracts econ history and returns it as JSON.
    
    method HistEconJson {case} {
        # FIRST, validate time parms, that's all there is
        if {![my ValidateTimes]} {
            return [js reject [qdict errors]]
        }

        # NEXT, get JSON and redirect
        my JSONQuery $case "econ" ""         
    }

    # HistBattleHtml case
    #
    # case    - an Arachne case
    #
    # This method returns a history request page for AAM battle history

    method HistBattleHtml {case} {
        my HistoryBanner $case "aam battle"

        hb form 

        my NbhoodForm $case
        hb para
        my GroupForm $case -var f -gtypes FRC
        hb para
        my GroupForm $case -var g -gtypes FRC
        hb para

        my TimeSpanForm $case "aam_battle"

        hb /form

        return [hb /page]      
    }

    # HistBattleJson case
    #
    # case  - an Arachne case
    #
    # This method extracts AAM battle history and returns it as JSON.

    method HistBattleJson {case} {
        set gtypes {FRC}

        # NEXT, validate nbhood and group
        set nbhoods [list ALL {*}[case with $case nbhood names]]
        set n [qdict prepare n -toupper -default ALL -in $nbhoods]

        set groups [list  ALL {*}[case with $case group names $gtypes]]
        set f [qdict prepare f -toupper -default ALL -in $groups]

        set groups [list  ALL {*}[case with $case group names $gtypes]]
        set g [qdict prepare g -toupper -default ALL -in $groups]

        # NEXT, validate time parms
        if {![my ValidateTimes]} {
            return [js reject [qdict errors]]
        }

        # NEXT, get JSON and redirect
        my JSONQuery $case "aam_battle" {n f g}  
    }

    # HistActivityHtml case
    #
    # case   - an Arachne case
    #
    # This method returns a history request page for group activities.

    method HistActivityHtml {case} {
        my HistoryBanner $case "activity"

        set alist [case with $case activity names]
        set alist [list ALL {*}$alist]

        hb form 

        my NbhoodForm $case
        hb para
        my GroupForm $case -gtypes {FRC ORG}
        hb para    
        hb putln "Select an activity or 'ALL'."
        hb para
        hb enum a -selected ALL $alist
        hb para
        my TimeSpanForm $case "activity_nga"

        hb /form

        return [hb /page]      
    }

    # HistActivityJson case
    #
    # case  - an Arachne case
    #
    # This method extracts group activity from history and returns it as
    # JSON.

    method HistActivityJson {case} {
        # NEXT, validate nbhood and group
        set nbhoods [list ALL {*}[case with $case nbhood names]]
        set n [qdict prepare n -toupper -default ALL -in $nbhoods]

        set groups [list  ALL {*}[case with $case group names {FRC ORG}]]
        set g [qdict prepare g -toupper -default ALL -in $groups]

        set alist [list ALL {*}[case with $case activity names]]
        set a [qdict prepare a -toupper -default ALL -in $alist]

        # NEXT, validate time parms
        if {![my ValidateTimes]} {
            return [js reject [qdict errors]]
        }

        # NEXT, get JSON and redirect
        my JSONQuery $case "activity_nga" {n g a}      
    }

    # HistServiceHtml case
    #
    # case   - an Arachne case
    #
    # This method returns a history request page for ENI and abstract
    # services.

    method HistServiceHtml {case} {
        my HistoryBanner $case "service"

        set slist [list ALL ENERGY ENI TRANSPORT WATER]

        hb form 

        hb putln "Select a service or 'ALL'."
        hb para
        hb enum s -selected ALL $slist
        hb para
        my GroupForm $case -gtypes CIV
        hb para
        my TimeSpanForm $case "service_sg"

        hb /form

        return [hb /page]
    }

    # HistServiceJson case
    #
    # case  - an Arachne case
    #
    # This method extracts ENI and abstract service data from history and 
    # returns it as JSON.

    method HistServiceJson {case} {
        set gtypes {CIV}

        set slist [list ALL ENI ENERGY TRANSPORT WATER]
        set s [qdict prepare s -toupper -default ALL -in $slist]

        set groups [list  ALL {*}[case with $case group names $gtypes]]
        set g [qdict prepare g -toupper -default ALL -in $groups]

        # NEXT, validate time parms
        if {![my ValidateTimes]} {
            return [js reject [qdict errors]]
        }

        # NEXT, get JSON and redirect
        my JSONQuery $case "service_sg" {s g}  
    }

    # HistUndefinedHtml case var
    #
    # Returns an HTML page for undefined variables.

    method HistUndefinedHtml {case var} {
        my HistoryBanner $case $var
        
        hb h2 "$var is not defined."

        return [hb /page]        
    }

    # JSONQuery case var keys
    #
    # case  - an Arachne case
    # var   - a history variable
    # keys  - list of keys in WHERE clause, possibly
    #
    # This method constructs an SQL query and a file name based on the
    # arguments provided, including any keys.  The query is made with that
    # file to receive any output.  Finally, a redirect is made to the file
    # created.

    method JSONQuery {case var keys} {
        # FIRST, the table for the lookup
        append tbl "hist_" $var

        # NEXT, build up the query
        set query "SELECT * FROM $tbl "

        # NEXT, values for where clause, if any
        set wlist [list]
        dict for {parm val} [qdict parms] {
            if {$parm in $keys && $val ne "ALL"} {
                lappend wlist "$parm='$val'"
            }
        }

        # NEXT, determine temp file name
        incr fcounter
        set fname "temp$fcounter"

        # NEXT, file extension and full path
        append fname ".json"

        if {![file exists [appdir join htdocs temp]]} {
            file mkdir [appdir join htdocs temp]
        }

        set path [appdir join htdocs temp]
        set filename [file join $path $fname]

        # NEXT, the time range
        set t1 [qdict get t1]
        set t2 [qdict get t2]

        if {$t2 eq "end"} {
            set t2 [case with $case clock now]
        }

        # NEXT, time span and where clause
        lappend wlist "t>=$t1"
        lappend wlist "t<=$t2"

        set wClause "WHERE "
        append wClause [join $wlist " AND "]

        append query $wClause

        # NEXT, extract data and redirect
        try {
            case with $case query $query -mode json -filename $filename
        } on error {result eopts} {
            return [js error $result [dict get $eopts -errorinfo]]
        }

        my redirect "/temp/[file tail $filename]" 
    }
}

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
            return [my HistNbhoodHtml $case $var]
        }

        mood -
        pop    {
            return [my HistGroupHtml $case $var -gtypes CIV]
        }

        plant_na -
        support  {
            return [my HistNbhoodActorHtml $case $var]
        } 

        aam_battle {
            return [my HistBattleHtml $case]
        }

        activity_nga {
            return [my HistActivityHtml $case]
        }

        coop {
            return [my HistGroupsHtml $case $var -gtypes1 CIV -gtypes2 FRC]
        }

        deploy_ng {
            return [my HistNbhoodGroupHtml $case $var -gtypes {FRC ORG}]
        }

        econ {
            return [my HistEconHtml $case]
        }

        flow {
            return [my HistGroupsHtml $case $var -gtypes1 CIV -gtypes2 CIV]
        }

        hrel {
            return [my HistGroupsHtml $case $var]
        }

        nbcoop {
            return [my HistNbhoodGroupHtml $case $var -gtypes FRC]
        }

        nbsat {
            return [my HistNbhoodHtml $case $var -concerns 1]
        }

        plant_a {
            return [my HistActorHtml $case $var]
        }

        sat {
            return [my HistGroupHtml $case $var -gtypes CIV -concerns 1]
        }

        security {
            return [my HistNbhoodGroupHtml $case $var]
        }

        service_sg {
            return [my HistServiceHtml $case]
        }

        vrel {
            return [my HistVrelHtml $case]
        }

        default {
            return [my HistUndefinedHtml $case $var]
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
            my HistNbhoodJson $case $var
        }

        mood -
        pop    {
            my HistNbhoodGroupJson $case $var -gtypes CIV
        }

        plant_na -
        support  {
            my HistNbhoodActorJson $case $var
        }

        aam_battle {
            my HistBattleJson $case
        }

        activity_nga {
            my HistActivityJson $case
        }

        coop {
            my HistGroupsJson $case $var -gtypes1 CIV -gtypes2 FRC
        }

        deploy_ng {
            my HistNbhoodGroupJson $case $var -gtypes {FRC ORG}
        }

        econ {
            my HistEconJson $case
        }

        flow {
            my HistGroupsJson $case $var -gtypes1 CIV -gtypes2 CIV
        }

        hrel {
            my HistGroupsJson $case $var
        }

        nbcoop {
            my HistNbhoodGroupJson $case $var -gtypes FRC
        }

        nbsat {
            my HistNbhoodJson $case $var -concerns 1
        }

        plant_a {
            my HistActorJson $case $var
        }

        sat {
            my HistGroupJson $case $var -gtypes CIV -concerns 1
        }

        security {
            my HistNbhoodGroupJson $case $var
        }

        service_sg {
            my HistServiceJson $case
        }

        vrel {
            my HistVrelJson $case
        }

        default {
            return [js error "$var not supported" ""]
        }
    }
}