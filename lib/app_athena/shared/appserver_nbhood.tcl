#-----------------------------------------------------------------------
# TITLE:
#    appserver_nbhood.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Neighborhoods
#
#    my://app/nbhoods/...
#    my://app/nbhood/...
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module NBHOOD {
    #-------------------------------------------------------------------
    # Type Variables

    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /nbhoods {nbhoods/?} \
            tcl/linkdict [myproc /nbhoods:linkdict] \
            tcl/enumlist [asproc enum:enumlist nbhood] \
            text/html    [myproc /nbhoods:html]                 {
                Links to the currently defined neighborhoods.  The
                HTML content includes neighborhood attributes.
            }

        appserver register /nbhoods/prox {nbhoods/prox/?} \
            text/html    [myproc /nbhoods/prox:html] {
                A tabular listing of neighborhood-to-neighborhood
                proximities.
            }

        appserver register /nbhood/{n} {nbhood/(\w+)/?} \
            text/html [myproc /nbhood:html]             \
            "Detail page for neighborhood {n}."
    }

    #-------------------------------------------------------------------
    # /nbhoods:         - All neighborhoods
    #
    # No match parameters.

    # /nbhoods:linkdict udict matchArray
    #
    # tcl/linkdict of all neighborhoods.
    
    proc /nbhoods:linkdict {udict matchArray} {
        return [objects:linkdict {
            label    "Neighborhoods"
            listIcon ::projectgui::icon::nbhood12
            table    gui_nbhoods
        }]
    }

    # /nbhoods:html udict matchArray
    #
    # Tabular display of neighborhood data; content depends on 
    # simulation state.

    proc /nbhoods:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Begin the page
        ht page "Neighborhoods"
        ht title "Neighborhoods"

        ht putln "The scenario currently includes the following neighborhoods:"
        ht para

        if {![locked]} {
            ht query {
                SELECT longlink      AS "Neighborhood",
                       local         AS "Local?",
                       urbanization  AS "Urbanization",
                       controller    AS "Controller",
                       pcf           AS "Prod. Capacity Factor"
                FROM gui_nbhoods 
                ORDER BY longlink
            } -default "None." -align LLLLRR

        } else {
            ht query {
                SELECT longlink      AS "Neighborhood",
                       local         AS "Local?",
                       urbanization  AS "Urbanization",
                       controller    AS "Controller",
                       since         AS "Since",
                       population    AS "Population",
                       mood0         AS "Mood at T0",
                       mood          AS "Mood Now",
                       volatility    AS "Vty",
                       pcf           AS "Prod. Capacity Factor"
                FROM gui_nbhoods
                ORDER BY longlink
            } -default "None." -align LLLLR
        }

        ht /page

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /nbhoods/prox:         - All neighborhood proximities
    #
    # No match parameters.

    # html_Nbrel udict matchArray
    #
    #
    # Tabular display of neighborhood relationship data.

    proc /nbhoods/prox:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Begin the page
        ht page "Neighborhood Proximities"
        ht title "Neighborhood Proximities"

        ht putln {
            The neighborhoods in the scenario have the following 
            proximities.
        }

        ht para

        ht query {
            SELECT m_longlink      AS "Of Nbhood",
                   n_longlink      AS "With Nbhood",
                   proximity       AS "Proximity"
            FROM gui_nbrel_mn 
            ORDER BY m_longlink, n_longlink
        } -default "No neighborhood proximities exist." -align LLL

        ht /page

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /nbhood/{n}:         - Detail page for neighborhood {n}
    #
    # Match Parameters:
    #
    # {n} ==> $(1)   - Neighborhood name

    # /nbhood:html udict matchArray
    #
    # Formats the summary page for /nbhood/{n}.

    proc /nbhood:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Get the neighborhood
        set n [string toupper $(1)]

        if {![rdb exists {SELECT * FROM nbhoods WHERE n=$n}]} {
            return -code error -errorcode NOTFOUND \
                "Unknown entity: [dict get $udict url]."
        }

        rdb eval {SELECT * FROM gui_nbhoods WHERE n=$n} data {}
        rdb eval {SELECT * FROM econ_n_view WHERE n=$n} econ {}
        rdb eval {
            SELECT * FROM gui_actors  
            WHERE a=$data(controller)
        } cdata {}

        # Begin the page
        ht page "Neighborhood: $n"
        ht title $data(fancy) "Neighborhood" 

        ht linkbar {
            "#civs"      "Civilian Groups"
            "#forces"    "Forces Present"
            "#eni"       "ENI Services"
            "#ais"       "Abstract Infrastructure Services"
            "#cap"       "CAP Coverage"
            "#infra"     "GOODS Production Infrastructure"
            "#control"   "Support and Control"
            "#sigevents" "Significant Events"
        }

        ht para
        
        # Non-local?
        if {!$data(local)} {
            ht putln "<b>$n is non-local, i.e., it is located outside of the main playbox.</b>"
            ht para
        }

        # When not locked.
        if {![locked]} {
            ht putln "Resident groups: "

            ht linklist -default "None" [rdb eval {
                SELECT url, g
                FROM gui_civgroups
                WHERE n=$n
                AND basepop > 0 
            }]

            ht put ". "

            if {$data(controller) eq "NONE"} {
                ht putln "No actor is initially in control."
            } else {
                ht putln "Actor "
                ht put "$cdata(link) is initially in control."
            }

            ht para
        }

        # Population, groups.
        if {[locked -disclaimer]} {
            if {$data(population) > 0} {
                set urb    [eurbanization longname $data(urbanization)]
                let labPct {double($data(labor_force))/$data(population)}
                let sagPct {double($data(subsistence))/$data(population)}
                set mood   [qsat name $data(mood)]
        
                ht putln "$data(fancy) is "
                ht putif {$urb eq "Urban"} "an " "a "
                ht put "$urb neighborhood with a population of "
                ht put [commafmt $data(population)]
                ht put ", "

                if {$data(local)} {
                    ht put "[percent $labPct] of which are in the labor force and "
                } 

                ht put "[percent $sagPct] of which are engaged in subsistence "
                ht put "agriculture."
        
                ht putln "The population belongs to the following groups: "
        
                ht linklist -default "None" [rdb eval {
                    SELECT url,g
                    FROM gui_civgroups
                    WHERE n=$n AND population > 0
                }]
                
                ht put "."
        
                ht putln "Their overall mood is [qsat format $data(mood)] "
                ht put "([qsat longname $data(mood)])."
        
                if {$data(local)} {
                    if {$data(labor_force) > 0} {
                        let rate {double($data(unemployed))/$data(labor_force)}
                        ht putln "The unemployment rate is [percent $rate]."
                    }
                    ht putln "$n's production capacity is [percent $econ(pcf)]."
                }
                ht para
            } else {
                ht putln "The neighborhood currently has no civilian population."
                ht para
            }
            
            # Actors
            if {$data(controller) eq "NONE"} {
                ht putln "$n is currently in a state of chaos: "
                ht put   "no actor is in control."
            } else {
                ht putln "Actor $cdata(link) is currently in control of $n."
            }
    
            ht putln "Actors with forces in $n: "
    
            ht linklist -default "None" [rdb eval {
                SELECT DISTINCT '/actor/' || a, a
                FROM gui_agroups
                JOIN force_ng USING (g)
                WHERE n=$n AND personnel > 0
                ORDER BY personnel DESC
            }]
    
            ht put "."
    
            ht putln "Actors with influence in $n: "
    
            ht linklist -default "None" [rdb eval {
                SELECT DISTINCT A.url, A.a
                FROM influence_na AS I
                JOIN gui_actors AS A USING (a)
                WHERE I.n=$n AND I.influence > 0
                ORDER BY I.influence DESC
            }]
    
            ht put "."
    
            ht para
    
            # Groups
            ht putln \
                "The following force and organization groups are" \
                "active in $n: "
    
            ht linklist -default "None" [rdb eval {
                SELECT G.url, G.g
                FROM gui_agroups AS G
                JOIN force_ng    AS F USING (g)
                WHERE F.n=$n AND F.personnel > 0
            }]
    
            ht put "."
        }   

        ht para

        # Civilian groups
        ht subtitle "Civilian Groups" civs

        if {[locked -disclaimer]} {
            
            ht putln "The following civilian groups live in $n:"
            ht para
    
            ht query {
                SELECT G.longlink  
                           AS 'Name',
                       G.population 
                           AS 'Population',
                       pair(qsat('format',G.mood), qsat('longname',G.mood))
                           AS 'Mood',
                       pair(qsecurity('format',S.security), 
                            qsecurity('longname',S.security))
                           AS 'Security'
                FROM gui_civgroups AS G
                JOIN force_ng      AS S USING (g)
                WHERE G.n=$n AND S.n=$n AND population > 0
                ORDER BY G.g
            }
        }

        ht para

        # Force/Org groups
        ht subtitle "Forces Present" forces

        if {[locked -disclaimer]} {
            ht query {
                SELECT G.longlink
                           AS 'Group',
                       P.personnel 
                           AS 'Personnel', 
                       G.fulltype
                           AS 'Type',
                       CASE WHEN G.gtype='FRC'
                       THEN pair(C.coop, qcoop('longname',C.coop))
                       ELSE 'n/a' END
                           AS 'Coop. of Nbhood'
                FROM force_ng     AS P
                JOIN gui_agroups  AS G USING (g)
                LEFT OUTER JOIN gui_coop_ng  AS C ON (C.n=P.n AND C.g=P.g)
                WHERE P.n=$n
                AND   personnel > 0
                ORDER BY G.g
            } -default "None."
        }
        
        ht para

        # ENI Services
        ht subtitle "ENI Services" eni

        if {!$data(local)} {
            ht putln {
                This neighborhood is non-local, and is therefore outside
                the local economy.  Groups residing in this neighborhood
                neither require nor expect Essential Non-Infrastructure
                Services.
            }
            ht para
        } elseif {$data(population) == 0} {
            ht putln {
                This neighborhood has no population to require
                services.
            }
            ht para
        } elseif {[locked -disclaimer]} {
            ht putln {
                Actors can provide Essential Non-Infrastructure (ENI) 
                services to the civilians in this neighborhood.  The level
                of service currently provided to the groups in this
                neighborhood is as follows.
            }
    
            ht para
    
            rdb eval {
                SELECT g,alink FROM gui_service_ga WHERE numeric_funding > 0.0
            } {
                lappend funders($g) $alink
            }
    
            ht table {
                "Group" "Funding,<br>$/week" "Actual" "Required" "Expected" 
                "Funding<br>Actors"
            } {
                rdb eval {
                    SELECT g, longlink, funding, pct_required, 
                           pct_actual, pct_expected 
                    FROM gui_service_sg
                    JOIN nbhoods USING (n)
                    JOIN demog_g USING (g)
                    WHERE n = $n AND 
                          gui_service_sg.s = 'ENI' AND 
                          demog_g.population > 0
                    ORDER BY g
                } row {
                    if {![info exists funders($row(g))]} {
                        set funders($row(g)) "None"
                    }
                    
                    ht tr {
                        ht td left  { ht put $row(longlink)                }
                        ht td right { ht put $row(funding)                 }
                        ht td right { ht put $row(pct_actual)              }
                        ht td right { ht put $row(pct_required)            }
                        ht td right { ht put $row(pct_expected)            }
                        ht td left  { ht put [join $funders($row(g)) ", "] }
                    }
                }
            }
    
            ht para
            ht putln {
                Service is said to be saturated when additional funding
                provides no additional service to the civilians.  We peg
                this level of service as 100% service, and express the actual,
                required, and expected levels of service as percentages.
                level required for survival.  The expected level of
                service is the level the civilians expect to receive
                based on past history.
            }
        }

        ht para

        ht subtitle "Abstract Infrastructure Services" ais

        if {!$data(local)} {
            ht putln {
                This neighborhood is non-local, and is therefore outside
                the local economy.  Groups residing in this neighborhood
                neither require nor expect Infrastructure
                Services.
            }
            ht para
        } elseif {$data(population) == 0} {
            ht putln {
                This neighborhood has no population to require
                services.
            }
            ht para
        } elseif {[locked]} {
            ht putln {
                This neighborhood needs abstract infrastructure service 
                (AIS) provided to the civilians in this neighborhood.  
                The required, expected and actual levels of service (LOS)
                for each service and group is as follows.
            }

            ht query  {
                SELECT link           AS "Civ. Group",
                       s              AS "Abstract Service", 
                       pct_required   AS "Required LOS %", 
                       pct_expected   AS "Expected LOS %", 
                       pct_actual     AS "Actual LOS %",
                       needs          AS "Needs factor",
                       expectf        AS "Expectations factor"
                FROM gui_service_sg 
                WHERE n=$n AND s!='ENI' AND population > 0
            } -default "None." -align LLRRRRR

    
            ht para
    
        } else  {
            ht putln {
                This neighborhood needs abstract infrastructure service 
                (AIS) provided to the civilians in this neighborhood.  
                The required and actual levels of service (LOS) 
                for each service and group when the scenario is locked
                is as follows.  The needs and expectations factors will
                be calculated after the scenario is locked.
            }

            ht query {
                SELECT glink        AS "Civ. Group", 
                       s            AS "Service",
                       pct_act      AS "% Actual LOS", 
                       pct_req      AS "% Required LOS"
                FROM gui_abservice
                WHERE n=$n  AND population > 0
            } -default "None." -align LLRR
        }

        ht para

        # CAP coverage
        ht subtitle "CAP Coverage" cap
        
        set hascapcov [rdb eval {
                           SELECT count(*) FROM capcov 
                           WHERE n=$n AND nbcov > 0.0
                       }]

        if {$hascapcov} {
            ht putln {
                Some groups in this neighborhood can be reached by 
                Communication Asset Packages (CAPs). The following is 
                a list of the groups resident in this neighborhood
                with the CAPs cover them.
            }

            ht para

            ht query {
                SELECT C.longlink                   AS "CAP",
                       C.owner                      AS "Owned By",
                       C.capacity                   AS "Capacity",
                       CC.glink                     AS "Group",
                       CC.nbcov                     AS "Nbhood Coverage",
                       CC.pen                       AS "Group Penetration",
                       "<b>" || CC.capcov || "</b>" AS "CAP Coverage"
                FROM gui_caps AS C
                JOIN gui_capcov AS CC USING( k)
                JOIN demog_g AS G USING (g)
                WHERE CC.n = $n
                AND CC.raw_nbcov > 0.0
                AND G.population > 0
            } -default "None." -align LLRLRRR
        } else {
            ht putln "This neighborhood is not covered by any"
            ht putln "Communication Asset Packages."
        }

        ht para

        # GOODS Production Infrastructure
        ht subtitle "GOODS Production Infrastructure" infra

        if {[econ state] eq "DISABLED"} {
            ht put {
                The economic model is disabled, so neighborhoods have no 
                GOODS production infrastructure.
            }
        } elseif {!$data(local)} {
            ht put {
                This neighborhood is non-local, and is therfore outside the
                local economy.  Because of this, no GOODS production 
                infrastructure can exist in this neighborhood.
            }
        } else {

            if {![locked]} {
                ht put {
                    The percentage of plants that this neighborhood will get 
                    when locked is approximately shown as follows.  When the 
                    scenario is locked the actual number of plants and their 
                    owning agent will be shown along with the average repair 
                    level.  Neighborhoods with no consumers will not have
                    plants allocated to them. These numbers are approximate 
                    because the demographics may be different after the 
                    scenario is locked.
                }
    
                ht para
    
                set adjpop 0.0
    
                rdb eval {
                    SELECT nbpop, pcf
                    FROM plants_n_view
                } row {
                    let adjpop {$adjpop + $row(nbpop)*$row(pcf)}
                }
    
                if {$adjpop > 0} {
                    ht push 

                    ht table {
                        "Consumers" "Prod. Capacity Factor"
                        "% of GOODS<br>Production Plants"
                    } {
                        rdb eval {
                            SELECT pcf            AS pcf,
                                   nbpop          AS nbpop 
                            FROM gui_plants_n
                            WHERE n=$n
                        } row {
                            set pct [expr {
                                        $row(nbpop)*$row(pcf)/$adjpop*100.0
                                     }]
    
                            ht tr {
                                ht td right {ht put $row(nbpop)               }
                                ht td right {ht put [format "%4.1f" $row(pcf)]}
                                ht td right {ht put [format "%4.1f" $pct]     }
                            }
                        }
                    }
                    
                    set text [ht pop]

                    if {[ht rowcount] > 0} {
                        ht put $text
                    } else {
                        ht put "None."
                    }
                } else {
                    ht put {
                        The scenario has no population defined yet.
                    }
                }
            } else {
                ht para
                ht put   "The following table shows the current laydown of "
                ht put   "GOODS production plants in $n and the agents that "
                ht put   "own them along with the average repair levels.  Note "
                ht put   "that plants under construction will not appear in "
                ht putln "this table until they are 100% complete."
                ht para 
    
                ht query {
                    SELECT alink    AS "Agent",
                           num      AS "Owned Plants",
                           rho      AS "Average Repair Level"
                    FROM gui_plants_na
                    WHERE n=$n
                } -default "None." -align LLL
    
                ht para
    
                set capN [plant capacity n $n]
                set capT [plant capacity total]
                set pct  [format "%.2f" [expr {($capN/$capT) * 100.0}]]
    
                ht put "
                    The GOODS production plants in this neighborhood are 
                    currently producing [moneyfmt $capN] goods baskets 
                    annually.  This is $pct% of the goods production 
                    capacity of the entire economy.  This neighborhood 
                    has a production capacity factor of $econ(pcf).
                "

                ht para

                ht put "The following table breaks down GOODS production "
                ht put "plants under construction by agent into ranges of "
                ht put "percentage complete."
                ht para
        
                ht push 
        
                ht table {
                    "Agent" "Total" "&lt 20%" "20%-40%" 
                    "40%-60%" "60%-80%" "&gt 80%" 
                } {
                    rdb eval {
                        SELECT a, alink, levels, num
                        FROM gui_plants_build
                        WHERE n=$n
                    } {
                        array set bins {0 0 20 0 40 0 60 0 80 0}
                        foreach lvl $levels {
                            if {$lvl < 0.2} {
                                incr bins(0)
                            } elseif {$lvl >= 0.2 && $lvl < 0.4} {
                                incr bins(20)
                            } elseif {$lvl >= 0.4 && $lvl < 0.6} {
                                incr bins(40)
                            } elseif {$lvl >= 0.6 && $lvl < 0.8} {
                                incr bins(60)
                            } elseif {$lvl >= 0.8} {
                                incr bins(80)
                            }
                        }
        
                        ht tr {
                            ht td left {
                                ht put $alink
                            }
        
                            ht td center {
                                ht put $num
                            }
        
                            ht td center {
                                ht put $bins(0)
                            }
        
                            ht td center {
                                ht put $bins(20)
                            }
        
                            ht td center {
                                ht put $bins(40)
                            }
        
                            ht td center {
                                ht put $bins(60)
                            }
        
                            ht td center {
                                ht put $bins(80)
                            }
        
                        }
                    }
                }

                set text [ht pop]
        
                if {[ht rowcount] > 0} {
                    ht putln $text
                } else {
                    ht putln \
                        "This neighborhood has no plants under construction."
                }
            }
        }

        # Support and Control
        ht subtitle "Support and Control" control

        if {[locked -disclaimer]} {
            if {$data(controller) eq "NONE"} {
                ht putln "$n is currently in a state of chaos: "
                ht put   "no actor is in control."
            } else {
                ht putln "Actor $cdata(link) is currently in control of $n."
            }
    
            ht putln "The actors with support in this neighborhood are "
            ht putln "as follows."
            ht putln "Note that an actor has influence in a neighborhood"
            ht putln "only if his total support from groups exceeds"
            ht putln [format %.2f [parm get control.support.min]].
            ht para
    
            ht query {
                SELECT A.longlink                      AS 'Actor',
                       format('%.2f',I.influence)      AS 'Influence',
                       format('%.2f',I.direct_support) AS 'Direct Support',
                       format('%.2f',I.support)        AS 'Total Support'
                FROM influence_na AS I
                JOIN gui_actors   AS A USING (a)
                WHERE I.n = $n AND I.influence > 0.0
                ORDER BY I.influence DESC
            } -default "None." -align LR
    
            ht para
            ht putln "Actor support comes from the following groups."
            ht putln "Note that a group only supports an actor if"
            ht putln "its vertical relationship with the actor is at"
            ht putln "least [parm get control.support.vrelMin], or if"
            ht putln "another actor lends his direct support to the"
            ht putln "first actor.  See each actor's page for a"
            ht putln "detailed analysis of the actor's support and"
            ht putln "influence."
            ht para
    
            ht query {
                SELECT A.link                            AS 'Actor',
                       G.link                            AS 'Group',
                       format('%.2f',S.influence)        AS 'Influence',
                       qaffinity('format',S.vrel)        AS 'Vert. Rel.',
                       G.g || ' ' || 
                         qaffinity('longname',S.vrel) ||
                         ' ' || A.a                      AS 'Narrative',
                       commafmt(S.personnel)             AS 'Personnel',
                       qfancyfmt('qsecurity',S.security) AS 'Security'
                FROM support_nga AS S
                JOIN gui_groups  AS G ON (G.g = S.g)
                JOIN gui_actors  AS A ON (A.a = S.a)
                WHERE S.n=$n AND S.personnel > 0
                ORDER BY S.influence DESC, S.vrel DESC, A.a
            } -default "None." -align LLRRLRL
        }

        ht para

        ht subtitle "Significant Events" sigevents

        if {[locked -disclaimer]} {
            appserver::SIGEVENTS recent $n
        }

        ht /page

        return [ht get]
    }
}



