#-----------------------------------------------------------------------
# TITLE:
#    ruleset_abservice.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena(n): Abstract Infrastructure Services ruleset
#
# FIRING DICTIONARY:
#    dtype       - The driver type (ENERGY, WATER, etc...)
#    g           - The civilian group receiving the services
#    actual      - The actual level of service (ALOS)
#    required    - The required level of service (RLOS)
#    expected    - The expected level of service (ELOS)
#    expectf     - The expectations factor
#    needs       - The needs factor
#    case        - The case: E+, E, E-, R-
#
# Four possible cases of ALOS:
#    R-  - ALOS is less than required.
#    E-  - ALOS is at least the required amount, but less than
#          expected.
#    E   - ALOS is approximately the same as expected
#    E+  - ALOS is more than expected.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# abservice

oo::class create ::athena::ruleset_abservice {
    superclass ::athena::ruleset

    #-------------------------------------------------------------------
    # Public Methods

    # assess
    #
    # Monitors the level of service provided to civilian groups.  The
    # rule firing dictionary contains the following data:
    #

    method assess {} {
        set s [my name]

        # NEXT, call the abstract services rule sets.
        [my adb] eval "
            SELECT s          AS dtype,
                   controller AS a,
                   g          AS g, 
                   actual     AS actual, 
                   required   AS required, 
                   expected   AS expected, 
                   expectf    AS expectf, 
                   needs      AS needs
            FROM local_civgroups 
            JOIN demog_g USING (g)
            JOIN service_sg USING (g)
            JOIN control_n ON (local_civgroups.n = control_n.n)
            WHERE s='$s'
            AND   demog_g.population > 0
            ORDER BY g
        " gdata {
            unset -nocomplain gdata(*)

            set dtype $gdata(dtype)

            set fdict [array get gdata]

            if {![my isactive]} {
                [my adb] log warning $dtype "driver type has been deactivated"
                continue
            }

            bgcatch {
                [my adb] log detail $dtype $fdict
                my ruleset $fdict
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
        set g $signature
        return "Provision of [my name] services to $g"
    }

    # narrative fdict
    #
    # fdict - Firing dictionary; see rulesets, below.
    #
    # Produces a one-line narrative text string for a given rule firing

    method narrative {fdict} {
        dict with fdict {}

        return "{group:$g} receives [my name] services (case $case)"
    }
    
    # detail fdict 
    #
    # fdict - Firing dictionary; see rulesets, below.
    # ht    - An htools(n) buffer
    #
    # Produces a narrative HTML paragraph including all fdict information.

    method detail {fdict ht} {
        dict with fdict {}

        $ht putln "Civilian group\n"
        $ht link /app/group/$g $g
        $ht putln "received $dtype services at an actual level of"
        $ht putln "[format %.2f $actual], that is, at"
        $ht putln "[string trim [percent $actual]] of the saturation level"
        $ht putln "of service.  Group $g requires a level of at least"
        $ht putln "[format %.2f $required], and expected a level of"
        $ht putln "[format %.2f $expected]."
        $ht para
        if {$a ne ""} {
            $ht putln "Actor\n"
            $ht link /app/actor/$a $a
            $ht putln "is in control of the neighborhood, so "
            $ht link /app/group/$g $g
            $ht putln "'s relationship with $a is affected."
            $ht para
        } else {
            $ht putln "There is no actor in control of the neighborhood,"
            $ht putln "so there are no vertical relationships affected."
        }

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
    # Helper Methods
    
    # GetCase fdict
    #
    # fdict   - The civgroups/service_sg group dictionary
    #
    # Returns the case symbol, E+, E, E-, R-, for the provision
    # of service to the group.
    
    method GetCase {fdict} {
        dict with fdict {}
        # FIRST, get the delta parameter
        set delta [[my adb] parm get service.$dtype.delta]

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
::athena::ruleset define ENERGY {g} {
    superclass ::athena::ruleset_abservice

    metadict rulename {
        ENERGY-1-1    "Energy services are less than required"
        ENERGY-1-2    "Energy services are less than expected"
        ENERGY-1-3    "Energy services are as expected"
        ENERGY-1-4    "Energy services are better than expected"
    }

    method ruleset {fdict} {
        dict with fdict {}
        
        # FIRST, get some data
        set case [my GetCase $fdict]

        dict set fdict case $case
        
        # ENERGY-1: Satisfaction Effects
        my rule ENERGY-1-1 $fdict {
            $case eq "R-"
        } {
            # While ENERGY is less than required for CIV group g
            # Then for group g
            my sat T $g \
                AUT [expr {[my mag* $expectf XXS+] + [my mag* $needs XXS-]}] \
                QOL [expr {[my mag* $expectf XXS+] + [my mag* $needs XXS-]}]

            if {$a ne ""} {
                my vrel T $g $a L-
            }
        }

        my rule ENERGY-1-2 $fdict {
            $case eq "E-"
        } {
            # While ENERGY is less than expected for CIV group g
            # Then for group g
            my sat T $g \
                AUT [my mag* $expectf XXS+] \
                QOL [my mag* $expectf XXS+]

            if {$a ne ""} {
                my vrel T $g $a M-
            }
        }

        my rule ENERGY-1-3 $fdict {
            $case eq "E"
        } {
            # While ENERGY is as expected for CIV group g
            # Then for group g

            # Nothing
        }

        my rule ENERGY-1-4 $fdict {
            $case eq "E+"
        } {
            # While ENERGY is better than expected for CIV group g
            # Then for group g
            my sat T $g \
                AUT [my mag* $expectf XXS+] \
                QOL [my mag* $expectf XXS+]

            if {$a ne ""} {
                my vrel T $g $a XL+
            }
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: WATER:  Provision of Potable WATER to civilians
#
# Service Situation: effect of provision/non-provision of service
# on a civilian group.

::athena::ruleset define WATER {g} {
    superclass ::athena::ruleset_abservice

    metadict rulename {
        WATER-1-1    "Access to potable water is less than required"
        WATER-1-2    "Access to potable water is less than expected"
        WATER-1-3    "Access to potable water is as expected"
        WATER-1-4    "Access to potable water is better than expected"
    }

    method ruleset {fdict} {
        dict with fdict {}
        
        # FIRST, get some data
        set case [my GetCase $fdict]

        dict set fdict case $case
        
        # WATER-1: Satisfaction Effects
        my rule WATER-1-1 $fdict {
            $case eq "R-"
        } {
            # While WATER is less than required for CIV group g
            # Then for group g
            my sat T $g \
                AUT [expr {[my mag* $expectf XS+] + [my mag* $needs XS-]}] \
                QOL [expr {[my mag* $expectf L+]  + [my mag* $needs L-]}]

            if {$a ne ""} {
                my vrel T $g $a L-
            }
        }

        my rule WATER-1-2 $fdict {
            $case eq "E-"
        } {
            # While WATER is less than expected for CIV group g
            # Then for group g
            my sat T $g \
                AUT [my mag* $expectf XXS+] \
                QOL [my mag* $expectf XS+]

            if {$a ne ""} {
                my vrel T $g $a M-
            }
        }

        my rule WATER-1-3 $fdict {
            $case eq "E"
        } {
            # While WATER is as expected for CIV group g
            # Then for group g

            # Nothing
        }

        my rule WATER-1-4 $fdict {
            $case eq "E+"
        } {
            # While WATER is better than expected for CIV group g
            # Then for group g
            my sat T $g \
                AUT [my mag* $expectf XXS+] \
                QOL [my mag* $expectf XXS+]

            if {$a ne ""} {
                my vrel T $g $a XL+
            }
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: TRANSPORT:  Provision of transportation services to civilians
#
# Service Situation: effect of provision/non-provision of service
# on a civilian group.

::athena::ruleset define TRANSPORT {g} {
    superclass ::athena::ruleset_abservice
    
    metadict rulename {
        TRANSPORT-1-1 "Transportation services are less than required"
        TRANSPORT-1-2 "Transportation services are less than expected"
        TRANSPORT-1-3 "Transportation services are as expected"
        TRANSPORT-1-4 "Transportation services are better than expected"
    }

    method ruleset {fdict} {
        dict with fdict {}
        
        # FIRST, get some data
        set case [my GetCase $fdict]

        dict set fdict case $case
        
        # TRANSPORT-1: Satisfaction Effects
        my rule TRANSPORT-1-1 $fdict {
            $case eq "R-"
        } {
            # While TRANSPORT is less than required for CIV group g
            # Then for group g
            my sat T $g \
                AUT [expr {[my mag* $expectf XXS+] + [my mag* $needs XXS-]}] \
                QOL [expr {[my mag* $expectf XXS+] + [my mag* $needs XXS-]}]

            if {$a ne ""} {
                my vrel T $g $a L-
            }
        }

        my rule TRANSPORT-1-2 $fdict {
            $case eq "E-"
        } {
            # While TRANSPORT is less than expected for CIV group g
            # Then for group g
            my sat T $g \
                AUT [my mag* $expectf XXS+] \
                QOL [my mag* $expectf XXS+]

            if {$a ne ""} {
                my vrel T $g $a M-
            }
        }

        my rule TRANSPORT-1-3 $fdict {
            $case eq "E"
        } {
            # While TRANSPORT is as expected for CIV group g
            # Then for group g

            # Nothing 
        }

        my rule TRANSPORT-1-4 $fdict {
            $case eq "E+"
        } {
            # While TRANSPORT is better than expected for CIV group g
            # Then for group g
            my sat T $g \
                AUT [my mag* $expectf XS+] \
                QOL [my mag* $expectf XS+]

            if {$a ne ""} {
                my vrel T $g $a XL+
            }
        }
    }
}





