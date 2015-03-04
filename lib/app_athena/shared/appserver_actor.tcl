#-----------------------------------------------------------------------
# TITLE:
#    appserver_actor.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Actors
#
#    my://app/actors
#    my://app/actor
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module ACTOR {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /actors {actors/?}          \
            tcl/linkdict [myproc /actors:linkdict]     \
            tcl/enumlist [asproc enum:enumlist actor] \
            text/html    [myproc /actors:html] {
                Links to all of the currently 
                defined actors.  HTML content 
                includes actor attributes.
            }

        appserver register /actor/{a} {actor/(\w+)/?} \
            text/html [myproc /actor:html]            \
            "Detail page for actor {a}."
    }



    #-------------------------------------------------------------------
    # /actors: All defined actors
    #
    # No match parameters

    # /actors:linkdict udict matchArray
    #
    # tcl/linkdict of all actors.
    
    proc /actors:linkdict {udict matchArray} {
        return [objects:linkdict {
            label    "Actors"
            listIcon ::projectgui::icon::actor12
            table    gui_actors
        }]
    }

    # /actors:html udict matchArray
    #
    # Tabular display of actor data; content depends on 
    # simulation state.

    proc /actors:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Begin the page
        ht page "Actors"
        ht title "Actors"

        ht putln "The scenario currently includes the following actors:"
        ht para

        ht query {
            SELECT longlink      AS "Actor",
                   supports_link AS "Usually Supports",
                   cash_reserve  AS "Reserve, $",
                   income        AS "Income, $/week",
                   atype         AS "Source",
                   cash_on_hand  AS "On Hand, $"
            FROM gui_actors
        } -default "None." -align LLRRR

        ht /page

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /actor/{a}: A single actor {a}
    #
    # Match Parameters:
    #
    # {a} => $(1)    - The actor's short name

    # /actor:html udict matchArray
    #
    # Detail page for a single actor {a}

    proc /actor:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Accumulate data
        set a [string toupper $(1)]

        if {![adb exists {SELECT * FROM actors WHERE a=$a}]} {
            return -code error -errorcode NOTFOUND \
                "Unknown entity: [dict get $udict url]."
        }

        # Begin the page
        adb eval {SELECT * FROM gui_actors WHERE a=$a} data {}

        ht page "Actor: $a"
        ht title $data(fancy) "Actor" 

        ht linkbar {
            "#money"     "Income/Assets/Expenditures"
            "#sphere"    "Sphere of Influence"
            "#base"      "Power Base"
            "#eni"       "ENI Funding"
            "#infra"     "GOODS Plant Ownership"
            "#cap"       "CAP Ownership"
            "#forces"    "Force Deployment"
            "#sigevents" "Significant Events"
        }
        
        ht putln "Belief System: "
        set bsysname [adb bsys system cget $data(bsid) -name]
        ht link my://app/bsystem/$data(bsid) "$bsysname ($data(bsid))"

        ht para

        ht putln "Groups owned: "

        ht linklist -default "None" [adb eval {
            SELECT url, g FROM gui_agroups 
            WHERE a=$a
            ORDER BY g
        }]

        ht put "."

        ht para
        # Asset Summary
        ht subtitle "Income/Assets/Expenditures" money

        ht putln "Fiscal assets: \$$data(income) per week, with "
        ht put "\$$data(cash_on_hand) cash on hand and "
        ht put "\$$data(cash_reserve) in reserve."
        ht para

        if {[locked -disclaimer] && [adb econ state] eq "ENABLED"} {
            if {$data(atype) eq "INCOME"} {
                ht putln {
                    The following table shows this actor's income per week
                    from the various sectors.
                }
                ht para

                ht query {
                    SELECT "$" || income_goods      AS "goods",
                           "$" || income_black_t    AS "black market (tax)",
                           "$" || income_black_nr   AS "black market (profits)",
                           "$" || income_pop        AS "pop",
                           "$" || income_world      AS "world",
                           "$" || income_graft      AS "graft"
                    FROM gui_econ_income_a
                    WHERE a=$a
                } -default "None." -align RRRRRR
            } else {
                ht putln "This actor has a budget of"
                ht putln "\$$data(budget) per week from sources"
                ht putln "outside the playbox.  Only money actually spent"
                ht putln "by the actor during a given week enters the"
                ht putln "local economy."
            }

            ht para

            ht putln "The following tables show this actor's expenditures "
            ht put   "to the various sectors."
            ht para

            ht query {
                SELECT lbl                 AS "",
                       "$" || exp_goods    AS "goods",
                       "$" || exp_black    AS "black market",
                       "$" || exp_pop      AS "pop",
                       "$" || exp_actor    AS "actors",
                       "$" || exp_region   AS "region",
                       "$" || exp_world    AS "world",
                       "$" || tot_exp      AS "total"
                FROM gui_econ_expense_a
                WHERE a=$a
            } -default "None." -align LRRRRRRR
        }
                

        # Sphere of Influence
        ht subtitle "Sphere of Influence" sphere

        if {[locked -disclaimer]} {
            ht putln "Actor $a has support from groups in the"
            ht putln "following neighborhoods."
            ht putln "Note that an actor has influence in a neighborhood"
            ht putln "only if his total support from groups exceeds"
            ht putln [format %.2f [adb parm get control.support.min]].
            ht para

            set supports [adb onecolumn {
                SELECT supports_link FROM gui_actors
                WHERE a=$a
            }]

            ht putln 

            if {$supports eq "SELF"} {
                ht putln "Actor $a usually supports himself"
            } elseif {$supports eq "NONE"} {
                ht putln "Actor $a doesn't usually support anyone,"
                ht putln "including himself,"
            } else {
                ht putln "Actor $a usually supports actor $supports"
            }

            ht putln "across the playbox."

            ht para

            ht query {
                SELECT N.longlink                      AS 'Neighborhood',
                       format('%.2f',I.direct_support) AS 'Direct Support',
                       S.supports_link                 AS 'Supports Actor',
                       format('%.2f',I.support)        AS 'Total Support',
                       format('%.2f',I.influence)      AS 'Influence'
                FROM influence_na AS I
                JOIN gui_nbhoods  AS N USING (n)
                JOIN gui_supports AS S ON (I.n = S.n AND I.a = S.a)
                WHERE I.a=$a AND (I.direct_support > 0.0 OR I.support > 0.0)
                ORDER BY I.influence DESC, I.support DESC, N.fancy
            } -default "None." -align LRLRR

            ht para
        }

        # Power Base
        ht subtitle "Power Base" base

        if {[locked -disclaimer]} {
            set vmin [adb parm get control.support.vrelMin]

            ht putln "Actor $a receives direct support from the following"
            ht putln "supporters (and would-be supporters)."
            ht putln "Note that a group only supports an actor if"
            ht putln "its vertical relationship with the actor is at"
            ht putln "least $vmin."
            ht para

            ht query {
                SELECT N.link                            AS 'In Nbhood',
                       G.link                            AS 'Group',
                       G.gtype                           AS 'Type',
                       format('%.2f',S.influence)        AS 'Influence',
                       qaffinity('format',S.vrel)        AS 'Vert. Rel.',
                       G.g || ' ' || 
                       qaffinity('longname',S.vrel) ||
                       ' ' || S.a                        AS 'Narrative',
                       commafmt(S.personnel)             AS 'Personnel',
                       qfancyfmt('qsecurity',S.security) AS 'Security'
                FROM support_nga AS S
                JOIN gui_groups  AS G ON (G.g = S.g)
                JOIN gui_nbhoods AS N ON (N.n = S.n)
                WHERE S.a=$a AND S.personnel > 0 AND S.vrel >= $vmin
                ORDER BY S.influence DESC, S.vrel DESC, N.n
            } -default "None." -align LLRRLRL

            ht para

            ht putln "In addition, actor $a receives indirect support from"
            ht putln "the following actors in the following neighborhoods:"

            ht para
            
            ht query {
                SELECT S.alonglink                      AS 'From Actor',
                       S.nlonglink                      AS 'In Nbhood',
                       format('%.2f',I.direct_support)  AS 'Contributed<br>Support'
                FROM gui_supports AS S
                JOIN influence_na AS I USING (n,a)
                WHERE S.supports = $a
                ORDER BY S.a, S.n
            } -default "None." -align LLR
        }

        # ENI Funding
        ht subtitle "ENI Funding" eni

        if {[locked -disclaimer]} {
            ht put {
                The funding of ENI services by this actor is as
                follows.  Civilian groups judge actors by whether
                they are getting sufficient ENI services, and whether
                they are getting more or less than they expect.  
                ENI services also affect each group's mood.
            }

            ht para

            ht query {
                SELECT GA.nlink                AS 'Nbhood',
                       GA.glink                AS 'Group',
                       GA.funding              AS 'Funding<br>$/week',
                       GA.pct_credit           AS 'Actor''s<br>Credit',
                       G.pct_actual            AS 'Actual<br>LOS',
                       G.pct_expected          AS 'Expected<br>LOS',
                       G.pct_required          AS 'Required<br>LOS'
                FROM gui_service_ga AS GA
                JOIN gui_service_sg AS G ON (G.g=GA.g AND G.s='ENI')
                WHERE GA.a=$a AND numeric_funding > 0.0
                ORDER BY GA.numeric_funding;
            } -align LLRRRRR
        } 

        # GOODS Plant Ownership
        ht subtitle "GOODS Plant Ownership" infra

        if {![locked]} {
            set nbhoods [adb eval {
                SELECT nlink FROM gui_plants_alloc
                WHERE a=$a
            }]

            if {[llength $nbhoods] == 0} {

                ht put "
                    $a is not currently allocated any shares of GOODS
                    production infrastructure.
                "
            } else {
                
                set nlist [join $nbhoods ", "]

                ht put "$a has been allocated shares of GOODS production "
                ht put "infrastructure in these neighborhoods: $nlist. See $a's"
                ht put "[ht link /plant/$a/ " infrastructure page"] "
                ht put "for more."
                ht para
            }
        } else {

            if {[adb econ state] eq "DISABLED"} {
                ht put {
                    The economic model is disabled, so actors own no
                    GOODS production infrastructure.
                }
                
                ht para
            } else {
                set nbhoods [adb eval {
                    SELECT nlink FROM gui_plants_na
                    WHERE a=$a
                }]

                if {[llength $nbhoods] == 0} {
                    ht put {
                        This actor does not own any GOODS production 
                        infrastructure.
                    }
                } else {

                    set nlist [join $nbhoods ", "]
                    set num [adb eval {
                        SELECT sum(num) FROM gui_plants_na
                        WHERE a=$a
                    }]

                    ht put "$a owns $num GOODS production infrastructure "
                    ht put "plants in these neighborhoods: $nlist. "
                    ht put "See $a's "
                    ht put "[ht link /plant/$a/ "infrastructure page"] "
                    ht put "for more."
                }

                ht para

                if {$data(auto_maintain)} {
                    ht put {
                        This actor automatically maintains GOODS production
                        infrastructure.  The repair level will not degrade
                        with time.
                    }

                } else {
                    ht put {
                        This actor must pay to maintain infrastructure
                        or it will fall into disrepair reducing the
                        production of goods for the economy.
                    }
                } 
            
                set capA [adb plant capacity a $a]
                set capT [adb plant capacity total]
                set pct  [format "%.2f" [expr {($capA/$capT) * 100.0}]]
            
                ht put "
                    The GOODS production plants this actor owns are currently
                    producing [moneyfmt $capA] goods baskets annually.  This 
                    is $pct% of the goods production capacity of the entire
                    economy.
                "

                ht para
            }
        }

        # CAP Ownership
        ht subtitle "CAP Ownership" cap

        ht put {
            This actor owns the following Communication Asset
            Packages (CAPs):
        }

        ht para

        ht query {
            SELECT longlink AS "Name",
                   capacity AS "Capacity",
                   cost     AS "Cost, $"
            FROM gui_caps WHERE owner=$a
        } -default "None." -align LRR

        # Deployment
        ht subtitle "Force Deployment" forces

        if {[locked -disclaimer]} {
            ht query {
                SELECT N.longlink              AS 'Neighborhood',
                       P.personnel             AS 'Personnel',
                       G.longlink              AS 'Group',
                       G.fulltype              AS 'Type'
                FROM deploy_ng AS P
                JOIN gui_agroups  AS G ON (G.g=P.g)
                JOIN gui_nbhoods  AS N ON (N.n=P.n)
                WHERE G.a=$a AND personnel > 0
            } -default "No forces are deployed."
        }

        ht subtitle "Significant Events" sigevents

        if {[locked -disclaimer]} {
            appserver::SIGEVENTS recent $a
        }

        ht /page

        return [ht get]
    }
}



