#-----------------------------------------------------------------------
# TITLE:
#    service_eni.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena_sim(1): ENI Service Manager
#
#    This module is the API used by tactics to fund ENI services
#    to civilian groups.  The ENI service allows an actor
#    to pump money into neighborhoods, thus raising group moods
#    and vertical relationships.
#
#    For methods that are shared across all services (eg. ENERGY, etc...)
#    the service module is used.
#
#-----------------------------------------------------------------------

snit::type service_eni {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Assessment
    #
    # This section contains the code to compute each actor's credit
    # wrt each group, and the resulting attitude effects.

    # assess
    #
    # Calls the ENI rule set to assess the attitude implications for
    # each group.

    typemethod assess {} {
        profile 1 $type ComputeCredit

        profile 1 ruleset ENI assess
    }

    # ComputeCredit
    #
    # Credits each actor with the fraction of service provided to each
    # civilian group.  First, the actor in control of the neighborhood
    # gets credit for the fraction of service he provides, up to 
    # saturation.  Credit for any fraction of service beyond that but
    # still below saturation is split between the other actors
    # in proportion to their funding.

    typemethod ComputeCredit {} {
        # FIRST, initialize every actor's credit to 0.0
        rdb eval { UPDATE service_ga SET credit = 0.0; }

        # NEXT, Prepare to compute the controlling actor's credit.
        foreach g [civgroup local names] {
            set controller($g) ""
            set conCredit($g)  0.0
        }

        # NEXT, For each controlling actor and group, get the actor's 
        # credit for funding that group.
        rdb eval {
            SELECT C.g                   AS g, 
                   CN.controller         AS a,
                   SGA.funding           AS funding,
                   SG.saturation_funding AS saturation,
                   SG.funding            AS total
            FROM local_civgroups AS C
            JOIN control_n AS CN USING (n)
            JOIN service_ga AS SGA ON (SGA.g = C.g AND SGA.a = CN.controller)
            JOIN service_sg AS SG  ON (SG.g = C.g AND SG.s = 'ENI');
        } {
            if {$funding == 0.0} {
                set credit 0.0
            } else {
                let credit {min(1.0, $funding / min($total, $saturation))}
            }

            set controller($g) $a
            set conCredit($g) $credit
        }

        # NEXT, get the total funding for each group by actors
        # who do NOT control the neighborhood.
        array set denom [rdb eval {
            SELECT g, total(funding)
            FROM service_ga
            JOIN civgroups USING (g)
            JOIN control_n USING (n)
            WHERE coalesce(controller,'') != a
            GROUP BY g
        }]

        # NEXT, compute the credit
        foreach {g a funding} [rdb eval {
            SELECT g, a, funding
            FROM service_ga
        }] {
            if {$a eq $controller($g)} {
                set credit $conCredit($g)
            } elseif {$funding > 0.0} {
                let credit {($funding/$denom($g))*(1 - $conCredit($g))}
            } else {
                set credit 0.0
            }
            
            rdb eval {
                UPDATE service_ga
                SET credit = $credit
                WHERE g=$g AND a=$a
            }
        }
    }

    #-------------------------------------------------------------------
    # Simulation 

    # srservice 
    # 
    # This method rebuilds the saturation and required service table based 
    # on the simulation state. In "PREP" it is the base population, otherwise
    # it is the actual population from the demographics model.
    #

    typemethod srservice {} {
        # FIRST, blow away whatever is there it will be computed again
        rdb eval {
            DELETE FROM sr_service;
        }

        # NEXT, determine the correct database query based on state
        if {[sim state] eq "PREP"} {
            set rdbQuery "
                SELECT g            AS g,
                       urbanization AS urb,
                       basepop      AS pop
                FROM local_civgroups
            "
        } else {
            set rdbQuery "
                SELECT g            AS g,
                       urbanization AS urb,
                       population   AS pop
                FROM local_civgroups
                JOIN demog_g USING (g)
            "
        }

        # NEXT, do the query and fill in the required and saturation 
        # service table
        rdb eval $rdbQuery {
            if {$pop > 0} {
                set Sr [money validate \
                    [parm get service.ENI.saturationCost.$urb]]
                let Sf {$pop * $Sr}
                set Rr [parm get service.ENI.required.$urb]
                let Rf {$Sf * $Rr}
            } else {
                let Sf 0.0
                let Rf 0.0
            }

            rdb eval {
                INSERT INTO sr_service(g, req_funding, sat_funding)
                VALUES($g, $Rf, $Sf)
            }
        }
    }

    #-------------------------------------------------------------------
    # Tactic API

    # load
    #
    # Populates the working tables for strategy execution.

    typemethod load {} {
        rdb eval {
            DELETE FROM working_service_ga;
            INSERT INTO working_service_ga(g,a)
            SELECT g, a FROM local_civgroups JOIN actors;
        }
    }

    # fundlevel pct glist
    #
    # pct   - percentage of SLOS
    # glist - List of groups
    #
    # This method returns the funding level required for the groups
    # in glist to receive the input percentage of the saturation
    # level of service. Note: It is assumed that there is only one
    # source of ENI funding.

    typemethod fundlevel {pct glist} {
        require {$pct >= 0.0} \
            "Attempt to compute funding level with negative percent: $pct"

        # FIRST, if there's no groups, nothing to compute
        if {[llength $glist] == 0} {
            return 0.0
        }

        # NEXT, if we are in PREP, the saturation funding should be
        # recomputed and then retrieved from the sr_service table, 
        # otherwise it is retrieved from the service_sg table which 
        # is computed every tick
        if {[sim state] eq "PREP"} {
            $type srservice

            set gclause "g IN ('[join $glist {','}]')"
            set sat_funding [rdb onecolumn "
                             SELECT total(sat_funding)
                             FROM sr_service
                             WHERE $gclause
                        "]
        } else {
            set gclause "g IN ('[join $glist {','}]') AND s='ENI'"
            set sat_funding [rdb onecolumn "
                             SELECT total(saturation_funding)
                             FROM service_sg
                             WHERE $gclause
                        "]
        }

        return [expr {$sat_funding * $pct/100.0}]
    }


    # fundeni a amount glist
    #
    # a        - An actor
    # amount   - ENI funding, in $/week
    # glist    - List of local groups to be funded.
    #
    # This routine is called by the FUNDENI tactic.  It allocates
    # the funding to the listed groups in proportion to their
    # population and the urbanization of their neighborhood.
    #
    # Returns 1 on success and 0 if all of the groups were empty.

    typemethod fundeni {a amount glist} {
        require {$amount >= 0} \
            "Attempt to fund ENI with negative amount: $amount"

        require {[llength $glist] != 0} \
            "Attempt to fund ENI for empty list of groups"

        # FIRST, get the "in" clause
        set gclause "G.g IN ('[join $glist ',']')"

        # NEXT initialize adjust cost by group and adjusted total
        # cost
        set Agcost [dict create]
        set Atcost 0.0

        foreach {g n urb pop} [rdb eval "
            SELECT G.g                AS g,
                   G.n                AS n,
                   N.urbanization     AS urb,
                   D.population       AS pop
            FROM civgroups  AS G 
            JOIN nbhoods    AS N   USING (n)
            JOIN demog_g    AS D   ON (D.g = G.g)
            WHERE $gclause
            GROUP BY G.g
        "] {
            # NEXT compute each groups adjusted cost based on urbanization
            # and keep a running total of adjusted cost
            if {$pop > 0} {
                set Sc     [money validate \
                    [parm get service.ENI.saturationCost.$urb]]
                let Acost  {$pop * $Sc}
                let Atcost {$Atcost + $Acost}

                dict set Agcost $g $Acost
            }
        }

        # NEXT, can't fund 0 people.
        if {$Atcost == 0.0} {
            return 0
        }

        dict for {g cost} $Agcost {
            let share {$cost/$Atcost*$amount}
            rdb eval {
                UPDATE working_service_ga
                SET funding = funding + $share
                WHERE g=$g AND a=$a
            }
        }

        return 1
    }

    # Saves the working data back to the persistent tables,
    # and computes the current level of service for all groups.
    # If locking, sets expected LOS to actual LOS when computing LOS.

    typemethod save {} {
        # FIRST, log all changed levels of funding
        $type LogFundingChanges

        # NEXT, save data back to the persistent tables
        rdb eval {
            SELECT g, a, funding
            FROM working_service_ga
        } {
            rdb eval {
                UPDATE service_ga
                SET funding = $funding
                WHERE g=$g AND a=$a
            }
        }

        # NEXT, update the required and saturation levels of funding
        $type srservice

        # NEXT, compute the actual and effective levels of service.
        $type ComputeLOS
    }

    # LogFundingChanges
    #
    # Logs all funding changes.

    typemethod LogFundingChanges {} {
        rdb eval {
            SELECT OLD.g                         AS g,
                   OLD.a                         AS a,
                   OLD.funding                   AS old,
                   NEW.funding                   AS new,
                   NEW.funding - OLD.funding     AS delta,
                   G.n                           AS n
            FROM service_ga AS OLD
            JOIN working_service_ga AS NEW USING (g,a)
            JOIN local_civgroups As g ON (G.g = OLD.g)
            WHERE abs(delta) >= 1.0
            ORDER BY delta DESC, a, g
        } {
            if {$delta > 0} {
                sigevent log 1 strategy "
                    Actor {actor:$a} increased ENI funding to {group:$g}
                    by [moneyfmt $delta] to [moneyfmt $new].
                " $a $g $n
            } else {
                let delta {-$delta}

                sigevent log 1 strategy "
                    Actor {actor:$a} decreased ENI funding to {group:$g}
                    by [moneyfmt $delta] to [moneyfmt $new].
                " $a $g $n
            }
        }
    }

    # ComputeLOS 
    #
    # Computes the actual and expected levels of service.  If
    # locking, the expected LOS is initialized to the
    # actual; otherwise, it follows the actual LOS using 
    # exponential smoothing.

    typemethod ComputeLOS {} {
        set parms(gainNeeds)  [parm get service.ENI.gainNeeds]
        set parms(gainExpect) [parm get service.ENI.gainExpect]

        foreach {g n urb pop Fg oldX} [rdb eval {
            SELECT G.g                AS g,
                   G.n                AS n,
                   G.urbanization     AS urb,
                   D.population       AS pop,
                   total(SGA.funding) AS Fg,
                   SG.expected        AS oldX
            FROM local_civgroups AS G 
            JOIN demog_g    AS D   ON (D.g = G.g)
            JOIN service_ga AS SGA ON (SGA.g = G.g)
            JOIN service_sg AS SG  ON (SG.g = G.g AND SG.s='ENI')
            GROUP BY G.g
        }] {
            # FIRST, default all ENI parms to 0.0
            set parms(Pg) 0.0
            set parms(Rg) 0.0
            set parms(Fg) 0.0
            set parms(Ag) 0.0
            set parms(Xg) 0.0
            set parms(expectf) 0.0
            set parms(needs) 0.0

            # NEXT, if the group has population, it needs ENI
            if {$pop > 0} {
                set parms(Fg) $Fg

                # Compute the actual value
                set Sr   [money validate \
                    [parm get service.ENI.saturationCost.$urb]]
                let parms(Pg) {$pop * $Sr}
                set parms(Rg) [parm get service.ENI.required.$urb]
                set beta [parm get service.ENI.beta.$urb]

                let parms(Ag) {min(1.0,($parms(Fg)/$parms(Pg))**$beta)}

                # The status quo expected value is the same as the
                # status quo actual value (but not more than 1.0).
                if {[strategy locking]} {
                    let oldX {min(1.0,$parms(Ag))}
                }

                # Get the smoothing constant.
                if {$parms(Ag) > $oldX} {
                    set alpha [parm get service.ENI.alphaA]
                } else {
                    set alpha [parm get service.ENI.alphaX]
                }

                # Compute the expected value
                let parms(Xg) {$oldX + $alpha*($parms(Ag) - $oldX)}

                # Compute expectf and needs factor
                set parms(expectf) [service expectf [array get parms]]
                set parms(needs)   [service needs [array get parms]]
            }

            # Save the new values
            rdb eval {
                UPDATE service_sg
                SET saturation_funding = $parms(Pg),
                    required           = $parms(Rg),
                    funding            = $parms(Fg),
                    actual             = $parms(Ag),
                    expected           = $parms(Xg),
                    expectf            = $parms(expectf),
                    needs              = $parms(needs)
                WHERE g=$g AND s='ENI';
            }
        }
    }
}

