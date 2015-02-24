#-----------------------------------------------------------------------
# TITLE:
#    ruleset_unemp.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#   athena(n): UNEMP rule set
#
# FIRING DICTIONARY:
#
#-----------------------------------------------------------------------

::athena::ruleset define UNEMP {n g} {
    metadict rulename {
        UNEMP-1-1    "Group is suffering from unemployment"
    }

    #-------------------------------------------------------------------
    # Public Typemethods

    # assess
    #
    # Assesses any existing UNEMP situations, which it finds for
    # itself.
    
    method assess {} {
        # FIRST, skip if the rule set is inactive.
        if {![my isactive]} {
            [my adb] log warning [my name] \
                "driver type has been deactivated"
            return
        }
        
        # NEXT, look for and assess unemployment
        [my adb] eval {
            SELECT n, g, nuaf AS uaf, nupc AS upc
            FROM demog_context
            WHERE population > 0
            AND nuaf > 0
        } row {
            unset -nocomplain row(*)
            set fdict [array get row]
            dict set fdict dtype [my name]
            dict with fdict {}
            
            bgcatch {
                [my adb] log detail [my name] $fdict
                my ruleset $fdict
            }
        }
    }
    
    # sigline signature
    #
    # signature - The driver signature
    #
    # Returns a one-line description of the driver given its signature
    # values.

    method sigline {signature} {
        lassign $signature n g
        return "Effect of $n unemployment on $g"
    }

    # narrative fdict
    #
    # fdict - Firing dictionary; see rulesets, below.
    #
    # Produces a one-line narrative text string for a given rule firing

    method narrative {fdict} {
        dict with fdict {}

        return "Unemployment in {nbhood:$n} affects {group:$g}"
    }
    
    # detail fdict 
    #
    # fdict - Firing dictionary; see rulesets, below.
    # ht    - An htools(n) buffer
    #
    # Produces a narrative HTML paragraph including all fdict information.

    method detail {fdict ht} {
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

    method ruleset {fdict} {
        dict with fdict {}

        my rule UNEMP-1-1 $fdict {
            $uaf > 0.0
        } {
            my sat T $g SFT [mag* $uaf M-]
            my sat T $g AUT [mag* $uaf S-]
        }
    }
}



