#-----------------------------------------------------------------------
# TITLE:
#    driver_eni.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Athena Driver Assessment Model (DAM): ENI
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# ENI

driver type define ENI {g} {
    #-------------------------------------------------------------------
    # Look-up tables

    # vmags: VREL magnitudes for ENI rule set given these variables:
    #
    # Control: C, NC
    #
    #   C   - Actor is in control of group's neighborhood.
    #   NC  - Actor is not in control of group's neighborhood.
    #
    # case: R-, E-, E, E+
    #
    #   R-  - actual LOS is less than required.
    #   E-  - actual LOS is at least the required amount, but less than
    #         expected.
    #   E   - actual LOS is approximately the same as expected
    #   E+  - actual LOS is more than expected.
    #
    # Credit: N, S, M
    #
    #   N   - Actor's contribution is a Negligible fraction of total
    #   S   - Actor has contributed Some of the total
    #   M   - Actor has contributed Most of the total

    typevariable vmags -array {
        C,E+,M  XL+
        C,E+,S  XL+
        C,E+,N  XL+

        C,E,M   L+
        C,E,S   L+
        C,E,N   L+

        C,E-,M  M-
        C,E-,S  L-
        C,E-,N  XL-

        C,R-,M  L-
        C,R-,S  XL-
        C,R-,N  XXL-

        NC,E+,M XXL+
        NC,E+,S XL+
        NC,E+,N 0

        NC,E,M  XL+
        NC,E,S  L+
        NC,E,N  0

        NC,E-,M L+
        NC,E-,S M+
        NC,E-,N 0

        NC,R-,M M+
        NC,R-,S S+
        NC,R-,N 0
    }


   
    #-------------------------------------------------------------------
    # Public Typemethods

    # assess
    #
    # Monitors the level of service provided to civilian groups.  The
    # rule firing dictionary contains the following data:
    #
    #   dtype       - The driver type (ENI)
    #   g           - The civilian group receiving the services
    #   actual      - The actual level of service (ALOS)
    #   required    - The required level of service (RLOS)
    #   expected    - The expected level of service (ELOS)
    #   expectf     - The expectations factor
    #   needs       - The needs factor
    #   controller  - The actor controlling g's neighborhood
    #   case        - The case: E+, E, E-, R-
    
    typemethod assess {} {
        set dtype ENI

        if {![dam isactive $dtype]} {
            log warning $dtype "driver type has been deactivated"
            return
        }

        # NEXT, call the ENI rule set.
        rdb eval {
            SELECT g, actual, required, expected, expectf, needs, controller
            FROM local_civgroups 
            JOIN demog_g USING (g)
            JOIN service_g USING (g)
            JOIN control_n ON (local_civgroups.n = control_n.n)
            WHERE demog_g.population > 0
            ORDER BY g
        } gdata {
            unset -nocomplain gdata(*)

            set fdict [array get gdata]
            dict set fdict dtype $dtype

            bgcatch {
                log detail $dtype $fdict
                $type ruleset $fdict
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

    typemethod sigline {signature} {
        set g $signature
        return "Provision of ENI services to $g"
    }

    # narrative fdict
    #
    # fdict - Firing dictionary; see rulesets, below.
    #
    # Produces a one-line narrative text string for a given rule firing

    typemethod narrative {fdict} {
        dict with fdict {}

        return "{group:$g} receives ENI services (case $case)"
    }
    
    # detail fdict 
    #
    # fdict - Firing dictionary; see rulesets, below.
    # ht    - An htools(n) buffer
    #
    # Produces a narrative HTML paragraph including all fdict information.

    typemethod detail {fdict ht} {
        dict with fdict {}

        $ht putln "Civilian group\n"
        $ht link my://app/group/$g $g
        $ht putln "received ENI services at an actual level of"
        $ht putln "[format %.2f $actual], that is, at"
        $ht putln "[string trim [percent $actual]] of the saturation level"
        $ht putln "of service.  Group $g requires a level of at least"
        $ht putln "[format %.2f $required], and expected a level of"
        $ht putln "[format %.2f $expected]."
        $ht para

        $ht putln "The case is therefore $case, that is, $g received"
        switch -exact -- $case {
            R- { $ht putln "less than it required."}
            E- { $ht putln "less than expected."}
            E  { $ht putln "what was expected."}
            E+ { $ht putln "more than expected."}
            default { error "Unknown case: \"$case\""}
        }

        $ht putln "These values led to the following rule set inputs:"
        $ht para
        $ht putln "<i>expectf</i> = [format %.2f $expectf]<br>"
        $ht putln "<i>needs</i> = [format %.2f $needs]"

        $ht para

        $ht putln "Group $g's neighborhood was controlled by"

        if {$controller ne ""} {
            $ht putln "actor "
            $ht link my://app/actor/$controller $controller
            $ht put "."
        } else {
            $ht putln "no actor."
        }

        $ht para
    }

    #-------------------------------------------------------------------
    # Rule Set: ENI:  Essential Non-Infrastructure Services
    #
    # Service Situation: effect of provision/non-provision of service
    # on a civilian group.

    typemethod ruleset {fdict} {
        dict with fdict {}
        
        # FIRST, get some data
        set case [GetCase $fdict]
        set cdict [GetCreditDict $g]

        dict set fdict case $case
        
        # ENI-1: Satisfaction Effects
        dam rule ENI-1-1 $fdict {
            $case eq "R-"
        } {
            # While ENI is less than required for CIV group g
            # Then for group g
            dam sat T $g \
                AUT [expr {[mag* $expectf XXS+] + [mag* $needs XXS-]}] \
                QOL [expr {[mag* $expectf XXS+] + [mag* $needs XXS-]}]

            # And for g with each actor a
            dict for {a credit} $cdict {
                if {$a eq $controller} {
                    dam vrel T $g $a $vmags(C,R-,$credit) \
                        "credit=$credit, has control"
                } else {
                    dam vrel T $g $a $vmags(NC,R-,$credit) \
                        "credit=$credit, no control"
                }
            }
        }

        dam rule ENI-1-2 $fdict {
            $case eq "E-"
        } {
            # While ENI is less than expected for CIV group g
            # Then for group g
            dam sat T $g \
                AUT [mag* $expectf XXS+] \
                QOL [mag* $expectf XXS+]

            # And for g with each actor a
            dict for {a credit} $cdict {
                if {$a eq $controller} {
                    dam vrel T $g $a $vmags(C,E-,$credit) \
                        "credit=$credit, has control"
                } else {
                    dam vrel T $g $a $vmags(NC,E-,$credit) \
                        "credit=$credit, no control"
                }
            }
        }

        dam rule ENI-1-3 $fdict {
            $case eq "E"
        } {
            # While ENI is as expected for CIV group g
            # Then for group g

            # Nothing

            # And for g with each actor a
            dict for {a credit} $cdict {
                if {$a eq $controller} {
                    dam vrel T $g $a $vmags(C,E,$credit) \
                        "credit=$credit, has control"
                } else {
                    dam vrel T $g $a $vmags(NC,E,$credit) \
                        "credit=$credit, no control"
                }
            }
        }

        dam rule ENI-1-4 $fdict {
            $case eq "E+"
        } {
            # While ENI is better than expected for CIV group g
            # Then for group g
            dam sat T $g \
                AUT [mag* $expectf XXS+] \
                QOL [mag* $expectf XXS+]

            # And for g with each actor a
            dict for {a credit} $cdict {
                if {$a eq $controller} {
                    dam vrel T $g $a $vmags(C,E+,$credit) \
                        "credit=$credit, has control"
                } else {
                    dam vrel T $g $a $vmags(NC,E+,$credit) \
                        "credit=$credit, no control"
                }
            }
        }
    }

    #-------------------------------------------------------------------
    # Helper Routines
    
    # GetCase fdict
    #
    # fdict   - The civgroups/service_g group dictionary
    #
    # Returns the case symbol, E+, E, E-, R-, for the provision
    # of service to the group.
    
    proc GetCase {fdict} {
        # FIRST, get the delta parameter
        set delta [parmdb get service.ENI.delta]

        # NEXT, compute the case
        dict with fdict {
            if {$actual < $required} {
                return R-
            } elseif {abs($actual - $expected) < $delta * $expected} {
                return E
            } elseif {$actual < $expected} {
                return E-
            } else {
                return E+
            }
        }
    }

    # GetCreditDict g
    #
    # g   - The civilian group
    #
    # Gets the credit symbol by actor.
    
    proc GetCreditDict {g} {
        set cdict [dict create]

        rdb eval {
            SELECT a, credit
            FROM service_ga WHERE g=$g
        } {
            dict set cdict $a [qcredit name $credit]
        }

        return $cdict
    }

}









