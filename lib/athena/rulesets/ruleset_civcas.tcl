#------------------------------------------------------------------------
# TITLE:
#    ruleset_civcas.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): CIVCAS ruleset
#
#-----------------------------------------------------------------------

::athena::ruleset define CIVCAS {f} {
    metadict rulename {
        CIVCAS-1-1    "Civilian casualties taken"
        CIVCAS-2-1    "Civilian casualties taken from force group"
        CIVCAS-3-1    "Civilian casualties taken from an actors force group(s)"
    }
    
    #-------------------------------------------------------------------
    # Public methods

    # assess sdict cdict
    #
    # edict - dictionary of effects for SAT, COOP, HREL and VREL it has
    #         the following structure:
    #
    #         $f => Dictionary of casualty data for CIV group f
    #            -> cas => Total number of casualties f has suffered
    #            -> $g  => Number of casualties caused by force group g
    #            -> $a  => Number of casualties caused by force group(s) 
    #                      owned by actor a 
    #                     
    # Assess all civilian casualties for the current week.

    method assess {edict} {
        if {![my isactive]} {
            $notify log warning CIVCAS "driver type has been deactivated"
            return
        }

        set actors [[my adb] actor names]
        set fgrps  [[my adb] frcgroup names]

        dict for {civgrp cdict} $edict {
            dict for {key value} $cdict {
                set parms(dtype) CIVCAS
                set parms(f)     $civgrp

                if {$key eq "cas"} {
                    # SAT effects
                    set parms(casualties) $value

                    my ruleset1 [array get parms]
                } elseif {$key in $fgrps} {
                    # COOP and HREL effects
                    set parms(g)          $key 
                    set parms(casualties) $value

                    my ruleset2 [array get parms]
                } elseif {$key in $actors} {
                    # VREL effects
                    set parms(a)          $key
                    set parms(casualties) $value

                    my ruleset3 [array get parms]
                }

                array unset parms
            }
        }
    }

    #-------------------------------------------------------------------
    # Narrative Type Methods

    # sigline signature
    #
    # signature - The driver signature
    #
    # Returns a one-line description of the driver given its signature
    # values.

    method sigline {signature} {
        return "Casualties to group $signature"
    }

    # narrative fdict
    #
    # fdict - Firing dictionary; see rulesets, below.
    #
    # Produces a one-line narrative text string for a given rule firing

    method narrative {fdict} {
        dict with fdict {}

        set narrative "{group:$f} took $casualties casualties"

        if {[dict exists $fdict g]} {
            append narrative " from {group:$g}"
        }

        if {[dict exists $fdict a]} {
            append narrative " from group(s) owned by {actor:$a}"
        }

        return $narrative
    }
    
    # detail fdict 
    #
    # fdict - Firing dictionary; see rulesets, below.
    # ht    - An htools(n) buffer
    #
    # Produces a narrative HTML paragraph including all fdict information.

    method detail {fdict ht} {
        dict with fdict {}

        $ht putln "Civilian group "
        $ht link /app/group/$f $f
        $ht putln "took a total of $casualties casualties this week"

        if {[dict exists $fdict g]} {
            $ht putln "as collateral damage in incidents in which\n"
            $ht link /app/group/$g $g
            $ht putln "was involved."
        } elseif {[dict exists $fdict a]} {
            $ht putln "as collateral damage in incidents in which"
            $ht putln "force groups owned by\n"
            $ht link /app/actor/$a $a
            $ht putln "were involved."
        } else {
            $ht putln "from incidents of all kinds."     
        }

        if {[dict exists $fdict g]} {
            $ht putln "The Z-curve multiplier for cooperation is"
            $ht putln "<i>mult</i>=[format %.2f $cmult]."
            $ht putln "The Z-curve multiplier for horiz. relationship is"
            $ht putln "<i>mult</i>=[format %.2f $hmult]."
        } else {
            $ht putln "The Z-curve multiplier is"
            $ht putln "<i>mult</i>=[format %.2f $mult]."
        }

        $ht para
    }

    #-------------------------------------------------------------------
    # Rule Set: CIVCAS: Civilian Casualties
    #
    # Aggregate Event.  This rule set determines the effect of a week's
    # worth of civilian casualties on a neighborhood group.
    #
    # CIVCAS-1 assesses the satisfaction effects, and CIVCAS-2 assesses
    # the cooperation effects.
    
    # ruleset1 fdict
    #
    # fdict - Dictionary containing rule firing data
    #
    #    f          - The civilian group taking attrition.
    #    casualties - The total number of casualties during the week.

    method ruleset1 {fdict} {
        dict with fdict {}

        # FIRST, compute the casualty multiplier
        set zsat [my parm dam.CIVCAS.Zsat]
        set mult [zcurve eval $zsat $casualties]
        dict set fdict mult $mult
            
        # NEXT, The rule fires trivially
        my rule CIVCAS-1-1 $fdict {1} {
            my sat P $f \
               AUT [my mag* $mult L-]  \
               SFT [my mag* $mult XL-] \
               QOL [my mag* $mult L-]
        }
    }

    # ruleset2 fdict
    #
    # fdict - Dictionary containing rule firing data
    #
    #    f          - The civilian group taking attrition.
    #    g          - A force group causing the casualties
    #    casualties - The total number of casualties during the week
    #                 in which g is involved.

    method ruleset2 {fdict} {
        dict with fdict {}

        # FIRST, compute the casualty multipliers
        set zcoop [my parm dam.CIVCAS.Zcoop]
        set zhrel [my parm dam.CIVCAS.Zhrel]
        set cmult [zcurve eval $zcoop $casualties]
        set hmult [zcurve eval $zhrel $casualties]
        set rmult [my rmf enmore [my hrel.fg $f $g]]
        let coopmult {$cmult * $rmult}
        let hrelmult {$hmult * $rmult}

        dict set fdict cmult $cmult
        dict set fdict hmult $hmult
        
        # NEXT, The rule fires trivially
        my rule CIVCAS-2-1 $fdict {1} {
            my coop P $f $g [my mag* $coopmult M-]
            my hrel P $f $g [my mag* $hrelmult M-]
        }
    }

    # ruleset3 fdict
    #
    # fdict - Dictionary containing rule firing data
    #
    #    f          - The civilian group taking attrition.
    #    a          - The actor owning the force group(s) causing casualties.
    #    casualties - The total number of casualties during the week in
    #                 which a's force groups are involved.

    method ruleset3 {fdict} {
        dict with fdict {}

        # FIRST, compute the casualty multiplier
        set vcoop [my parm dam.CIVCAS.Zvrel]
        set vmult [zcurve eval $vcoop $casualties]
        set rmult [my rmf enmore [my vrel.ga $f $a]]
        let mult {$vmult * $rmult}

        dict set fdict mult $vmult

        # NEXT, the rule fires trivially
        my rule CIVCAS-3-1 $fdict {1} {
            my vrel P $f $a [my mag* $mult M-]
        }
    }
}



