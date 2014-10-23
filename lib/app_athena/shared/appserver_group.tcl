#-----------------------------------------------------------------------
# TITLE:
#    appserver_group.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Group Entities
#
#    my://app/groups/...
#    my://app/group/...
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module GROUPS {
    #-------------------------------------------------------------------
    # Object Types
    #
    # This data is used to handle the group subsets

    # objectInfo: Nested dictionary of object data.
    #
    # key: object collection resource
    #
    # value: Dictionary of data about each object/object type
    #
    #   label     - A human readable label for this kind of object.
    #   listIcon  - A Tk icon to use in lists and trees next to the
    #               label

    typevariable objectInfo {
        /groups {
            label    "Groups"
            listIcon ::projectgui::icon::group12
            table    gui_groups
        }

        /groups/civ {
            label    "Civ. Groups"
            listIcon ::projectgui::icon::civgroup12
            table    gui_civgroups
        }

        /groups/frc {
            label    "Force Groups"
            listIcon ::projectgui::icon::frcgroup12
            table    gui_frcgroups
        }

        /groups/org {
            label    "Org. Groups"
            listIcon ::projectgui::icon::orggroup12
            table    gui_orggroups
        }
    }

    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /groups {groups/?}      \
            tcl/linkdict [myproc /groups:linkdict] \
            tcl/enumlist [myproc /groups:enumlist] \
            text/html    [myproc /groups:html]     {
                Links to the currently defined groups.  The HTML content
                includes group attributes.
            }

        appserver register /groups/{gtype} {groups/(civ|frc|org)/?} \
            tcl/linkdict [myproc /groups:linkdict]                  \
            tcl/enumlist [myproc /groups:enumlist]                  \
            text/html    [myproc /groups:html] {
                Links to the currently defined groups of type {gtype}
                (civ, frc, or org).  The HTML content includes group
                attributes.
            }

        appserver register /group/{g} {group/(\w+)/?} \
            text/html [myproc /group:html]            \
            "Detail page for group {g}."

    }

    #-------------------------------------------------------------------
    # /groups:               All groups
    # /groups/{gtype}:       Groups of type civ, or, or frc
    #
    # Match Parameters:
    # 
    # {gtype} ==> $(1)   - Group type, or "" for all


    # /groups:linkdict udict matchArray
    #
    # Returns tcl/linkdict for a group collection.

    proc /groups:linkdict {udict matchArray} {
        upvar 1 $matchArray ""

        # FIRST, get the otype.
        if {$(1) eq ""} {
            set otype /groups
        } else {
            set otype /groups/$(1)
        }

        dict with objectInfo $otype {
            return [objects:linkdict [dict create \
                    label    $label               \
                    listIcon $listIcon            \
                    table    $table               \
            ]]
        }
    }

    # /groups:enumlist udict matchArray
    #
    # Returns tcl/enumlist for a group collection.

    proc /groups:enumlist {udict matchArray} {
        upvar 1 $matchArray ""

        switch -exact -- $(1) {
            ""   { return [group names] }
            civ  { return [civgroup names] }
            frc  { return [frcgroup names] }
            org  { return [orggroup names] }
            default {
                error "Unexpected group type: \"$(1)\""
            }
        }
    }


    # /groups:html udict matchArray
    #
    # Returns a text/html of links for a collection of groups.

    proc /groups:html {udict matchArray} {
        upvar 1 $matchArray ""

        # FIRST, get the group type; might be "" for all groups.
        set gtype [string toupper $(1)]

        # FIRST, update the saturation and required levels of service
        service_eni srservice

        # Begin the page
        if {$gtype eq ""} {
            ht page "Groups"
            ht title "Groups"

            ht putln "The scenario contains the following groups:"
            ht para

            ht query {
                SELECT longlink     AS "Group",
                       gtypelink    AS "Type",
                       demeanor     AS "Demeanor"
                FROM gui_groups 
                ORDER BY longlink
            } -default "None."

        } elseif {$gtype eq "CIV"} {
            ht page "Groups: Civilian"
            ht title "Groups: Civilian"

            ht putln "The scenario contains the following civilian groups:"
            ht para

            if {[sim state] eq "PREP"} {
                ht query {
                    SELECT longlink       AS "Group",
                           n              AS "Nbhood",
                           housing        AS "Housing",
                           demeanor       AS "Demeanor",
                           basepop        AS "Population",
                           pop_cr         AS "Pop. Change<br>Rate, %/year",
                           pretty_sa_flag AS "Subsist. Agric.<br>Flag",
                           req_funding    AS "Req. ENI<br>funding, $/wk",
                           sat_funding    AS "Sat. ENI<br>funding, $/wk"
                    FROM gui_civgroups 
                    ORDER BY longlink
                } -default "None." -align LLLRRRR
            } else {
                ht query {
                    SELECT longlink       AS "Group",
                           n              AS "Nbhood",
                           housing        AS "Housing",
                           demeanor       AS "Demeanor",
                           population     AS "Population",
                           pop_cr         AS "Pop. Change<br>Rate, %/year",
                           pretty_sa_flag AS "Subsist. Agric.<br>Flag",
                           req_funding    AS "Req. ENI<br>funding, $/wk",
                           sat_funding    AS "Sat. ENI<br>funding, $/wk",
                           mood0          AS "Mood at T0",
                           mood           AS "Mood Now"
                    FROM gui_civgroups 
                    ORDER BY longlink
                } -default "None." -align LLLRRRRRR
            }
        } elseif {$gtype eq "FRC"} {
            ht page "Groups: Force"
            ht title "Groups: Force"

            ht putln "The scenario contains the following force groups:"
            ht para

            ht query {
                SELECT longlink     AS "Group",
                       a            AS "Owner",
                       forcetype    AS "Force Type",
                       training     AS "Training Level",
                       demeanor     AS "Demeanor",
                       personnel    AS "Personnel",
                       cost         AS "Cost, $/person/week",
                       local        AS "Local?"
                FROM gui_frcgroups 
                ORDER BY longlink
            } -default "None."

        } elseif {$gtype eq "ORG"} {
            ht page "Groups: Organization"
            ht title "Groups: Organization"

            ht putln "The scenario contains the following organization groups:"
            ht para

            ht query {
                SELECT longlink     AS "Group",
                       a            AS "Owner",
                       orgtype      AS "Org. Type",
                       demeanor     AS "Demeanor",
                       personnel    AS "Personnel",
                       cost         AS "Cost, $/person/week"
                FROM gui_orggroups 
                ORDER BY longlink
            } -default "None."

        } else {
            # No special error needed; the gtype is validated by
            # the URL regexp.
            error "Unknown group type"
        }

        ht /page
        
        return [ht get]
    }


    #-------------------------------------------------------------------
    # /group/{g}:            Information about group {g}
    #
    # Match Parameters:
    # 
    # {g} ==> $(1)   - Group name


    # /group:html udict matchArray
    #
    # Formats the detail page for /group/{g}.

    proc /group:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Get the group
        set g [string toupper $(1)]

        if {![rdb exists {SELECT * FROM groups WHERE g=$g}]} {
            return -code error -errorcode NOTFOUND \
                "Unknown entity: [dict get $udict url]."
        }

        # Next, what kind of group is it?
        set gtype [group gtype $g]

        switch $gtype {
            CIV     { return [CivGroup:html $g] }
            FRC     { return [FrcGroup:html $g] }
            ORG     { return [OrgGroup:html $g] }
            default { 
                # Unexpected error
                error "Unknown group type."    
            }
        }
    }

    # CivGroup:html g
    #
    # g - The group name
    #
    # Formats the summary page for civilian /group/{g}.

    proc CivGroup:html {g} {
        # FIRST, update the saturation and required levels of service
        service_eni srservice

        # NEXT, get the data about this group
        rdb eval {SELECT * FROM gui_civgroups  WHERE g=$g}              data {}
        rdb eval {SELECT * FROM gui_nbhoods    WHERE n=$data(n)}        nb   {}
        rdb eval {SELECT * FROM gui_service_sg WHERE g=$g AND s='ENI'}  eni  {}
        
        # NEXT, begin the page.
        ht page "Civilian Group: $g"
        ht title "$data(longname) ($g)" "Civilian Group" "Summary"

        # NEXT, what we do depends on whether the simulation is locked
        # or not.
        let locked {[sim state] ne "PREP"}

        ht linkbar {
            "#actors"     "Relationships with Actors"
            "#rel"        "Friends and Enemies"
            "#eni"        "ENI Service"
            "#ais"        "Abstract Infrastructure Services"
            "#cap"        "CAP Coverage"
            "#sat"        "Satisfaction Levels"
            "#drivers"    "Drivers"
            "#sigevents"  "Significant Events"
        }


        # NEXT, determine the population.
        # TBD: Once demog_g is populated only when the simulation is locked,
        # we can update gui_civgroups to coalesce basepop into population,
        # and just use the one column.
        if {$locked} {
            set population $data(population)
        } else {
            set population $data(basepop)
        }
        
        if {$population == 0} {
            ht put {
                <b>Note:</b> This group is <i>empty</i>, that is,
                it has a population of 0.
                It might have had population and lost all of it, or
                it might be expected to gain population later.  At
                the moment, <b>it doesn't really exist.</b>  The
                data in this page describe what the group will
                be like should it gain population. 
            }
            ht para
            ht hr
        }
        
        ht putln "$data(longname) ($g) resides in neighborhood "
        ht link  /nbhood/$data(n) "$nb(longname) ($data(n))"
        ht put   " and has a population of [commafmt $population]."
        ht putln "The group's housing status is $data(housing)."

        ht putln "The group's belief system is "
        set bsysname [bsys system cget $data(bsid) -name]
        ht link my://app/bsystem/$data(bsid) "\"$bsysname ($data(bsid))\"."

        if {!$nb(local)} {
            ht putln {
                <b>This is a non-local neighborhood;
                consequently this group does not participate in the
                local economy.</b>
            }
        }

        ht putln "The group's demeanor is "
        ht put   [edemeanor longname $data(demeanor)].

        if {[locked] && $population > 0} {
            # NEXT, the rest of the summary
            if {$data(sa_flag)} {
                ht putln {
                    The group members support themselves by means of
                    subsistence agriculture.
                }
            } elseif {$nb(local)} {
                let lf {double($data(labor_force))/$data(population)}

                ht putln "[percent $lf] of the group is in the labor force"

                if {$data(labor_force) > 0} {
                    let ur {double($data(unemployed))/$data(labor_force)}
                    ht put ", and the unemployment rate is [percent $ur]."
                } else {
                    ht put "."
                }        
            }

            ht putln "The population of the group is changing by "
            ht putln "$data(pop_cr)% per year."

            if {$nb(local)} {
                ht putln "The group is receiving "

                if {$eni(actual) < $eni(required)} {
                    ht put "less than the required level of "
                } elseif {$eni(pct_actual) eq $eni(pct_expected)} {
                    ht put "about the expected amount of "
                } elseif {$eni(actual) < $eni(expected)} {
                    ht put "less than the expected amount of "
                } else {
                    ht put "more than the expected amount of "
                }

                ht put "ENI services."
            }


            ht putln "$g's overall mood is [qsat format $data(mood)] "
            ht put   "([qsat longname $data(mood)])."
            ht para

            # Actors
            set controller [rdb onecolumn {
                SELECT controller FROM control_n WHERE n=$data(n)
            }]

            if {$controller eq ""} {
                ht putln "No actor is in control of $data(n)."
                set vrel_c -1.0
            } else {
                set vrel_c [rdb onecolumn {
                    SELECT vrel FROM gui_uram_vrel
                    WHERE g=$g AND a=$controller
                }]

                set vrelMin [parm get control.support.vrelMin]
                ht putln "$g "
                ht putif {$vrel_c > $vrelMin} "favors" "does not favor"
                ht put   " actor "
                ht link /actor/$controller $controller
                ht put   ", who is in control of neighborhood $data(n)."
            }

            rdb eval {
                SELECT a,vrel FROM gui_uram_vrel
                WHERE g=$g
                ORDER BY vrel DESC
                LIMIT 1
            } fave {}

            if {$fave(vrel) > $vrel_c} {
                if {$fave(vrel) > 0.2} {
                    ht putln "$g would prefer to see actor "
                    ht put "$fave(a) in control of $data(n)."
                } else {
                    ht putln ""
                    ht putif {$controller ne ""} "In fact, "
                    ht put "$g does not favor "
                    ht put   "any of the actors."
                }
            } else {
                ht putln ""
                ht putif {$vrel_c <= 0.2} "However, "
                ht putln "$g prefers $controller to the other candidates."
            }
        }

        ht para
        
        # NEXT, Detail Block: Relationships with actors

        ht subtitle "Relationships with Actors" actors 

        if {[locked -disclaimer]} {
            if {$population == 0} {
                ht putln {
                    If this group had any population, its initial
                    base relationships with the actors would be
                    as follows, based on the group's belief system.
                }
                
                ht para

                ht query {
                    SELECT A.longlink                  AS 'Actor',
                           qaffinity('format',V.vrel)  AS 'Vertical<br>Rel.',
                           V.g || ' ' || qaffinity('longname', V.vrel) 
                               || ' ' || V.a           AS 'Narrative'
                    FROM gui_uram_vrel AS V 
                    JOIN gui_actors AS A USING (a)
                    WHERE V.g=$g
                    ORDER BY V.vrel DESC
                } -align LRL
            } else {
                ht query {
                    SELECT A.longlink                  AS 'Actor',
                           qaffinity('format',V.vrel)  AS 'Vertical<br>Rel.',
                           V.g || ' ' || qaffinity('longname', V.vrel) 
                               || ' ' || V.a           AS 'Narrative',
                           format('%.2f',S.direct_support) 
                                                       AS 'Direct<br>Support',
                           format('%.2f',S.support)    AS 'Actual<br>Support',
                           format('%.2f',S.influence)  AS 'Contributed<br>Influence'
                    FROM gui_uram_vrel AS V 
                    JOIN support_nga AS S USING (g,a)
                    JOIN gui_actors AS A USING (a)
                    WHERE V.g=$g
                    ORDER BY V.vrel DESC
                } -align LRLRRR
            }
        }
        
        ht subtitle "Friends and Enemies" rel

        if {$population == 0} {
            ht putln {
                If this group had any population, its initial
                base relationships with other groups would be
                as follows, based on the group's belief system.
            }
            
            ht para
        } else {
            ht putln {
                Friends and enemies have a non-zero horizontal relationship
                (HRel) with each other.  The HRel can vary over time, but
                (in the absence of significant drivers) will regress back to
                its natural level, which depends on the affinity between
                the groups.
            }
        }

        ht para

        if {![locked]} {
            ht query {
                SELECT G.longlink                          AS 'Friend/Enemy',
                       G.gtypelink                         AS 'Type',
                       base                                AS 'Base. HRel',
                       $g || ' ' || qaffinity('longname',base) 
                       || ' ' || g                         AS 'Narrative',
                       nat                                 AS 'Nat. HRel'
                FROM gui_hrel_view
                JOIN gui_groups AS G USING (g)
                WHERE f=$g
                AND qaffinity('name',base) != 'INDIFF'
                ORDER BY base DESC
            } -align LLRLR
        } else {
            ht query {
                SELECT G.longlink                          AS 'Friend/Enemy',
                       G.gtypelink                         AS 'Type',
                       hrel                                AS 'HRel',
                       $g || ' ' || qaffinity('longname',hrel) 
                       || ' ' || g                         AS 'Narrative',
                       base                                AS 'Base. HRel',
                       nat                                 AS 'Nat. HRel'
                FROM gui_uram_hrel
                JOIN gui_groups AS G USING (g)
                WHERE f=$g AND qaffinity('name',hrel) != 'INDIFF'
                ORDER BY hrel DESC
            } -align LLRLR
        }

        ht subtitle "ENI Services" eni

        if {!$nb(local)} {
            ht putln {
                This group resides in a non-local neighborhood, and
                consequently does not receive or require ENI services
                from the actors in the scenario.
            }
            ht para
        } elseif {$population == 0} {
            ht putln {
                This information is not available for this group
                at this time.
            }
            ht para        
        } elseif {[locked]} {
            ht putln "$g can receive Essential Non-Infrastructure (ENI) "
            ht put   "services from actors. At present, $g is receiving "
            ht put   "\$$eni(funding)/week worth of "
            ht put   "ENI service.  $g's saturation level of funding is "
            ht put   "\$$data(sat_funding)/week, so $g is receiving "
            ht put   "$eni(pct_actual) of the saturation level of ENI service. "
            ht put   "$g expects to receive $eni(pct_expected); and "
            ht put   "$eni(pct_required) is the minimum required for survival. "
            ht put   "Thus, $g's required level of funding is "
            ht put   "\$$data(req_funding)/week. "
            ht putln "$g's <i>needs</i> factor is $eni(needs), and $g's "
            ht put   "<i>expectf</i> factor is $eni(expectf). "
            ht para

            if {$eni(actual) > 0.0} {
                ht putln "The following actors are providing ENI service to $g:"
                ht para

                ht query {
                    SELECT alonglink                   AS 'Actor',
                           funding                     AS 'Funding, $/week',
                           pct_credit                  AS 'Credit'
                    FROM gui_service_ga
                    WHERE g=$g
                    ORDER BY credit DESC
                } -align LRR
            }
        } else {
            ht putln "$g can receive Essential Non-Infrastructure (ENI) "
            ht put   "services from actors. "
            ht put   "$g's saturation level of funding is "
            ht put   "\$$data(sat_funding)/week and "
            ht putln "$g's required level of funding is "
            ht put   "\$$data(sat_funding)/week."
            ht put   "<br><br>"
            ht tinyi {
                More information will be available once the scenario has
                been locked.
            }
            ht para
        }
        
        ht subtitle "Abstract Infrastructure Services" ais
        
        if {!$nb(local)} {
            ht putln {
                This group resides in a non-local neighborhood, and
                consequently does not receive or require any insfrastructure
                services.
            }
            ht para
        } elseif {$population == 0} {
            ht putln {
                This information is not available for this group
                at this time.
            }
            ht para        
        } elseif {[locked]} {
            ht putln "$g can receive Abstract Infrastructure Services. "
            ht put   "The table below shows which abstract services $g "
            ht put   "is receiving along with the level of service (LOS) "
            ht put   "they require, expect and are actually getting. The "
            ht put   "saturation level of service is always 1.0."
            ht para  

            ht query  {
                SELECT s              AS "Abstract Service", 
                       pct_required   AS "Required LOS %", 
                       pct_expected   AS "Expected LOS %", 
                       pct_actual     AS "Actual LOS %"
                FROM gui_service_sg 
                WHERE g=$g AND s!='ENI'
            } -default "None." -align LRRR

        } else {
            ht putln "When the scenario is locked $g will have the "
            ht put   "following required and actual services for each "
            ht put   "abstract service listed.   The actual level of "
            ht put   "service can be changed by using the SERVICE tactic "
            ht put   "with the "
            ht link  /agent/SYSTEM SYSTEM
            ht put   " agent."
            ht para

            ht query {
                SELECT s             AS "Abstract Service",
                       pct_req       AS "Required LOS %",
                       pct_act       AS "Actual LOS %"
                FROM gui_abservice
                WHERE g=$g AND s!='ENI'
            } -default "None." -align LRR
        }

        ht subtitle "CAP Coverage" cap

        if {$population == 0} {
            ht putln {
                If this group gains population, it will be covered by
                CAPs as described below.
            }
            ht para
        }
        
        set hascapcov [rdb eval {
                           SELECT count(*) FROM capcov
                           WHERE g=$g
                           AND   capcov > 0.0
                       }]

        if {$hascapcov} {
            ht putln {
                This group is covered by one or more Communication Asset 
                Packages (CAPs). A group can be covered, but not have any 
                penetration by a CAP. CAPs that have coverage of a group in
                a neighborhood but no penetration are considered "orphaned".
                The list of CAPs covering this group is below.
            }

            ht para

            ht query {
                SELECT C.longlink              AS "CAP",
                       C.owner                 AS "Owner",
                       CC.nlink                AS "Neighborhood",
                       CC.nbcov                AS "Nbhood Coverage",
                       CC.pen                  AS "Group Penetration",
                       "<b>" || CC.capcov || "</b>" AS "CAP Coverage"
                FROM gui_caps AS C JOIN gui_capcov AS CC USING(k)
                WHERE CC.g = $g
                AND   CC.raw_capcov > 0.0
            } -default "None." -align LLLRRR
        } else {
            ht putln {
                This group is not covered by any Communication Asset
                Packages (CAPs).
            }
        }
                   
                       
        ht subtitle "Satisfaction Levels" sat

        if {$population == 0} {
            ht putln {This group is empty, and hence has no attitudes.}
            ht para
        } elseif {[locked -disclaimer]} {
            ht putln "$g's overall mood is [qsat format $data(mood)] "
            ht put   "([qsat longname $data(mood)]).  $g's satisfactions "
            ht put   "with the various concerns are as follows."
            ht para

            ht query {
                SELECT pair(C.longname, C.c)            AS 'Concern',
                       qsat('format',sat)               AS 'Satisfaction',
                       qsat('longname',sat)             AS 'Narrative',
                       qsaliency('longname',saliency)   AS 'Saliency'
                FROM uram_sat JOIN concerns AS C USING (c)
                WHERE g=$g
                ORDER BY C.c
            } -align LRLL
        }

        ht subtitle "Satisfaction Drivers" drivers

        if {$population == 0} {
            ht putln {This group is empty, and hence has no attitudes.}
            ht para
        } elseif {[locked -disclaimer]} {
            ht putln "The most important satisfaction drivers for this group "
            ht put   "at the present time are as follows:"
            ht para

            aram contribs mood $g \
                -start [simclock now]

            ht query {
                SELECT format('%8.3f', contrib) AS 'Delta',
                       driver                   AS 'Driver',
                       sigline(dtype,signature) As 'Signature'
                FROM uram_contribs
                JOIN drivers ON (driver_id = driver)
                ORDER BY abs(contrib) DESC
            } -default "No significant drivers." -align RRL
        }

        ht subtitle "Significant Events" sigevents

        if {[locked -disclaimer]} {
            appserver::SIGEVENTS recent $g
        }

        ht /page

        return [ht get]
    }


    # FrcGroup:html g
    #
    # g  - The group
    #
    # Formats the summary page for force /group/{g}.

    proc FrcGroup:html {g} {
        rdb eval {SELECT * FROM frcgroups_view WHERE g=$g} data {}

        ht page "Force Group: $g"
        ht title "$data(longname) ($g)" "Force Group" 

        ht linkbar {
            "#deployment" "Deployment"
            "#sigevents"  "Significant Events"
        }

        # General information
        ht putln "$data(longname) ($g) is a force group of type"
        ht putln "$data(forcetype) belonging to actor "
        ht link /actor/$data(a) $data(a)
        ht put ".  It is "

        if {!$data(local)} {
            ht put "not"
        }
        ht put " local to the playbox."

        ht putln "It has a training level of $data(training) and a"
        ht putln "demeanor of $data(demeanor)."

        ht putln "It has a deployment cost of [moneyfmt $data(cost)]"
        ht putln "$/week/person."

        ht para

        # Deployment; anchor is "deployment".
        GroupDeployment:html $g

        ht subtitle "Significant Events" sigevents

        if {[locked -disclaimer]} {
            appserver::SIGEVENTS recent $g
        }

        ht /page

        return [ht get]
    }

    # OrgGroup:html g
    #
    # g  - The group
    #
    # Formats the summary page for org /group/{g}.

    proc OrgGroup:html {g} {
        rdb eval {SELECT * FROM orggroups_view WHERE g=$g} data {}

        ht page "Organization Group: $g"
        ht title "$data(longname) ($g)" "Organization Group" 

        ht linkbar {
            "#deployment" "Deployment"
            "#sigevents"  "Significant Events"
        }

        # Deployment; anchor is "deployment".
        GroupDeployment:html $g

        ht subtitle "Significant Events" sigevents

        if {[locked -disclaimer]} {
            appserver::SIGEVENTS recent $g
        }

        ht /page

        return [ht get]
    }

    # GroupDeployment:html g
    #
    # g   - A FRC/ORG group.
    #
    # Outputs the deployment for group g, with title; the 
    # anchor is "deployment".  During PREP, shows the status
    # quo deployment, with explanation.

    proc GroupDeployment:html {g} {
        ht subtitle "Deployment" deployment

        if {[locked]} {
            ht put "Group $g is currently deployed into the following "
            ht put "neighborhoods:" 

            ht para

            ht query {
                SELECT N.longlink     AS "Neighborhood",
                       D.personnel    AS "Personnel"
                FROM deploy_ng AS D
                JOIN gui_nbhoods AS N ON (D.n = N.n)
                WHERE D.g = $g AND D.personnel > 0
                ORDER BY N.longlink
            } -default "No personnel are deployed." -align LR
        } else {
            ht put "Deployment for $g should be done as part of strategy "
            ht put "execution using \"On Lock\" tactics."
            ht para

            ht putln ""
            ht tinyi {
                More information will be available once the scenario has
                been locked.
            }
            ht para
        }
        ht para
    }
}



