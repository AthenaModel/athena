#-----------------------------------------------------------------------
# TITLE:
#    aam.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Athena Attrition Model manager
#
#    This module is responsible for computing and applying attrition
#    to units and neighborhood groups.
#
#    As attrition tactics execute, a list of attrition dictionaries
#    is accumulated by this module.  When the assess method is called
#    the attrition data is extracted from this list and applied.  For 
#    civilian casualties, satisfaction and cooperation dictionaries 
#    are built up and then passed into the CIVCAS rule set where the 
#    effects are applied.
#
#    The satisfaction and cooperation dictionaries are entirely 
#    transient. They only exist for the purpose of storing the data 
#    needed by the CIVCAS rule set.  The dictionaries are created, 
#    used and deleted within the assess method.
#
# Global references: demog, unit, group, personnel, ptype
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Module Singleton

snit::type ::athena::aam {
    #-------------------------------------------------------------------
    # Components

    component adb  ;# the athenadb(n) instance

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance
    #
    # Initializes instances of this type

    constructor {adb_} {
        set adb $adb_
    }

    #------------------------------------------------------------------
    # Variables

    variable alist {} ;# list of attrition dictionaries
    variable sdict    ;# dict used to assess SAT effects
    variable cdict    ;# dict used to assess COOP effects
    variable roedict  ;# array of dicts used to store ROE tactic information

    #-------------------------------------------------------------------
    # reset

    method reset {} {
        set alist ""
        set sdict ""
        set cdict ""
        array unset roedict
    }

    method start {} {
        $self ComputeEffectiveForce
    }

    method ComputeEffectiveForce {} {
        foreach {dem trn ft urb pers n g} [$adb eval {
            SELECT F.demeanor      AS demeanor,
                   F.training      AS training,
                   F.forcetype     AS forcetype,
                   N.urbanization  AS urb,
                   D.personnel     AS personnel,
                   D.n             AS n,
                   D.g             AS g
            FROM gui_frcgroups AS F
            JOIN deploy_ng     AS D ON (D.g=F.g)
            JOIN nbhoods       AS N ON (D.n=N.n)
            WHERE D.personnel > 0
        }] {
            set Fd [$adb parm get aam.FRC.demeanor.$dem]
            set Ff [$adb parm get aam.FRC.forcetype.$ft]
            set Ft [$adb parm get aam.FRC.discipline.$trn]

            let eff_pers {entier(ceil($Fd * $Ft * $Ff * $pers))}

            $adb eval {
                UPDATE deploy_ng
                SET eff_personnel=$eff_pers
                WHERE n=$n AND g=$g
            }

        }
    }

    #-------------------------------------------------------------------
    # Attrition Assessment

    # assess
    #
    # This routine is to be called every tick to do the 
    # attrition assessment.

    method assess {} {
         $adb log normal aam "assess"

        # FIRST, create SAT and COOP dicts to hold transient data
        set sdict [dict create]
        set cdict [dict create]

        # NEXT, Apply all saved magic attrition. This updates 
        # units and deployments, and accumulates all civilian 
        # attrition as input to the CIVCAS rule set.
        $self ApplyAttrition

        # NEXT, assess the attitude implications of all attrition for
        # this tick.
        $adb ruleset CIVCAS assess $sdict $cdict

        # NEXT, clear the saved data for this tick; we're done.
        set alist ""
        set sdict ""
        set cdict ""
        array unset roedict
    }

    #-------------------------------------------------------------------
    # ROE Tactic API 

    # setroe n g rdict
    #
    # n       - a neighborhood in which g assumes an ROE
    # g       - a force group assuming the ROE
    # rdict   - dictionary of ROE key/values
    #
    # rdict contains the following data related to how g should conduct
    # itself while in combat against other force groups in n:
    #
    #    $f  => dictionary of ROE data for the FRC group g is engaging
    #        -> roe => the ROE $g is attempting with $f: ATTACK or DEFEND
    #        -> athresh => the force/enemy ratio below which $g DEFENDs
    #        -> dthresh => the force/enemy ratio below which $g WITHDRAWs
    #        -> civc => $g's concern for civilian casualties
    #
    # The data in this array of dictionaries is used to set up the initial
    # conditions of the various conflicts between FRC groups by neighborhood.
    # It should be noted that just because a FRC group is ordered to assume
    # a posture via the ROE, that posture may not be attainable due to
    # the computed force ratios.

    method setroe {n g rdict} {
        dict set roedict($n) $g $rdict 
    }

    # hasroe n g f
    #
    # n   - a neighborhood
    # g   - a force group
    # f   - other force group
    #
    # This method returns a flag indicating whether g has an ROE already
    # set against g in n.  This is used during ROE tactic execution to
    # determine whether an ROE has already been set and, therefore, cannot
    # be overridden.

    method hasroe {n g f} {
        if {![info exists roedict($n)]} {
            return 0
        }

        return [dict exists $roedict($n) $g $f]
    }

    # getroe
    #
    # Returns the roedict as a dictionary

    method getroe {} {
        return [array get roedict]
    }

    #-------------------------------------------------------------------
    # Attrition, from ATTRIT tactic
    # TBD: Use this with AAM combat? (mode always GROUP)
    
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

    method attrit {parmdict} {
        lappend alist $parmdict
    }

    #-------------------------------------------------------------------
    # Apply Attrition
    
    # ApplyAttrition
    #
    # Applies the attrition from magic attrition and then that
    # accumulated by the normal attrition algorithms.

    method ApplyAttrition {} {
        # FIRST, apply the magic attrition
        foreach adict $alist {
            dict with adict {}
            switch -exact -- $mode {
                NBHOOD {
                    $self AttritNbhood $n $casualties $g1 $g2
                }

                GROUP {
                    $self AttritGroup $n $f $casualties $g1 $g2
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

    method AttritGroup {n f casualties g1 g2} {
         $adb log normal aam "AttritGroup $n $f $casualties $g1 $g2"

        # FIRST, determine the set of units to attrit.
        $adb eval {
            UPDATE units
            SET attrit_flag = 0;

            UPDATE units
            SET attrit_flag = 1
            WHERE n=$n 
            AND   g=$f
            AND   personnel > 0
        }

        # NEXT, attrit the units
        $self AttritUnits $casualties $g1 $g2

        # NEXT, attrit FRC/ORG deployments.
        if {[$adb group gtype $f] in {FRC ORG}} {
            $self AttritDeployments $n $f $casualties
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

    method AttritNbhood {n casualties g1 g2} {
         $adb log normal aam "AttritNbhood $n $casualties $g1 $g2"

        # FIRST, determine the set of units to attrit (all
        # the CIV units in the neighborhood).
        $adb eval {
            UPDATE units
            SET attrit_flag = 0;

            UPDATE units
            SET attrit_flag = 1
            WHERE n=$n 
            AND   gtype='CIV'
            AND   personnel > 0
        }

        # NEXT, attrit the units
        $self AttritUnits $casualties $g1 $g2
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

    method AttritUnits {casualties g1 g2} {
        # FIRST, determine the number of personnel in the attrited units
        set total [$adb eval {
            SELECT total(personnel) FROM units
            WHERE attrit_flag
        }]

        # NEXT, compute the actual number of casualties.
        let actual {min($casualties, $total)}

        if {$actual == 0} {
             $adb log normal aam \
                "Overkill; no casualties can be inflicted."
            return 
        } elseif {$actual < $casualties} {
             $adb log normal aam \
                "Overkill; only $actual casualties can be inflicted."
        }
        
        # NEXT, apply attrition to the units, in order of size.
        set remaining $actual

        $adb eval {
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

            $self AttritUnit [array get row]

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
 
    method AttritUnit {parmdict} {
        dict with parmdict {}

        # FIRST, log the attrition
        let personnel {$personnel - $casualties}

         $adb log normal aam \
          "Unit $u takes $casualties casualties, leaving $personnel personnel"
            
        # NEXT, update the unit.
        $adb unit personnel $u $personnel

        # NEXT, if this is a CIV unit, attrit the unit's
        # group.
        if {$gtype eq "CIV"} {
            # FIRST, attrit the group 
            $adb demog attrit $g $casualties

            # NEXT, save the attrition for attitude assessment
            $self SaveCivAttrition $parmdict
        } else {
            # FIRST, It's a force or org unit.  Attrit its pool in
            # its neighborhood.
            $adb personnel attrit $n $g $casualties
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

    method AttritDeployments {n g casualties} {
        # FIRST, determine the number of personnel in the attrited units
        set total [$adb eval {
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

        foreach {tactic_id personnel share} [$adb eval {
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
            $adb eval {
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
    
    # SaveCivAttrition parmdict
    #
    # parmdict contains the following keys/data:
    #
    # n           The neighborhood in which the attrition took place.
    # g           The CIV group receiving the attrition
    # casualties  The number of casualties
    # g1          A responsible force group, or ""
    # g2          A responsible force group, g2 != g1, or ""
    #
    # Accumulates the attrition for later attitude assessment.

    method SaveCivAttrition {parmdict} {
        dict with parmdict {}

        # FIRST, accumulate by CIV group for SAT effects
        if {![dict exists $sdict $g]} {
            dict set sdict $g 0
        }

        let sum {[dict get $sdict $g] + $casualties}
        dict set sdict $g $sum

        # NEXT, accumulate by CIV and FRC group for COOP effects
        if {$g1 ne ""} {
            if {![dict exists cdict "$g $g1"]} {
                dict set cdict "$g $g1" 0
            }

            let sum {[dict get $cdict "$g $g1"] + $casualties}
            dict set cdict "$g $g1" $sum
        }

        if {$g2 ne ""} {
            if {![dict exists cdict "$g $g2"]} {
                dict set cdict "$g $g2" 0
            }

            let sum {[dict get $cdict "$g $g2"] + $casualties}
            dict set cdict "$g $g2" $sum
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

    method AllButG1 {g1} {
        set groups [ptype frcg+none names]
        ldelete groups $g1

        return $groups
    }
}



