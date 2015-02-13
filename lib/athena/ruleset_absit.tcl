#-----------------------------------------------------------------------
# TITLE:
#   ruleset_absit.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n): Abstract Situation rule sets
#
# FIRING DICTIONARY:
#   dtype     - Driver type (i.e., rule set name)
#   s         - Situation ID
#   state     - Situation state
#   n         - Neighborhood
#   inception - Inception flag, 1 or 0
#   coverage  - Coverage fraction
#   resolver  - Resolving group

#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# ruleset_absit: absit rule set base class

oo::class create ::athena::ruleset_absit {
    superclass ::athena::ruleset

    meta sigparms {state n}

    #-------------------------------------------------------------------
    # Public methods

    # assess fdict
    #
    # Assesses an absit given its firing dictionary.
    
    method assess {fdict} {
        if {![my isactive]} {
            [my adb] log warning [my name] "driver type has been deactivated"
            return
        }

        set n [dict get $fdict n]

        if {[my demog getn $n population] == 0} {
            [my adb] log normal [my name] \
                "skipping, nbhood $n is empty."
            return
        }

        bgcatch {
            [my adb] log detail [my name] $fdict
            my ruleset $fdict
        }
    }


    #-------------------------------------------------------------------
    # Narrative Methods

    # sigline signature
    #
    # signature - The driver signature, {state n}
    #
    # Returns a one-line description of the driver given its signature
    # values.

    method sigline {signature} {
        lassign $signature state n
        return "[my name] [string tolower $state] in $n"
    }

    # narrative fdict
    #
    # fdict - Firing dictionary; see above.
    #
    # Produces a one-line narrative text string for a given rule firing.
    #
    # NOTE: None of the current rules will fire on resolution unless the
    # resolver is a local group, and so the "resolver eq NONE" case
    # will never be used.  It wasn't also so, however, so we include
    # the case here and in [detail] in case the rules change.

    method narrative {fdict} {
        dict with fdict {}

        set pcov [string trim [percent $coverage]]

        set start "[my name] [string tolower $state]"
        set end   "in {nbhood:$n}"

        if {$state eq "ONGOING"} {
            return "$start $end ($pcov)"
        } elseif {$resolver ni {"NONE" ""}} {
            return "$start by {group:$resolver} $end"
        } else {
            return "$start $end"
        }
    }
    
    # detail fdict 
    #
    # fdict - Firing dictionary; see rulesets, below.
    # ht    - An htools(n) buffer
    #
    # Produces a narrative HTML paragraph including all fdict information.

    method detail {fdict ht} {
        dict with fdict {}

        set pcov [string trim [percent $coverage]]

        $ht putln "An abstract situation of type [my name]"

        if {$state eq "ONGOING"} {
            if {$inception} {
                $ht putln "has begun"
            } else {
                $ht putln "is ongoing"
            } 
            $ht putln "in neighborhood\n"
            $ht link my://app/nbhood/$n $n
            $ht put " with $pcov coverage."
        } else {
            $ht putln "has been resolved"
            if {$resolver ne "NONE"} {
                $ht putln "by group "
                $ht link my://app/group/$resolver $resolver
            }
            $ht putln "in neighborhood "
            $ht link my://app/nbhood/$n $n
            $ht put "."
        }

        $ht para
    }

    #-------------------------------------------------------------------
    # Helper Routines

    # resolverIsLocal g
    #
    # g    A group
    #
    # Returns 1 if g is known and local, and 0 otherwise.
    method resolverIsLocal {g} {
        expr {$g ne "" && [[my adb] group isLocal $g]}
    }

    # satinput flist cov con mag ?con mag...?
    #
    # flist - The groups affected
    # cov   - The coverage fraction
    # con   - The affected concern
    # mag   - The nominal magnitude
    #
    # Enters satisfaction inputs for flist and cov.

    method satinput {flist cov args} {
        assert {[llength $args] != 0 && [llength $args] % 2 == 0}

        set nomCov [my parm dam.absit.nominalCoverage]
        let mult   {$cov/$nomCov}

        set result [list]
        foreach {con mag} $args {
            lappend result $con [my mag* $mult $mag]
        }

        my sat T $flist {*}$result
    }
}


#-------------------------------------------------------------------
# Rule Set: BADFOOD: Contaminated Food Supply
#
# Abstract Situation: The local food supply has been contaminated.


