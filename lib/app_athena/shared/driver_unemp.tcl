#-----------------------------------------------------------------------
# TITLE:
#    driver_unemp.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#   Athena Driver Assessment Model (DAM): UNEMP rules
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# UNEMP

driver type define UNEMP {n g} {
    #-------------------------------------------------------------------
    # Public Typemethods

    # assess
    #
    # Assesses any existing UNEMP situations, which it finds for
    # itself.
    
    typemethod assess {} {
        set dtype UNEMP

        # FIRST, skip if the rule set is inactive.
        if {![dam isactive UNEMP]} {
            log warning UNEMP \
                "driver type has been deactivated"
            return
        }
        
        # NEXT, look for and assess unemployment
        rdb eval {
            SELECT n, g, nuaf AS uaf, nupc AS upc
            FROM demog_context
            WHERE population > 0
            AND nuaf > 0
        } row {
            unset -nocomplain row(*)
            set fdict [array get row]
            dict set fdict dtype $dtype
            dict with fdict {}
            
            bgcatch {
                log detail $dtype $fdict
                $type ruleset $fdict
            }
        }
    }
    
    # sigline signature
    #
    # signature - The driver signature
    #
    # Returns a one-line description of the driver given its signature
    # values.

    typemethod sigline {signature} {
        lassign $signature n g
        return "Effect of $n unemployment on $g"
    }

    # narrative fdict
    #
    # fdict - Firing dictionary; see rulesets, below.
    #
    # Produces a one-line narrative text string for a given rule firing

    typemethod narrative {fdict} {
        dict with fdict {}

        return "Unemployment in {nbhood:$n} affects {group:$g}"
    }
    
    # detail fdict 
    #
    # fdict - Firing dictionary; see rulesets, below.
    # ht    - An htools(n) buffer
    #
    # Produces a narrative HTML paragraph including all fdict information.

    typemethod detail {fdict ht} {
        dict with fdict {}

        set upc [format %.1f $upc]

        $ht putln "Unemployment in neighborhood\n"
        $ht link my://app/nbhood/$n $n
        $ht putln "is at a level of $upc% unemployed persons per capita;"
        $ht putln "this affects civilian group\n"
        $ht link my://app/group/$g $g
        $ht putln "with an Unemployment Attitude Factor (UAF) of"
        $ht putln "[format %.2f $uaf]."
        $ht para
    }

    #-------------------------------------------------------------------
    # Rule Set: UNEMP:  Unemployment
    #
    # Demographic Situation: unemployment is affecting a neighborhood
    # group

    typemethod ruleset {fdict} {
        dict with fdict {}

        dam rule UNEMP-1-1 $fdict {
            $uaf > 0.0
        } {
            dam sat T $g SFT [mag* $uaf M-]
            dam sat T $g AUT [mag* $uaf S-]
        }
    }
}



