#-----------------------------------------------------------------------
# TITLE:
#   rebase.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena_sim(1): Simulation Rebase Manager 
#
#   Rebasing the simulation is the creation of a new scenario that when
#   locked will be equivalent to the current state of the simulation.
#   This module is responsible for updating the scenario data for this 
#   purpose.  The process is as follows:
#
#   * Rebasing requires data from the previous time tick.  
#     [rebase prepare] saves this data at the beginning of each [tick].
#   * The user sends SIM:REBASE, usually via the Orders menu.
#   * SIM:REBASE calls [sim mutate rebase], which handles the simulation
#     control issues.
#   * [sim mutate rebase] calls [sdb rebase], which handles the
#     scenario issues, e.g., purging history and so forth.
#   * [sdb rebase] calls [rebase save] to actually save the 
#     required state to the scenario tables.
#
#-----------------------------------------------------------------------

snit::type rebase {
    # Make it a singleton
    pragma -hasinstances no

    # prepare
    #
    # This routine should be called at the beginning of each time tick
    # to save data for the state of the simulation as of the start of
    # the tick, e.g., current satisfaction levels.

    typemethod prepare {} {
        rdb eval {
            DELETE FROM rebase_sat;
            INSERT INTO rebase_sat(g, c, current)
            SELECT g, c, sat FROM uram_sat;

            DELETE FROM rebase_hrel;
            INSERT INTO rebase_hrel(f, g, current)
            SELECT f, g, hrel FROM uram_hrel;

            DELETE FROM rebase_vrel;
            INSERT INTO rebase_vrel(g, a, current)
            SELECT g, a, vrel FROM uram_vrel;
        }
    }
    
    # rebase
    #
    # Save scenario prep data based on the current simulation
    # state.  For some modules, we do the rebasing effort right here,
    # because it is straightforward and it's more convenient to have it
    # all in one place.  For others it's significantly tricky, and it's
    # better to have it with its source module.
    
    typemethod save {} {
        # FIRST, do the tricky modules.
        econ rebase
        absit rebase
        strategy rebase

        # NEXT, rebase the other scenario tables.
        RebaseCivgroups
        RebaseCooperation
        RebaseFrcgroups
        RebaseHorizontalRelationships
        RebaseNeighborhoods        
        RebaseOrggroups
        RebaseSatisfaction
        RebaseVerticalRelationships
    }

    # RebaseCivgroups
    #
    # Save civgroups data on rebase.

    proc RebaseCivgroups {} {
        # FIRST, set civilian group base population to the current
        # population.
        rdb eval {
            SELECT g, population, upc
            FROM demog_g
        } {
            rdb eval {
                UPDATE civgroups
                SET basepop   = $population,
                    hist_flag = 1,
                    upc       = $upc
                WHERE g=$g
            }
        }
    }

    # RebaseCooperation
    #
    # Save coop_fg data on rebase.

    proc RebaseCooperation {} {
        # FIRST, set base to current values.
        rdb eval {
            SELECT f, g, bvalue, cvalue FROM uram_coop;
        } {
            rdb eval {
                UPDATE coop_fg
                SET base=$bvalue,
                    regress_to = 'NATURAL',
                    natural = $cvalue
                WHERE f=$f AND g=$g
            }
        }
    }

    # RebaseFrcgroups
    #
    # Save frcgroups data on rebase.

    proc RebaseFrcgroups {} {
        # FIRST, set force group base personnel to the current level.
        rdb eval {
            SELECT g, personnel
            FROM personnel_g
        } {
            rdb eval {
                UPDATE frcgroups
                SET base_personnel = $personnel
                WHERE g=$g
            }
        }
    }

    # RebaseHorizontalRelationships
    #
    # Save HREL data on rebase.

    proc RebaseHorizontalRelationships {} {
        # FIRST, set overrides to natural relationships
        rdb eval {
            DELETE FROM hrel_fg;

            INSERT INTO hrel_fg(f, g, base, hist_flag, current)
            SELECT H.f              AS f,
                   H.g              AS g,
                   H.bvalue         AS base,
                   1                AS hist_flag,
                   R.current        AS current
            FROM uram_hrel AS H
            JOIN rebase_hrel AS R USING (f,g)
            WHERE f !=g AND (H.bvalue != H.cvalue OR R.current != H.cvalue)
        }
    }

    # RebaseNeighborhoods
    #
    # Save nbhoods data on rebase.

    proc RebaseNeighborhoods {} {
        # FIRST, set nbhood controller to current controller.
        rdb eval {
            SELECT n, controller FROM control_n
        } {
            rdb eval {
                UPDATE nbhoods 
                SET controller=nullif($controller,'')
                WHERE n=$n
            }
        }
    }

    # RebaseOrggroups
    #
    # Save orggroups data on rebase.

    proc RebaseOrggroups {} {
        # FIRST, set org group base personnel to the current level.
        rdb eval {
            SELECT g, personnel
            FROM personnel_g
        } {
            rdb eval {
                UPDATE orggroups
                SET base_personnel = $personnel
                WHERE g=$g
            }
        }
    }
    
    # RebaseSatisfaction
    #
    # Save satisfaction data on rebase.
    
    proc RebaseSatisfaction {} {
        # FIRST, set base to current values.
        rdb eval {
            SELECT U.g       AS g, 
                   U.c       AS c, 
                   U.bvalue  AS bvalue,
                   R.current AS current 
            FROM uram_sat AS U
            JOIN rebase_sat AS R USING (g,c)
        } {
            rdb eval {
                UPDATE sat_gc
                SET base      = $bvalue,
                    hist_flag = 1,
                    current   = $current
                WHERE g=$g AND c=$c
            }
        }
    }


    # RebaseVerticalRelationships
    #
    # Save VREL data on rebase.

    proc RebaseVerticalRelationships {} {
        # FIRST, set overrides to current relationships
        rdb eval {
            DELETE FROM vrel_ga;
            
            INSERT INTO vrel_ga(g, a, base, hist_flag, current)
            SELECT V.g              AS g,
                   V.a              AS a,
                   V.bvalue         AS base,
                   1                AS hist_flag,
                   R.current        AS current
                   FROM uram_vrel AS V
                   JOIN rebase_vrel AS R USING (g,a)
                   WHERE V.bvalue != V.cvalue OR R.current != V.cvalue;
        }
    }
}

