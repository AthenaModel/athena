#-----------------------------------------------------------------------
# TITLE:
#    aam.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Athena Attrition Model
#
#    This module is responsible for computing and applying attritions
#    to units and neighborhood groups.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Module Singleton

snit::type aam {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Attrition Assessment

    # assess
    #
    # This routine is to be called every tick to do the 
    # attrition assessment.

    typemethod assess {} {
        log normal aam "assess"

        # FIRST, Apply all saved magic attrition from the
        # magic_attrit table.  This updates units and deployments,
        # and accumulates all civilian attrition as input to the
        # CIVCAS rule set.
        $type ApplyAttrition

        # NEXT, assess the attitude implications of all attrition for
        # this tick.
        driver::CIVCAS assess

        # NEXT, clear the saved data for this tick; we're done.
        $type ClearPendingdAta
    }


    # ClearPendingdAta
    #
    # Clears the tables used to store attrition for use in
    # assessing attitudinal effects.

    typemethod ClearPendingdAta {} {
        # FIRST, clear the accumulated attrition statistics, in preparation
        # for the next tock.
        rdb eval {
            DELETE FROM magic_attrit;
            DELETE FROM attrit_nf;
            DELETE FROM attrit_nfg;
        }
    }

    #-------------------------------------------------------------------
    # Magic attrition, from ATTRIT tactic
    

    # attrit parmdict
    #
    # parmdict
    # 
    # mode          Mode of attrition: GROUP or NBHOOD 
    # casualties    Number of casualties taken by GROUP or NBHOOD
    # n             The neighborhood 
    # f             The group if mode is GROUP
    # g1            Responsible force group, or ""
    # g2            Responsible force group, or ""
    # 
    # Adds a record to the magic attrit table for adjudication at the
    # next aam assessment.
    #
    # g1 and g2 are used only for attrition to a civilian group

    typemethod attrit {parmdict} {
        dict with parmdict {
            # FIRST add a record to the table
            rdb eval {
                INSERT INTO magic_attrit(mode,casualties,n,f,g1,g2)
                VALUES($mode,
                       $casualties,
                       $n,
                       nullif($f,  ''),
                       nullif($g1, ''),
                       nullif($g2, ''));
            }
        }
    }

    #-------------------------------------------------------------------
    # Apply Attrition
    
    # ApplyAttrition
    #
    # Applies the attrition from magic attrition and then that
    # accumulated by the normal attrition algorithms.

    typemethod ApplyAttrition {} {
        # FIRST, apply the magic attrition
        rdb eval {
            SELECT mode,
                   n,
                   f,
                   casualties,
                   g1,
                   g2
            FROM magic_attrit
        } {
            switch -exact -- $mode {
                NBHOOD {
                    $type AttritNbhood $n $casualties $g1 $g2
                }

                GROUP {
                    $type AttritGroup $n $f $casualties $g1 $g2
                }

                default {error "Unrecognized attrition mode: \"$mode\""}
            }
        }
    }

    # AttritGroup n f casualties g1 g2
    #
    # parmdict      Dictionary of order parms
    #
    #   n           Neighborhood in which attrition occurs
    #   f           Group taking attrition.
    #   casualties  Number of casualties taken by the group.
    #   g1          Responsible force group, or ""
    #   g2          Responsible force group, or "".
    #
    # Attrits the specified group in the specified neighborhood
    # by the specified number of casualties (all of which are kills).
    #
    # The group's units are attrited in proportion to their size.
    # For FRC/ORG groups, their deployments in deploy_tng are
    # attrited as well, to support deployment without reinforcement.
    #
    # g1 and g2 are used only for attrition to a civilian group.

    typemethod AttritGroup {n f casualties g1 g2} {
        log normal aam "AttritGroup $n $f $casualties $g1 $g2"

        # FIRST, determine the set of units to attrit.
        rdb eval {
            UPDATE units
            SET attrit_flag = 0;

            UPDATE units
            SET attrit_flag = 1
            WHERE n=$n 
            AND   g=$f
            AND   personnel > 0
        }

        # NEXT, attrit the units
        $type AttritUnits $casualties $g1 $g2

        # NEXT, attrit FRC/ORG deployments.
        if {[group gtype $f] in {FRC ORG}} {
            $type AttritDeployments $n $f $casualties
        }
    }

    # AttritNbhood n casualties g1 g2
    #
    # parmdict      Dictionary of order parms
    #
    #   n           Neighborhood in which attrition occurs
    #   casualties  Number of casualties taken by the group.
    #   g1          Responsible force group, or "".
    #   g2          Responsible force group, or "".
    #
    # Attrits all civilian units in the specified neighborhood
    # by the specified number of casualties (all of which are kills).
    # Units are attrited in proportion to their size.

    typemethod AttritNbhood {n casualties g1 g2} {
        log normal aam "AttritNbhood $n $casualties $g1 $g2"

        # FIRST, determine the set of units to attrit (all
        # the CIV units in the neighborhood).
        rdb eval {
            UPDATE units
            SET attrit_flag = 0;

            UPDATE units
            SET attrit_flag = 1
            WHERE n=$n 
            AND   gtype='CIV'
            AND   personnel > 0
        }

        # NEXT, attrit the units
        $type AttritUnits $casualties $g1 $g2
    }

    # AttritUnits casualties g1 g2
    #
    # casualties  Number of casualties taken by the group.
    # g1          Responsible force group, or "".
    # g2          Responsible force group, or "".
    #
    # Attrits the units marked with the attrition flag 
    # proportional to their size until
    # all casualites are inflicted or the units have no personnel.
    # The actual work is performed by AttritUnit.

    typemethod AttritUnits {casualties g1 g2} {
        # FIRST, determine the number of personnel in the attrited units
        set total [rdb eval {
            SELECT total(personnel) FROM units
            WHERE attrit_flag
        }]

        # NEXT, compute the actual number of casualties.
        let actual {min($casualties, $total)}

        if {$actual == 0} {
            log normal aam \
                "Overkill; no casualties can be inflicted."
            return 
        } elseif {$actual < $casualties} {
            log normal aam \
                "Overkill; only $actual casualties can be inflicted."
        }
        
        # NEXT, apply attrition to the units, in order of size.
        set remaining $actual

        rdb eval {
            SELECT u                                   AS u,
                   g                                   AS g,
                   gtype                               AS gtype,
                   personnel                           AS personnel,
                   n                                   AS n,
                   $actual*(CAST (personnel AS REAL)/$total) 
                                                       AS share
            FROM units
            WHERE attrit_flag
            ORDER BY share DESC
        } row {
            # FIRST, allocate the share to this body of people.
            let kills     {entier(min($remaining, ceil($row(share))))}
            let remaining {$remaining - $kills}

            # NEXT, compute the attrition.
            let take {entier(min($row(personnel), $kills))}

            # NEXT, attrit the unit
            set row(g1)         $g1
            set row(g2)         $g2
            set row(casualties) $take

            $type AttritUnit [array get row]

            # NEXT, we might have finished early
            if {$remaining == 0} {
                break
            }
        }
    }

    # AttritUnit parmdict
    #
    # parmdict      Dictionary of unit data, plus g1 and g2
    #
    # Attrits the specified unit by the specified number of 
    # casualties (all of which are kills); also decrements
    # the unit's staffing pool.  This is the fundamental attrition
    # routine; the others all flow down to this.
 
    typemethod AttritUnit {parmdict} {
        dict with parmdict {
            # FIRST, log the attrition
            let personnel {$personnel - $casualties}

            log normal aam \
          "Unit $u takes $casualties casualties, leaving $personnel personnel"
            
            # NEXT, update the unit.
            unit mutate personnel $u $personnel

            # NEXT, if this is a CIV unit, attrit the unit's
            # group.
            if {$gtype eq "CIV"} {
                # FIRST, attrit the group 
                demog attrit $g $casualties

                # NEXT, save the attrition for attitude assessment
                $type SaveCivAttrition $n $g $casualties $g1 $g2
            } else {
                # FIRST, It's a force or org unit.  Attrit its pool in
                # its neighborhood.
                personnel attrit $n $g $casualties
            }
        }

        return
    }

    # AttritDeployments n g casualties
    #
    # n           The neighborhood in which the attrition took place.
    # g           The FRC or ORG group that was attrited.
    # casualties  Number of casualties taken by the group.
    #
    # Attrits the deployment of the given group in the given neighborhood, 
    # spreading the attrition across all DEPLOY tactics active during
    # the current tick.
    #
    # This is to support DEPLOY without reinforcement.  The deploy_tng
    # table lists the actual troops deployed during the last
    # tick by each DEPLOY tactic, broken down by neighborhood and group.
    # This routine removes casualties from this table, so that the 
    # attrited troop levels can inform the next round of deployments.

    typemethod AttritDeployments {n g casualties} {
        # FIRST, determine the number of personnel in the attrited units
        set total [rdb eval {
            SELECT total(personnel) FROM deploy_tng
            WHERE n=$n AND g=$g
        }]

        # NEXT, compute the actual number of casualties.
        let actual {min($casualties, $total)}

        if {$actual == 0} {
            return 
        }

        # NEXT, apply attrition to the tactics, in order of size.
        set remaining $actual

        foreach {tactic_id personnel share} [rdb eval {
            SELECT tactic_id,
                   personnel,
                   $actual*(CAST (personnel AS REAL)/$total) AS share
            FROM deploy_tng
            WHERE n=$n AND g=$g
            ORDER BY share DESC
        }] {
            # FIRST, allocate the share to this body of troops.
            let kills     {entier(min($remaining, ceil($share)))}
            let remaining {$remaining - $kills}

            # NEXT, compute the attrition.
            let take {entier(min($personnel, $kills))}

            # NEXT, attrit the tactic's deployment.
            rdb eval {
                UPDATE deploy_tng
                SET personnel = personnel - $take
                WHERE tactic_id = $tactic_id AND n = $n AND g = $g
            }

            # NEXT, we might have finished early
            if {$remaining == 0} {
                break
            }
        }
    }
    
    # SaveCivAttrition n f casualties g1 g2
    #
    # n           The neighborhood in which the attrition took place.
    # f           The CIV group receiving the attrition
    # casualties  The number of casualties
    # g1          A responsible force group, or ""
    # g2          A responsible force group, g2 != g1, or ""
    #
    # Accumulates the attrition for later attitude assessment.

    typemethod SaveCivAttrition {n f casualties g1 g2} {
        # FIRST, save nf casualties for satisfaction.
        rdb eval {
            INSERT INTO attrit_nf(n,f,casualties)
            VALUES($n,$f,$casualties);
        }

        # NEXT, save nfg casualties for cooperation
        if {$g1 ne ""} {
            rdb eval {
                INSERT INTO attrit_nfg(n,f,casualties,g)
                VALUES($n,$f,$casualties,$g1);
            }
        }

        if {$g2 ne ""} {
            rdb eval {
                INSERT INTO attrit_nfg(n,f,casualties,g)
                VALUES($n,$f,$casualties,$g2);
            }
        }

        return 
    }

    #-------------------------------------------------------------------
    # Tactic Order Helpers

    # AllButG1 g1
    #
    # g1 - A force group
    #
    # Returns a list of all force groups but g1 and puts "NONE" at the
    # beginning of the list.
    #
    # TBD: Should go in tactic_attrit.tcl

    typemethod AllButG1 {g1} {
        set groups [ptype frcg+none names]
        ldelete groups $g1

        return $groups
    }
}



