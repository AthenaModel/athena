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

#-----------------------------------------------------------------------
# CIVCAS

oo::class create ::athena::ruleset_CIVCAS {
    superclass ::athena::ruleset
    
    meta name     "CIVCAS"
    meta sigparms {f}

    #-------------------------------------------------------------------
    # Public methods

    # assess sdict cdict
    #
    # sdict - dictionary of satisfaction rule firing data, the keys
    #         are CIV group names and values are number of casualties
    #
    # cdict - dictionary of cooperation rule firing data, the keys
    #         are two element lists: a CIV group and a FRC group.
    #         The values are the number of casualties the FRC group
    #         caused the CIV group
    #
    # Assess all civilian casualties for the current week.

    method assess {sdict cdict} {
        if {![my isactive]} {
            $notify log warning CIVCAS "driver type has been deactivated"
            return
        }

        set parms(dtype) CIVCAS

        # FIRST, sat effects
        dict for {key value} $sdict {
            set parms(f)          $key
            set parms(casualties) $value

            my ruleset1 [array get parms]
        }

        # NET coop effects
        dict for {key value} $cdict {
            set parms(f)          [lindex $key 0]
            set parms(g)          [lindex $key 1]
            set parms(casualties) $value

            my ruleset2 [array get parms]
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
        $ht link my://app/group/$f $f
        $ht putln "took a total of $casualties casualties this week"

        if {[dict exists $fdict g]} {
            $ht putln "as collateral damage in incidents in which\n"
            $ht link my://app/group/$g $g
            $ht putln "was involved."
        } else {
            $ht putln "from incidents of all kinds."     
        }

        $ht putln "The Z-curve multiplier is <i>mult</i>=[format %.2f $mult]."
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
               AUT [mag* $mult L-]  \
               SFT [mag* $mult XL-] \
               QOL [mag* $mult L-]
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

        # FIRST, compute the casualty multiplier
        set zsat [my parm dam.CIVCAS.Zcoop]
        set cmult [zcurve eval $zsat $casualties]
        set rmult [rmf enmore [hrel.fg $f $g]]
        let mult {$cmult * $rmult}

        dict set fdict mult $cmult
        
        # NEXT, The rule fires trivially
        my rule CIVCAS-2-1 $fdict {1} {
            my coop P $f $g [mag* $mult M-]
        }
    }
}