oo::class create ::athena::ruleset_BADFOOD {
    superclass ::athena::ruleset_absit
    meta name BADFOOD

    method ruleset {fdict} {
        dict with fdict {}

        set flist [my demog gIn $n]

        my rule BADFOOD-1-1 $fdict {
           $state eq "ONGOING" && $inception
        } {
            my satinput $flist $coverage \
                AUT M-    \
                SFT XXXS- \
                QOL XXL-
        }

        my rule BADFOOD-1-2 $fdict {
           $state eq "ONGOING" && !$inception
        } {
            my satinput $flist $coverage \
                AUT M-    \
                SFT XXXS- \
                QOL L-
        }

        my rule BADFOOD-2-1 $fdict {
            $state eq "RESOLVED" && [my resolverIsLocal $resolver]
        } {
            my satinput $flist $coverage  \
                AUT S+
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: BADWATER: Contaminated Water Supply
#
# Abstract Situation: The local water supply has been contaminated.
 
oo::class create ::athena::ruleset_BADWATER {
    superclass ::athena::ruleset_absit
    meta name BADWATER

    method ruleset {fdict} {
        dict with fdict {}

        set flist [my demog gIn $n]

        my rule BADWATER-1-1 $fdict {
           $state eq "ONGOING" && $inception
        } {
            my satinput $flist $coverage \
                AUT M-    \
                SFT XXXS- \
                QOL XXL-
        }

        my rule BADWATER-1-2 $fdict {
           $state eq "ONGOING" && !$inception
        } {
            my satinput $flist $coverage \
                AUT M-    \
                SFT XXXS- \
                QOL L-
        }

        my rule BADWATER-2-1 $fdict {
            $state eq "RESOLVED" && [my resolverIsLocal $resolver]
        } {
            my satinput $flist $coverage  \
                AUT S+
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: COMMOUT: Communications Outage
#
# Abstract Situation: Communications are out in the neighborhood.
 
    
oo::class create ::athena::ruleset_COMMOUT {
    superclass ::athena::ruleset_absit
    meta name COMMOUT

    method ruleset {fdict} {
        dict with fdict {}

        set flist [my demog gIn $n]

        my rule COMMOUT-1-1 $fdict {
           $state eq "ONGOING" && $inception
        } {
            my satinput $flist $coverage \
                SFT L-    \
                CUL M-    \
                QOL XXL-
        }

        my rule COMMOUT-1-2 $fdict {
           $state eq "ONGOING" && !$inception
        } {
            my satinput $flist $coverage \
                SFT S-    \
                CUL S-    \
                QOL XL-
        }
    }
}


#-------------------------------------------------------------------
# Rule Set: CULSITE: Damage to Cultural Site/Artifact
#
# Abstract Situation: A cultural site or artifact is
# damaged, presumably due to kinetic action.
    
oo::class create ::athena::ruleset_CULSITE {
    superclass ::athena::ruleset_absit
    meta name CULSITE

    method ruleset {fdict} {
        dict with fdict {}

        set flist [my demog gIn $n]

        my rule CULSITE-1-1 $fdict {
           $state eq "ONGOING" && $inception
        } {
            my satinput $flist $coverage \
                CUL XXXXL- \
                QOL XXXS-
        }

        my rule CULSITE-1-2 $fdict {
           $state eq "ONGOING" && !$inception
        } {
            my satinput $flist $coverage \
                CUL XL-
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: DISASTER: Disaster
#
# Abstract Situation: Disaster
    
oo::class create ::athena::ruleset_DISASTER {
    superclass ::athena::ruleset_absit
    meta name DISASTER

    method ruleset {fdict} {
        dict with fdict {}

        set flist [my demog gIn $n]

        my rule DISASTER-1-1 $fdict {
           $state eq "ONGOING" && $inception
        } {
            my satinput $flist $coverage \
                SFT XXL-   \
                QOL XXXXL-
        }

        my rule DISASTER-1-2 $fdict {
           $state eq "ONGOING" && !$inception
        } {
            my satinput $flist $coverage \
                SFT L-    \
                QOL XXL-
        }

        my rule DISASTER-2-1 $fdict {
            $state eq "RESOLVED" && [my resolverIsLocal $resolver]
        } {
            my satinput $flist $coverage  \
                AUT S+
        }
    }
}


#-------------------------------------------------------------------
# Rule Set: DISEASE: Disease
#
# Abstract Situation: General disease due to unhealthy conditions.
    
oo::class create ::athena::ruleset_DISEASE {
    superclass ::athena::ruleset_absit
    meta name DISEASE

    method ruleset {fdict} {
        dict with fdict {}

        set flist [my demog gIn $n]

        my rule DISEASE-1-1 $fdict {
           $state eq "ONGOING" && $inception
        } {
            my satinput $flist $coverage \
                AUT L-    \
                SFT XXL-  \
                QOL XXXL-
        }

        my rule DISEASE-1-2 $fdict {
           $state eq "ONGOING" && !$inception
        } {
            my satinput $flist $coverage \
                AUT S-    \
                SFT L-    \
                QOL XL-
        }

        my rule DISEASE-2-1 $fdict {
            $state eq "RESOLVED" && [my resolverIsLocal $resolver]
        } {
            my satinput $flist $coverage  \
                AUT L+
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: DROUGHT: Long-term Drought
#
# Abstract Situation: Long-term Drought.
    
oo::class create ::athena::ruleset_DROUGHT {
    superclass ::athena::ruleset_absit
    meta name DROUGHT

    method ruleset {fdict} {
        dict with fdict {}

        set sa    [my demog saIn $n]
        set nonsa [my demog nonSaIn $n]

        my rule DROUGHT-1-1 $fdict {
           $state eq "ONGOING" && [llength $nonsa] > 0
        } {
            my satinput $nonsa $coverage \
                AUT XS-   \
                QOL XS-
        }

        my rule DROUGHT-1-2 $fdict {
           $state eq "ONGOING" && [llength $sa] > 0
        } {
            my satinput $sa $coverage \
                AUT L-    \
                SFT XS-   \
                QOL L-
        }
    }
}


#-------------------------------------------------------------------
# Rule Set: EPIDEMIC: Epidemic
#
# Abstract Situation: Epidemic disease
 
oo::class create ::athena::ruleset_EPIDEMIC {
    superclass ::athena::ruleset_absit
    meta name EPIDEMIC

    method ruleset {fdict} {
        dict with fdict {}

        set flist [my demog gIn $n]

        my rule EPIDEMIC-1-1 $fdict {
           $state eq "ONGOING" && $inception
        } {
            my satinput $flist $coverage \
                AUT XXL-   \
                SFT XL-    \
                QOL XXXXL-
        }

        my rule EPIDEMIC-1-2 $fdict {
           $state eq "ONGOING" && !$inception
        } {
            my satinput $flist $coverage \
                AUT L-    \
                SFT L-    \
                QOL XXL-
        }

        my rule EPIDEMIC-2-1 $fdict {
            $state eq "RESOLVED" && [my resolverIsLocal $resolver]
        } {
            my satinput $flist $coverage  \
                AUT M+
        }
    }
}


#-------------------------------------------------------------------
# Rule Set: FOODSHRT: Food Shortage
#
# Abstract Situation: There is a food shortage in the neighborhood.
 
oo::class create ::athena::ruleset_FOODSHRT {
    superclass ::athena::ruleset_absit
    meta name FOODSHRT

    method ruleset {fdict} {
        dict with fdict {}

        set flist [my demog gIn $n]

        my rule FOODSHRT-1-1 $fdict {
           $state eq "ONGOING" && $inception
        } {
            my satinput $flist $coverage \
                AUT M-  \
                QOL XL-
        }

        my rule FOODSHRT-1-2 $fdict {
           $state eq "ONGOING" && !$inception
        } {
            my satinput $flist $coverage \
                AUT M-  \
                QOL L-
        }

        my rule FOODSHRT-2-1 $fdict {
            $state eq "RESOLVED" && [my resolverIsLocal $resolver]
        } {
            my satinput $flist $coverage  \
                AUT L+
        }
    }
}


#-------------------------------------------------------------------
# Rule Set: FUELSHRT: Fuel Shortage
#
# Abstract Situation: There is a fuel shortage in the neighborhood.
 
oo::class create ::athena::ruleset_FUELSHRT {
    superclass ::athena::ruleset_absit
    meta name FUELSHRT

    method ruleset {fdict} {
        dict with fdict {}

        set flist [my demog gIn $n]

        my rule FUELSHRT-1-1 $fdict {
           $state eq "ONGOING" && $inception
        } {
            my satinput $flist $coverage \
                AUT M-           \
                QOL XXXL-
        }

        my rule FUELSHRT-1-2 $fdict {
           $state eq "ONGOING" && !$inception
        } {
            my satinput $flist $coverage \
                AUT M-  \
                QOL XL-
        }

        my rule FUELSHRT-2-1 $fdict {
            $state eq "RESOLVED" && [my resolverIsLocal $resolver]
        } {
            my satinput $flist $coverage  \
                AUT S+
        }
    }
}


#-------------------------------------------------------------------
# Rule Set: GARBAGE: Garbage in the Streets
#
# Abstract Situation: Garbage is piling up in the streets.
 
oo::class create ::athena::ruleset_GARBAGE {
    superclass ::athena::ruleset_absit
    meta name GARBAGE

    method ruleset {fdict} {
        dict with fdict {}

        set flist [my demog gIn $n]

        my rule GARBAGE-1-1 $fdict {
           $state eq "ONGOING" && $inception
        } {
            my satinput $flist $coverage \
                AUT L-   \
                SFT XL-  \
                QOL XL-
        }

        my rule GARBAGE-1-2 $fdict {
           $state eq "ONGOING" && !$inception
        } {
            my satinput $flist $coverage \
                AUT M-   \
                SFT M-   \
                QOL L-
        }

        my rule GARBAGE-2-1 $fdict {
            $state eq "RESOLVED" && [my resolverIsLocal $resolver]
        } {
            my satinput $flist $coverage  \
                AUT S+
        }
    }
}



#-------------------------------------------------------------------
# Rule Set: INDSPILL: Industrial Spill
#
# Abstract Situation: Damage to an industrial facility has released
# possibly toxic substances into the surrounding area.
 
oo::class create ::athena::ruleset_INDSPILL {
    superclass ::athena::ruleset_absit
    meta name INDSPILL

    method ruleset {fdict} {
        dict with fdict {}

        set flist [my demog gIn $n]

        my rule INDSPILL-1-1 $fdict {
           $state eq "ONGOING" && $inception
        } {
            my satinput $flist $coverage \
                AUT M-   \
                SFT XL-  \
                QOL XXL-
        }

        my rule INDSPILL-1-2 $fdict {
           $state eq "ONGOING" && !$inception
        } {
            my satinput $flist $coverage \
                AUT M-   \
                SFT S-   \
                QOL L-
        }

        my rule INDSPILL-2-1 $fdict {
            $state eq "RESOLVED" && [my resolverIsLocal $resolver]
        } {
            my satinput $flist $coverage  \
                AUT M+
        }
    }
}


#-------------------------------------------------------------------
# Rule Set: MINEFIELD: Minefield
#
# Abstract Situation: The residents of this neighborhood know that
# there is a minefield in the neighborhood.
 
oo::class create ::athena::ruleset_MINEFIELD {
    superclass ::athena::ruleset_absit
    meta name MINEFIELD

    method ruleset {fdict} {
        dict with fdict {}

        set flist [my demog gIn $n]

        my rule MINEFIELD-1-1 $fdict {
           $state eq "ONGOING" && $inception
        } {
            my satinput $flist $coverage \
                AUT XXL-    \
                SFT XXXXL-  \
                QOL XXXXL-
        }

        my rule MINEFIELD-1-2 $fdict {
           $state eq "ONGOING" && !$inception
        } {
            my satinput $flist $coverage \
                AUT L-    \
                SFT XXL-  \
                QOL XXL-
        }

        my rule MINEFIELD-2-1 $fdict {
            $state eq "RESOLVED" && [my resolverIsLocal $resolver]
        } {
            my satinput $flist $coverage  \
                AUT XXL+
        }
    }
}


#-------------------------------------------------------------------
# Rule Set: ORDNANCE: Unexploded Ordnance
#
# Abstract Situation: The residents of this neighborhood know that
# there is unexploded ordnance (probably from cluster munitions)
# in the neighborhood.
 
oo::class create ::athena::ruleset_ORDNANCE {
    superclass ::athena::ruleset_absit
    meta name ORDNANCE

    method ruleset {fdict} {
        dict with fdict {}

        set flist [my demog gIn $n]

        my rule ORDNANCE-1-1 $fdict {
           $state eq "ONGOING" && $inception
        } {
            my satinput $flist $coverage \
                AUT XL-    \
                SFT XXXXL- \
                QOL XXXL-
        }

        my rule ORDNANCE-1-2 $fdict {
           $state eq "ONGOING" && !$inception
        } {
            my satinput $flist $coverage \
                AUT L-   \
                SFT XXL- \
                QOL XXL-
        }

        my rule ORDNANCE-2-1 $fdict {
            $state eq "RESOLVED" && [my resolverIsLocal $resolver]
        } {
            my satinput $flist $coverage  \
                AUT S+
        }
    }
}



#-------------------------------------------------------------------
# Rule Set: PIPELINE: Oil Pipeline Fire
#
# Abstract Situation: Damage to an oil pipeline has caused to catch
# fire.
 
oo::class create ::athena::ruleset_PIPELINE {
    superclass ::athena::ruleset_absit
    meta name PIPELINE

    method ruleset {fdict} {
        dict with fdict {}

        set flist [my demog gIn $n]

        my rule PIPELINE-1-1 $fdict {
           $state eq "ONGOING" && $inception
        } {
            my satinput $flist $coverage \
                AUT L-     \
                SFT S-     \
                QOL XXXXL-
        }

        my rule PIPELINE-1-2 $fdict {
           $state eq "ONGOING" && !$inception
        } {
            my satinput $flist $coverage \
                AUT M-     \
                SFT XXS-   \
                QOL XXL-
        }

        my rule PIPELINE-2-1 $fdict {
            $state eq "RESOLVED" && [my resolverIsLocal $resolver]
        } {
            my satinput $flist $coverage  \
                AUT S+
        }
    }
}


#-------------------------------------------------------------------
# Rule Set: REFINERY: Oil Refinery Fire
#
# Abstract Situation: Damage to an oil refinery has caused it to
# catch fire.
 
oo::class create ::athena::ruleset_REFINERY {
    superclass ::athena::ruleset_absit
    meta name REFINERY

    method ruleset {fdict} {
        dict with fdict {}

        set flist [my demog gIn $n]

        my rule REFINERY-1-1 $fdict {
           $state eq "ONGOING" && $inception
        } {
            my satinput $flist $coverage \
                AUT XXL-   \
                SFT L-     \
                QOL XXXXL-
        }

        my rule REFINERY-1-2 $fdict {
           $state eq "ONGOING" && !$inception
        } {
            my satinput $flist $coverage \
                AUT L-   \
                SFT M-   \
                QOL XXL-
        }

        my rule REFINERY-2-1 $fdict {
            $state eq "RESOLVED" && [my resolverIsLocal $resolver]
        } {
            my satinput $flist $coverage  \
                AUT XL+
        }
    }
}



#-------------------------------------------------------------------
# Rule Set: RELSITE: Damage to Religious Site/Artifact
#
# Abstract Situation: A religious site or artifact is
# damaged, presumably due to kinetic action.
 
oo::class create ::athena::ruleset_RELSITE {
    superclass ::athena::ruleset_absit
    meta name RELSITE

    method ruleset {fdict} {
        dict with fdict {}

        set flist [my demog gIn $n]

        my rule RELSITE-1-1 $fdict {
           $state eq "ONGOING" && $inception
        } {
            my satinput $flist $coverage \
                AUT M-    \
                SFT XL-   \
                CUL XXXL- \
                QOL L-
        }

        my rule RELSITE-1-2 $fdict {
           $state eq "ONGOING" && !$inception
        } {
            my satinput $flist $coverage \
                AUT S-   \
                SFT S-   \
                CUL XL-  \
                QOL XS-
        }

        my rule RELSITE-2-1 $fdict {
            $state eq "RESOLVED" && [my resolverIsLocal $resolver]
        } {
            my satinput $flist $coverage  \
                AUT M+
        }
    }
}


#-------------------------------------------------------------------
# Rule Set: SEWAGE: Sewage Spill
#
# Abstract Situation: Sewage is pooling in the streets.
 
oo::class create ::athena::ruleset_SEWAGE {
    superclass ::athena::ruleset_absit
    meta name SEWAGE

    method ruleset {fdict} {
        dict with fdict {}

        set flist [my demog gIn $n]

        my rule SEWAGE-1-1 $fdict {
           $state eq "ONGOING" && $inception
        } {
            my satinput $flist $coverage \
                AUT L-    \
                QOL XXXL-
        }

        my rule SEWAGE-1-2 $fdict {
           $state eq "ONGOING" && !$inception
        } {
            my satinput $flist $coverage \
                AUT M-    \
                QOL XL-
        }

        my rule SEWAGE-2-1 $fdict {
            $state eq "RESOLVED" && [my resolverIsLocal $resolver]
        } {
            my satinput $flist $coverage  \
                AUT S+
        }
    }
}




