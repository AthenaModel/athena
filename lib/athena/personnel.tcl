#-----------------------------------------------------------------------
# TITLE:
#   personnel.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n) Tactic API: Personnel Manager
#
#   This module is responsible for managing the deployment of 
#   FRC and ORG personnel in neighborhoods and the assignment of
#   activities to deployed personnel, and the flow of population
#   from one civilian group to another, during strategy execution.
#
# TBD: Global refs: unit, parm, sigevent
#
#-----------------------------------------------------------------------

snit::type ::athena::personnel {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Instance Variables

    # Pending population flows (transient)
    variable pendingFlows {}
    

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

    #-------------------------------------------------------------------
    # Simulation 

    # start
    #
    # This routine is called when the scenario is locked and the 
    # simulation starts.  It populates the personnel_g and deploy_ng
    # tables.

    method start {} {
        # FIRST, populate the personnel_g and deploy_ng tables from
        # the status quo FRC/ORG deployments.
        $adb eval {
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

    method load {} {
        # FIRST, prepare the working tables for force/org personnel.
        $adb eval {
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

        # NEXT, prepare to receive civilian population flows
        set pendingFlows [list]
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

    method deploy {tactic_id n g personnel} {
        set available [$adb onecolumn {
            SELECT available FROM working_personnel WHERE g=$g
        }]

        require {$personnel > 0} \
            "Attempt to deploy negative personnel: $personnel"

        require {$personnel <= $available} \
            "Insufficient personnel available: $personnel > $available"

        $adb eval {
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

    method inplaybox {g} {
        $adb onecolumn {SELECT personnel FROM working_personnel WHERE g=$g}
    }

    # available g
    #
    # g  - A force or ORG group
    #
    # Retrieves the number of personnel available for deployment.

    method available {g} {
        $adb eval {
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

    method unassigned {n g} {
        $adb eval {
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

    method demob {g personnel} {
        set available [$adb onecolumn {
            SELECT available FROM working_personnel WHERE g=$g
        }]

        require {$personnel <= $available} \
            "Insufficient personnel available: $personnel > $available"

        $adb eval {
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

    method mobilize {g personnel} {
        $adb eval {
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

    method assign {tactic_id g n a personnel} {
        # FIRST, ensure that enough personnel remain.
        set unassigned [$self unassigned $n $g]

        require {$personnel <= $unassigned} \
            "Insufficient unassigned personnel: $personnel > $unassigned"
        
        # NEXT, allocate the personnel.
        $adb eval {
            UPDATE working_deployment
            SET unassigned = unassigned - $personnel
            WHERE n=$n AND g=$g
        }

        # NEXT, assign the tactic unit to this activity.
        return [unit assign $tactic_id $g $n $a $personnel]
    }

    # flow f g delta
    #
    # f          - The source group
    # g          - The destination group
    # personnel  - The number of people to move
    #
    # Saves the pending flow until later.

    method flow {f g delta} {
        lappend pendingFlows $f $g $delta
    }

    # pendingFlows
    #
    # Returns the list of pending flows.

    method pendingFlows {} {
        return $pendingFlows
    }

    # save
    #
    # Saves the working data back to the persistent tables.  In particular,
    # 
    # * Deployment changes are logged.
    # * Undeployed troops are demobilized (if strategy.autoDemob is set)
    # * Force levels and deployments are saved.

    method save {} {
        # FIRST, log all changed deployments.
        $self LogDeploymentChanges

        # NEXT, Demobilize undeployed troops
        if {[parm get strategy.autoDemob]} {
            foreach {g available a} [$adb eval {
                SELECT g, available, a 
                FROM working_personnel
                JOIN agroups USING (g) 
                WHERE available > 0
            }] {
                sigevent log warning strategy "
                    Demobilizing $available undeployed {group:$g} personnel.
                " $g $a
                $self demob $g $available
            }
        }

        # NEXT, save data back to the persistent tables
        $adb eval {
            DELETE FROM personnel_g;
            INSERT INTO personnel_g(g,personnel)
            SELECT g,personnel FROM working_personnel;
            
            DELETE FROM deploy_ng;
            INSERT INTO deploy_ng(n,g,personnel,unassigned)
            SELECT n,g,personnel,unassigned FROM working_deployment;
        }

        # NEXT, save pending civilian flows
        foreach {f g delta} $pendingFlows {
            $adb demog flow $f $g $delta
        }

        set pendingFlows [list]
    }

    # LogDeploymentChanges
    #
    # Logs all deployment changes.

    method LogDeploymentChanges {} {
        $adb eval {
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

    method attrit {n g casualties} {
        # FIRST, get the undo information
        set deployed [$adb onecolumn {
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
        $adb eval {
            UPDATE deploy_ng
            SET personnel = personnel - $casualties
            WHERE n=$n AND g=$g;

            UPDATE personnel_g
            SET personnel = personnel - $casualties
            WHERE g=$g
        } {}
    }
}



