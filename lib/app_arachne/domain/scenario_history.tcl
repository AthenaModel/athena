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

    metadict histvar {
        plant_a      HistActor
        control      HistNbhood
        nbmood       HistNbhood
        nbur         HistNbhood
        npop         HistNbhood
        plant_n      HistNbhood
        volatility   HistNbhood 
        mood         HistCivGroup
        pop          HistCivGroup
        sat          HistSat
        deploy_ng    HistDeployNg
        nbcoop       HistNbCoop
        security     HistSecurity
        coop         HistCoop
        flow         HistFlow
        plant_na     HistNbhoodActor
        support      HistNbhoodActor
        hrel         HistHrel
        service_sg   HistService
        vrel         HistVrel
        econ         HistEcon
        aam_battle   HistBattle 
        activity_nga HistActivity
    }

    method ValidateVar {case var} {
        set var [string tolower $var]

        if {$var ni [dict keys [my histvar]]} {
            throw NOTFOUND "No such history variable: $var"
        }

        return $var
    }

    # HistActor content case var
    #
    # content - html | json
    # case   - an Arachne case
    # var    - a history variable with an actor for the key
    #
    # This method generates a history request page for an Athena history
    # variable keyed to actor.

    method HistActor {content case var} {
        if {$content eq "html"} {
            hb form {
                my ActorForm $case
                hb para
                my TimeSpanForm $case $var
            }
        } else {
            set actors [list  ALL {*}[case with $case actor names]]
            set a [qdict prepare a -toupper -default ALL -in $actors]

            # NEXT, validate time parms
            my ValidateTimes

            if {![qdict ok]} {
                return [js reject [qdict errors]]
            }

            # NEXT, get JSON and redirect
            my JSONQuery $case $var {a}            
        }       
    }

    # HistNbhood content case var
    #
    # content - html | json
    # case    - an Arachne case
    # var     - a history variable with nbhood for the key
    #
    # This method either generates an HTML form for a nbhood history variable
    # or returns the history as JSON.

    method HistNbhood {content case var} {
        if {$content eq "html"} {
            hb form {
                my NbhoodForm $case
                hb para
                my TimeSpanForm $case $var
            }
        } else {
            # NEXT, validate nbhood
            set nbhoods [list ALL {*}[case with $case nbhood names]]
            set n [qdict prepare n -toupper -default ALL -in $nbhoods]
            lappend keys n

            # NEXT, validate time parms
            my ValidateTimes

            if {![qdict ok]} {
                return [js reject [qdict errors]]
            }

            # NEXT, construct the query
            my JSONQuery $case $var n             
        }        
    }

    # HistCivGroup content case var args
    #
    # content - html | json
    # case    - an Arachne case
    # var     - a history variable
    #
    # This method either generates an HTML form for a CIV group history 
    # variable or returns the history as JSON.

    method HistCivGroup {content case var} {
        if {$content eq "html"} {
            hb form {
                my GroupForm $case -gtypes CIV
                hb para
                my TimeSpanForm $case $var
            }
        } else {
            set groups [list  ALL {*}[case with $case group names CIV]]
            set g [qdict prepare g -toupper -default ALL -in $groups]

            # NEXT, validate time parms
            my ValidateTimes

            if {![qdict ok]} {
                return [js reject [qdict errors]]
            }

            # NEXT, get JSON and redirect
            my JSONQuery $case $var g            
        }  
    }

    # HistSat content case var args
    #
    # content - html | json
    # case    - an Arachne case
    # var     - a history variable
    #
    # This method either generates an HTML form for satisfaction history 
    # or returns the history as JSON.

    method HistSat {content case var} {
        if {$content eq "html"} {
            hb form {
                my GroupForm $case -gtypes CIV
                hb para
                my ConcernForm
                hb para
                my TimeSpanForm $case $var
            }
        } else {
            set groups [list  ALL {*}[case with $case group names CIV]]
            set g [qdict prepare g -toupper -default ALL -in $groups]

            set concerns [list ALL AUT CUL SFT QOL]
            set c [qdict prepare c -toupper -default ALL -in $concerns]

            # NEXT, validate time parms
            my ValidateTimes

            if {![qdict ok]} {
                return [js reject [qdict errors]]
            }

            # NEXT, get JSON and redirect
            my JSONQuery $case $var {g c}            
        }          
    }

    # HistNbhoodGroupHtml content case var
    #
    # content - html | json
    # case    - an Arachne case
    # var     - a history variable with nbhood and group for the key
    #
    # This method either generates an HTML form for deployment history 
    # or returns the history as JSON.

    method HistDeployNg {content case var} {
        if {$content eq "html"} {
            hb form {
                my NbhoodForm $case
                hb para
                my GroupForm $case -gtypes {FRC ORG}
                hb para
                my TimeSpanForm $case $var
            }
        } else {
            # NEXT, validate nbhood and group
            set nbhoods [list ALL {*}[case with $case nbhood names]]
            set n [qdict prepare n -toupper -default ALL -in $nbhoods]

            set groups [list  ALL {*}[case with $case group names {FRC ORG}]]
            set g [qdict prepare g -toupper -default ALL -in $groups]

            # NEXT, validate time parms
            my ValidateTimes

            if {![qdict ok]} {
                return [js reject [qdict errors]]
            }

            # NEXT, get JSON and redirect
            my JSONQuery $case $var {n g}            
        }
    }

    # HistNbCoop content case var
    #
    # content - html | json
    # case    - an Arachne case
    # var     - a history variable with nbhood for the key
    #
    # This method either generates an HTML form for nbhood coop history 
    # or returns the history as JSON.

    method HistNbCoop {content case var} {
        if {$content eq "html"} {
            hb form {
                my NbhoodForm $case
                hb para
                my GroupForm $case -gtypes FRC
                hb para
                my TimeSpanForm $case $var
            }
        } else {
            # NEXT, validate nbhood and group
            set nbhoods [list ALL {*}[case with $case nbhood names]]
            set n [qdict prepare n -toupper -default ALL -in $nbhoods]

            set groups [list  ALL {*}[case with $case group names FRC]]
            set g [qdict prepare g -toupper -default ALL -in $groups]

            # NEXT, validate time parms
            my ValidateTimes

            if {![qdict ok]} {
                return [js reject [qdict errors]]
            }

            # NEXT, get JSON and redirect
            my JSONQuery $case $var {n g}            
        }
    }

    # HistSecurity content case var
    #
    # content - html | json
    # case    - an Arachne case
    # var     - a history variable with nbhood for the key
    #
    # This method either generates an HTML form for security history 
    # or returns the history as JSON.

    method HistSecurity {content case var} {
        if {$content eq "html"} {
            hb form {
                my NbhoodForm $case
                hb para
                my GroupForm $case -gtypes {CIV FRC ORG}
                hb para
                my TimeSpanForm $case $var
            }
        } else {
            # NEXT, validate nbhood and group
            set nbhoods [list ALL {*}[case with $case nbhood names]]
            set n [qdict prepare n -toupper -default ALL -in $nbhoods]

            set groups [list ALL {*}[case with $case group names {CIV FRC ORG}]]
            set g [qdict prepare g -toupper -default ALL -in $groups]

            # NEXT, validate time parms
            my ValidateTimes

            if {![qdict ok]} {
                return [js reject [qdict errors]]
            }

            # NEXT, get JSON and redirect
            my JSONQuery $case $var {n g}            
        }
    }

    # HistNbhoodActor content case var
    #
    # content - html | json 
    # case    - an Arachne case
    # var     - a history variable 
    #
    # This method either generates an HTML form for history by nbhood and 
    # actor or returns the history as JSON.

    method HistNbhoodActor {content case var} {
        if {$content eq "html"} {
            hb form {
                my NbhoodForm $case
                hb para
                my ActorForm $case
                hb para
                my TimeSpanForm $case $var
            }
        } else {
            set actors [list  ALL {*}[case with $case actor names]]
            set a [qdict prepare a -toupper -default ALL -in $actors]

            # NEXT, validate nbhood
            set nbhoods [list ALL {*}[case with $case nbhood names]]
            set n [qdict prepare n -toupper -default ALL -in $nbhoods]

            # NEXT, validate time parms
            my ValidateTimes

            if {![qdict ok]} {
                return [js reject [qdict errors]]
            }

            # NEXT, get JSON and redirect
            my JSONQuery $case $var {n a}             
        }   
    }


    # HistCoop case var
    #
    # content - html | json
    # case    - an Arachne case
    # var     - a history variable
    #
    # This method either generates an HTML form for cooperation history
    # or returns the history as JSON.

    method HistCoop {content case var} {
        if {$content eq "html"} {
            hb form {
                my GroupForm $case -var f -gtypes CIV
                hb para
                my GroupForm $case -var g -gtypes FRC
                hb para
                my TimeSpanForm $case $var
            }
        } else {
            set groups1 [list  ALL {*}[case with $case group names CIV]]
            set f [qdict prepare f -toupper -default ALL -in $groups1]

            set groups2 [list  ALL {*}[case with $case group names FRC]]
            set g [qdict prepare g -toupper -default ALL -in $groups2]

            # NEXT, validate time parms
            my ValidateTimes

            if {![qdict ok]} {
                return [js reject [qdict errors]]
            }

            # NEXT, get JSON and redirect
            my JSONQuery $case $var {f g}             
        }
    }

    # HistHrel content case var
    #
    # content - html | json
    # case    - an Arachne case
    # var     - a history variable with nbhood for the key
    #
    # This method either generates an HTML form for horiz. relationshop 
    # history or returns the history as JSON.

    method HistHrel {content case var} {
        if {$content eq "html"} {
            hb form {
                my GroupForm $case -var f 
                hb para
                my GroupForm $case -var g 
                hb para
                my TimeSpanForm $case $var
            }
        } else {
            set groups1 [list  ALL {*}[case with $case group names]]
            set f [qdict prepare f -toupper -default ALL -in $groups1]

            set groups2 [list  ALL {*}[case with $case group names]]
            set g [qdict prepare g -toupper -default ALL -in $groups2]

            # NEXT, validate time parms
            my ValidateTimes

            if {![qdict ok]} {
                return [js reject [qdict errors]]
            }

            # NEXT, get JSON and redirect
            my JSONQuery $case $var {f g}             
        }
    }

    # HistFlow content case var
    #
    # content - html | json
    # case    - an Arachne case
    # var     - a history variable with nbhood for the key
    #
    # This method either generates an HTML form for population flow history 
    # or returns the history as JSON.

    method HistFlow {content case var} {
        if {$content eq "html"} {
            hb form {
                my GroupForm $case -var f -gtypes CIV
                hb para
                my GroupForm $case -var g -gtypes CIV
                hb para
                my TimeSpanForm $case $var
            }
        } else {
            set groups1 [list  ALL {*}[case with $case group names CIV]]
            set f [qdict prepare f -toupper -default ALL -in $groups1]

            set groups2 [list  ALL {*}[case with $case group names CIV]]
            set g [qdict prepare g -toupper -default ALL -in $groups2]

            # NEXT, validate time parms
            my ValidateTimes

            if {![qdict ok]} {
                return [js reject [qdict errors]]
            }

            # NEXT, get JSON and redirect
            my JSONQuery $case $var {f g}             
        }
    }

    # HistVrel content case var
    #
    # content - html | json
    # case    - an Arachne case
    # var     - not used
    # 
    # This method either generates an HTML form for vert. relationship history 
    # or returns the history as JSON.

    method HistVrel {content case var} {
        if {$content eq "html"} {
            hb form {
                my GroupForm $case
                hb para
                my ActorForm $case
                hb para
                my TimeSpanForm $case "vrel"
            }
        } else {
            set groups [list  ALL {*}[case with $case group names]]
            set g [qdict prepare g -toupper -default ALL -in $groups]

            set actors [list  ALL {*}[case with $case actor names]]
            set a [qdict prepare a -toupper -default ALL -in $actors]

            # NEXT, validate time parms
            my ValidateTimes

            if {![qdict ok]} {
                return [js reject [qdict errors]]
            }

            # NEXT, get JSON and redirect
            my JSONQuery $case "vrel" {g a}
        }
    }

    # HistEcon content case var
    #
    # content - html | json 
    # case    - an Arachne case
    # var     - not used
    #
    # This method either generates an HTML form for econ history 
    # or returns the history as JSON.

    method HistEcon {content case var} {
        if {$content eq "html"} {
            hb form {
                my TimeSpanForm $case "econ"
            }
        } else {
            # NEXT, validate time parms
            my ValidateTimes

            if {![qdict ok]} {
                return [js reject [qdict errors]]
            }

            # NEXT, get JSON and redirect
            my JSONQuery $case "econ" ""
        }
    }

    # HistBattle content case var
    #
    # content - html | json
    # case    - an Arachne case
    # var     - not used
    #
    # This method either generates an HTML form for battle history 
    # or returns the history as JSON.

    method HistBattle {content case var} {
        if {$content eq "html"} {
            hb form {
                my NbhoodForm $case
                hb para
                my GroupForm $case -var f -gtypes FRC
                hb para
                my GroupForm $case -var g -gtypes FRC
                hb para

                my TimeSpanForm $case "aam_battle"
            }
        } else {
            # NEXT, validate nbhood and group
            set nbhoods [list ALL {*}[case with $case nbhood names]]
            set n [qdict prepare n -toupper -default ALL -in $nbhoods]

            set groups [list  ALL {*}[case with $case group names FRC]]
            set f [qdict prepare f -toupper -default ALL -in $groups]

            set groups [list  ALL {*}[case with $case group names FRC]]
            set g [qdict prepare g -toupper -default ALL -in $groups]

            # NEXT, validate time parms
            my ValidateTimes

            if {![qdict ok]} {
                return [js reject [qdict errors]]
            }

            # NEXT, get JSON and redirect
            my JSONQuery $case "aam_battle" {n f g}
        }
    }

    # HistActivity content case var
    #
    # content - html | json
    # case    - an Arachne case
    # var     - not used
    #
    # This method either generates an HTML form for group activity history 
    # or returns the history as JSON.

    method HistActivity {content case var} {
        set alist [case with $case activity names]
        set alist [list ALL {*}$alist]

        if {$content eq "html"} {
            hb form {
                my NbhoodForm $case
                hb para
                my GroupForm $case -gtypes {FRC ORG}
                hb para    
                hb putln "Select an activity or 'ALL'."
                hb para
                hb enum a -selected ALL $alist
                hb para
                my TimeSpanForm $case "activity_nga"
            }
        } else {
            # NEXT, validate nbhood and group
            set nbhoods [list ALL {*}[case with $case nbhood names]]
            set n [qdict prepare n -toupper -default ALL -in $nbhoods]

            set groups [list  ALL {*}[case with $case group names {FRC ORG}]]
            set g [qdict prepare g -toupper -default ALL -in $groups]

            set a [qdict prepare a -toupper -default ALL -in $alist]

            # NEXT, validate time parms
            my ValidateTimes

            if {![qdict ok]} {
                return [js reject [qdict errors]]
            }

            # NEXT, get JSON and redirect
            my JSONQuery $case "activity_nga" {n g a} 
        }     
    }

    # HistService content case var
    #
    # content - html | json
    # case    - an Arachne case
    # var     - not used
    #
    # This method either generates an HTML form for ENI and abstract service
    # history or returns the history as JSON.

    method HistService {content case var} {
        set slist [list ALL ENERGY ENI TRANSPORT WATER]
        if {$content eq "html"} {
            hb form {
                hb putln "Select a service or 'ALL'."
                hb para
                hb enum s -selected ALL $slist
                hb para
                my GroupForm $case -gtypes CIV
                hb para
                my TimeSpanForm $case "service_sg"
            }
        } else {
            set s [qdict prepare s -toupper -default ALL -in $slist]

            set groups [list  ALL {*}[case with $case group names CIV]]
            set g [qdict prepare g -toupper -default ALL -in $groups]

            # NEXT, validate time parms
            my ValidateTimes

            if {![qdict ok]} {
                return [js reject [qdict errors]]
            }

            # NEXT, get JSON and redirect
            my JSONQuery $case "service_sg" {s g}
        }  
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
        set filename [app namegen ".json"]

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
            case with $case query $query -mode jsonok -filename $filename
        } on error {result eopts} {
            return [js exception $result [dict get $eopts -errorinfo]]
        }

        my redirect "/temp/[file tail $filename]" 
    }
}

