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

        # FIRST, initialize the force multiplier denominator
        set urb   [$adb parm get aam.FRC.urbcas.URBAN]
        set civc  [$adb parm get aam.FRC.civconcern.NONE]
        set elvl  [$adb parm get aam.FRC.equiplevel.BEST]
        set ftype [$adb parm get aam.FRC.forcetype.REGULAR]
        set tlvl  [$adb parm get aam.FRC.discipline.PROFICIENT]
        set dem   [$adb parm get aam.FRC.demeanor.AVERAGE]

        let frcmultD {$urb * $civc * $elvl * $ftype * $tlvl * $dem}
    }

    #------------------------------------------------------------------
    # Variables

    variable alist {}   ;# list of attrition dictionaries
    variable roedict    ;# dict used to store ROE tactic information
    variable hdict      ;# dict used to keep track of hiding force groups

    #------------------------------------------------------------------
    # Ruleset dictionary
    variable edict 

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
    # civcas(n,g)     - Total civilian casualties caused by g in n 

    variable effFrc     -array {}
    variable frcMult    -array {}
    variable civcasMult -array {}
    variable aThresh    -array {}
    variable dThresh    -array {}
    variable civconc    -array {}
    variable civcas     -array {}

    #-------------------------------------------------------------------
    # reset

    method reset {} {
        set alist ""
        set edict ""
        set roedict [lzipper [$adb nbhood names]]
        set hdict   [lzipper [$adb nbhood names]]
        array unset effFrc
        array unset frcMult
        array unset civcasMult
        array unset aThresh
        array unset dThresh
        array unset civconc
        array unset civcas 
    }

    method start {} {
        # FIRST, compute force group multiplier denominator, the parms
        # may have changed value
        set urb   [$adb parm get aam.FRC.urbcas.URBAN]
        set civc  [$adb parm get aam.FRC.civconcern.NONE]
        set elvl  [$adb parm get aam.FRC.equiplevel.BEST]
        set ftype [$adb parm get aam.FRC.forcetype.REGULAR]
        set tlvl  [$adb parm get aam.FRC.discipline.PROFICIENT]
        set dem   [$adb parm get aam.FRC.demeanor.AVERAGE]

        let frcmultD {$urb * $civc * $elvl * $ftype * $tlvl * $dem}

        # NEXT, initialize ROE and HIDE dicts
        set roedict [lzipper [$adb nbhood names]]
        set hdict   [lzipper [$adb nbhood names]]
    }

    #-------------------------------------------------------------------
    # Attrition Assessment

    # assess
    #
    # This routine is to be called every tick to do the 
    # attrition assessment.

    method assess {} {
         $adb log normal aam "assess"

        # FIRST, clear out old battle data, about to recompute it 
        $adb eval {
            DELETE FROM aam_battle;
        }

        # NEXT, clear transient battle data
        array unset effFrc
        array unset frcMult
        array unset civcasMult
        array unset aThresh
        array unset dThresh
        array unset civconc
        array unset civcas

        # NEXT, create effects dict to hold transient effects data
        set edict [dict create]

        # NEXT, force on force battle and collateral civilian casualties
        if {[$adb parm get aam.maxCombatTimeHours] > 0} {
            $self ComputeEffectiveForce
            $self BuildBattleData 
            $self AllocateForce
            $self DoGroupCombat
        }

        # NEXT, Apply all combat attrition and saved magic attrition. 
        # This updates units and deployments, and accumulates all civilian 
        # attrition as input to the CIVCAS rule set.
        $self ApplyAttrition

        # NEXT, assess the attitude implications of all attrition for
        # this tick.
        $adb ruleset CIVCAS assess $edict

        # NEXT, clear the saved data for this tick; we're done.
        set alist   ""
        set edict   ""
        set roedict ""
        set hdict   ""
    }

    # ComputeEffectiveForce
    #
    # This method computes a deployed force groups effective force
    # based on it's makeup.  For example, highly disciplined regular 
    # forces with the best equipment will project more force than 
    # poorly trained irregular forces with poor equipment.

    method ComputeEffectiveForce {} {
        $adb eval {
            SELECT F.equip_level   AS elvl,
                   F.training      AS tlvl,
                   F.forcetype     AS frctype,
                   F.demeanor      AS dem,
                   N.urbanization  AS urb,
                   D.personnel     AS pers,
                   D.n             AS n,
                   D.g             AS g
            FROM fmt_frcgroups AS F
            JOIN deploy_ng     AS D ON (D.g=F.g)
            JOIN nbhoods       AS N ON (D.n=N.n)
            WHERE D.personnel > 0
        } {

            # Effective force and force multipliers
            set Fe [$adb parm get aam.FRC.equiplevel.$elvl]
            set Ff [$adb parm get aam.FRC.forcetype.$frctype]
            set Ft [$adb parm get aam.FRC.discipline.$tlvl]
            set Fd [$adb parm get aam.FRC.demeanor.$dem]
            set Fu [$adb parm get aam.FRC.urbcas.$urb]

            let effFrc($n,$g)  {entier(ceil($Fe * $Ff * $Ft * $Fd * $pers))}
            let frcMult($n,$g) {$Fe * $Ff * $Ft * $Fd * $Fu}

            # Civilian casualty multipliers
            set Cf [$adb parm get aam.civcas.forcetype.$frctype]
            set Ct [$adb parm get aam.civcas.discipline.$tlvl]
            set Cu [$adb parm get aam.civcas.$urb]

            let civcasMult($n,$g) {$Cf * $Ct * $Cu}

            # Initialize civilian casualties array
            set civcas($n,$g) 0
        }
    }

    # BuildBattleData
    #
    # This method builds the AAM battle table based on deployments.
    # Default ROEs, thresholds and postures are set for those groups
    # that have not explictly been given them via an actor's strategy.

    method BuildBattleData {} {
        # FIRST, get max combat time for this week
        set hours [$adb parm get aam.maxCombatTimeHours]

        $adb eval {
            SELECT N.n         AS n,
                   F.g         AS f,
                   G.g         AS g,
                   DF.personnel AS persf,
                   DG.personnel AS persg
            FROM nbhoods AS N
            JOIN frcgroups AS F 
            JOIN frcgroups AS G
            JOIN deploy_ng AS DF ON (DF.n = N.n AND DF.g = F.g)
            JOIN deploy_ng AS DG ON (DG.n = N.n AND DG.g = G.g)
            WHERE F.g != G.g AND DF.personnel > 0 AND DG.personnel > 0
        } {
            if {[info exists dThresh($n,$f,$g)]} {
                continue
            }
            set ddt [$adb parm get aam.defaultDefendThresh]
            set cc  [$adb parm get aam.defaultCivcasConcern]

            # NEXT, defaults for f->g in case no ROE specified
            array set fvals \
                [list roe "DEFEND" athresh 0.0 dthresh $ddt civc $cc]

            # NEXT, pull data from ROE dict, if it's there 
            if {[dict exists $roedict $n $f $g]} {
                array set fvals [dict get $roedict $n $f $g]
            }

            # NEXT, defaults for g->f in case no ROE specified
            array set gvals \
                [list roe "DEFEND" athresh 0.0 dthresh $ddt civc $cc]

            # NEXT, pull data from ROE dict, if it's there 
            if {[dict exists $roedict $n $g $f]} {
                array set gvals [dict get $roedict $n $g $f]
            }

            # NEXT, if ROE on both side is DEFEND, no need to add to
            # battle table
            if {$fvals(roe) eq "DEFEND" && $gvals(roe) eq "DEFEND"} {
                continue
            }

            # NEXT, compute force ratios used for determining posture
            # later 
            let frcRatio {
                (double($effFrc($n,$g))/double($persg)) / 
                (double($effFrc($n,$f))/double($persf))
            }

            # f -> g
            let aThresh($n,$f,$g) {$fvals(athresh) * $frcRatio}
            let dThresh($n,$f,$g) {$fvals(dthresh) * $frcRatio}
            set civconc($n,$f,$g) $fvals(civc)

            # g -> f
            let aThresh($n,$g,$f) {$gvals(athresh) * $frcRatio}
            let dThresh($n,$g,$f) {$gvals(dthresh) * $frcRatio}
            set civconc($n,$g,$f) $gvals(civc)
            
            # NEXT, add to the working force table
            $adb eval {
                INSERT INTO aam_battle(n,f,g,pers_f,pers_g,
                                       roe_f,roe_g,hours_left)
                VALUES($n,$f,$g,$persf,$persg,$fvals(roe),$gvals(roe),$hours)
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
        # FIRST, accumulate effective force from both f and g's
        # point of view
        $adb eval {
            SELECT n,f,g FROM aam_battle
        } {

            # NEXT, initialize accumulators
            if {![info exists totEffFrcF($n,$f)]} {
                set totEffFrcF($n,$f) 0.0
            }

            if {![info exists totEffFrcG($n,$g)]} {
                set totEffFrcG($n,$g) 0.0
            }

            # NEXT, effective force accumulators from both sides'
            # point of view 
            let totEffFrcF($n,$f) {$totEffFrcF($n,$f) + $effFrc($n,$g)}
            let totEffFrcG($n,$g) {$totEffFrcG($n,$g) + $effFrc($n,$f)}
        }

        # NEXT, designate personnel to combat based upon the fraction of
        # force each opponent has in the battle 
        foreach {n f g roe_f} [$adb eval {
            SELECT n,f,g,roe_f FROM aam_battle
        }] {

            let fracF {$effFrc($n,$g) / $totEffFrcF($n,$f)}
            let fracG {$effFrc($n,$f) / $totEffFrcG($n,$g)}

            # NEXT, compute an apply detection factors 
            set dFactors [$self ComputeDetectionFactors $n $f $g]

            # NEXT, if f isn't the attacker, then g is
            if {$roe_f eq "ATTACK"} {
                let fracG {$fracG * [lindex $dFactors 0]}
                let fracF {$fracF * [lindex $dFactors 1]}
            } else {
                let fracF {$fracF * [lindex $dFactors 0]}
                let fracG {$fracG * [lindex $dFactors 1]}
            }

            # NEXT, must have at least one personnel designated
            # to the fight
            $adb eval {
                UPDATE aam_battle
                SET dpers_f = CAST(round(max(1,pers_f*$fracF)) AS INTEGER),
                    dpers_g = CAST(round(max(1,pers_g*$fracG)) AS INTEGER)
                WHERE n=$n AND f=$f AND g=$g
            }           
        }
    }

    # ComputeDetectionFactors n f g
    #
    # n   - a neighborhood
    # f   - a (possibly hiding) force group in combat with g
    # g   - a (possibly hiding) force group in combat with f
    #
    # This method computes the detection factor for a hiding group and 
    # the involved personnel factor for the group attacking
    # it.  If neither group is hiding it trivially returns
    # with values of 1.0 for each factor.  The factors are returned as a
    # list, one for the hiding group and one for the attacking group.

    method ComputeDetectionFactors {n f g} {
        # FIRST, figure out if either side is hiding. They both can't
        # be
        if {[$self hiding $n $f]} {
            set hiding   $f
            set attacker $g
        } elseif {[$self hiding $n $g]} {
            set hiding   $g
            set attacker $f
        } else {
            # Neither hiding
            return [list 1.0 1.0]
        }

        # NEXT, get multipliers and nbhood population
        set dGain  [$adb parm get aam.detectionGain]
        set urb    [$adb nbhood get $n urbanization]
        set visUrb [$adb parm get aam.visibility.$urb]
        set pop    [$adb demog getn $n population]

        # NEXT, compute visibility of the hiding groups personnel that are
        # performing neighborhood activities
        set visAct  0.0

        $adb eval {
            SELECT a,effective FROM activity_nga
            WHERE coverage > 0.0 AND n=$n AND g=$hiding
        } {
            set actMult [$adb parm get activity.FRC.$a.visFactor]
            let visAct {$visAct + $actMult * $effective}
        }

        # NEXT, detected personnel and involved personnel factors are computed 
        # from the visiblity of the hiding group's activities and the
        # cooperation the attacker has from the civilians in n.
        let visPers {$visUrb * $visAct}
        set covfunc [$adb parm get aam.visibility.coverage]
        set visibility [coverage eval $covfunc $visPers $pop]

        set nbcoop [$adb eval {
            SELECT nbcoop FROM uram_nbcoop WHERE n=$n AND g=$attacker
        }]

        let dpFact {$visibility * (100.0-$nbcoop)/100.0 + ($nbcoop/100.0)}
        let ipFact {$dGain * $dpFact}

        return [list $dpFact $ipFact]
    }
    
    # DoGroupCombat
    #
    # Updates force allocation based on ROEs and computes attrition to
    # force groups and civilian groups.

    method DoGroupCombat {} {
        # FIRST, set initial posture and store beginning of combat history
        $self SetGroupPosture   
        $self SaveStartHistory

        # NEXT, loop until all combat is done 
        set moreCombat 1
        while {$moreCombat} {
            set moreCombat [$self ComputeForceGroupAttrition]
            $self SetGroupPosture
        }

        # NEXT, assess casualties to force groups 
        $adb eval {
            SELECT n, f, g, cas_f, cas_g FROM aam_battle
            WHERE cas_f > 0 OR cas_g > 0
        } {
            $self AttritForceGroups $n $f $g $cas_f $cas_g
        }

        # NEXT, assess civilian casualties due to force group combat
        $self ComputeCivilianCasualties

        # NEXT, save end of combat history
        $self SaveEndHistory
    }

    # SetGroupPosture
    #
    # Based on designated personnel, ordered ROE and force/enemy ratios,
    # this method sets group posture for each group in the working force
    # table involved in combat

    method SetGroupPosture {} {
        foreach {n f g DPf DPg roeF roeG} [$adb eval {
            SELECT n,f,g,dpers_f,dpers_g,roe_f,roe_g 
            FROM aam_battle
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
                UPDATE aam_battle
                SET posture_f = $posture_f,
                    posture_g = $posture_g
                WHERE n=$n AND f=$f AND g=$g
            }
        }
    }

    # AttritForceGroups n f g casf casg 
    #
    # n    - A neighborhood ID 
    # f    - A force group that has, perhaps, taken casualties
    # g    - Another force group that has, perhaps, taken casualties
    # casf - The casualties to f, may be zero
    # casg - The casualties to g, may be zero
    #
    # This helper method appends attrition data for one or two force groups
    # that have taken casualties during the AAM assessment.  Only groups with
    # non-zero casualties are added to the list.  The attrition is adjudicated
    # later at the end of assessment.

    method AttritForceGroups {n f g casf casg} {
        # FIRST, initialize the attrition dictionary 
        set adata [dict create mode GROUP g1 "" g2 "" n $n]

        # NEXT, as appropriate add attrition taken by f and/or g
        if {$casf > 0} {
            dict set adata f $f
            dict set adata casualties $casf
            lappend alist $adata
        }

        if {$casg > 0} {
            dict set adata f $g
            dict set adata casualties $casg
            lappend alist $adata
        }
    }

    # ComputeForceGroupAttrition
    #
    # This method goes through the AAM battle table and computes
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
            FROM aam_battle
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

            # Coefficient multipliers for Agf
            set civc $civconc($n,$g,$f)
            set Fc [$adb parm get aam.FRC.civconcern.$civc]
            let Agf {$agf * $Fc * $frcMult($n,$g) / $frcmultD}

            # NEXT, populate transient input data for computing
            # casualties and time of combat 
            set idata [dict create]
            dict set idata Afg   $Afg
            dict set idata Agf   $Agf
            dict set idata Rfg   $Rfg
            dict set idata Rgf   $Rgf
            dict set idata DPf   $dpers_f
            dict set idata DPg   $dpers_g
            dict set idata Tleft $hours_left

            lassign [$self ComputeForceGroupCasualties $idata] PRf PRg t

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
                UPDATE aam_battle
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
            # NOTE: using floor because a partial casualty is a full casualty
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

    # ComputeCivilianCasualties
    #
    # This method computes the number of casualties inflicted on the
    # civilians in neighborhoods that have active combat between two
    # or more force groups.  The computed casualties are then added to 
    # the growing list of casualty dictionaries that is assessed later.

    method ComputeCivilianCasualties {} {
        # FIRST, extract the limit to civilian casualties
        set limit [$adb parm get aam.civcas.limit]

        # NEXT, if the limit is zero, we are done
        if {$limit == 0}  {
            return
        }

        # NEXT, initialize the casualty dictionary
        set casdict [lzipper [$adb nbhood names]]

        # NEXT, fill in the data based on force group casualties 
        $adb eval {
            SELECT n,f,g,cas_f,cas_g FROM aam_battle
            WHERE cas_f > 0 OR cas_g > 0
        } {
            if {![dict exists $casdict $n $f]} {
                dict set casdict $n $f 0.0
            }

            if {![dict exists $casdict $n $g]} {
                dict set casdict $n $g 0.0
            }

            # NEXT, accumulate casualties caused by f in n 
            if {$cas_g > 0} {
                set currcas [dict get $casdict $n $f]
                set civc $civconc($n,$f,$g)
                set Cc [$adb parm get aam.FRC.civconcern.$civc]
                let newcas {
                    $currcas + $civcasMult($n,$f) * $Cc * $cas_g
                }
                dict set casdict $n $f $newcas
            }

            # NEXT, accumulate casualties caused by g in n 
            if {$cas_f > 0} {
                set currcas [dict get $casdict $n $g]
                set civc $civconc($n,$g,$f)
                set Cc [$adb parm get aam.FRC.civconcern.$civc]
                let newcas {
                    $currcas + $civcasMult($n,$g) * $Cc * $cas_f
                }
                dict set casdict $n $g $newcas
            }
        }

        # NEXT, traverse the casualty dictionary and accumulate civilian
        # casualties limited by the maximum allowed
        dict for {n fdict} $casdict {
            # NEXT, no combat, no collateral civilian casualties
            if {$fdict eq ""} {
                continue
            }

            # NEXT, set the limit and enforce it
            let maxcas {$limit * [$adb demog getn $n population]}

            dict for {grp cas} $fdict {
                let totcas {entier(floor(min($cas, $maxcas)))}
                set civcas($n,$grp) $totcas
                if {$totcas > 0} {
                    lappend alist [list \
                        mode NBHOOD g1 $grp g2 "" n $n f "" casualties $totcas]
                }
            }   
        }
    }

    #-------------------------------------------------------------------
    # Combat history management

    # SaveStartHistory
    #
    # This method inserts new records into the AMM battle history table to
    # represent the state of force groups at the start of combat during
    # a tick.  Only groups with ROEs of "ATTACK" are represented.

    method SaveStartHistory {} {
        $adb eval {
            INSERT INTO hist_aam_battle(t,n,f,g,roe_f,roe_g,
                                        dpers_f,dpers_g,startp_f,startp_g)
            SELECT now() AS t, n, f, g, roe_f, roe_g, 
                   dpers_f, dpers_g, posture_f, posture_g
            FROM aam_battle;
        }
    }

    # SaveEndHistory
    #
    # This method updates the records in the AAM battle history table with
    # data representing the state of force groups as the end of combat
    # during a tick.  Only groups with ROEs of "DEFEND" are represented.

    method SaveEndHistory {} {
        foreach {n f g posture_f posture_g cas_f cas_g} [$adb eval {
            SELECT n,f,g,posture_f,posture_g,cas_f,cas_g 
            FROM aam_battle
        }] {
            set civcas_f $civcas($n,$f)
            set civcas_g $civcas($n,$g)
            set civc_f   $civconc($n,$f,$g)
            set civc_g   $civconc($n,$g,$f)
            $adb eval {
                UPDATE hist_aam_battle 
                SET endp_f   = $posture_f,
                    endp_g   = $posture_g,
                    cas_f    = $cas_f,
                    cas_g    = $cas_g,
                    civcas_f = $civcas_f,
                    civcas_g = $civcas_g,
                    civc_f   = $civc_f,
                    civc_g   = $civc_g
                WHERE t = now() AND n=$n AND f=$f AND g=$g                
            }
        }

    }

    #-------------------------------------------------------------------
    # ROE Tactic API 

    # setroe n f g rdict
    #
    # n       - a neighborhood in which g assumes an ROE
    # f       - a force group assuming the ROE
    # g       - a force group to whom the ROE is directed
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
    # The data in this nested dictionart is used to set up the initial
    # conditions of the various conflicts between FRC groups by neighborhood.
    # It should be noted that just because a FRC group is ordered to assume
    # a posture via the ROE, that posture may not be attainable due to
    # the computed force ratios.

    method setroe {n f g rdict} {
        dict set roedict $n $f $g $rdict 
    }

    # hasroe n f g
    #
    # n   - a neighborhood
    # f   - a force group
    # g   - another force group
    #
    # This method returns a flag indicating whether f has an ROE already
    # set against g in n.  This is used during ROE tactic execution to
    # determine whether an ROE has already been set and, therefore, cannot
    # be overridden.

    method hasroe {n f g} {
        return [dict exists $roedict $n $f $g]
    }


    #-------------------------------------------------------------------
    # HIDE Tactic API

    # hide n f
    #
    # n   - a neighborhood
    # f   - a force group
    #
    # This method adds the group f to the list of groups hiding in n

    method hide {n f} {
        dict lappend hdict $n $f
    }

    # hiding n f
    #
    # n   - a neighborhood
    # f   - a force group
    #
    # This method returns a flag indicating whether the group f is 
    # hiding in n

    method hiding {n f} {
        if {![dict exists $hdict $n]} {
            return 0
        }

        return [expr {$f in [dict get $hdict $n]}]
    }

    # hasattack n f
    #
    # n   - a neighborhood
    # f   - a group that may have an ATTACK roe in n
    #
    # This method returns 1 if f has an ATTACK ROE in n, 0 otherwise.
    # It is used by the HIDE tactic to filter out force groups that
    # cannot hide due to being ordered to attack.
    
    method hasattack {n f} {
        # FIRST, no explicit ROE means ATTACK not possible
        if {![dict exists $roedict $n $f]} {
            return 0
        }

        # NEXT, find any occurence of an ATTACK ROE in n
        foreach {g gdict} [dict get $roedict $n $f] {
            dict with gdict {}
            if {$roe eq "ATTACK"} {
                return 1
            }
        }

        return 0
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

        # FIRST, if we don't yet have attrition for this CIV group
        # create an entry in the dict 
        if {![dict exists $edict $g]} {
            dict set edict $g cas 0
        }

        # NEXT, sum attrition for SAT effects
        let sum {[dict get $edict $g cas] + $casualties}
        dict set edict $g cas $sum

        # NEXT, if force groups were involved deal with COOP, HREL and 
        # VREL effects
        if {$g1 ne ""} {
            # COOP and HREL
            if {![dict exists $edict $g $g1]} {
                dict set edict $g $g1 0
            }

            let sum {[dict get $edict $g $g1] + $casualties}
            dict set edict $g $g1 $sum

            # VREL for owning actor
            set a [$adb frcgroup get $g1 a]
            if {![dict exists $edict $g $a]} {
                dict set edict $g $a 0
            }

            let sum {[dict get $edict $g $a] + $casualties}
            dict set edict $g $a $sum
        }

        # NEXT, if a second force group is involved deal with COOP, HREL
        # and VREL for them
        if {$g2 ne ""} {
            # COOP and HREL
            if {![dict exists $edict $g $g2]} {
                dict set edict $g $g2 0
            }

            let sum {[dict get $edict $g $g2] + $casualties}
            dict set edict $g $g2 $sum

            # VREL
            set a [$adb frcgroup get $g2 a]
            if {![dict exists $edict $g $a]} {
                dict set edict $g $a 0
            }

            let sum {[dict get $edict $g $a] + $casualties}
            dict set edict $g $a $sum
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
    # NOTE: if this helper become used by more than just the ATTRIT 
    # tactic, consider moving into athena_order.

    method AllButG1 {g1} {
        set groups [$adb ptype frcg+none names]
        ldelete groups $g1

        return $groups
    }
}



