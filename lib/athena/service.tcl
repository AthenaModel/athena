#-----------------------------------------------------------------------
# TITLE:
#    service.tcl
#
# AUTHOR:
#    Will Duquette
#    Dave Hanks
#
# DESCRIPTION:
#    athena(n): Services Manager
#
#    This module is the API used by tactics to affect the level of
#    services to civilian groups.  There are, at present, two types
#    of services: those that require funding (Essential Non-Infrastructure
#    Services or ENI for short), and those that are abstract and, thus, do not 
#    require funding, nor have any type of infrastructure associated with 
#    them (ENERGY, TRANSPORT, and WATER).
#    
#    The ENI service allows an actor to pump money into neighborhoods,
#    thus raising group moods and vertical relationships.
#
#    All three abstract services allow an actor (or the SYSTEM) to change
#    the level of that service thus raising or lowering group moods and,
#    if an actor is responsible, vertical relationships.
#
#-----------------------------------------------------------------------

snit::type ::athena::service {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance.

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of this type.

    constructor {adb_} {
        set adb $adb_
    }
 
    #-------------------------------------------------------------------
    # Non-Checkpointed Variables
    #
    # changed 
    #
    # This array variable keeps track of which neighborhoods have already
    # had LOS modified for a particular abstract infrastructure service.  
    # The SERVICE tactic uses this to determine whether LOS should be 
    # changed

    variable changed -array {}

    # start
    #
    # This routine is called when the scenario is locked and the 
    # simulation starts.  It populates the service_* tables.

    method start {} {
        # FIRST, populate the service_ga table with the defaults.
        $adb eval {
            -- Populate service_ga table
            INSERT INTO service_ga(g,a)
            SELECT C.g, A.a
            FROM local_civgroups AS C
            JOIN actors    AS A;
        }

        # NEXT, populate the service_sg table
        foreach s [eservice names] {
            $adb eval {
                SELECT g FROM local_civgroups
            } {
                $adb eval {
                    -- Populate service_sg table
                    INSERT INTO service_sg(s,g) 
                    VALUES($s,$g);
                }
           }
        }

        # NEXT, initialize abstract services
        set aisnames [eabservice names]

        foreach {g urb s} [$adb eval {
            SELECT G.g                AS g,
                   G.urbanization     AS urb,
                   SG.s               AS s
            FROM local_civgroups AS G 
            JOIN demog_g    AS D   ON (D.g = G.g)
            JOIN service_sg AS SG  ON (SG.g = G.g)
        }] {

            if {$s ni $aisnames} {
                continue
            }

            # NEXT, defaults for actual, required and expected
            set actual   [$adb parm get service.$s.actual.$urb]
            set required [$adb parm get service.$s.required.$urb]

            $adb eval {
                UPDATE service_sg
                SET actual     = $actual,
                    new_actual = $actual,
                    required   = $required,
                    expected   = $actual
                WHERE g=$g AND s=$s
            }
        }
    }

    # reset
    #
    # Called between ticks, this method clears the changed array 

    method reset {} {
        array unset changed
    }

    # changed n s
    #
    # n   - a nbhood
    # s   - an abstract infrastructure service
    #
    # Returns a flag indicating if a particular abstract infrastructure 
    # service has been changed during strategy execution.  Only services
    # that have not already had LOS changed should be modified.

    method changed {n s} {
        if {![info exists changed($n,$s)]} {
            return 0
        }

        return 1
    }


    # expectf  pdict
    #
    # pdict  - dictionary of data needed to compute expectf
    #
    # Computes the expectations factor given the dictionary of data.
    # Each specific service (ENI, ENERGY, etc...) is responsible for
    # supplying the requisite data.
    #
    # The dictionary must have at least:
    #
    #    gainExpect   - the gain on the expectations factor 
    #    Ag           - the actual level of service 
    #    Xg           - the expected level of service

    method Expectf {pdict} {
        # FIRST, extract data from the dictionary
        dict with pdict {}

        # NEXT, the expectations factor
        let expectf {$gainExpect * (min(1.0,$Ag) - $Xg)}

        if {abs($expectf) < 0.01} {
            set expectf 0.0
        }

        return $expectf
    }

    # needs   pdict
    # 
    # pdict   - a dictionary of data needed to compute needs
    #
    # Computes the needs factor given the dictionary of data.
    # Each specific service (ENI, ENERGY, etc...) is responsible
    # for aupplying the requisite data.
    #
    # The dictionary must have at least:
    #
    #    gainNeeds   - the gain on the needs factor
    #    Ag          - the actual level of service
    #    Rg          - the required level of service

    method Needs {pdict} {
        # FIRST, extract data from the dictionary
        dict with pdict {}

        # NEXT, the needs factor
        if {$Ag >= $Rg} {
            set needs 0.0
        } elseif {$Ag == 0.0} {
            set needs 1.0
        } else {
            # $Ag < $Rg
            let needs {($Rg - $Ag)/$Rg}
        } 

        let needs {$needs * $gainNeeds}

        if {abs($needs) < 0.01} {
            set needs 0.0
        }

        return $needs
    }

    #-------------------------------------------------------------------
    # Assessment
    #
    # This section contains the code to compute each actor's credit
    # wrt each group, and the resulting attitude effects.

    # assess
    #
    # Calls the ENI rule set to assess the attitude implications for
    # each group.

    method assess {} {
        # ENI services
        $self ComputeCredit

        # Abstract services
        $self LogLOSChanges
        $self ComputeFactors 

        profile 1 $adb ruleset ENI       assess
        profile 1 $adb ruleset ENERGY    assess
        profile 1 $adb ruleset TRANSPORT assess
        profile 1 $adb ruleset WATER     assess
    }

    #-------------------------------------------------------------------
    # Simulation 

    # srservice 
    # 
    # This method rebuilds the saturation and required service table based 
    # on the simulation state. In "PREP" it is the base population, otherwise
    # it is the actual population from the demographics model.
    #

    method srservice {} {
        # FIRST, blow away whatever is there it will be computed again
        $adb eval {
            DELETE FROM sr_service;
        }

        # NEXT, determine the correct database query based on state
        if {[$adb state] eq "PREP"} {
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
        $adb eval $rdbQuery {
            if {$pop > 0} {
                set Sr [money validate \
                    [$adb parm get service.ENI.saturationCost.$urb]]
                let Sf {$pop * $Sr}
                set Rr [$adb parm get service.ENI.required.$urb]
                let Rf {$Sf * $Rr}
            } else {
                let Sf 0.0
                let Rf 0.0
            }

            $adb eval {
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

    method load {} {
        $adb eval {
            DELETE FROM working_service_ga;
            INSERT INTO working_service_ga(g,a)
            SELECT g, a FROM local_civgroups JOIN actors;
        }
    }

    # save
    #
    # Saves the working data back to the persistent tables,
    # and computes the current level of service for all groups.
    # If locking, sets expected LOS to actual LOS when computing LOS.

    method save {} {
        # FIRST, log all changed levels of funding
        $self LogFundingChanges

        # NEXT, save data back to the persistent tables
        $adb eval {
            SELECT g, a, funding
            FROM working_service_ga
        } {
            $adb eval {
                UPDATE service_ga
                SET funding = $funding
                WHERE g=$g AND a=$a
            }
        }

        # NEXT, update the required and saturation levels of funding
        $self srservice

        # NEXT, compute the actual and effective levels of service.
        $self ComputeLOS
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

    method fundlevel {pct glist} {
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
        if {[$adb state] eq "PREP"} {
            $self srservice

            set gclause "g IN ('[join $glist {','}]')"
            set sat_funding [$adb onecolumn "
                             SELECT total(sat_funding)
                             FROM sr_service
                             WHERE $gclause
                        "]
        } else {
            set gclause "g IN ('[join $glist {','}]') AND s='ENI'"
            set sat_funding [$adb onecolumn "
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

    method fundeni {a amount glist} {
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

        foreach {g n urb pop} [$adb eval "
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
                    [$adb parm get service.ENI.saturationCost.$urb]]
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
            $adb eval {
                UPDATE working_service_ga
                SET funding = funding + $share
                WHERE g=$g AND a=$a
            }
        }

        return 1
    }

    # actual n s los
    #
    # nlist - a list of neighborhoods
    # s     - an abstract infrastructure service; eabservice(n) name
    # los   - the actual level of service for s
    #
    # This method sets the actual level of service 's' to los for
    # each group in neighborhood n.  Satisfaction effects are then
    # based on this level of service when the rule set for this 
    # service fires.

    method actual {nlist s los} {
        # FIRST, los must be in the range [0.0, 1.0]
        require {$los >= 0.0 && $los <= 1.0} \
            "Invalid LOS: $los, must be between 0.0 and 1.0 inclusive."

        # NEXT, grab all groups in the neighborhoods and set
        # their ALOS and changed flag
        set glist [list]
        foreach n $nlist {
            lappend glist {*}[$adb civgroup gIn $n]
            set changed($n,$s) 1
        }

        set gclause "g IN ('[join $glist {','}]') AND s='$s'"

        $adb eval "
            UPDATE service_sg
            SET new_actual = $los
            WHERE $gclause
        "
    }

    # delta mode nlist s frac
    #
    # mode   - the mode of change one of: RDELTA, EDELTA or ADELTA
    # nlist  - a list of neighborhoods
    # s      - the abstract infrastructure service
    # frac   - the delta amount, up or down, to change the service
    #
    # This method changes actual LOS of an abstract infrastructure service
    # up or down by a fractional amount based on mode:
    #
    #  RDELTA  - fraction of required LOS
    #  EDELTA  - fraction of expected LOS
    #  ADELTA  - fraction of actual LOS
    #
    # The changed flag is set for each neighborhood in nlist for the service
    # being changed.  

    method delta {mode nlist s frac} {
        # FIRST, frac must be >= -1.0
        require {$frac >= -1.0} \
            "Invalid fraction: $frac, must be >= -1.0."

        # NEXT, grab all groups in the neighborhoods and set ALOS
        # and changed flag
        set glist [list]
        foreach n $nlist {
            lappend glist {*}[$adb civgroup gIn $n]
            set changed($n,$s) 1
        }

        set gclause "g IN ('[join $glist {','}]') AND s='$s'"

        # NEXT, update LOS based on mode
        if {$mode eq "RDELTA"} {
            set which "required"
        } elseif {$mode eq "EDELTA"} {
            set which "expected"
        } elseif {$mode eq "ADELTA"} {
            set which "actual"
        } else {
            error "Unknown mode: \"$mode\""
        }

        # NEXT, update the new actual LOS clamping it between 0.0 and 1.0
        $adb eval "
            UPDATE service_sg
            SET new_actual = max(0.0,min(1.0,$which + ($which * $frac)))
            WHERE $gclause
        "
    }

    # ComputeFactors
    #
    # This method uses the new ALOS, current ELOS and RLOS to compute
    # the needs and expectations factors which are then used later
    # when the abservice driver module assess the LOS of each abstract
    # service on the civilian population.

    method ComputeFactors {} {
        # FIRST, extract the names of all abstract services
        set slist [eabservice names]

        # NEXT, cache the needs and expectations factor gain values so
        # we do not need to keep hitting the parmdb
        foreach s $slist {
            set parms(gainNeeds,$s)  [$adb parm get service.$s.gainNeeds]
            set parms(gainExpect,$s) [$adb parm get service.$s.gainExpect]
        }

        # NEXT, extract data from the RDB for abstract services
        foreach {s g urb pop oldX Ag Rg} [$adb eval "
            SELECT SG.s               AS s,
                   G.g                AS g,
                   G.urbanization     AS urb,
                   D.population       AS pop,
                   SG.expected        AS oldX,
                   SG.new_actual      AS Ag,
                   SG.required        AS Rg
            FROM local_civgroups AS G 
            JOIN demog_g    AS D   ON (D.g = G.g)
            JOIN service_sg AS SG  ON (SG.g = G.g)
            WHERE s IN ('[join $slist ',']')
        "] {
            set parms(gainNeeds)  $parms(gainNeeds,$s)
            set parms(gainExpect) $parms(gainExpect,$s)

            # FIRST, set actual and required, abstract service gets 
            # ALOS set from outside
            set parms(Ag) $Ag
            set parms(Rg) $Rg

            # NEXT, default other service parms to 0.0
            set parms(Xg) 0.0
            set parms(expectf) 0.0
            set parms(needs) 0.0

            # NEXT, if the group has population, it needs service
            if {$pop > 0} {
                # Compute the actual value

                # The status quo expected value is the same as the
                # status quo actual value (but not more than 1.0).
                if {[$adb strategy locking]} {
                    let oldX {min(1.0,$parms(Ag))}
                }

                # Get the smoothing constant.
                if {$parms(Ag) > $oldX} {
                    set alpha [$adb parm get service.$s.alphaA]
                } else {
                    set alpha [$adb parm get service.$s.alphaX]
                }

                # Compute the expected value
                let parms(Xg) {$oldX + $alpha*(min(1.0,$parms(Ag)) - $oldX)}

                # Compute expectf and needs factor
                set parms(expectf) [$self Expectf [array get parms]]
                set parms(needs)   [$self Needs [array get parms]]
            }

            # Save the new values
            $adb eval {
                UPDATE service_sg
                SET required    = $parms(Rg),
                    expected    = $parms(Xg),
                    actual      = $parms(Ag),
                    expectf     = $parms(expectf),
                    needs       = $parms(needs)
                WHERE g=$g AND s=$s;
            }
        }
    }

    # ComputeLOS 
    #
    # Computes the actual and expected levels of service.  If
    # locking, the expected LOS is initialized to the
    # actual; otherwise, it follows the actual LOS using 
    # exponential smoothing.

    method ComputeLOS {} {
        set parms(gainNeeds)  [$adb parm get service.ENI.gainNeeds]
        set parms(gainExpect) [$adb parm get service.ENI.gainExpect]

        foreach {g n urb pop Fg oldX} [$adb eval {
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
                    [$adb parm get service.ENI.saturationCost.$urb]]
                let parms(Pg) {$pop * $Sr}
                set parms(Rg) [$adb parm get service.ENI.required.$urb]
                set beta [$adb parm get service.ENI.beta.$urb]

                let parms(Ag) {min(1.0,($parms(Fg)/$parms(Pg))**$beta)}

                # The status quo expected value is the same as the
                # status quo actual value (but not more than 1.0).
                if {[$adb strategy locking]} {
                    let oldX {min(1.0,$parms(Ag))}
                }

                # Get the smoothing constant.
                if {$parms(Ag) > $oldX} {
                    set alpha [$adb parm get service.ENI.alphaA]
                } else {
                    set alpha [$adb parm get service.ENI.alphaX]
                }

                # Compute the expected value
                let parms(Xg) {$oldX + $alpha*($parms(Ag) - $oldX)}

                # Compute expectf and needs factor
                set parms(expectf) [$self Expectf [array get parms]]
                set parms(needs)   [$self Needs [array get parms]]
            }

            # Save the new values
            $adb eval {
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

    # ComputeCredit
    #
    # Credits each actor with the fraction of service provided to each
    # civilian group.  First, the actor in control of the neighborhood
    # gets credit for the fraction of service he provides, up to 
    # saturation.  Credit for any fraction of service beyond that but
    # still below saturation is split between the other actors
    # in proportion to their funding.

    method ComputeCredit {} {
        # FIRST, initialize every actor's credit to 0.0
        $adb eval { UPDATE service_ga SET credit = 0.0; }

        # NEXT, Prepare to compute the controlling actor's credit.
        foreach g [$adb civgroup local names] {
            set controller($g) ""
            set conCredit($g)  0.0
        }

        # NEXT, For each controlling actor and group, get the actor's 
        # credit for funding that group.
        $adb eval {
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
        array set denom [$adb eval {
            SELECT g, total(funding)
            FROM service_ga
            JOIN civgroups USING (g)
            JOIN control_n USING (n)
            WHERE coalesce(controller,'') != a
            GROUP BY g
        }]

        # NEXT, compute the credit
        foreach {g a funding} [$adb eval {
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
            
            $adb eval {
                UPDATE service_ga
                SET credit = $credit
                WHERE g=$g AND a=$a
            }
        }
    }

    # LogLOSChanges
    #
    # This method logs changes to actual level of service provided to
    # civilian groups.  Only changes greater than 0.001 to the
    # current level of service are logged.

    method LogLOSChanges {} {
        set slist [eabservice names]

        $adb eval "
            SELECT SG.new_actual        AS new,
                   SG.actual            AS actual,
                   SG.new_actual-actual AS delta,
                   SG.g                 AS g,
                   SG.s                 AS s,
                   G.n                  AS n
            FROM service_sg AS SG
            JOIN local_civgroups AS G ON (G.g = SG.g)
            WHERE s IN ('[join $slist ',']')
            AND   abs(delta) > 0.001
            ORDER BY delta DESC, g
        " {
            set dir "increased"
            if {$delta < 0} {
                set dir "decreased"
                let delta {-$delta}
            }

            $adb sigevent log 1 strategy "
                Civilian group {group:$g} has actual level of $s
                service $dir by [format %.1f%% [expr {$delta*100.0}]]
                to [format %.1f%% [expr {$new*100.0}]].
            " $g $n
        }
    }

    # LogFundingChanges
    #
    # Logs all funding changes.

    method LogFundingChanges {} {
        $adb eval {
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
                $adb sigevent log 1 strategy "
                    Actor {actor:$a} increased ENI funding to {group:$g}
                    by [moneyfmt $delta] to [moneyfmt $new].
                " $a $g $n
            } else {
                let delta {-$delta}

                $adb sigevent log 1 strategy "
                    Actor {actor:$a} decreased ENI funding to {group:$g}
                    by [moneyfmt $delta] to [moneyfmt $new].
                " $a $g $n
            }
        }
    }
}

