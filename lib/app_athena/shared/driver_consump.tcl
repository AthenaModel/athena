#-----------------------------------------------------------------------
# TITLE:
#    driver_consump.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#   Athena Driver Assessment Model (DAM): CONSUMP rules
#
#    ::demsit_rules is a singleton object implemented as a snit::type.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# CONSUMP

driver type define CONSUMP {g} {
    #-------------------------------------------------------------------
    # Public Typemethods

    # assess
    #
    # Assesses any existing CONSUMP situations, which it finds for
    # itself.
    
    typemethod assess {} {
        set dtype CONSUMP

        # FIRST, skip if the rule set is inactive.
        if {![dam isactive CONSUMP]} {
            log warning CONSUMP \
                "driver type has been deactivated"
            return
        }
        
        # NEXT, look for and assess consumption
        rdb eval {
            SELECT G.g, G.aloc, G.eloc, G.povfrac, C.n, N.controller AS a
            FROM demog_g AS G
            JOIN civgroups AS C USING (g)
            JOIN control_n AS N USING (n)
            WHERE consumers > 0
        } row {
            # FIRST, get the data.
            unset -nocomplain row(*)
            set fdict [array get row]
            dict set fdict dtype $dtype
            dict with fdict {}
            
            # NEXT, get the expectations factor gain
            set ge [parm get demog.consump.expectfGain]
            
            # NEXT, if econ is disabled, pull parmdb parameters for the
            # rule set otherwise compute the expectations factor
            # NOTE: when econ is enabled, povfrac comes from demog_g
            if {[econ state] eq "DISABLED"} {
                set urb \
                    [rdb onecolumn {
                        SELECT urbanization FROM nbhoods WHERE n=$n
                    }]

                set expectf [parm get dam.CONSUMP.expectf.$urb]
                set povfrac [parm get dam.CONSUMP.povfrac.$urb]
                dict set fdict povfrac $povfrac
                let expectf {$ge*$expectf}
            } else {
                let expectf {$ge*min(1.0, ($aloc - $eloc)/max(1.0, $eloc))}
            }
            
            # NEXT, round to one decimal place
            dict set fdict expectf [format "%.1f" $expectf]
            
            # NEXT, compute the poverty factor, again rounding it to two
            # decimal places.
            set Zpovf [parm get demog.consump.Zpovf]
            set povf [zcurve eval $Zpovf $povfrac]
            
            dict set fdict povf [format "%.2f" $povf]
            
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
        set g $signature
        return "Group $g's consumption of goods"
    }

    # narrative fdict
    #
    # fdict - Firing dictionary; see rulesets, below.
    #
    # Produces a one-line narrative text string for a given rule firing

    typemethod narrative {fdict} {
        dict with fdict {}
        set expectf [format %.1f $expectf]
        set povf [format %.1f $povf]

        return "{group:$g}'s consumption, expectf=$expectf povf=$povf"
    }
    
    # detail fdict 
    #
    # fdict - Firing dictionary; see rulesets, below.
    # ht    - An htools(n) buffer
    #
    # Produces a narrative HTML paragraph including all fdict information.

    typemethod detail {fdict ht} {
        dict with fdict {}

        set povfrac [string trim [percent $povfrac]]

        if {[econ state] eq "DISABLED"} {
            $ht putln "The economic model is disabled, therefore the"
            $ht putln "consumption of goods by\n"
            $ht link my://app/group/$g $g
            $ht putln "is being controlled by CONSUMP rule set\n"
            $ht link my://app/parmdb?pattern=dam.consump.* "model parameters."
            $ht putln "To change the rule set inputs, change the value"
            $ht putln "of the appropriate parameters."
        } else {
            $ht putln "Civilian group\n"
            $ht link my://app/group/$g $g
            $ht putln "is consuming goods at a rate of"
            $ht putln "[format %.1f $aloc] baskets per week;"
            $ht putln "the group expects to consume at a rate of"
            $ht putln "[format %.1f $eloc] baskets per week."
            $ht putln "$povfrac of the group is living in poverty."
        }

        if {$a ne ""} {
            $ht putln "Actor "
            $ht link my://app/actor/$a $a
        } else {
            $ht putln "No actor"
        }
        $ht putln "is in control of neighborhood\n"
        $ht link my://app/nbhood/$n $n
        $ht put "."
        $ht para

        $ht putln "These conditions lead to the following rule set inputs:"
        $ht para

        $ht putln "<i>expectf</i>=[format %.2f $expectf]<br>"
        $ht putln "<i>povf</i>=[format %.2f $povf]"

        $ht para
    }

    
    #-------------------------------------------------------------------
    # Rule Set: CONSUMP:  Unemployment
    #
    # Demographic Situation: unemployment is affecting a neighborhood
    # group

    typemethod ruleset {fdict} {
        dict with fdict {}

        dam rule CONSUMP-1-1 $fdict {
            $expectf != 0.0 || $povf > 0.0
        } {
            dam sat T $g AUT [expr {[mag* $expectf S+] + [mag* $povf S-]}]
            dam sat T $g QOL [expr {[mag* $expectf M+] + [mag* $povf M-]}]
        }
        
        dam rule CONSUMP-2-1 $fdict {
            $a ne "" && $expectf >= 0.0 && $povf > 0.0
        } {
            dam vrel T $g $a [mag* $povf S-]
        }
        
        dam rule CONSUMP-2-2 $fdict {
            $a ne "" && $expectf < 0.0 && $povf > 0.0
        } {
            # Note: mag symbol for expectf is positive, but result will
            # be negative.
            dam vrel T $g $a [expr {[mag* $expectf L+] + [mag* $povf S-]}]
        }
    }
}



