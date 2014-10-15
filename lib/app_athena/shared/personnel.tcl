#-----------------------------------------------------------------------
# TITLE:
#   personnel.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena_sim(1): Personnel Manager
#
#   This module is responsible for managing the deployment of 
#   FRC and ORG personnel in neighborhoods and the assignment of
#   activities to deployed personnel.
#
#-----------------------------------------------------------------------

snit::type personnel {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Simulation 

    # start
    #
    # This routine is called when the scenario is locked and the 
    # simulation starts.  It populates the personnel_g and deploy_ng
    # tables.

    typemethod start {} {
        # FIRST, populate the personnel_g and deploy_ng tables from
        # the status quo FRC/ORG deployments.
        rdb eval {
            -- Populate personnel_g table.
            INSERT INTO personnel_g(g,personnel)
            SELECT g, base_personnel
            FROM agroups;

            -- Populate FRC/ORG rows with zeros, they'll need to be
            -- updated at strategy execution
            INSERT INTO deploy_ng(n,g,personnel,unassigned)
            SELECT n, g, 0, 0
            FROM agroups JOIN nbhoods;
        }

        # NEXT, make the base units.
        unit makebase
    }

    # load
    #
    # Populates the working tables for strategy execution.

    typemethod load {} {
        rdb eval {
            DELETE FROM working_personnel;
            INSERT INTO working_personnel(g,personnel,available)
            SELECT g, personnel, personnel FROM personnel_g;
            
            DELETE FROM working_deployment;

            INSERT INTO working_deployment(n,g)
            SELECT n,g FROM deploy_ng JOIN agroups USING (g);

            DROP TABLE IF EXISTS working_deploy_tng;
            CREATE TEMP TABLE working_deploy_tng AS SELECT * FROM deploy_tng;
            DELETE FROM deploy_tng;
        }
    }

    # deploy tactic_id n g personnel
    #
    # tactic_id    - The ID of the DEPLOY tactic
    # n            - The neighborhood to which troops are deployed
    # g            - The group to which the troops belong
    # personnel    - The number of troops to deploy
    #
    # This routine is called by the DEPLOY tactic.  It deploys the
    # requested number of available FRC or ORG personnel.

    typemethod deploy {tactic_id n g personnel} {
        set available [rdb onecolumn {
            SELECT available FROM working_personnel WHERE g=$g
        }]

        require {$personnel > 0} \
            "Attempt to deploy negative personnel: $personnel"

        require {$personnel <= $available} \
            "Insufficient personnel available: $personnel > $available"

        rdb eval {
            UPDATE working_personnel
            SET available = available - $personnel
            WHERE g=$g;

            UPDATE working_deployment
            SET personnel  = personnel  + $personnel,
                unassigned = unassigned + $personnel
            WHERE n=$n AND g=$g;

            INSERT INTO deploy_tng(tactic_id, n, g, personnel)
            VALUES($tactic_id, $n, $g, $personnel)
        }
    }

    # inplaybox g
    #
    # g  - A force or ORG group
    #
    # Retrieves the number of personnel in the playbox.

    typemethod inplaybox {g} {
        rdb onecolumn {SELECT personnel FROM working_personnel WHERE g=$g}
    }

    # available g
    #
    # g  - A force or ORG group
    #
    # Retrieves the number of personnel available for deployment.

    typemethod available {g} {
        rdb eval {
            SELECT available FROM working_personnel WHERE g=$g
        } {
            return $available
        }

        return 0
    }

    # unassigned n g
    #
    # n  - A neighborhood
    # g  - A group
    #
    # Retrieves the number of unassigned personnel from group g in 
    # neighborhood n.

    typemethod unassigned {n g} {
        rdb eval {
            SELECT unassigned FROM working_deployment 
            WHERE n=$n AND g=$g
        } {
            return $unassigned
        }

        return 0
    }



    # demob g personnel
    #
    # g         - A force or ORG group
    # personnel - The number of personnel to demobilize, or "all"
    #
    # Demobilizes the specified number of undeployed personnel.

    typemethod demob {g personnel} {
        set available [rdb onecolumn {
            SELECT available FROM working_personnel WHERE g=$g
        }]

        require {$personnel <= $available} \
            "Insufficient personnel available: $personnel > $available"

        rdb eval {
            UPDATE working_personnel
            SET available = available - $personnel,
                personnel = personnel - $personnel
            WHERE g=$g;
        }
    }

    # mobilize g personnel
    #
    # g         - A force or ORG group
    # personnel - The number of personnel to mobilize, or "all"
    #
    # Mobilizes the specified number of new personnel.

    typemethod mobilize {g personnel} {
        rdb eval {
            UPDATE working_personnel
            SET available = available + $personnel,
                personnel = personnel + $personnel
            WHERE g=$g;
        }
    }

    # assign tactic_id g n a personnel
    #
    # tactic_id   - The tactic ID for which the personnel are being
    #               assigned.
    # g           - The group providing the personnel
    # n           - The nbhood in which the personnel will be assigned
    # a           - The activity to which they will be assigned
    # personnel   - The number of personnel to assign.
    #
    # Assigns the personnel to the activity, decrementing the
    # "unassigned" count.  If there's no unit already existing, 
    # creates it.  Otherwise, updates the unit's personnel.

    typemethod assign {tactic_id g n a personnel} {
        # FIRST, ensure that enough personnel remain.
        set unassigned [$type unassigned $n $g]

        require {$personnel <= $unassigned} \
            "Insufficient unassigned personnel: $personnel > $unassigned"
        
        # NEXT, allocate the personnel.
        rdb eval {
            UPDATE working_deployment
            SET unassigned = unassigned - $personnel
            WHERE n=$n AND g=$g
        }

        # NEXT, assign the tactic unit to this activity.
        return [unit assign $tactic_id $g $n $a $personnel]
    }

    # save
    #
    # Saves the working data back to the persistent tables.  In particular,
    # 
    # * Deployment changes are logged.
    # * Undeployed troops are demobilized (if strategy.autoDemob is set)
    # * Force levels and deployments are saved.

    typemethod save {} {
        # FIRST, log all changed deployments.
        $type LogDeploymentChanges

        # NEXT, Demobilize undeployed troops
        if {[parm get strategy.autoDemob]} {
            foreach {g available a} [rdb eval {
                SELECT g, available, a 
                FROM working_personnel
                JOIN agroups USING (g) 
                WHERE available > 0
            }] {
                sigevent log warning strategy "
                    Demobilizing $available undeployed {group:$g} personnel.
                " $g $a
                personnel demob $g $available
            }
        }

        # NEXT, save data back to the persistent tables
        rdb eval {
            DELETE FROM personnel_g;
            INSERT INTO personnel_g(g,personnel)
            SELECT g,personnel FROM working_personnel;
            
            DELETE FROM deploy_ng;
            INSERT INTO deploy_ng(n,g,personnel,unassigned)
            SELECT n,g,personnel,unassigned FROM working_deployment;
        }
    }

    # LogDeploymentChanges
    #
    # Logs all deployment changes.

    typemethod LogDeploymentChanges {} {
        rdb eval {
            SELECT OLD.n                         AS n,
                   OLD.g                         AS g,
                   OLD.personnel                 AS old,
                   NEW.personnel                 AS new,
                   NEW.personnel - OLD.personnel AS delta,
                   A.a                           AS a
            FROM deploy_ng AS OLD
            JOIN working_deployment AS NEW USING (n,g)
            JOIN agroups AS A USING (g)
            WHERE delta != 0
            ORDER BY g, delta ASC
        } {
            if {$new == 0 && $old > 0} {
                sigevent log 1 strategy "
                    Actor {actor:$a} withdrew all $old {group:$g} 
                    personnel from {nbhood:$n}.
                " $a $g $n

                continue
            }

            if {$delta > 0} {
                sigevent log 1 strategy "
                    Actor {actor:$a} added $delta {group:$g} personnel 
                    to {nbhood:$n}, for a total of $new personnel.
                " $a $g $n
            } elseif {$delta < 0} {
                let delta {-$delta}

                sigevent log 1 strategy "
                    Actor {actor:$a} withdrew $delta {group:$g} personnel 
                    from {nbhood:$n} for a total of $new personnel.
                " $a $g $n
            }
        }
    }

    # attrit n g casualties
    #
    # n            - A neighborhood
    # g            - A FRC/ORG group
    # casualties   - The number of casualties
    #
    # Updates deploy_ng and personnel_g given the casualties.  If
    # casualties is negative, personnel are returned.

    typemethod attrit {n g casualties} {
        # FIRST, get the undo information
        set deployed [rdb onecolumn {
            SELECT personnel FROM deploy_ng
            WHERE n=$n AND g=$g
        }]

        if {$casualties > 0} {
            # Can't kill more than are there.
            let casualties {min($casualties,$deployed)}
        } else {
            # We're putting people back.
            # Nothing to do.
        }
        
        # We undo by putting the same number of people back.
        let undoCasualties {-$casualties}
        
        # NEXT, Update the group
        rdb eval {
            UPDATE deploy_ng
            SET personnel = personnel - $casualties
            WHERE n=$n AND g=$g;

            UPDATE personnel_g
            SET personnel = personnel - $casualties
            WHERE g=$g
        } {}
    }
}



