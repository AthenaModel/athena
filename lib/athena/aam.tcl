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

    variable alist {}   ;# list of attrition dictionaries
    variable sdict      ;# dict used to assess SAT effects
    variable cdict      ;# dict used to assess COOP effects
    variable roedict    ;# array of dicts used to store ROE tactic information

    # Transient combat variables
    #
    # frcMultD   -  force mult denominator, same for all force groups
    variable frcmultD 

    # Transient arrays
    #
    # effFrc(n,g)     - effective force for group g in n
    # frcMult(n,g)    - force multiplier for group g in n
    # civcasMult(n,g) - civilian casualties multiplier for group g
    # aThresh(n,f,g)  - ATTACK force ratio threshold of f with g in n
    # dThresh(n,f,g)  - DEFEND force ratio threshold of f with g in n
    # civconc(n,f,g)  - Concern for CIVCAS by f against g in n

    variable effFrc     -array {}
    variable frcMult    -array {}
    variable civcasMult -array {}
    variable aThresh    -array {}
    variable dThresh    -array {}
    variable civconc    -array {}

    #-------------------------------------------------------------------
    # reset

    method reset {} {
        set alist ""
        set sdict ""
        set cdict ""
        array unset roedict
        array unset effFrc
        array unset frcMult
        array unset civcasMult
        array unset aThresh
        array unset dThresh
        array unset civconc
    }

    method start {} {
        # FIRXT, compute force group multiplier denominator
        set urb   [$adb parm get aam.FRC.urbcas.URBAN]
        set civc  [$adb parm get aam.FRC.civconcern.NONE]
        set elvl  [$adb parm get aam.FRC.equiplevel.BEST]
        set ftype [$adb parm get aam.FRC.forcetype.REGULAR]
        set tlvl  [$adb parm get aam.FRC.discipline.PROFICIENT]
        set dem   [$adb parm get aam.FRC.demeanor.AVERAGE]
        
        let frcmultD {$urb * $civc * $elvl * $ftype * $tlvl * $dem}
    }

    #-------------------------------------------------------------------
    # Attrition Assessment

    # assess
    #
    # This routine is to be called every tick to do the 
    # attrition assessment.

    method assess {} {
         $adb log normal aam "assess"

        # FIRST, clear out temporary table 
        $adb eval {
            DELETE FROM working_force;
        }

        # NEXT, clear transient combat data
        array unset effFrc
        array unset frcMult
        array unset civcasMult
        array unset aThresh
        array unset dThresh
        array unset civconc

        # NEXT, create SAT and COOP dicts to hold transient effects data
        set sdict [dict create]
        set cdict [dict create]

        # NEXT, force on force combat and collateral civilian casualties
        if {[$adb parm get aam.maxCombatTimeHours] > 0} {
            $self ComputeEffectiveForce
            $self BuildWorkingCombatData
            $self AllocateForce
            $self DoGroupCombat
        }

        # NEXT, Apply all combat attrition and saved magic attrition. 
        # This updates units and deployments, and accumulates all civilian 
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

    # ComputeEffectiveForce
    #
    # This method computes a deployed force groups effective force
    # based on it's makeup.  For example, highly disciplined regular 
    # forces with the best equipment will project more force than 
    # poorly trained irregular forces with poor equipment.

    method ComputeEffectiveForce {} {
        foreach {elvl tlvl frctype dem urb pers n g} [$adb eval {
            SELECT F.equip_level   AS equip_level,
                   F.training      AS training,
                   F.forcetype     AS forcetype,
                   F.demeanor      AS demeanor,
                   N.urbanization  AS urb,
                   D.personnel     AS personnel,
                   D.n             AS n,
                   D.g             AS g
            FROM gui_frcgroups AS F
            JOIN deploy_ng     AS D ON (D.g=F.g)
            JOIN nbhoods       AS N ON (D.n=N.n)
            WHERE D.personnel > 0
        }] {
            set Fe [$adb parm get aam.FRC.equiplevel.$elvl]
            set Ff [$adb parm get aam.FRC.forcetype.$frctype]
            set Ft [$adb parm get aam.FRC.discipline.$tlvl]
            set Fd [$adb parm get aam.FRC.demeanor.$dem]
            set Fu [$adb parm get aam.FRC.urbcas.$urb]

            let effFrc($n,$g)  {entier(ceil($Fe * $Ff * $Ft * $Fd * $pers))}
            let frcMult($n,$g) {$Fe * $Ff * $Ft * $Fd * $Fu}
        }
    }

    # BuildWorkingCombatData
    #
    # This method builds the working combat table based on deployments.
    # Default ROEs, thresholds and postures are set for those groups
    # that have not explictly been given them via an actor's strategy.

    method BuildWorkingCombatData {} {
        # FIRST, get max combat time for this week
        set hours [$adb parm get aam.maxCombatTimeHours]

        # NEXT, fill in the working combat table based on
        # deployments
        foreach {n f pers_f} [$adb eval {
            SELECT n,g,personnel FROM deploy_ng 
            WHERE personnel > 0
        }] {
            # NEXT, only care about FRC groups
            if {$f ni [$adb frcgroup names]} {
                continue
            }           

            # NEXT, groups in n other than f
            foreach {g pers_g} [$adb eval {
                SELECT g,personnel FROM deploy_ng 
                WHERE n=$n AND personnel > 0 AND g!=$f
            }] {

                # NEXT, only care about FRC groups
                if {$g ni [$adb frcgroup names]} {
                    continue
                }

                # NEXT, skip if we already have data for g->f 
                if {[info exists dThresh($n,$g,$f)]} {
                    continue
                }

                # NEXT, defaults for f->g in case no ROE specified
                set roeF  "DEFEND"
                set athrF 0.0
                set dthrF 0.15
                set civcF "HIGH"

                # NEXT, pull data from ROE dict, if it's there 
                if {[info exists roedict($n)] && 
                    [dict exists $roedict($n) $f $g]} {
                    set roeF  [dict get $roedict($n) $f $g roe]
                    set athrF [dict get $roedict($n) $f $g athresh]
                    set dthrF [dict get $roedict($n) $f $g dthresh]
                    set civcF [dict get $roedict($n) $f $g civc]
                }

                # NEXT, defaults for g->f in case no ROE specified
                set roeG  "DEFEND"
                set athrG 0.0
                set dthrG 0.15
                set civcG "HIGH"

                # NEXT, pull data from ROE dict, if it's there 
                if {[info exists roedict($n)] && 
                    [dict exists $roedict($n) $g $f]} {
                    set roeG  [dict get $roedict($n) $g $f roe]
                    set athrG [dict get $roedict($n) $g $f athresh]
                    set dthrG [dict get $roedict($n) $g $f dthresh]
                    set civcG [dict get $roedict($n) $g $f civc]
                }

                # NEXT, compute force ratios used for determining posture
                # later 
                let frcRatio {
                    (double($effFrc($n,$g))/double($pers_g)) / 
                    (double($effFrc($n,$f))/double($pers_f))
                }

                # f -> g
                let aThresh($n,$f,$g) {$athrF * $frcRatio}
                let dThresh($n,$f,$g) {$dthrF * $frcRatio}
                set civconc($n,$f,$g) $civcF

                # g -> f
                let aThresh($n,$g,$f) {$athrG * $frcRatio}
                let dThresh($n,$g,$f) {$dthrG * $frcRatio}
                set civconc($n,$g,$f) $civcG
                
                # NEXT, add to the working force table
                $adb eval {
                    INSERT INTO working_force(n,f,g,pers_f,pers_g,
                                              roe_f,roe_g,hours_left)
                    VALUES($n,$f,$g,$pers_f,$pers_g,$roeF,$roeG,$hours)
                }
            }
        }
    }

    # AllocateForce
    #
    # This method determines how many personnel in force group f
    # should be allocated against force group g where either f is
    # attacking g or g is attacking f (or both).  Allocation is based
    # upon how much force is projected by the groups involved in combat.

    method AllocateForce {} {
        # FIRST, go through the working combat table looking for groups
        # that could possibly be in combat
        foreach {n f g} [$adb eval {
            SELECT n,f,g FROM working_force
            WHERE roe_f = 'ATTACK' OR roe_g = 'ATTACK'
        }] {
            # NEXT, compute total effective force from f's point of view
            # Those g's that f is attacking
            set totalEffFrcG 0.0

            foreach grp [$adb eval {
                SELECT g FROM working_force
                WHERE n=$n AND f=$f AND roe_f='ATTACK'
            }] {
                let totalEffFrcG {$totalEffFrcG + $effFrc($n,$grp)}
            }

            # Those g's attacking f 
            set totalEffFrcF 0.0
            foreach grp [$adb eval {
                SELECT g FROM working_force
                WHERE n=$n AND f=$f AND roe_g='ATTACK'
            }] {
                let totalEffFrcF {$totalEffFrcF + $effFrc($n,$grp)}
            }

            let fracF {$effFrc($n,$g) / ($totalEffFrcG + $totalEffFrcF)}

            # NEXT, compute total effective force from g's point of view
            # Those g is attacking
            set totalEffFrcF 0.0
            foreach grp [$adb eval {
                SELECT f FROM working_force
                WHERE n=$n AND g=$g AND roe_g='ATTACK'
            }] {
                let totalEffFrcF {$totalEffFrcF + $effFrc($n,$grp)}
            }

            # Those attacking g
            set totalEffFrcG 0.0

            foreach grp [$adb eval {
                SELECT f FROM working_force
                WHERE n=$n AND g=$g AND roe_f='ATTACK'
            }] {
                let totalEffFrcG {$totalEffFrcG + $effFrc($n,$grp)}
            }

            let fracG {$effFrc($n,$f) / ($totalEffFrcG + $totalEffFrcF)}

            # NEXT, allocate personnel based on effective force
            $adb eval {
                UPDATE working_force
                SET dpers_f = CAST(round(pers_f*$fracF) AS INTEGER),
                    dpers_g = CAST(round(pers_g*$fracG) AS INTEGER)
                WHERE n=$n AND f=$f AND g=$g
            }               
        }
    }

    # SetGroupPosture
    #
    # Based on designated personnel, ordered ROE and force/enemy ratios,
    # this method sets group posture for each group in the working force
    # table involved in combat

    method SetGroupPosture {} {
        foreach {n f g DPf DPg roeF roeG} [$adb eval {
            SELECT n,f,g,dpers_f,dpers_g,roe_f,roe_g 
            FROM working_force
            WHERE dpers_f > 0 AND dpers_g > 0
        }] {
            let DPf {double($DPf)}
            let DPg {double($DPg)}

            # FIRST, f's posture towards g, ATTACK only if ordered
            set posture_f "DEFEND"

            if {$DPf/$DPg >= $aThresh($n,$f,$g) && $roeF eq "ATTACK"} {
                set posture_f "ATTACK"
            } elseif {$DPf/$DPg < $dThresh($n,$f,$g)} {
                set posture_f "WITHDRAW"
            } 

            # NEXT, g's posture towards f, ATTACK only if ordered
            set posture_g "DEFEND"

            if {$DPg/$DPf >= $aThresh($n,$g,$f) && $roeG eq "ATTACK"} {
                set posture_g "ATTACK"
            } elseif {$DPg/$DPf < $dThresh($n,$g,$f)} {
                set posture_g "WITHDRAW"
            } 

            # NEXT, set posture in the adb
            $adb eval {
                UPDATE working_force
                SET posture_f = $posture_f,
                    posture_g = $posture_g
                WHERE n=$n AND f=$f AND g=$g
            }
        }
    }

    # DoGroupCombat
    #
    # Updates force allocation based on ROEs and computes attrition to
    # force groups and civilian groups.

    method DoGroupCombat {} {
        set moreCombat 1
        while {$moreCombat} {
            $self SetGroupPosture   
            set moreCombat [$self ComputeForceGroupAttrition]
        }

        # NEXT, assess casualties to force groups 
        $adb eval {
            SELECT n, f, g, cas_f, cas_g FROM working_force
            WHERE cas_f > 0 OR cas_g > 0
        } {
            set parmdict [dict create]
            dict set parmdict mode GROUP
            dict set parmdict g1 ""
            dict set parmdict g2 ""

            if {$cas_f > 0} {
                dict set parmdict casualties $cas_f
                dict set parmdict n $n
                dict set parmdict f $f
                $self attrit $parmdict
            }

            if {$cas_g > 0} {
                dict set parmdict casualties $cas_g
                dict set parmdict n $n
                dict set parmdict f $g
                $self attrit $parmdict                
            }
        }

        # NEXT, assess civilian casualties due to force group combat
        $self ComputeCivilianCasualties
    }


    # ComputeForceGroupAttrition
    #
    # This method goes through the working force table and computes
    # the amount of time two combatant fight based on postures and 
    # Lanchester attrition rates.  This time is used to compute the
    # number of casualties each side of a force on force fight
    # takes and updates the number of personnel engaged in combat.  
    # A flag indicating whether there is more fighting to be done is
    # returned.  Fighting ceases under these conditions:
    #
    #    * All personnel on one side are killed
    #    * Both force groups assume a posture for which fighting ceases
    #    * The amount of time exceeds the amount of time allocated for combat
    #
    # This method will return 1 if there is at least one pair of combatants
    # that do NOT meet any of these conditions and 0 otherwise.

    method ComputeForceGroupAttrition {} { 
        # FIRST, initialize transient combat outcome data
        set outcome [list] 

        # NEXT, go through active combat and assess
        $adb eval {
            SELECT n,f,g,posture_f,posture_g,dpers_f,dpers_g,
                   roe_f,hours_left
            FROM working_force
            WHERE dpers_f > 0 AND dpers_g > 0 AND hours_left > 0 
        } {
            # NEXT, get model parameter Lanchester coefficients 
            set afg [$adb parm get aam.lc.$posture_f.$posture_g]
            set agf [$adb parm get aam.lc.$posture_g.$posture_f]

            # NEXT, no assessment if no casualties will take place
            if {$afg == 0.0 && $agf == 0.0} {
                continue
            }

            # NEXT, combat time depends on posture and force ratio
            # thresholds
            set Rfg $aThresh($n,$f,$g)

            if {$posture_f eq "DEFEND"} {
                set Rfg $dThresh($n,$f,$g)
            } elseif {$posture_f eq "WITHDRAW"} {
                set Rfg 0.0
            }

            set Rgf $aThresh($n,$g,$f)

            if {$posture_g eq "DEFEND"} {
                set Rgf $dThresh($n,$g,$f)
            } elseif {$posture_g eq "WITHDRAW"} {
                set Rgf 0.0
            }

            # Coefficient multipliers for Afg
            set civc $civconc($n,$f,$g)
            set Fc [$adb parm get aam.FRC.civconcern.$civc]
            let Afg {$afg * $Fc * $frcMult($n,$f) / $frcmultD}

            set civc $civconc($n,$g,$f)
            # Coefficient multipliers for Agf
            set Fc [$adb parm get aam.FRC.civconcern.$civc]
            let Agf {$agf * $Fc * $frcMult($n,$g) / $frcmultD}

            # NEXT, populate transient input data for computing
            # casualties and time of combat 
            set idata(Afg)   $Afg
            set idata(Agf)   $Agf
            set idata(Rfg)   $Rfg
            set idata(Rgf)   $Rgf
            set idata(DPf)   $dpers_f
            set idata(DPg)   $dpers_g
            set idata(Tleft) $hours_left

            lassign [$self ComputeForceGroupCasualties [array get idata]] \
                PRf PRg t

            # NEXT, minumum casualty of 1 for the attacker. If both
            # have an ATTACK ROE, arbitrarily choose f. This prevents
            # force ratios from becoming unchanged if there are two
            # evenly matched, small force groups where one is very close to a 
            # posture change and the minimum fight time is not enough to 
            # change that.
            let casF {max(0,$dpers_f - $PRf)}
            let casG {max(0,$dpers_g - $PRg)}

            if {$roe_f eq "ATTACK"} {
                let casF {max(1,$casF)}
            } else {
                let casG {max(1,$casG)}
            }

            # NEXT, store combat outcome data for later
            # adjudication
            lappend outcome $n $f $g $casF $casG $t
        }

        # NEXT adjudicate the outcome of any fighting
        foreach {n f g casF casG t} $outcome {
            $adb eval {
                UPDATE working_force
                SET cas_f      = cas_f+$casF,
                    cas_g      = cas_g+$casG,
                    pers_f     = pers_f-$casF,
                    pers_g     = pers_g-$casG,
                    dpers_f    = dpers_f-$casF,
                    dpers_g    = dpers_g-$casG,
                    hours_left = max(0.0, hours_left-$t)
                WHERE n=$n AND f=$f AND g=$g            
            }
        }

        # NEXT, indicate more combat possible if fighting occurred
        if {[llength $outcome] > 0} {
            return 1
        }

        # NEXT, combat is done 
        return 0
    }

    # ComputeForceGroupCasualties tdata
    #
    # tdata   - dictionary of transient data
    #
    # This method takes the contents of the supplied dictionary and
    # computes the number of casualties taken by one or two sides involved in
    # combat.  It returns, in a list, the number of personnel remaining in
    # the first group, number of personnel remaining in the second group 
    # and the amount of time expended during combat.

    method ComputeForceGroupCasualties {tdata} {
        dict with tdata {}

        # FIRST, if Afg and Agf are non-zero we need to compute
        # the constants C1 and C2 that will determine the combat time
        if {$Afg > 0.0 && $Agf > 0.0} {
            let rootA {sqrt($Agf*$Afg)}

            # NEXT, combat time constants
            let C1 {0.5 * (($DPf/sqrt($Agf)) - ($DPg/sqrt($Afg)))}
            let C2 {0.5 * (($DPf/sqrt($Agf)) + ($DPg/sqrt($Afg)))}

            # NEXT, handle the case where C1 is 0.0, which means that
            # fighting time should be the time remaining
            if {$C1 == 0.0} {
                set t $Tleft
            } elseif {$C2/$C1 < 0.0} {
                let Larg {
                    $C2/$C1*($Rfg*sqrt($Afg) - sqrt($Agf)) /
                            ($Rfg*sqrt($Afg) + sqrt($Agf))
                }

                let t {0.5/$rootA * log($Larg)}
            } else {
                let Larg {
                    $C2/$C1*(sqrt($Afg) - $Rgf*sqrt($Agf)) /
                            (sqrt($Afg) + $Rgf*sqrt($Agf))

                }

                let t {0.5/$rootA * log($Larg)}
            }

            # NEXT, conbat time cannot exceed time left 
            let t {min($t,$Tleft)}

            # NEXT, personnel remaining, protect against negative personnel
            let PRf {max(0,
                entier(floor($C1*sqrt($Agf)*exp($rootA*$t) +
                             $C2*sqrt($Agf)*exp(-$rootA*$t))))
            }

            let PRg {max(0,
                entier(floor(-1.0*$C1*sqrt($Afg)*exp($rootA*$t) +
                                  $C2*sqrt($Afg)*exp(-$rootA*$t))))
            }        
        } elseif {$Agf > 0.0} {
            # NEXT, Afg is 0.0; only f suffers casualties
            let t {($DPf - $Rfg * $DPg) / ($Agf * $DPg)} 

            # NEXT, enforce the max combat time
            let t {min($t,$Tleft)}

            set PRg $DPg

            let PRf {max(0,entier(floor($DPf - $Agf * $DPg * $t)))}   
        } else {
            # NEXT, Agf is 0.0; only g suffers casualties
            let t {($DPg - $Rgf * $DPf) / ($Afg * $DPf)}

            # NEXT, enforce the max combat time
            let t {min($t,$Tleft)}

            set PRf $DPf

            let PRg {max(0,entier(floor($DPg - $Afg * $DPf * $t)))}
        }

        # NEXT, return personnel remaining for both sides and time expended
        return [list $PRf $PRg $t]
    }

    method ComputeCivilianCasualties {} {
        # TBD
    }

    #-------------------------------------------------------------------
    # ROE Tactic API 

    # setroe n f rdict
    #
    # n       - a neighborhood in which g assumes an ROE
    # f       - a force group assuming the ROE
    # rdict   - dictionary of ROE key/values
    #
    # rdict contains the following data related to how g should conduct
    # itself while in combat against other force groups in n:
    #
    #    $g  => dictionary of ROE data for the FRC group f is engaging
    #        -> roe => the ROE $f is attempting with $g: ATTACK or DEFEND
    #        -> athresh => the force/enemy ratio below which $f DEFENDs
    #        -> dthresh => the force/enemy ratio below which $f WITHDRAWs
    #        -> civc => $f's concern for civilian casualties
    #
    # The data in this array of dictionaries is used to set up the initial
    # conditions of the various conflicts between FRC groups by neighborhood.
    # It should be noted that just because a FRC group is ordered to assume
    # a posture via the ROE, that posture may not be attainable due to
    # the computed force ratios.

    method setroe {n f g rdict} {
        dict set roedict($n) $f $g $rdict 
    }

    # hasroe n g f
    #
    # n   - a neighborhood
    # f   - a force group
    # g   - other force group
    #
    # This method returns a flag indicating whether g has an ROE already
    # set against g in n.  This is used during ROE tactic execution to
    # determine whether an ROE has already been set and, therefore, cannot
    # be overridden.

    method hasroe {n f g} {
        if {![info exists roedict($n)]} {
            return 0
        }

        return [dict exists $roedict($n) $f $g]
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



