#-----------------------------------------------------------------------
# FILE: demog.tcl
#
#   Athena Demographics Model
#
# PACKAGE:
#   athena(n): Demographics Manager
#
#   This module is responsible for computing demographics for neighborhoods
#   and neighborhood groups.  The data is stored in the demog_g, demog_n,
#   and demog_local tables.  Entries in the demog_n and demog_g tables
#   are created and deleted by the nbhood and civgroup modules respectively,
#   as neighborhoods and civilian groups come and go.  The (single)
#   entry in the demog_local table is created/replaced on <analyze pop>.
#
# PROJECT:
#   Athena S&RO Simulation
#
# AUTHOR:
#    Will Duquette
#
# TBD:
#    * Global entities in use: ::econ, ::sim, ::parmdb
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------

snit::type ::athena::demog {

    #-------------------------------------------------------------------
    # Components 

    component adb  ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Non-Checkpointed Variables
    #
    # This variable is used to keep track of unused labor force by
    # neighborhood. It's used when unemployment is disaggregated

    variable lfremain -array {}

    # This variable is used to keep track of jobs remaining by 
    # neighborhood. It's used when unemployment is disaggregated

    variable jobsremain -array {}

    # This variable keeps track of the number of iterations of the
    # unemployment disaggregation algorithm given a priority level

    variable iter

    #-------------------------------------------------------------------
    # Constructor

    constructor {adb_} {
        set adb $adb_
    }

    #-------------------------------------------------------------------
    # Scenario Control

    # start
    #
    # Computes population statistics at scenario lock.

    method start {} {
        # FIRST, populate the demog_g and demog_n tables.

        $adb eval {
            INSERT INTO demog_g(g,real_pop,population,upc)
            SELECT g, 
                   basepop, 
                   basepop,
                   upc
            FROM civgroups_view;

            INSERT INTO demog_n(n)
            SELECT n FROM nbhoods;
        }

        # NEXT, do the initial population analysis
        $self stats
    }
    

    #-------------------------------------------------------------------
    # Population Stats

    # stats
    #
    # Computes the population statistics, both breakdowns and
    # rollups, in demog_g(g), demog_n(n), and demog_local for all n, g.
    #
    # This routine can be called at any time after scenario lock.

    method stats {} {
        $self ComputePopG
        $self ComputePopN
        $self ComputePopLocal

        # Notify the GUI that demographics may have changed.
        $adb notify demog <Update>

        return
    }

    # ComputePopG
    #
    # Computes the population statistics for each civilian group.

    method ComputePopG {} {
        # FIRST, compute the breakdown for all groups.
        foreach {g population sa_flag lfp} [rdb eval {
            SELECT g, population, sa_flag, lfp
            FROM demog_g JOIN civgroups USING (g)
        }] {
            if {$sa_flag} {
                let subsistence $population
                let consumers   0
                let labor_force 0
            } else {
                let subsistence 0
                let consumers   $population
                let labor_force {round($lfp * $consumers/100.0)}
            }

            $adb eval {
                UPDATE demog_g
                SET subsistence = $subsistence,
                    consumers   = $consumers,
                    labor_force = $labor_force
                WHERE g=$g;
            }
        }
    }

    # ComputePopN
    #
    # Computes the population statistics and labor force for each
    # neighborhood.

    method ComputePopN {} {
        # FIRST, compute neighborhood population, consumers, and
        # labor force given the neighborhood groups.
        $adb eval {
            SELECT n,
                   total(population)  AS population,
                   total(subsistence) AS subsistence,
                   total(consumers)   AS consumers,
                   total(labor_force) AS labor_force
            FROM demog_g
            JOIN civgroups USING (g)
            GROUP BY n
        } {
            $adb eval {
                UPDATE demog_n
                SET population  = $population,
                    subsistence = $subsistence,
                    consumers   = $consumers,
                    labor_force = $labor_force
                WHERE n=$n
            }
        }

        # NEXT, if econ is disabled, treat the demographic playbox
        # unemployment rate as though it were from the econ model
        # NOTE: the econ model will compute the jobs in the econ_n table
        # if it is enabled
        set defaultUR 0.0
        if {[econ state] eq "DISABLED"} {
            set defaultUR [parm get demog.playboxUR]
        }

        foreach {n labor_force} [rdb eval {
             SELECT n,labor_force FROM demog_n
        }] {
            let jobs {$labor_force * (1.0 - ($defaultUR / 100.0))}
           $adb eval {
                UPDATE econ_n
                SET jobs=$jobs
                WHERE n=$n
            }
        }
    }

    # ComputePopLocal
    #
    # Computes the population statistics and labor force for the
    # local region of interest.

    method ComputePopLocal {} {
        # FIRST, compute and save the total population and
        # labor force in the local region.

        $adb eval {
            DELETE FROM demog_local;

            INSERT INTO demog_local
            SELECT total(population), total(consumers), total(labor_force)
            FROM demog_n
            JOIN nbhoods USING (n)
            WHERE nbhoods.local = 1;
        }
    }


    #-------------------------------------------------------------------
    # Population Growth/Change

    # growth
    #
    # Computes the adjustment to each civilian group's population
    # based on its change rate.

    method growth {} {
        foreach {g real_pop pop_cr} [rdb eval {
            SELECT g, real_pop, pop_cr
            FROM civgroups JOIN demog_g USING (g)
            WHERE pop_cr != 0.0
        }] {
            # FIRST, compute the delta.  Note that pop_cr is an
            # annual rate expressed as a percentage; we need a
            # weekly fraction.  Thus, we divide by 100*52.
            let delta {$real_pop * $pop_cr/5200.0}
            log detail demog "Group $g's population changes by $delta"
            $self adjust $g $delta
        }
    }


    #-------------------------------------------------------------------
    # Analysis of Economic Effects on the Population

    # econstats
    #
    # Computes the effects of the economy on the population.

    method econstats {} {
        # FIRST, compute the statistics
        $self ComputeUnemployment
        $self ComputeNbhoodEconStats
        $self ComputeGroupEmployment
        $self ComputeGroupConsumption
        $self ComputeExpectedGroupConsumption
        $self ComputeGroupPoverty


        # NEXT, Notify the GUI that demographics may have changed.
        $adb notify demog <Update>

        return
    }

    # geounemp
    #
    # Returns the number of workers geographically unemployed (are too
    # far from where the work is)

    method geounemp {} {
        # FIRST, no econ model, no geo-unemployment
        if {[econ state] eq "DISABLED"} {
            return 0
        }

        # NEXT, grab the CGE M page unemployment and the disaggregated
        # unemployment
        array set data [econ get M -bare]

        set cgeUnemp $data(Unemp)

        set demogUnemp \
            [rdb onecolumn {SELECT total(unemployed) FROM demog_n}]

        # NEXT, return the difference between the two
        let GU {max(0, round($demogUnemp-$cgeUnemp))}

        return $GU
    }

    # ComputeGroupEmployment
    #
    # Compute the group employment statistics for each group.
    
    method ComputeGroupEmployment {} {
        # FIRST, get the unemployment rate and the Unemployment
        # Factor Z-curve.
        set zuaf [parmdb get demog.Zuaf]

        # NEXT, compute the group employment statistics
        foreach {n g population labor_force} [rdb eval {
            SELECT n, g, population, labor_force
            FROM demog_g
            JOIN civgroups USING (g)
            JOIN nbhoods USING (n)
            WHERE nbhoods.local
            GROUP BY g
        }] {
            set laborN [rdb eval {
                SELECT labor_force FROM demog_n
                WHERE n=$n
            }]

            set unemployedN [rdb eval {
                SELECT unemployed FROM demog_n
                WHERE n=$n
            }]

            if {$laborN > 0} {
                # number of employed and unemployed workers
                let unemployed {
                    double($labor_force)/double($laborN)*double($unemployedN)
                }
                let unemployed {round($unemployed)}
                let employed   {$labor_force - $unemployed}

                # unemployed per capita
                if {$population > 0} {
                    let upc {100.0 * $unemployed / $population}
                    let ur 0.0
                    if {$labor_force > 0} {
                        let ur  {100.0 * $unemployed / $labor_force}
                    }
                } else {
                    set upc 0.0
                    set ur  0.0
                }

                # Unemployment Attitude Factor
                set uaf [zcurve eval $zuaf $upc]
            } else {
                let unemployed 0
                let employed   0
                let ur         0.0
                let upc        0.0
                let uaf        0.0
            }

            # Save results
            $adb eval {
                UPDATE demog_g
                SET employed   = $employed,
                    unemployed = $unemployed,
                    ur         = $ur,
                    upc        = $upc,
                    uaf        = $uaf
                WHERE g=$g;
            }
        }
    }
    
    # ComputeGroupConsumption
    #
    # Computes the actual consumption of goods by each group.
    
    method ComputeGroupConsumption {} {
        # FIRST, clear the values;
        $adb eval {
            UPDATE demog_g
            SET tc   = 0,
                aloc = 0,
                rloc = 0;
        }
        
        # NEXT, if the economic model is disabled, that's all we'll do.
        if {[econ state] eq "DISABLED"} {
            return            
        }
        
        # NEXT, compute total employment
        set totalEmployed [rdb onecolumn {
            SELECT total(employed) FROM demog_g
        }]

        # NEXT, disaggregate the consumption of goods to the groups.         
        set QD [econ value Out::QD.goods.pop]
        
        foreach {g employed consumers urbanization} [rdb eval {
            SELECT D.g            AS g,
                   D.employed     AS employed,
                   D.consumers    AS consumers,
                   N.urbanization AS urbanization
            FROM demog_g AS D
            JOIN civgroups AS C USING (g)
            JOIN nbhoods AS N USING (n)
            WHERE D.consumers > 0
        }] {
            if {$totalEmployed == 0} {
                set tc   0.0
                set aloc 0.0
            } else {
                # QD is a yearly rate of consumption; divided by 52 to get
                # weekly consumption.
                let tc   {($QD/52.0)*($employed/$totalEmployed)}
                let aloc {$tc/$consumers}
            }

            let rloc {[parm get demog.consump.RGPC.$urbanization]/52.0}
            
           $adb eval {
                UPDATE demog_g
                SET tc   = $tc,
                    aloc = $aloc,
                    rloc = $rloc
                WHERE g = $g;
            }
        }
    }
    
    # ComputeExpectedGroupConsumption
    #
    # Update the expected level of consumption of goods for all groups.
    
    method ComputeExpectedGroupConsumption {} {
        # FIRST, if the economic model is disabled, we're done.
        if {[econ state] eq "DISABLED"} {
            $adb eval {
                UPDATE demog_g
                SET eloc = 0;
            }
        
            return            
        }
    
        # NEXT, on lock the expected consumption is just the actual
        # consumption.
        if {[simclock delta] == 0} {
           $adb eval {
                UPDATE demog_g
                SET eloc = aloc;
            }
            
            return            
        }
    
        # NEXT, compute the new expected consumption from the old,
        # along with the expectations factor.
        set alphaA [parm get demog.consump.alphaA]
        set alphaE [parm get demog.consump.alphaE]
    
        foreach {g aloc eloc} [rdb eval {
            SELECT g, aloc, eloc
            FROM demog_g
            WHERE consumers > 0
        }] {
            # NOTE: eloc is the eloc from the previous week; aloc is
            # newly computed.
            
            if {$aloc - $eloc >= 0.0} {
                let eloc {$eloc + $alphaA*($aloc - $eloc)}
            } else {
                let eloc {$eloc + $alphaE*($aloc - $eloc)}
            }
        
           $adb eval {
                UPDATE demog_g
                SET eloc = $eloc
                WHERE g = $g
            }
        }
    }
    
    # ComputeGroupPoverty
    #
    # Computes each group's poverty fraction given the group's consumption
    # and the regional Gini coefficient.
    
    method ComputeGroupPoverty {} {
        # FIRST, clear the values.
       $adb eval {
            UPDATE demog_g
            SET povfrac = 0;
        }
        
        # NEXT, if the economic model is disabled we're done.
        if {[econ state] eq "DISABLED"} {
            return            
        }
    
        # NEXT, if the Gini coefficient is 1.0 then effectively one
        # person has all of the income and no one else has anything.
        # Otherwise, compute the povfrac given the formula.
        set gini [parm get demog.gini]
        
        if {$gini == 1.0} {
            let povfrac 1.0
        } else {
            # The Lorenz curve can be approximated as x^n where
            # n is a function of the Gini coefficient.
            let n {(1 + $gini)/(1 - $gini)}
            
            # We want groups that are non-subsistence agriculture, and
            # that have population.  Requiring consumers > 0 does this.
            foreach {g tc rloc population} [rdb eval {
                SELECT g, tc, rloc, population
                FROM demog_g
                WHERE consumers > 0
            }] {
                # FIRST, compute the full fraction.
                let povfrac { (($rloc*$population)/($n*$tc))**(1/($n-1)) }
                
                # NEXT, clamp to 1.0 and round to two decimal places.
                # NEXT, round to two decimal places
                set povfrac [format %.2f [expr {min(1.0, $povfrac)}]]
                
                $adb eval {
                    UPDATE demog_g
                    SET povfrac = $povfrac
                    WHERE g = $g
                }
            }
        }
    }

    # AllocateJobsByPriority prio
    #
    # prio    - An eproximity(n) value
    #
    # This method allocates workers from neighborhoods that have labor
    # to jobs in neighborhoods that have work given a neighborhood
    # proximity.  It's possible that one time through the method
    # is not enough so this method should be called multiple times until 
    # the finished condition is reached. The finshed condition is true
    # when the following is true:
    #
    #    For each neighborhood n and m that have the given eproximity(n):
    #
    #           lfremain(n) * jobsremain(m) = 0
    #
    # The result of this calculation is returned to the caller.
    # 
    # The following variables are used in the algorithm below given the
    # input eproximity value:
    #
    #    laborAvailableToNb(n) - total amount of labor available to n
    #    jobOffersToNb(n)      - total number of job offers given to n
    #    jobOffers(n,m)        - job offers by nbhood n to labor in nbhood m
    #    jobsFilled(n,m)       - jobs filled in nbhood n by labor in nbhood m

    method AllocateJobsByPriority {prio} {
        # FIRST, initialize labor force available to each neighborhood 
        # and job offers made to each neighborhood
        foreach n [array names lfremain] {
            set laborAvailToNb($n) 0
        }

        foreach n [array names jobsremain] {
            set jobOffersToNb($n) 0
        }

        # NEXT, create a mapping of neighborhoods that have jobs to
        # neighborhoods with workers that could work them
        set jmap [dict create]

        set nbWithJobs [rdb eval {
            SELECT DISTINCT N.n
            FROM nbhoods AS N JOIN nbrel_mn AS R
            WHERE R.n        =N.n
            AND   R.proximity=$prio
            AND   N.local    =1
        }]

        foreach n $nbWithJobs {
            # Neighborhoods with workers 
            set nbWithWorkers [rdb eval {
                SELECT DISTINCT R.m
                FROM nbrel_mn AS R 
                JOIN nbhoods AS N ON (N.n=R.m)
                WHERE R.n        =$n
                AND   R.proximity=$prio
                AND   N.local    =1
            }]

            dict set jmap $n $nbWithWorkers

            # Total up workers available to each neighborhood
            foreach m $nbWithWorkers {
               let laborAvailToNb($n) {$lfremain($m) + $laborAvailToNb($n)}
            }
        }

        # NEXT, go through neighborhoods with jobs and make job offers
        # to those workers available in other neighborhoods
        foreach n [dict keys $jmap] {
            foreach m [dict get $jmap $n] {
                set jobOffers($n,$m) 0

                # No labor force available, no job offers
                if {$laborAvailToNb($n) == 0} {
                    set jobOffers($n,$m) 0
                } else {
                    let jobOffers($n,$m) {
                        ceil($jobsremain($n) * 
                            ($lfremain($m) / $laborAvailToNb($n)))
                    }
                }
            }

            # NEXT, sum up the total number of job offers made to the
            # neighborhood that has the workers, there may be more
            # offers than there are workers
            foreach m [dict get $jmap $n] {
                let jobOffersToNb($m) {
                    $jobOffersToNb($m) + $jobOffers($n,$m)
                }
            }
        }

        # NEXT, given the available labor force determine how the jobs
        # get filled in n by the workers available in each m
        foreach n [dict keys $jmap] {
            foreach m [dict get $jmap $n] {
                set jobsFilled($n,$m) 0

                if {$jobOffersToNb($m) > 0} {
                    # If the total number of job offers to the neighborhood
                    # is greater than the labor force remaining, the ratio
                    # of job offers in the neighborhood to the total number
                    # of job offers is used
                    if {$jobOffersToNb($m) >= $lfremain($m)} {
                        let jobsFilled($n,$m) {
                            ceil($lfremain($m) * 
                                ($jobOffers($n,$m) / $jobOffersToNb($m)))
                        }
                    } else {
                        set jobsFilled($n,$m) $jobOffers($n,$m)
                    }
                } 

                # Decrement the number of job offers by the number of
                # filled positions
                let jobOffers($n,$m) {$jobOffers($n,$m)-$jobsFilled($n,$m)}
            }
        }
                
        # NEXT, compute new totals of labor force remaining and jobs
        # remaining now that jobs have been filled
        set morework 0
        foreach n [dict keys $jmap] {
            foreach m [dict get $jmap $n] {
                # It's possible that the ceil() function causes a -1 in the
                # jobs remaining or labor force remaining, so guard against
                # that
                let lfremain($m) {
                    max(0,$lfremain($m) - $jobsFilled($n,$m))
                }
                
                let jobsremain($n) {
                    max(0,$jobsremain($n) - $jobsFilled($n,$m))
                }

                # NEXT, determine if all possible jobs that could be filled
                # have been
                let morework {$morework + $lfremain($m)*$jobsremain($n)}
            }
        }

        # NEXT, return the morework indicator
        return $morework
    }

    # ComputeUnemployment
    #
    # This method disaggregates unemployment based upon the number of
    # workers demanded in the economic model and where GOODS production
    # plants exist in the infrastructure model.  Essentially, jobs exist
    # where plants exist and whether a worker is willing to work at
    # a plant is a function of neighborhood proximity.  The maximum proximity
    # a worker will take a job is controlled by a model parameter.

    method ComputeUnemployment {} {
        # FIRST, extract jobs and labor force available. Those in turbulence
        # are not considered part of the labor force
        set TurFrac [parm get demog.turFrac]

        $adb eval {
            SELECT E.n           AS n,
                   E.jobs        AS jobs, 
                   D.labor_force AS LF 
                   FROM econ_n_view  AS E
                   JOIN demog_n AS D ON E.n=D.n
        } {
            # Only whole jobs and whole people are considered
            let jobsremain($n) {floor($jobs)}
            let lfremain($n)   {floor($LF * (1.0-$TurFrac))}
        }

        # NEXT, based on neighborhood proximity as the priority, 
        # disaggregate unemployment taking into account that
        # some folks are geographically unemployed (too far from 
        # where the jobs are)
        set max [parmdb get demog.maxcommute]

        foreach prox [eproximity names] {
            set morework 1
            set iter 0

            # NEXT, allocate the jobs at each priority, making sure that
            # all jobs that could possibly be filled are filled.
            if {[eproximity le $prox $max]} {
                while {$morework} {
                    incr iter
                    set morework [$self AllocateJobsByPriority $prox]

                    # If we haven't finished by 1000 iterations, something
                    # is completely hosed.
                    if {$iter >= 1000} {
                        log debug demog \
                            "Jobs remaining by nbhood: [array get jobsremain]"
                        log debug demog \
                            "Labor remaining by nbhood: [array get lfremain]"
                        error "Disaggregation of unemployment failed"
                    }
                }
            } else {
                break
            }
        }
    }

    # ComputeNbhoodEconStats
    #
    # Computes the neighborhood's economic statistics.
 
    method ComputeNbhoodEconStats {} {
        # FIRST, compute neighborhood statistics based upon the disaggregated
        # unemployment
        set zuaf [parmdb get demog.Zuaf]
        set TurFrac [parm get demog.turFrac]

        foreach {n population labor_force} [rdb eval {
            SELECT n, population, labor_force
            FROM demog_n
            JOIN nbhoods USING (n)
            WHERE nbhoods.local
        }] {
            if {$population > 0} {
                # number of unemployed workers
                let unemployed {round($lfremain($n) + $labor_force*$TurFrac)}

                # unemployment rate
                if {$labor_force > 0} {
                    let ur {100.0 * $unemployed / $labor_force}
                } else {
                    set ur 0.0
                }

                # unemployed per capita
                let upc {100.0 * $unemployed / $population}

                # Unemployment Attitude Factor
                set uaf [zcurve eval $zuaf $upc]
            } else {
                let unemployed 0
                let ur         0.0
                let upc        0.0
                let uaf        0.0
            }

            # Save results
           $adb eval {
                UPDATE demog_n
                SET unemployed = $unemployed,
                    ur         = $ur,
                    upc        = $upc,
                    uaf        = $uaf
                WHERE n=$n;
            }
        }

    }
    
    #-------------------------------------------------------------------
    # Queries

    # getg g ?parm?
    #
    # g    - A group in the neighborhood
    # parm - A demog_g column name
    #
    # Retrieves a row dictionary, or a particular column value, from
    # demog_g.

    method getg {g {parm ""}} {
        # FIRST, get the data
       $adb eval {SELECT * FROM demog_g WHERE g=$g} row {
            if {$parm ne ""} {
                return $row($parm)
            } else {
                unset row(*)
                return [array get row]
            }
        }

        return ""
    }


    # getn n ?parm?
    #
    #   n    - A neighborhood
    #   parm - A demog_n column name
    #
    # Retrieves a row dictionary, or a particular column value, from
    # demog_n.

    method getn {n {parm ""}} {
        # FIRST, get the data
       $adb eval {SELECT * FROM demog_n WHERE n=$n} row {
            if {$parm ne ""} {
                return $row($parm)
            } else {
                unset row(*)
                return [array get row]
            }
        }

        return ""
    }

    # getlocal ?parm?
    #
    #   parm - A demog_local column name
    #
    # Retrieves a row dictionary, or a particular column value, from
    # demog_local.

    method getlocal {{parm ""}} {
        # FIRST, get the data
       $adb eval {
            SELECT * FROM demog_local LIMIT 1
        } row {
            if {$parm ne ""} {
                return $row($parm)
            } else {
                unset row(*)
                return [array get row]
            }
        }

        return ""
    }

    # gIn n
    #
    # n  - A neighborhood ID
    #
    # Returns a list of the NON-EMPTY civ groups that reside
    # in the neighborhood.

    method gIn {n} {
        if {[sim state] eq "PREP"} {
            return [rdb eval {
                SELECT g FROM civgroups WHERE n=$n AND basepop > 0 ORDER BY g
            }]
        } else {
            return [rdb eval {
                SELECT g
                FROM demog_g
                JOIN civgroups USING (g)
                WHERE n=$n AND population > 0
                ORDER BY g
            }]
        }
    }

    # saIn n
    #
    # n  - A neighborhood ID
    #
    # Returns a list of the NON-EMPTY subsistence agriculture
    # that reside in the neighborhood.

    method saIn {n} {
        if {[sim state] eq "PREP"} {
            return [rdb eval {
                SELECT g FROM civgroups 
                WHERE n=$n AND basepop > 0 AND sa_flag 
                ORDER BY g
            }]
        } else {
            return [rdb eval {
                SELECT g
                FROM demog_g
                JOIN civgroups USING (g)
                WHERE n=$n AND population > 0 AND sa_flag
                ORDER BY g
            }]
        }
    }

    # nonSaIn n
    #
    # n  - A neighborhood ID
    #
    # Returns a list of the NON-EMPTY non-subsistence agriculture
    # that reside in the neighborhood.

    method nonSaIn {n} {
        if {[sim state] eq "PREP"} {
            return [rdb eval {
                SELECT g FROM civgroups 
                WHERE n=$n AND basepop > 0 AND NOT sa_flag 
                ORDER BY g
            }]
        } else {
            return [rdb eval {
                SELECT g
                FROM demog_g
                JOIN civgroups USING (g)
                WHERE n=$n AND population > 0 AND NOT sa_flag
                ORDER BY g
            }]
        }
    }

    # pop nbhoods
    #
    # nbhoods  - A list of neighborhoods
    #
    # Returns the total population of the neighborhoods in the
    # list.

    method pop {nbhoods} {
        set total [rdb onecolumn "
            SELECT total(population)
            FROM demog_n
            WHERE n IN ('[join $nbhoods ',']')
        "]

        return [expr {entier($total)}]
    }

    # shares nbhoods
    #
    # nbhoods   - A list of neighborhoods
    #
    # Returns a population profile for the list of neighborhoods: the
    # fractional share each neighborhood has of the total population
    # of the neighborhoods.

    method shares {nbhoods} {
        # FIRST, get the total population.
        set total [$self pop $nbhoods]

        # NEXT, handle a set of empty neighborhoods.
        if {$total == 0.0} {
            foreach n $nbhoods {
                dict set result $n 0.0
            }
            return $result
        }

        # NEXT, compute the profile for the set of neighborhoods.
        return [rdb eval "
            SELECT n, (CAST (population AS DOUBLE))/\$total
            FROM demog_n 
            WHERE n IN ('[join $nbhoods ',']')
            ORDER BY n
        "]
    }


    #-------------------------------------------------------------------
    # Mutators
    #
    # Note: these are not mutators in the sense of an order mutator.

    # adjust g delta
    #
    # g      - Group ID
    # delta  - Some change to population
    #
    # Adjusts a population figure by some amount, which may be positive
    # or negative, and may include a fractional part.  Fractional
    # parts are accumulated over time.  The integer population is
    # the rounded "real_pop".  If the "real_pop" is less than 1,
    # it is set to zero.
    #
    # Note that this routine doesn't recompute all of the breakdowns
    # and roll-ups; call [demog stats] as needed.

    method adjust {g delta} {
        set real_pop [$self getg $g real_pop]

        let real_pop {max(0.0, $real_pop + $delta)}

        # If it's less than 1.0, make it zero
        if {$real_pop < 1.0} {
            let real_pop {0.0}
        }

        let population {floor(round($real_pop))}

       $adb eval {
            UPDATE demog_g
            SET population = $population,
                real_pop   = $real_pop
            WHERE g=$g
        } {}
    }

    # flow f g delta
    #
    # f     - A civilian group
    # g     - Another civilian group
    # delta - Some number of people
    #
    # Flows up to delta people from group f to group g.  The
    # delta can include fractional flows.

    method flow {f g delta} {
        # FIRST, Make sure delta's not too big.
        set fpop [$self getg $f population]
        let delta {min($fpop, $delta)}

        # NEXT, Adjust the two groups
        $self adjust $f -$delta
        $self adjust $g $delta

        # NEXT, Record the change
        if {[parm get hist.pop]} {
           $adb eval {
                INSERT OR IGNORE INTO hist_flow(t,f,g)
                VALUES(now(), $f, $g);

                UPDATE hist_flow
                SET flow = flow + $delta
                WHERE t=now() AND f=$f AND g=$g;
            }
        }
    }

    # attrit g casualties
    #
    # g           - Group ID
    # casualties  - A number of casualites to attrit
    #
    # Attrits a civilian group's population.  Note that it doesn't
    # recompute all of the breakdowns and roll-ups; call
    # [$self stats] as needed.  Casualties never have a fractional
    # part.
    #
    # TBD: This routine could be simplified

    method attrit {g casualties} {
        # FIRST, get the undo information
       $adb eval {
            SELECT population,attrition FROM demog_g
            WHERE g=$g
        } {}

        assert {$casualties >= 0}
        let casualties {min($casualties, $population)}
        let undoCasualties {-$casualties}
        set undoing 0

        # NEXT, Update the group
       $adb eval {
            UPDATE demog_g
            SET attrition = attrition + $casualties,
                population = population - $casualties,
                real_pop = real_pop - $casualties
            WHERE g=$g
        }
    }
}
