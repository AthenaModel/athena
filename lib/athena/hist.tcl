#-----------------------------------------------------------------------
# TITLE: 
#    hist.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#   athena(n): Results history manager
#
# History is saved for t=0 on lock and for t > 0 at the end of each
# time-step's activities.  [hist tick] saves all history that is
# saved at every tick; [hist econ] saves all history that is saved
# at each econ tock.
#
#-----------------------------------------------------------------------

snit::type ::athena::hist {
    #-------------------------------------------------------------------
    # Components

    component adb  ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Construcutor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of this type.

    constructor {adb_} {
        set adb $adb_
    }

    #-------------------------------------------------------------------
    # Public Methods

    # purge t
    #
    # t   - The sim time in ticks at which to purge
    #
    # Removes "future history" from the history tables when going
    # backwards in time.  We are paused at time t; all time t 
    # history is behind us.  So purge everything later.
    #
    # On unlock, this will be used to purge all history, including
    # time 0 history, by setting t to -1. NOTE: in the case of t = -1
    # its *much* quicker to leave out the WHERE clause

    method purge {t} {
        if {$t == -1} {
            $adb eval {
                DELETE FROM hist_nbhood;
                DELETE FROM hist_sat;
                DELETE FROM hist_mood;
                DELETE FROM hist_coop;
                DELETE FROM hist_nbcoop;
                DELETE FROM hist_econ;
                DELETE FROM hist_econ_i;
                DELETE FROM hist_econ_ij;
                DELETE FROM hist_security;
                DELETE FROM hist_service_sg;
                DELETE FROM hist_support;
                DELETE FROM hist_hrel;
                DELETE FROM hist_vrel;
                DELETE FROM hist_pop;
                DELETE FROM hist_flow;
                DELETE FROM hist_activity_nga;
            }
        } else {
            $adb eval {
                DELETE FROM hist_nbhood       WHERE t > $t;
                DELETE FROM hist_sat          WHERE t > $t;
                DELETE FROM hist_mood         WHERE t > $t;
                DELETE FROM hist_coop         WHERE t > $t;
                DELETE FROM hist_nbcoop       WHERE t > $t;
                DELETE FROM hist_econ         WHERE t > $t;
                DELETE FROM hist_econ_i       WHERE t > $t;
                DELETE FROM hist_econ_ij      WHERE t > $t;
                DELETE FROM hist_security     WHERE t > $t;
                DELETE FROM hist_service_sg   WHERE t > $t;
                DELETE FROM hist_support      WHERE t > $t;
                DELETE FROM hist_hrel         WHERE t > $t;
                DELETE FROM hist_vrel         WHERE t > $t;
                DELETE FROM hist_pop          WHERE t > $t;
                DELETE FROM hist_flow         WHERE t > $t;
                DELETE FROM hist_activity_nga WHERE t > $t;
            }
        }
    }

    # tick
    #
    # This method is called at each time tick, and preserves data values
    # that change tick-by-tick.  
    #
    # "Significant" outputs (i.e., those used in practice by analysts)
    # are always saved, as are outputs required to construct causal
    # chains.  Other outputs may be disabled by setting the appropriate
    # parameter.

    method tick {} {
        set t [$adb clock now]

        $adb eval {
            INSERT INTO hist_nbhood(t,n,a,nbmood,volatility,population,
                                    security)
            SELECT $t AS t, n, 
                   C.controller AS a, 
                   U.nbmood, 
                   F.volatility, 
                   D.population,
                   F.security
            FROM uram_n    AS U
            JOIN force_n   AS F USING (n)
            JOIN demog_n   AS D USING (n)
            JOIN control_n AS C USING (n);
        }


        # TBD: The data collection that follows has not yet been
        # "cleaned up".
        if {[$adb parm get hist.coop]} {
            $adb eval {
                INSERT INTO hist_coop(t,f,g,coop,base,nat)
                SELECT now() AS t, f, g, coop, bvalue, cvalue
                FROM uram_coop;
            }
        }

        # We always save mood; it's needed by the MOOD rule set.
        $adb eval {
            INSERT INTO hist_mood(t,g,mood)
            SELECT now() AS t, g, mood
            FROM uram_mood;
        }

        if {[$adb parm get hist.nbcoop]} {
            $adb eval {
                INSERT INTO hist_nbcoop(t,n,g,nbcoop)
                SELECT now() AS t, n, g, nbcoop
                FROM uram_nbcoop;
            }
        }

        if {[$adb parm get hist.sat]} {
            $adb eval {
                INSERT INTO hist_sat(t,g,c,sat,base,nat)
                SELECT now() AS t, g, c, sat, bvalue, cvalue 
                FROM uram_sat;
            }
        }

        if {[$adb parm get hist.security]} {
            $adb eval {
                INSERT INTO hist_security(t,n,g,security)
                SELECT now(), n, g, security
                FROM force_ng;
            }
        }

        if {[$adb parm get hist.support]} {
            $adb eval {
                INSERT INTO hist_support(t,n,a,direct_support,support,influence)
                SELECT now(), n, a, direct_support, support, influence
                FROM influence_na;
            }
        }

        if {[$adb parm get hist.hrel]} {
            $adb eval {
                INSERT INTO hist_hrel(t,f,g,hrel,base,nat)
                SELECT now(), f, g, hrel, bvalue, cvalue
                FROM uram_hrel;
            }
        }

        if {[$adb parm get hist.vrel]} {
            $adb eval {
                INSERT INTO hist_vrel(t,g,a,vrel,base,nat)
                SELECT now(), g, a, vrel, bvalue, cvalue
                FROM uram_vrel;
            }
        }
    
        if {[$adb parm get hist.pop]} {
            $adb eval {
                INSERT INTO hist_pop(t,g,population)
                SELECT now(), g, population
                FROM demog_g
            }
        }

        if {[$adb parm get hist.service]} {
            $adb eval {
                INSERT INTO hist_service_sg(t,s,g,saturation_funding,required,
                                           funding,actual,expected,expectf,
                                           needs)
                SELECT now(), s, g, saturation_funding, required,
                       funding, actual, expected, expectf, needs
                FROM service_sg
            }
        }

        if {[$adb parm get hist.activity]} {
            $adb eval {
                INSERT INTO hist_activity_nga(t,n,g,a,security_flag,can_do,
                                              nominal,effective,coverage)
                SELECT now(), n, g, a, security_flag, can_do, nominal,
                       effective, coverage
                FROM activity_nga WHERE nominal > 0
            }            
        }
    }

    # Type Method: econ
    #
    # This method is called at each econ tock, and preserves data
    # values that change tock-by-tock.

    method econ {} {
        # FIRST, if the econ model has been disabled we're done.
        if {[$adb econ state] eq "DISABLED"} {
            return
        }

        # NEXT, get the data and save it.
        array set inputs  [$adb econ get In  -bare]
        array set outputs [$adb econ get Out -bare]

        $adb eval {
            -- hist_econ
            INSERT INTO hist_econ(t, consumers, subsisters, labor, 
                                  lsf, csf, rem, cpi, dgdp, ur)
            VALUES(now(), 
                   $inputs(Consumers), $inputs(Subsisters), $inputs(LF),
                   $inputs(LSF), $inputs(CSF), $inputs(REM),
                   $outputs(CPI), $outputs(DGDP), $outputs(UR));
        }

        foreach i {goods pop black actors region world} {
            if {$i in {goods pop black}} {
                $adb eval "
                    -- hist_econ_i
                    INSERT INTO hist_econ_i(t, i, p, qs, rev)
                    VALUES(now(), upper(\$i), \$outputs(P.$i), 
                           \$outputs(QS.$i),\$outputs(REV.$i));
                "
            }

            foreach j {goods pop black actors region world} {
                $adb eval "
                    -- hist_econ_ij
                    INSERT INTO hist_econ_ij(t, i, j, x, qd)
                    VALUES(now(), upper(\$i), upper(\$j), 
                           \$outputs(X.$i.$j), \$outputs(QD.$i.$j)); 
                "
            }
        }
    }
}
