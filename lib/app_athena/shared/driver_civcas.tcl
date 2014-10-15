#------------------------------------------------------------------------
# TITLE:
#    driver_civcas.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Athena Driver Assessment Model (DAM): CIVCAS
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# CIVCAS

driver type define CIVCAS {f} {
    #-------------------------------------------------------------------
    # Public Typemethods

    # assess
    #
    # Assess all civilian casualties for the current week.

    typemethod assess {} {
        if {![dam isactive CIVCAS]} {
            log warning CIVCAS "driver type has been deactivated"
            return
        }

        # FIRST, assess the satisfaction implications
        rdb eval {
            SELECT 'CIVCAS'          AS dtype,
                   f                 AS f,
                   total(casualties) AS casualties
            FROM attrit_nf
            GROUP BY f
        } row {
            unset -nocomplain row(*)

            $type ruleset1 [array get row]
        }

        # NEXT, assess the cooperation implications
        rdb eval {
            SELECT 'CIVCAS'          AS dtype,
                   f                 AS f,
                   g                 AS g,
                   total(casualties) AS casualties
            FROM attrit_nfg
            GROUP BY f,g
        } row {
            unset -nocomplain row(*)

            $type ruleset2 [array get row]
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

    typemethod sigline {signature} {
        return "Casualties to group $signature"
    }

    # narrative fdict
    #
    # fdict - Firing dictionary; see rulesets, below.
    #
    # Produces a one-line narrative text string for a given rule firing

    typemethod narrative {fdict} {
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

    typemethod detail {fdict ht} {
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

    typemethod ruleset1 {fdict} {
        dict with fdict {}

        # FIRST, compute the casualty multiplier
        set zsat [parmdb get dam.CIVCAS.Zsat]
        set mult [zcurve eval $zsat $casualties]
        dict set fdict mult $mult
            
        # NEXT, The rule fires trivially
        dam rule CIVCAS-1-1  $fdict {1} {
            dam sat P $f \
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

    typemethod ruleset2 {fdict} {
        dict with fdict {}

        # FIRST, compute the casualty multiplier
        set zsat [parmdb get dam.CIVCAS.Zcoop]
        set cmult [zcurve eval $zsat $casualties]
        set rmult [rmf enmore [hrel.fg $f $g]]
        let mult {$cmult * $rmult}

        dict set fdict mult $cmult
        
        # NEXT, The rule fires trivially
        dam rule CIVCAS-2-1 $fdict {1} {
            dam coop P $f $g [mag* $mult M-]
        }
    }
}



