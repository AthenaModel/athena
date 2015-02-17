#-----------------------------------------------------------------------
# TITLE:
#    ruleset_consump.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#   athena(n): CONSUMP rule set
#
# FIRING DICTIONARY:
#   g       - The group consuming goods
#   n       - The group's neighborhood
#   a       - The neighborhood's controlling actor
#   povf    - The poverty factor
#   expectf - The expectations factor
#
#-----------------------------------------------------------------------

oo::class create ::athena::ruleset_CONSUMP {
    superclass ::athena::ruleset
    
    meta name     "CONSUMP"
    meta sigparms {g}

    # assess
    #
    # Assesses all consumption situations.

    method assess {} {
        # FIRST, skip if the rule set is inactive.
        if {![my isactive]} {
            [my adb] log warning [my name] \
                "driver type has been deactivated"
            return
        }

        # NEXT, look for and assess consumption
        [my adb] eval {
            SELECT G.g, G.aloc, G.eloc, G.povfrac, C.n, N.controller AS a
            FROM demog_g AS G
            JOIN civgroups AS C USING (g)
            JOIN control_n AS N USING (n)
            WHERE consumers > 0
        } row {
            # FIRST, get the data.
            unset -nocomplain row(*)
            set fdict [array get row]
            dict set fdict dtype CONSUMP
            dict with fdict {}
            
            # NEXT, get the expectations factor gain
            set ge [my parm demog.consump.expectfGain]
            
            # NEXT, if econ is disabled, pull parmdb parameters for the
            # rule set otherwise compute the expectations factor
            # NOTE: when econ is enabled, povfrac comes from demog_g
            if {[[my adb] econ state] eq "DISABLED"} {
                set urb \
                    [[my adb] onecolumn {
                        SELECT urbanization FROM nbhoods WHERE n=$n
                    }]

                set expectf [my parm dam.CONSUMP.expectf.$urb]
                set povfrac [my parm dam.CONSUMP.povfrac.$urb]
                dict set fdict povfrac $povfrac
                let expectf {$ge*$expectf}
            } else {
                let expectf {$ge*min(1.0, ($aloc - $eloc)/max(1.0, $eloc))}
            }
            
            # NEXT, round to one decimal place
            dict set fdict expectf [format "%.1f" $expectf]
            
            # NEXT, compute the poverty factor, again rounding it to two
            # decimal places.
            set Zpovf [my parm demog.consump.Zpovf]
            set povf [zcurve eval $Zpovf $povfrac]
            
            dict set fdict povf [format "%.2f" $povf]
            
            # NEXT, call the rule set.
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
        set g $signature
        return "Group $g's consumption of goods"
    }

    # narrative fdict
    #
    # fdict - Firing dictionary; see rulesets, below.
    #
    # Produces a one-line narrative text string for a given rule firing

    method narrative {fdict} {
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

    method detail {fdict ht} {
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

    method ruleset {fdict} {
        dict with fdict {}

        my rule CONSUMP-1-1 $fdict {
            $expectf != 0.0 || $povf > 0.0
        } {
            my sat T $g AUT [expr {[my mag* $expectf S+] + [my mag* $povf S-]}]
            my sat T $g QOL [expr {[my mag* $expectf M+] + [my mag* $povf M-]}]
        }
        
        my rule CONSUMP-2-1 $fdict {
            $a ne "" && $expectf >= 0.0 && $povf > 0.0
        } {
            my vrel T $g $a [my mag* $povf S-]
        }
        
        my rule CONSUMP-2-2 $fdict {
            $a ne "" && $expectf < 0.0 && $povf > 0.0
        } {
            # Note: mag symbol for expectf is positive, but result will
            # be negative.
            my vrel T $g $a [expr {[my mag* $expectf L+] + [my mag* $povf S-]}]
        }
    }
}



