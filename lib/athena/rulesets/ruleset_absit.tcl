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
            $ht link /app/nbhood/$n $n
            $ht put " with $pcov coverage."
        } else {
            $ht putln "has been resolved"
            if {$resolver ne "NONE"} {
                $ht putln "by group "
                $ht link /app/group/$resolver $resolver
            }
            $ht putln "in neighborhood "
            $ht link /app/nbhood/$n $n
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


::athena::ruleset define BADFOOD {state n} {
    superclass ::athena::ruleset_absit

    metadict rulename {
        BADFOOD-1-1   "Food supply begins to be contaminated"
        BADFOOD-1-2   "Food supply continues to be contaminated"
        BADFOOD-2-1   "Food contamination is resolved by locals"
    }

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
 
::athena::ruleset define BADWATER {state n} {
    superclass ::athena::ruleset_absit

    metadict rulename {
        BADWATER-1-1  "Water supply begins to be contaminated"
        BADWATER-1-2  "Water supply continues to be contaminated"
        BADWATER-2-1  "Water contamination is resolved by locals"
    }

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
 
    
::athena::ruleset define COMMOUT {state n} {
    superclass ::athena::ruleset_absit

    metadict rulename {
        COMMOUT-1-1   "Communications go out"
        COMMOUT-1-2   "Communications remain out"
    }

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
    
::athena::ruleset define CULSITE {state n} {
    superclass ::athena::ruleset_absit

    metadict rulename {
        CULSITE-1-1   "A cultural site is damaged"
        CULSITE-1-2   "Damage has not been resolved"
    }

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
    
::athena::ruleset define DISASTER {state n} {
    superclass ::athena::ruleset_absit

    metadict rulename {
        DISASTER-1-1  "Disaster occurred in the neighborhood"
        DISASTER-1-2  "Disaster continues"
        DISASTER-2-1  "Disaster resolved by locals"
    }

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
    
::athena::ruleset define DISEASE {state n} {
    superclass ::athena::ruleset_absit

    metadict rulename {
        DISEASE-1-1   "Unhealthy conditions begin to cause disease"
        DISEASE-1-2   "Unhealthy conditions continue to cause disease"
        DISEASE-2-1   "Unhealthy conditions are resolved by locals"
    }

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
    
::athena::ruleset define DROUGHT {state n} {
    superclass ::athena::ruleset_absit

    metadict rulename {
        DROUGHT-1-1   "Long-term drought affects non-subsistence population"
        DROUGHT-1-2   "Long-term drought affects subsistence population"
    }

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
 
::athena::ruleset define EPIDEMIC {state n} {
    superclass ::athena::ruleset_absit

    metadict rulename {
        EPIDEMIC-1-1  "Epidemic begins to spread"
        EPIDEMIC-1-2  "Epidemic continues to spread"
        EPIDEMIC-2-1  "Spread of epidemic is halted by locals"
    }

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
 
::athena::ruleset define FOODSHRT {state n} {
    superclass ::athena::ruleset_absit

    metadict rulename {
        FOODSHRT-1-1  "Food begins to run short"
        FOODSHRT-1-2  "Food continues to run short"
        FOODSHRT-2-1  "Food shortage is ended by locals"
    }

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
 
::athena::ruleset define FUELSHRT {state n} {
    superclass ::athena::ruleset_absit

    metadict rulename {
        FUELSHRT-1-1  "Fuel begins to run short"
        FUELSHRT-1-2  "Fuel continues to be in short supply"
        FUELSHRT-2-1  "Fuel shortage is ended by locals"
    }

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
 
::athena::ruleset define GARBAGE {state n} {
    superclass ::athena::ruleset_absit

    metadict rulename {
        GARBAGE-1-1   "Garbage begins to accumulate"
        GARBAGE-1-2   "Garbage is piled in the streets"
        GARBAGE-2-1   "Garbage is cleaned up by locals"
    }

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
 
::athena::ruleset define INDSPILL {state n} {
    superclass ::athena::ruleset_absit

    metadict rulename {
        INDSPILL-1-1  "Industrial spill occurs"
        INDSPILL-1-2  "Industrial spill has not been cleaned up"
        INDSPILL-2-1  "Industrial spill is cleaned up by locals"
    }

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
 
::athena::ruleset define MINEFIELD {state n} {
    superclass ::athena::ruleset_absit

    metadict rulename {
        MINEFIELD-1-1 "Minefield is placed"
        MINEFIELD-1-2 "Minefield remains"
        MINEFIELD-2-1 "Minefield is cleared by locals"
    }

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
 
::athena::ruleset define ORDNANCE {state n} {
    superclass ::athena::ruleset_absit

    metadict rulename {
        ORDNANCE-1-1  "Unexploded ordnance is found"
        ORDNANCE-1-2  "Unexploded ordnance remains"
        ORDNANCE-2-1  "Unexploded ordnance is removed by locals"
    }

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
 
::athena::ruleset define PIPELINE {state n} {
    superclass ::athena::ruleset_absit

    metadict rulename {
        PIPELINE-1-1  "Oil pipeline catches fire"
        PIPELINE-1-2  "Oil pipeline is still burning"
        PIPELINE-2-1  "Oil pipeline fire is extinguished by locals"
    }

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
 
::athena::ruleset define REFINERY {state n} {
    superclass ::athena::ruleset_absit

    metadict rulename {
        REFINERY-1-1  "Oil refinery catches fire"
        REFINERY-1-2  "Oil refinery is still burning"
        REFINERY-2-1  "Oil refinery fire is extinguished by locals"
    }

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
 
::athena::ruleset define RELSITE {state n} {
    superclass ::athena::ruleset_absit

    metadict rulename {
        RELSITE-1-1   "A religious site is damaged"
        RELSITE-1-2   "Damage has not been resolved"
        RELSITE-2-1   "Damage is resolved by locals"
    }

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
 
::athena::ruleset define SEWAGE {state n} {
    superclass ::athena::ruleset_absit

    metadict rulename {
        SEWAGE-1-1    "Sewage begins to pool in the streets"
        SEWAGE-1-2    "Sewage has pooled in the streets"
        SEWAGE-2-1    "Sewage is cleaned up by locals"
    }

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




