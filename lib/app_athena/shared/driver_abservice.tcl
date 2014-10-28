#-----------------------------------------------------------------------
# TITLE:
#    driver_abservice.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    Athena Driver Assessment Model (DAM): 
#    Abstract Infrastructure Services
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# abservice

snit::type driver::abservice {
    pragma -hasinstances 0
    #-------------------------------------------------------------------
    # Look-up tables

    # case: R-, E-, E, E+
    #
    #   R-  - actual LOS is less than required.
    #   E-  - actual LOS is at least the required amount, but less than
    #         expected.
    #   E   - actual LOS is approximately the same as expected
    #   E+  - actual LOS is more than expected.
    #

    typevariable vmags -array {
        E+  XL+
        E   L+
        E-  M-
        R-  L-
    }


    #-------------------------------------------------------------------
    # Public Typemethods

    # assess
    #
    # Monitors the level of service provided to civilian groups.  The
    # rule firing dictionary contains the following data:
    #
    #   dtype       - The driver type (ENERGY, WATER, etc...)
    #   g           - The civilian group receiving the services
    #   actual      - The actual level of service (ALOS)
    #   required    - The required level of service (RLOS)
    #   expected    - The expected level of service (ELOS)
    #   expectf     - The expectations factor
    #   needs       - The needs factor
    #   case        - The case: E+, E, E-, R-
    
    typemethod assess {} {
        set slist [eabservice names]

        # NEXT, call the abstract services rule sets.
        rdb eval "
            SELECT s AS dtype, g, actual, required, expected, expectf, needs
            FROM local_civgroups 
            JOIN demog_g USING (g)
            JOIN service_sg USING (g)
            JOIN control_n ON (local_civgroups.n = control_n.n)
            WHERE s IN ('[join $slist ',']')
            AND   demog_g.population > 0
            ORDER BY g
        " gdata {
            unset -nocomplain gdata(*)

            set dtype $gdata(dtype)

            set fdict [array get gdata]

            if {![dam isactive $dtype]} {
                log warning $dtype "driver type has been deactivated"
                continue
            }

            bgcatch {
                log detail $dtype $fdict
                driver::$dtype ruleset $fdict
            }
        }
    }

    typemethod define {name defscript} {
        set footer "
            delegate typemethod sigline   using {driver::abservice %m $name}
            delegate typemethod narrative using {driver::abservice %m}
            delegate typemethod detail    using {driver::abservice %m}

            typeconstructor {
                namespace path ::driver::abservice::
            }
        "

        driver type define $name {g} "$defscript\n$footer" 
    }
    #-------------------------------------------------------------------
    # Narrative Type Methods

    # sigline signature
    #
    # signature - The driver signature
    #
    # Returns a one-line description of the driver given its signature
    # values.

    typemethod sigline {dtype signature} {
        set g $signature
        return "Provision of $dtype services to $g"
    }

    # narrative fdict
    #
    # fdict - Firing dictionary; see rulesets, below.
    #
    # Produces a one-line narrative text string for a given rule firing

    typemethod narrative {fdict} {
        dict with fdict {}

        return "{group:$g} receives $dtype services (case $case)"
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
        $ht putln "received $dtype services at an actual level of"
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
    }

    #-------------------------------------------------------------------
    # Helper Routines
    
    # GetCase fdict
    #
    # fdict   - The civgroups/service_sg group dictionary
    #
    # Returns the case symbol, E+, E, E-, R-, for the provision
    # of service to the group.
    
    proc GetCase {fdict} {
        dict with fdict {}
        # FIRST, get the delta parameter
        set delta [parmdb get service.$dtype.delta]

        # NEXT, compute the case
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

#-------------------------------------------------------------------
# Rule Set: ENERGY:  Provision of ENERGY services to civilians
#
# Service Situation: effect of provision/non-provision of service
# on a civilian group.

driver::abservice define ENERGY {
    typemethod ruleset {fdict} {
        dict with fdict {}
        
        # FIRST, get some data
        set case [GetCase $fdict]

        dict set fdict case $case
        
        # ENERGY-1: Satisfaction Effects
        dam rule ENERGY-1-1 $fdict {
            $case eq "R-"
        } {
            # While ENERGY is less than required for CIV group g
            # Then for group g
            dam sat T $g \
                AUT [expr {[mag* $expectf XXS+] + [mag* $needs XXS-]}] \
                QOL [expr {[mag* $expectf XXS+] + [mag* $needs XXS-]}]
        }

        dam rule ENERGY-1-2 $fdict {
            $case eq "E-"
        } {
            # While ENERGY is less than expected for CIV group g
            # Then for group g
            dam sat T $g \
                AUT [mag* $expectf XXS+] \
                QOL [mag* $expectf XXS+]
        }

        dam rule ENERGY-1-3 $fdict {
            $case eq "E"
        } {
            # While ENERGY is as expected for CIV group g
            # Then for group g

            # Nothing
        }

        dam rule ENERGY-1-4 $fdict {
            $case eq "E+"
        } {
            # While ENERGY is better than expected for CIV group g
            # Then for group g
            dam sat T $g \
                AUT [mag* $expectf XXS+] \
                QOL [mag* $expectf XXS+]
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: WATER:  Provision of WATER services to civilians
#
# Service Situation: effect of provision/non-provision of service
# on a civilian group.

driver::abservice define WATER {
    typemethod ruleset {fdict} {
        dict with fdict {}
        
        # FIRST, get some data
        set case [GetCase $fdict]

        dict set fdict case $case
        
        # WATER-1: Satisfaction Effects
        dam rule WATER-1-1 $fdict {
            $case eq "R-"
        } {
            # While WATER is less than required for CIV group g
            # Then for group g
            dam sat T $g \
                AUT [expr {[mag* $expectf XXS+] + [mag* $needs XXS-]}] \
                QOL [expr {[mag* $expectf XXS+] + [mag* $needs XXS-]}]
        }

        dam rule WATER-1-2 $fdict {
            $case eq "E-"
        } {
            # While WATER is less than expected for CIV group g
            # Then for group g
            dam sat T $g \
                AUT [mag* $expectf XXS+] \
                QOL [mag* $expectf XXS+]
        }

        dam rule WATER-1-3 $fdict {
            $case eq "E"
        } {
            # While WATER is as expected for CIV group g
            # Then for group g

            # Nothing
        }

        dam rule WATER-1-4 $fdict {
            $case eq "E+"
        } {
            # While WATER is better than expected for CIV group g
            # Then for group g
            dam sat T $g \
                AUT [mag* $expectf XXS+] \
                QOL [mag* $expectf XXS+]
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: TRANSPORT:  Provision of transportation services to civilians
#
# Service Situation: effect of provision/non-provision of service
# on a civilian group.

driver::abservice define TRANSPORT {
    typemethod ruleset {fdict} {
        dict with fdict {}
        
        # FIRST, get some data
        set case [GetCase $fdict]

        dict set fdict case $case
        
        # TRANSPORT-1: Satisfaction Effects
        dam rule TRANSPORT-1-1 $fdict {
            $case eq "R-"
        } {
            # While TRANSPORT is less than required for CIV group g
            # Then for group g
            dam sat T $g \
                AUT [expr {[mag* $expectf XXS+] + [mag* $needs XXS-]}] \
                QOL [expr {[mag* $expectf XXS+] + [mag* $needs XXS-]}]
        }

        dam rule TRANSPORT-1-2 $fdict {
            $case eq "E-"
        } {
            # While TRANSPORT is less than expected for CIV group g
            # Then for group g
            dam sat T $g \
                AUT [mag* $expectf XXS+] \
                QOL [mag* $expectf XXS+]
        }

        dam rule TRANSPORT-1-3 $fdict {
            $case eq "E"
        } {
            # While TRANSPORT is as expected for CIV group g
            # Then for group g

            # Nothing
        }

        dam rule TRANSPORT-1-4 $fdict {
            $case eq "E+"
        } {
            # While TRANSPORT is better than expected for CIV group g
            # Then for group g
            dam sat T $g \
                AUT [mag* $expectf XXS+] \
                QOL [mag* $expectf XXS+]
        }
    }
}





