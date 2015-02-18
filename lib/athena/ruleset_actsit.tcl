#-----------------------------------------------------------------------
# TITLE:
#    driver_actsit.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Athena Driver Assessment Model (DAM): Activity Situations
#
# FIRING DICTIONARY:
#    dtype         - The driver type, as always
#    n             - The nbhood in which the activity takes place
#    g             - The group performing the activity (FRC or ORG)
#    a             - The activity being performed
#    personnel     - The number of effective personnel
#    coverage      - The coverage fraction of the activity, > 0.0.
#   
#    The individual driver type can add the following fields to the fdict:
#   
#    mitigates     - A list of absit types actually being mitigated by
#                    this activity.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# ruleset_absit: actsit rule set base class

oo::class create ::athena::ruleset_actsit {
    superclass ::athena::ruleset

    #------------------------------------------------------------------
    # Public Methods

    # assess fdict
    #
    # fdict  - The firing dictionary; see above.
    #
    # Assesses the activity situation.
    
    method assess {fdict} {
        if {![my isactive]} {
            [my adb] log warning [my name] "driver type has been deactivated"
            continue
        }

        bgcatch {
            [my adb] log detail [my name] $fdict
            my ruleset $fdict
        }
    }

    #-------------------------------------------------------------------
    # Narrative Type Methods

    method sigline {signature} {
        lassign $signature n g
        return "$g [my name] in $n"
    }

    # narrative fdict
    #
    # fdict - Firing dictionary; see [assess], above.
    #
    # Produces a one-line narrative text string for a given rule firing

    method narrative {fdict} {
        dict with fdict {}

        set pcov [string trim [percent $coverage]]
        return "{group:$g} [my name] in {nbhood:$n} ($pcov)"
    }
    
    # detail fdict 
    #
    # fdict - Firing dictionary; see above.
    # ht    - An htools(n) buffer
    #
    # Produces a narrative HTML paragraph including all fdict information.

    method detail {fdict ht} {
        dict with fdict {}

        # FIRST, get the actual activity
        set a [my name]

        # NEXT, get the coverage function for that activity.
        set gtype [[my adb] group gtype $g]
        lassign [my parm activity.$gtype.$a.coverage] P T

        # NEXT, produce the narrative detail.
        $ht putln "Group "
        $ht link my://app/group/$g $g
        $ht putln "is performing the $a activity"
        $ht putln "in neighborhood\n"
        $ht link my://app/nbhood/$n $n
        $ht putln "with $personnel effective personnel."
        $ht putln "yielding [string trim [percent $coverage]] coverage."
        $ht para

        if {[dict exists $fdict mitigates] && [llength $mitigates] > 0} {
            $ht putln "The activity is mitigating the following absits:"
            $ht putln [join $mitigates ", "].
            $ht para
        }

 
        $ht putln "Note: The coverage function is $P/$T"
        $ht putln "(2/3rds coverage at $P personnel per $T in the population)."
        $ht para
    }

    #-------------------------------------------------------------------
    # Rule Set Tools

    # satinput flist g cov note con rmf mag ?con rmf mag...?
    #
    # flist    - The affected group(s)
    # g        - The doing group
    # cov      - The coverage fraction
    # note     - A brief descriptive note
    # con      - The affected concern
    # rmf      - The RMF to apply
    # mag      - The nominal magnitude
    #
    # Enters satisfaction inputs.

    method satinput {flist g cov note args} {
        set nomCov [my parm dam.actsit.nominalCoverage]

        assert {[llength $args] != 0 && [llength $args] % 3 == 0}

        foreach f $flist {
            set hrel [my hrel.fg $f $g]

            set result [list]

            foreach {con rmf mag} $args {
                let mult {[rmf $rmf $hrel] * $cov / $nomCov}
                
                lappend result $con [my mag* $mult $mag]
            }
            
            my sat T $f {*}$result $note
        }
    }


    # coopinput flist g cov rmf mag note
    #
    # flist    - The affected CIV groups
    # g        - The acting force group
    # cov      - The coverage fraction
    # rmf      - The RMF to apply
    # mag      - The nominal slope
    # note     - A brief descriptive note
    #
    # Enters cooperation inputs.

    method coopinput {flist g cov rmf mag {note ""}} {
        set nomCov [my parm dam.actsit.nominalCoverage]

        foreach f $flist {
            set hrel [my hrel.fg $f $g]

            let mult {[rmf $rmf $hrel] * $cov / $nomCov}
        
            my coop T $f $g [my mag* $mult $mag] $note
        }
    }

    # checkMitigation fdictVar
    #
    # fdictVar    A variable containing the fdict.
    #
    # Sets fdict.mitigates to a list of the absits present in the 
    # neighborhood that are mitigated by the current activity,
    # updates the number of stops, and provides a note for the
    # attitude inputs.

    method checkMitigation {fdictVar} {
        upvar 1 $fdictVar fdict

        # FIRST, set some defaults.
        dict set fdict mitigates {}
        dict set fdict note      ""
        dict set fdict stops     0


        # FIRST, extract some values from the fdict
        set ruleset [dict get $fdict dtype]
        set n       [dict get $fdict n]

        # NEXT, get the mitigated absits and form them into an 
        # "IN" list.  If none, just return immediately.

        set absits [my parm dam.$ruleset.mitigates]

        if {[llength $absits] == 0} {
            return
        }

        set inList "('[join $absits ',']')"

        # NEXT, check for active absits, collecting the affected groups as
        # we go.
        set elist [[my adb] eval "
            SELECT stype FROM absits
            WHERE n     = \$n
            AND   state = 'ONGOING'
            AND   stype IN $inList
        "]

        dict set fdict mitigates $elist

        if {[llength $elist] > 0} {
            dict set fdict note "mitigates"
            dict set fdict stops 1
        }
    }
}

#===================================================================
# Force and Organization Activity Situations
#
# The following rule sets are for situations which depend
# on the stated ACTIVITY of FRC and ORG units.

#-------------------------------------------------------------------
# Rule Set: CHKPOINT:  Checkpoint/Control Point
#
# Activity Situation: Units belonging to a force group are 
# operating checkpoints in a neighborhood.

::athena::ruleset define CHKPOINT {n g} {
    superclass ::athena::ruleset_actsit

    metadict rules {
        CHKPOINT-1-1  "Force is manning checkpoints"
    }

    method ruleset {fdict} {
        dict with fdict {}

        my rule CHKPOINT-1-1 $fdict {
            $coverage > 0.0
        } {
            foreach f $flist {
                set hrel [my hrel.fg $f $g]

                if {$hrel >= 0} {
                    # FRIENDS
                    my satinput $f $g $coverage "friends" \
                        AUT quad     S+   \
                        SFT quad     S+   \
                        CUL constant XXS- \
                        QOL constant XS- 
                } elseif {$hrel < 0} {
                    # ENEMIES
                    # Note: RMF=quad for AUT, SFT, which will
                    # reverse the sign in this case.
                    my satinput $f $g $coverage "enemies" \
                        AUT quad     S+  \
                        SFT quad     S+  \
                        CUL constant S-  \
                        QOL constant S-
                }
            }

            my coopinput $flist $g $coverage quad XXXS+
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: CONSTRUCT:  Construction
#
# Activity Situation: Units belonging to a group are 
# doing CONSTRUCT in a neighborhood.

::athena::ruleset define CONSTRUCT {n g} {
    superclass ::athena::ruleset_actsit

    metadict rules {
        CONSTRUCT-1-1  "Force is doing construction work"
        CONSTRUCT-2-1  "ORG is doing construction work"
    }

    method ruleset {fdict} {
        my checkMitigation fdict
        dict with fdict {}

        my rule CONSTRUCT-1-1 $fdict {
            $gtype eq "FRC" && $coverage > 0.0
        } {
            my satinput $flist $g $coverage $note      \
                AUT quad     [my mag+ $stops S+]  \
                SFT constant [my mag+ $stops S+]  \
                CUL constant [my mag+ $stops XS+] \
                QOL constant [my mag+ $stops L+]

            my coopinput $flist $g $coverage frmore [my mag+ $stops M+] $note
        }

        my rule CONSTRUCT-2-1 $fdict {
            $gtype eq "ORG" && $coverage > 0.0
        } {
            my satinput $flist $g $coverage $note \
                AUT constant [my mag+ $stops S+]  \
                SFT constant [my mag+ $stops S+]  \
                CUL constant [my mag+ $stops XS+] \
                QOL constant [my mag+ $stops L+]

        }
    }
}


#-------------------------------------------------------------------
# Rule Set: COERCION:  Coercion
#
# Activity Situation: Units belonging to a force group are 
# coercing local civilians to cooperate with them through threats
# of violence.

::athena::ruleset define COERCION {n g} {
    superclass ::athena::ruleset_actsit

    metadict rules {
        COERCION-1-1  "Force is coercing local civilians"
    }

    method ruleset {fdict} {
        dict with fdict {}

        my rule COERCION-1-1 $fdict {
            $coverage > 0.0
        } {
            my satinput $flist $g $coverage "" \
                AUT enquad XL-  \
                SFT enquad XXL- \
                CUL enquad XS-  \
                QOL enquad M-

            my coopinput $flist $g $coverage enmore XXXL+
        }
    }
}


#-------------------------------------------------------------------
# Rule Set: CRIME:  Criminal Activities
#
# Activity Situation: Units belonging to a force group are 
# engaging in criminal activities in a neighborhood.

::athena::ruleset define CRIME {n g} {
    superclass ::athena::ruleset_actsit

    metadict rules {
        CRIME-1-1     "Force is engaging in criminal activities"
    }

    method ruleset {fdict} {
        dict with fdict {}

        my rule CRIME-1-1 $fdict {
            $coverage > 0.0
        } {
            my satinput $flist $g $coverage "" \
                AUT enquad L-  \
                SFT enquad XL- \
                QOL enquad L-
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: CURFEW:  Curfew
#
# Activity Situation: Units belonging to a force group are 
# enforcing a curfew in a neighborhood.

::athena::ruleset define CURFEW {n g} {
    superclass ::athena::ruleset_actsit

    metadict rules {
        CURFEW-1-1    "Force is enforcing a curfew"
    }

    method ruleset {fdict} {
        dict with fdict {}

        my rule CURFEW-1-1 $fdict {
            $coverage > 0.0
        } {
            foreach f $flist {
                set rel [my hrel.fg $f $g]

                if {$rel >= 0} {
                    # Friends
                    my satinput $f $g $coverage "friends" \
                        AUT constant S- \
                        SFT frquad   S+ \
                        CUL constant S- \
                        QOL constant S-
                } else {
                    # Enemies
                    
                    # NOTE: Because $rel < 0, and the expected RMF
                    # is "quad", the SFT input turns into a minus.
                    my satinput $f $g $coverage "enemies" \
                        AUT constant S- \
                        SFT enquad   M- \
                        CUL constant S- \
                        QOL constant S-
                }
            }

            my coopinput $flist $g $coverage quad M+
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: EDU:  Schools
#
# Activity Situation: Units belonging to a group are 
# doing EDU in a neighborhood.

::athena::ruleset define EDU {n g} {
    superclass ::athena::ruleset_actsit

    metadict rules {
        EDU-1-1       "Force is providing schools"
        EDU-2-1       "ORG is providing schools"
    }

    method ruleset {fdict} {
        my checkMitigation fdict
        dict with fdict {}

        my rule EDU-1-1 $fdict {
            $gtype eq "FRC" && $coverage > 0.0
        } {
            my satinput $flist $g $coverage "$note" \
                AUT quad     [my mag+ $stops S+]   \
                SFT constant [my mag+ $stops XXS+] \
                CUL quad     [my mag+ $stops XXS+] \
                QOL constant [my mag+ $stops L+]

            my coopinput $flist $g $coverage frmore [my mag+ $stops M+] $note
        }

        my rule EDU-2-1 $fdict {
            $gtype eq "ORG" && $coverage > 0.0
        } {
            my satinput $flist $g $coverage $note       \
                AUT constant [my mag+ $stops S+]   \
                SFT constant [my mag+ $stops XXS+] \
                CUL constant [my mag+ $stops XXS+] \
                QOL constant [my mag+ $stops L+]
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: EMPLOY:  Provide Employment
#
# Activity Situation: Units belonging to a group are 
# doing EMPLOY in a neighborhood.

::athena::ruleset define EMPLOY {n g} {
    superclass ::athena::ruleset_actsit

    metadict rules {
        EMPLOY-1-1    "Force is providing employment"
        EMPLOY-2-1    "ORG is providing employment"
    }

    method ruleset {fdict} {
        my checkMitigation fdict
        dict with fdict {}

        my rule EMPLOY-1-1 $fdict {
            $gtype eq "FRC" && $coverage > 0.0
        } {
            my satinput $flist $g $coverage $note       \
                AUT quad     [my mag+ $stops S+]   \
                SFT constant [my mag+ $stops XXS+] \
                CUL constant [my mag+ $stops XXS+] \
                QOL constant [my mag+ $stops L+]

            my coopinput $flist $g $coverage frmore [my mag+ $stops M+] $note
        }

        my rule EMPLOY-2-1 $fdict {
            $gtype eq "ORG" && $coverage > 0.0
        } {
            my satinput $flist $g $coverage $note       \
                AUT constant [my mag+ $stops S+]   \
                SFT constant [my mag+ $stops XXS+] \
                CUL constant [my mag+ $stops XXS+] \
                QOL constant [my mag+ $stops L+]
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: GUARD:  Guard
#
# Activity Situation: Units belonging to a force group are 
# guarding sites in a neighborhood.

::athena::ruleset define GUARD {n g} {
    superclass ::athena::ruleset_actsit

    metadict rules {
        GUARD-1-1     "Force is guarding"
    }

    method ruleset {fdict} {
        dict with fdict {}

        my rule GUARD-1-1 $fdict {
            $coverage > 0.0
        } {
            my satinput $flist $g $coverage "" \
                AUT enmore L- \
                SFT enmore L- \
                CUL enmore L- \
                QOL enmore M-

            my coopinput $flist $g $coverage quad S+
        }
    }
}

    
#-------------------------------------------------------------------
# Rule Set: INDUSTRY:  Support Industry
#
# Activity Situation: Units belonging to a group are 
# doing INDUSTRY in a neighborhood.

::athena::ruleset define INDUSTRY {n g} {
    superclass ::athena::ruleset_actsit

    metadict rules {
        INDUSTRY-1-1  "Force is aiding industry"
        INDUSTRY-2-1  "ORG is aiding industry"
    }

    method ruleset {fdict} {
        my checkMitigation fdict
        dict with fdict {}

        my rule INDUSTRY-1-1 $fdict {
            $gtype eq "FRC" && $coverage > 0.0
        } {
            my satinput $flist $g $coverage $note       \
                AUT quad     [my mag+ $stops S+]   \
                SFT constant [my mag+ $stops XXS+] \
                CUL constant [my mag+ $stops XXS+] \
                QOL constant [my mag+ $stops L+]

            my coopinput $flist $g $coverage frmore [my mag+ $stops M+] $note
        }

        my rule INDUSTRY-2-1 $fdict {
            $gtype eq "ORG" && $coverage > 0.0
        } {
            my satinput $flist $g $coverage $note       \
                AUT constant [my mag+ $stops S+]   \
                SFT constant [my mag+ $stops XXS+] \
                CUL constant [my mag+ $stops XXS+] \
                QOL constant [my mag+ $stops L+]
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: INFRA:  Support Infrastructure
#
# Activity Situation: Units belonging to a group are 
# doing INFRA in a neighborhood.

::athena::ruleset define INFRA {n g} {
    superclass ::athena::ruleset_actsit

    metadict rules {
        INFRA-1-1     "Force is improving infrastructure"
        INFRA-2-1     "ORG is improving infrastructure"
    }

    method ruleset {fdict} {
        my checkMitigation fdict
        dict with fdict {}

        my rule INFRA-1-1 $fdict {
            $gtype eq "FRC" && $coverage > 0.0
        } {
            my satinput $flist $g $coverage $note       \
                AUT quad     [my mag+ $stops S+]   \
                SFT constant [my mag+ $stops XXS+] \
                CUL constant [my mag+ $stops XXS+] \
                QOL constant [my mag+ $stops M+]

            my coopinput $flist $g $coverage frmore [my mag+ $stops M+] $note
        }

        my rule INFRA-2-1 $fdict {
            $gtype eq "ORG" && $coverage > 0.0
        } {
            my satinput $flist $g $coverage $note       \
                AUT constant [my mag+ $stops S+]   \
                SFT constant [my mag+ $stops XXS+] \
                CUL constant [my mag+ $stops XXS+] \
                QOL constant [my mag+ $stops M+]
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: LAWENF:  Law Enforcement
#
# Activity Situation: Units belonging to a force group are 
# enforcing the law in a neighborhood.

::athena::ruleset define LAWENF {n g} {
    superclass ::athena::ruleset_actsit

    metadict rules {
        LAWENF-1-1    "Force is enforcing the law"
    }

    method ruleset {fdict} {
        dict with fdict {}

        my rule LAWENF-1-1 $fdict {
            $coverage > 0.0
        } {
            my satinput $flist $g $coverage "" \
                AUT quad M+  \
                SFT quad S+

            my coopinput $flist $g $coverage quad M+
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: MEDICAL:  Healthcare
#
# Activity Situation: Units belonging to a group are 
# doing MEDICAL in a neighborhood.

::athena::ruleset define MEDICAL {n g} {
    superclass ::athena::ruleset_actsit

    metadict rules {
        MEDICAL-1-1   "Force is providing health care"
        MEDICAL-2-1   "ORG is providing health care"
    }

    method ruleset {fdict} {
        my checkMitigation fdict
        dict with fdict {}

        my rule MEDICAL-1-1 $fdict {
            $gtype eq "FRC" && $coverage > 0.0
        } {
            my satinput $flist $g $coverage $note       \
                AUT quad     [my mag+ $stops S+]   \
                SFT constant [my mag+ $stops XXS+] \
                QOL constant [my mag+ $stops L+]

            my coopinput $flist $g $coverage frmore [my mag+ $stops L+] $note
        }

        my rule MEDICAL-2-1 $fdict {
            $gtype eq "ORG" && $coverage > 0.0
        } {
            my satinput $flist $g $coverage $note       \
                AUT constant [my mag+ $stops S+]   \
                SFT constant [my mag+ $stops XXS+] \
                CUL constant [my mag+ $stops XXS+] \
                QOL constant [my mag+ $stops L+]
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: PATROL:  Patrol
#
# Activity Situation: Units belonging to a force group are 
# patrolling a neighborhood.

::athena::ruleset define PATROL {n g} {
    superclass ::athena::ruleset_actsit

    metadict rules {
        PATROL-1-1    "Force is patrolling"
    }

    method ruleset {fdict} {
        dict with fdict {}

        my rule PATROL-1-1 $fdict {
            $coverage > 0.0
        } {
            my satinput $flist $g $coverage "" \
                AUT enmore M- \
                SFT enmore M- \
                CUL enmore S- \
                QOL enmore L-

            my coopinput $flist $g $coverage quad S+
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: PSYOP:  Psychological Operations
#
# Activity Situation: Units belonging to a force group are 
# doing PSYOP in a neighborhood.

::athena::ruleset define PSYOP {n g} {
    superclass ::athena::ruleset_actsit

    metadict rules {
        PSYOP-1-1     "Force is doing PSYOP"
    }

    method ruleset {fdict} {
        dict with fdict {}
        
        my rule PSYOP-1-1 $fdict {
            $coverage > 0.0
        } {
            foreach f $flist {
                set rel [my hrel.fg $f $g]

                if {$rel >= 0} {
                    # Friends
                    my satinput $f $g $coverage "friends" \
                        AUT constant S+ \
                        SFT constant S+ \
                        CUL constant S+ \
                        QOL constant S+
                } else {
                    # Enemies
                    my satinput $f $g $coverage "enemies" \
                        AUT constant XS+ \
                        SFT constant XS+ \
                        CUL constant XS+ \
                        QOL constant XS+
                }
            }

            my coopinput $flist $g $coverage frmore XL+
        }
    }
}


#-------------------------------------------------------------------
# Rule Set: RELIEF:  Humanitarian Relief
#
# Activity Situation: Units belonging to a group are 
# providing humanitarian relief in a neighborhood.

::athena::ruleset define RELIEF {n g} {
    superclass ::athena::ruleset_actsit

    metadict rules {
        RELIEF-1-1    "Force is providing humanitarian relief"
        RELIEF-2-1    "ORG is providing humanitarian relief"
    }

    method ruleset {fdict} {
        my checkMitigation fdict
        dict with fdict {}

        my rule RELIEF-1-1 $fdict {
            $gtype eq "FRC" && $coverage > 0.0
        } {
            my satinput $flist $g $coverage $note      \
                AUT quad     [my mag+ $stops S+]  \
                SFT constant [my mag+ $stops S+]  \
                CUL constant [my mag+ $stops XS+] \
                QOL constant [my mag+ $stops L+]

            my coopinput $flist $g $coverage frmore [my mag+ $stops M+] $note
        }


        my rule RELIEF-2-1 $fdict {
            $gtype eq "ORG" && $coverage > 0.0
        } {
            my satinput $flist $g $coverage $note      \
                AUT constant [my mag+ $stops S+]  \
                SFT constant [my mag+ $stops S+]  \
                CUL constant [my mag+ $stops XS+] \
                QOL constant [my mag+ $stops L+]
        }
    }
}
