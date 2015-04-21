#-----------------------------------------------------------------------
# TITLE:
#   rebase.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n): Simulation Rebase Manager 
#
#   Rebasing the simulation is the creation of a new scenario that when
#   locked will be equivalent to the current state of the simulation.
#   This module is responsible for updating the scenario data for this 
#   purpose.  The methodess is as follows:
#
#   * Rebasing requires data from the previous time tick.  
#     [rebase prepare] saves this data at the beginning of each [tick].
#   * The user calls `$adb unlock -rebase`.
#
#-----------------------------------------------------------------------

snit::type ::athena::rebase {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        set adb $adb_
    }

    # prepare
    #
    # This routine should be called at the beginning of each time tick
    # to save data for the state of the simulation as of the start of
    # the tick, e.g., current satisfaction levels.

    method prepare {} {
        $adb eval {
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
    
    # save
    #
    # Save scenario prep data based on the current simulation
    # state.  For some modules, we do the rebasing effort right here,
    # because it is straightforward and it's more convenient to have it
    # all in one place.  For others it's significantly tricky, and it's
    # better to have it with its source module.
    
    method save {} {
        # FIRST, do the tricky modules.
        $adb econ rebase
        $adb absit rebase
        $adb strategy rebase

        # NEXT, rebase the other scenario tables.
        $self RebaseCivgroups
        $self RebaseCooperation
        $self RebaseFrcgroups
        $self RebaseHorizontalRelationships
        $self RebaseNeighborhoods        
        $self RebaseOrggroups
        $self RebaseSatisfaction
        $self RebaseVerticalRelationships
    }

    # RebaseCivgroups
    #
    # Save civgroups data on rebase.

    method RebaseCivgroups {} {
        # FIRST, set civilian group base population to the current
        # population.
        $adb eval {
            SELECT g, population, upc
            FROM demog_g
        } {
            $adb eval {
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

    method RebaseCooperation {} {
        # FIRST, set base to current values.
        $adb eval {
            SELECT f, g, bvalue, cvalue FROM uram_coop;
        } {
            $adb eval {
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

    method RebaseFrcgroups {} {
        # FIRST, set force group base personnel to the current level.
        $adb eval {
            SELECT g, personnel
            FROM personnel_g
        } {
            $adb eval {
                UPDATE frcgroups
                SET base_personnel = $personnel
                WHERE g=$g
            }
        }
    }

    # RebaseHorizontalRelationships
    #
    # Save HREL data on rebase.

    method RebaseHorizontalRelationships {} {
        # FIRST, set overrides to natural relationships
        $adb eval {
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

    method RebaseNeighborhoods {} {
        # FIRST, set nbhood controller to current controller.
        $adb eval {
            SELECT n, controller FROM control_n
        } {
            $adb eval {
                UPDATE nbhoods 
                SET controller=nullif($controller,'')
                WHERE n=$n
            }
        }
    }

    # RebaseOrggroups
    #
    # Save orggroups data on rebase.

    method RebaseOrggroups {} {
        # FIRST, set org group base personnel to the current level.
        $adb eval {
            SELECT g, personnel
            FROM personnel_g
        } {
            $adb eval {
                UPDATE orggroups
                SET base_personnel = $personnel
                WHERE g=$g
            }
        }
    }
    
    # RebaseSatisfaction
    #
    # Save satisfaction data on rebase.
    
    method RebaseSatisfaction {} {
        # FIRST, set base to current values.
        $adb eval {
            SELECT U.g       AS g, 
                   U.c       AS c, 
                   U.bvalue  AS bvalue,
                   R.current AS current 
            FROM uram_sat AS U
            JOIN rebase_sat AS R USING (g,c)
        } {
            $adb eval {
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

    method RebaseVerticalRelationships {} {
        # FIRST, set overrides to current relationships
        $adb eval {
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