smarturl /scenario /{case}/history/index.html {
    Test URL for displaying history variables/keys as HTML
} {
    set case [my ValidateCase $case]

    qdict prepare op -in {get}
    qdict prepare histvar_ -tolower
    qdict assign op histvar_

    # FIRST, begin the page
    hb page "Scenario '$case': History Variables"
    my CaseNavBar $case

    hb h1 "Scenario '$case': History Variables"

    hb putln "Select a history variable and press 'Select'."
    hb para

    set hvars [case with $case hist vars]
    hb form
    hb enum histvar_ -selected $histvar_ [lsort [dict keys $hvars]]
    hb submit "Select"
    hb /form
    hb para

    set vars [case with $case hist vars]

    if {$histvar_ ne ""} {
        if {$histvar_ ni [dict keys [my histvar]]} {
            hb span -class error \
                "Error: $histvar_ not a valid history variable."
        } else {
            hb h2 $histvar_
            set handler [my histvar $histvar_]
            my $handler html $case $histvar_
        }
    } 

    return [hb /page]
}

smarturl /scenario /{case}/history/index.json {
    Returns a list of history variables and keys to be used when 
    requesting data for a particular history variable.   
} {
    set case [my ValidateCase $case]

    set histvars [list]

    foreach {var keys} [case with $case hist vars] {
        set data(id) $var
        set data(keys) $keys

        lappend histvars [array get data]
    }

    return [js dictab $histvars]
}

smarturl /scenario /{case}/history/{var}/index.html {
    Retrieves history request form for {case} for history 
    variable {var}.
} {
    set case [my ValidateCase $case]
    set var [my ValidateVar $case $var]

    # FIRST, begin the page
    hb page "Scenario '$case': History Variable: $var"
    my CaseNavBar $case

    hb h1 "Scenario '$case': History Variable: $var"

    set handler [my histvar $var]
    my $handler html $case $var 

    return [hb /page]
}

smarturl /scenario /{case}/history/{var}/index.json {
    Retrieves history from {case} for history variable {var}.
} {

    set case [my ValidateCase $case]
    set var [my ValidateVar $case $var]

    set handler [my histvar $var]
    my $handler json $case $var
}

