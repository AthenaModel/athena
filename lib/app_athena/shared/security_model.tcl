#-----------------------------------------------------------------------
# TITLE:
#    security_model.tcl
#
# AUTHOR:
#    Will Duquette
#    Dave Hanks
#
# DESCRIPTION:
#    athena_sim(1) Simulation Module: Force & Security
#
#    This module contains code which analyzes the status of each
#    neighborhood, including group force, neighborhood volatility, 
#    and group security.  The results are used by the DAM rule sets, as
#    well as by other modules.
#
#    ::security is a singleton object implemented as a snit::type.  To
#    initialize it, call "::security init".  It can be re-initialized
#    on demand.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# security

snit::type security_model {
    # Make it an ensemble
    pragma -hastypedestroy 0 -hasinstances 0
    
    #-------------------------------------------------------------------
    # Initialization method

    typemethod start {} {
        # FIRST, check requirements
        require {[info commands ::log]  ne ""} "log is not defined."
        require {[info commands ::rdb]  ne ""} "rdb is not defined."

        # NEXT, Initialize the RDB tables used.
        rdb eval {
            DELETE FROM force_n;
            
            INSERT INTO force_n(n)
            SELECT n FROM nbhoods;
        }

        rdb eval {
            DELETE FROM force_civg;

            INSERT INTO force_civg(g)
            SELECT g
            FROM civgroups;
        }

        rdb eval {
            DELETE FROM force_ng;

            INSERT INTO force_ng(n,g)
            SELECT n, g
            FROM nbhoods JOIN groups;
        }
    }


    #-------------------------------------------------------------------
    # analyze

    # analyze
    #
    # Analyzes neighborhood status, as of the present
    # time, given the current contents of the RDB.

    typemethod analyze {} {
        # FIRST, compute the "force" values for each group in each 
        # neighborhood.
        profile 2 $type ComputeCrimeSuppression
        profile 2 $type ComputeCriminalFraction
        profile 2 $type ComputeOwnForce
        profile 2 $type ComputeLocalFriendsAndEnemies
        profile 2 $type ComputeAllFriendsAndEnemies
        profile 2 $type ComputeTotalForce
        profile 2 $type ComputePercentForce

        # NEXT, compute the volatility for each neighborhood.
        profile 2 $type ComputeVolatility

        # NEXT, compute the security for each group in each nbhood.
        profile 2 $type ComputeSecurity
   }


    # ComputeCrimeSuppression
    #
    # Computes suppression.n, the fraction of crime suppressed by 
    # current law enforcements in neighborhood n.

    typemethod ComputeCrimeSuppression {} {
        # FIRST, we're accumulating effective law enforcement personnel 
        # (LEP) by neighborhood.
        foreach n [nbhood names] {
            set LEP($n) 0 
        }

        # NEXT, accumulate the LEP for each group in each neighborhood.
        rdb eval {
            SELECT U.n                AS n,
                   U.g                AS g,
                   U.a                AS a,
                   total(U.personnel) AS P,
                   G.forcetype        AS forcetype,
                   G.training         AS training
            FROM units AS U
            JOIN frcgroups AS G USING (g)
            GROUP BY U.a
        } {
            set beta [parm get force.law.beta.$a]
            set E    [parm get force.law.efficiency.$training]
            set S    [parm get force.law.suitability.$forcetype]

            set LEP($n) [expr {$LEP($n) + $beta*$E*$S*$P}]
        }

        # NEXT, for each neighborhood compute the suppression.
        rdb eval {
            SELECT n, urbanization, population
            FROM nbhoods JOIN demog_n USING (n)
        } {
            set covfunc [parm get force.law.coverage.$urbanization]

            set suppression [coverage eval $covfunc $LEP($n) $population]

            rdb eval {
                UPDATE force_n
                SET suppression=$suppression
                WHERE n=$n
            }
        }
    }

    # ComputeCriminalFraction
    #
    # Computes the nominal and actual criminal fraction for each
    # non-empty civilian group.

    typemethod ComputeCriminalFraction {} {
        rdb eval {
            SELECT G.g                AS g,
                   G.n                AS n,
                   G.demeanor         AS demeanor,
                   FN.suppression     AS suppression,
                   DG.upc             AS upc
            FROM civgroups_view AS G
            JOIN force_n AS FN ON (FN.n=G.n)
            JOIN demog_g AS DG ON (DG.g=G.g)
            WHERE DG.population > 0
        } {
            set Zcrimfrac [parm get force.law.crimfrac.$demeanor]
            set suppfrac [parm get force.law.suppfrac]

            set nomCF [zcurve eval $Zcrimfrac $upc]
            set actCF [expr {
                (1.0 - $suppression)*$suppfrac*$nomCF +
                (1.0 - $suppfrac)*$nomCF
            }]

            rdb eval {
                UPDATE force_civg
                SET nominal_cf = $nomCF,
                    actual_cf  = $actCF
                WHERE g=$g
            }
        }
    }

    # ComputeOwnForce
    #
    # Compute Q.ng, each group g's "own force" in neighborhood n,
    # for all n and g.

    typemethod ComputeOwnForce {} {
        rdb eval {
            UPDATE force_ng
            SET own_force     = 0,
                crim_force    = 0,
                noncrim_force = 0,
                personnel     = 0
        }

        #---------------------------------------------------------------
        # CIV Groups

        # Population force.

        rdb eval {
            SELECT civgroups.n             AS n,
                   civgroups.g             AS g,
                   civgroups.demeanor      AS demeanor,
                   uram_mood.mood          AS mood,
                   total(units.personnel)  AS P
            FROM civgroups_view AS civgroups
            JOIN uram_mood USING (g)
            JOIN units USING (g)
            GROUP BY civgroups.n,civgroups.g
        } {
            set a [parmdb get force.population]
            set D [parmdb get force.demeanor.$demeanor]
            
            set b [parmdb get force.mood]
            let M {1.0 - $b*$mood/100.0}

            let pop_force {entier(ceil($a*$D*$M*$P))}

            rdb eval {
                UPDATE force_ng
                SET own_force = $pop_force,
                    personnel = $P
                WHERE n = $n AND g = $g
            }
        }

        #---------------------------------------------------------------
        # FRC Groups

        # We break down the group's personnel by activity.
        rdb eval {
            SELECT U.n                AS n,
                   U.g                AS g,
                   U.a                AS a,
                   total(U.personnel) AS P,
                   G.demeanor         AS demeanor,
                   G.forcetype        AS forcetype
            FROM units AS U 
            JOIN frcgroups_view AS G USING (g)
            WHERE U.personnel > 0
            GROUP BY n, g, U.a
        } {
            set D [parmdb get force.demeanor.$demeanor]
            set E [parmdb get force.forcetype.$forcetype]
            set A [parmdb get force.alpha.$a]

            let own_force_by_a {entier(ceil($A*$E*$D*$P))}

            rdb eval {
                UPDATE force_ng
                SET own_force = own_force + $own_force_by_a,
                    personnel = personnel + $P
                WHERE n = $n AND g = $g
            }
        }

        #---------------------------------------------------------------
        # ORG Groups

        rdb eval {
            SELECT n,
                   g,
                   total(personnel) AS P,
                   demeanor,
                   orgtype
            FROM units JOIN orggroups_view USING (g)
            WHERE personnel > 0
            GROUP BY n, g 
        } {
            set D [parmdb get force.demeanor.$demeanor]
            set E [parmdb get force.orgtype.$orgtype]
            let own_force {entier(ceil($E*$D*$P))}
            
            rdb eval {
                UPDATE force_ng
                SET own_force=$own_force,
                    personnel=$P
                WHERE n = $n AND g = $g
            }
        }

        # NEXT, compute criminal vs. non-criminal force.
        # For non-civilian groups, it's just the own_force. For civilians,
        # it is more complicated.
        rdb eval { UPDATE force_ng SET noncrim_force = own_force }

        foreach {n g actual_cf} [rdb eval {
            SELECT n, g, actual_cf
            FROM force_ng
            JOIN force_civg USING (g)
        }] {
            rdb eval {
                UPDATE force_ng
                SET crim_force    = $actual_cf * own_force,
                    noncrim_force = (1.0 - $actual_cf) * own_force
                WHERE n=$n AND g=$g
            }
        }
    }

    # ComputeLocalFriendsAndEnemies
    #
    # Computes LocalFriends.ng and LocalEnemies.ng for each n and g.

    typemethod ComputeLocalFriendsAndEnemies {} {
        # FIRST, get parmdb values.
        set crel [parm get force.law.crimrel]

        # NEXT, Get the discipline level for each force group.
        rdb eval {
            SELECT g, training FROM frcgroups
        } {
            set disc($g) [parm get force.discipline.$training]
        }

        # NEXT, prepare to accumulate the local force and local enemy
        # for each n,g
        rdb eval {
            SELECT n,g FROM force_ng
        } {
            set id [list $n $g]
            set local_force($id) 0
            set local_enemy($id) 0
        }

        # NEXT, iterate over all pairs of groups in each neighborhood.
        # Note that for non-civilian groups, noncrim_force = own_force
        # and crim_force = 0.

        rdb eval {
            SELECT NF.n                         AS n,
                   NF.g                         AS f,
                   NF.noncrim_force             AS f_noncrim_force,
                   NF.crim_force                AS f_crim_force,
                   FG.g                         AS g,
                   FG.hrel                      AS hrel,
                   coalesce(SN.stance,S.stance) AS stance
            FROM force_ng AS NF
            JOIN uram_hrel AS FG ON (FG.f = NF.g)
            LEFT OUTER JOIN stance_nfg AS SN 
                ON (SN.n=NF.n AND SN.f=NF.g AND SN.g=FG.g)
            LEFT OUTER JOIN stance_fg  AS S  
                ON (S.f=NF.g AND S.g=FG.g)
            WHERE hrel != 0.0 AND NF.own_force > 0
        } {
            set id [list $n $g]

            # FIRST, compute the effective relationship, if f is a
            # force group, and has a stance specified. Otherwise,
            # the effective relationship is simply the normal
            # relationship.
            if {$stance ne ""} {
                set hrel [expr {$hrel + ($stance - $hrel)*$disc($f)}]
            }

            # NEXT, compute friends and enemies.
            if {$hrel > 0} {
                set friends [expr {entier(ceil($f_noncrim_force*$hrel))}]
                set enemies [expr {entier(ceil($f_crim_force*abs($crel)))}]

                incr local_force($id) $friends
                incr local_enemy($id) $enemies
            } elseif {$hrel < 0} {
                set enemies [expr {
                    entier(ceil($f_noncrim_force*abs($hrel) + 
                                $f_crim_force*abs($crel)))
                }]

                incr local_enemy($id) $enemies
            }
        }

        foreach id [array names local_force] {
            lassign $id n g
            set force $local_force($id)
            set enemy $local_enemy($id)
            
            rdb eval {
                UPDATE force_ng
                SET local_force = $force,
                    local_enemy = $enemy
                WHERE n = $n AND g = $g
            }
        }
    }

    # ComputeAllFriendsAndEnemies
    #
    # Computes Force.ng and Enemy.ng for each n and g.

    typemethod ComputeAllFriendsAndEnemies {} {
        # FIRST, initialize the accumulators
        rdb eval {
            UPDATE force_ng
            SET force = local_force,
                enemy = local_enemy;
        }

        # NEXT, get the proximity multiplier
        set h [parmdb get force.proximity]

        # NEXT, iterate over all pairs of nearby neighborhoods.
        rdb eval {
            SELECT nbrel_mn.m                AS m,
                   nbrel_mn.n                AS n,
                   mforce_ng.local_force     AS m_friends,
                   mforce_ng.local_enemy     AS m_enemies,
                   nforce_ng.g               AS g
            FROM nbrel_mn 
            JOIN force_ng AS mforce_ng
            JOIN force_ng AS nforce_ng
            WHERE nbrel_mn.proximity = 'NEAR'
            AND   mforce_ng.n = nbrel_mn.m
            AND   nforce_ng.n = nbrel_mn.n
            AND   mforce_ng.g = nforce_ng.g
        } {
            let friends {entier(ceil($h*$m_friends))}
            let enemies {entier(ceil($h*$m_enemies))}

            rdb eval {
                UPDATE force_ng
                SET force = force + $friends,
                    enemy = enemy + $enemies
                WHERE n = $n AND g = $g
            }
        }
    }

    # ComputeTotalForce
    #
    # Computes TotalForce.n.

    typemethod ComputeTotalForce {} {
        # FIRST, initialize the accumulators
        rdb eval {
            UPDATE force_n
            SET total_force = 0;
        }

        # NEXT, get the force in each neighborhood
        rdb eval {
            SELECT n, g, own_force FROM force_ng
        } {
            rdb eval {
                UPDATE force_n
                SET total_force = total_force + $own_force
                WHERE n = $n
            }
        }

        # NEXT, get the proximity multiplier
        set h [parmdb get force.proximity]

        # NEXT, iterate over all pairs of nearby neighborhoods.
        rdb eval {
            SELECT nbrel_mn.n              AS n,
                   mforce_ng.own_force     AS m_own_force
            FROM nbrel_mn 
            JOIN force_ng AS mforce_ng 
            JOIN force_ng AS nforce_ng
            WHERE nbrel_mn.proximity = 'NEAR'
            AND   mforce_ng.n = nbrel_mn.m
            AND   nforce_ng.n = nbrel_mn.n
            AND   mforce_ng.g = nforce_ng.g
        } {
            let force {entier(ceil($h*$m_own_force))}

            rdb eval {
                UPDATE force_n
                SET total_force = total_force + $force
                WHERE n = $n
            }
        }
    }

    # ComputePercentForce
    #
    # Computes %Force.ng, %Enemy.ng

    typemethod ComputePercentForce {} {
        rdb eval {
            SELECT n, total_force
            FROM force_n
        } {
            if {$total_force > 1.0} {
                rdb eval {
                    UPDATE force_ng
                    SET pct_force = 100*force/$total_force,
                        pct_enemy = 100*enemy/$total_force
                    WHERE n = $n
                }
            } else {
                rdb eval {
                    UPDATE force_ng
                    SET pct_force = 0.0,
                        pct_enemy = 0.0
                    WHERE n = $n
                }
            }
        }
    }

    # ComputeVolatility
    #
    # Computes Volatility.n

    typemethod ComputeVolatility {} {
        rdb eval {
            SELECT force_ng.n                   AS n,
                   total(enemy*force)           AS conflicts,
                   total_force                  AS total_force
            FROM force_ng JOIN force_n USING (n) JOIN nbhoods USING (n)
            WHERE force_ng.own_force > 0
            GROUP BY n
        } { 
            # Avoid integer overflow
            let total_force {double($total_force)}
            let tfSquared {$total_force * $total_force}

            # Volatility depends on there being significant force
            # in the neighborhood.  If there's no force, there's
            # no volatility.

            if {$tfSquared > 1.0} {
                let volatility {
                    entier(ceil(100*$conflicts/$tfSquared))
                }
            } else {
                set volatility 0.0
            }
            
            rdb eval {
                UPDATE force_n
                SET volatility_gain    = 1.0,
                    nominal_volatility = $volatility,
                    volatility         = $volatility
                WHERE n = $n
            }
        }
    }

    # ComputeSecurity
    #
    # Computes Security.ng

    typemethod ComputeSecurity {} {
        # FIRST, get the volatility attenuator.
        set v [parmdb get force.volatility]

        rdb eval {
            SELECT n, g, pct_force, pct_enemy, personnel, volatility
            FROM force_ng AS NG
            JOIN force_n USING (n)
        } {
            if {$personnel > 0} {
                let vol {$v*$volatility}
                let realSecurity {
                    100.0*($pct_force - $pct_enemy - $vol)/(100.0 + $vol)
                }
            
                let security {entier(ceil($realSecurity))}
            } else {
                let security {0}
            }
            
            rdb eval {
                UPDATE force_ng
                SET security = $security
                WHERE n = $n AND g = $g
            }
        }
    }
}








