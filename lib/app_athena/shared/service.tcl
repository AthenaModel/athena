#-----------------------------------------------------------------------
# TITLE:
#    service.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Service Manager
#
#    This module is the API used by tactics to fund services
#    to civilian groups.  At present, the only service
#    defined is Essential Non-Infrastructure Services (ENI), 
#    aka "governmental services".  The ENI service allows an actor
#    to pump money into neighborhoods, thus raising group moods
#    and vertical relationships.
#
#-----------------------------------------------------------------------

snit::type service {
    # Make it a singleton
    pragma -hasinstances no
 
    #-------------------------------------------------------------------
    # sqlsection(i)
    #
    # The following variables and routines implement the module's 
    # sqlsection(i) interface.

    # sqlsection title
    #
    # Returns a human-readable title for the section

    typemethod {sqlsection title} {} {
        return "service(sim)"
    }

    # sqlsection schema
    #
    # Returns the section's persistent schema definitions, if any.

    typemethod {sqlsection schema} {} {
        return ""
    }

    # sqlsection tempschema
    #
    # Returns the section's temporary schema definitions, if any.

    typemethod {sqlsection tempschema} {} {
        return \
            [readfile [file join $::app_athena_shared::library service_temp.sql]]
    }

    # sqlsection functions
    #
    # Returns a dictionary of function names and command prefixes

    typemethod {sqlsection functions} {} {
        return ""
    }

    # start
    #
    # This routine is called when the scenario is locked and the 
    # simulation starts.  It populates the service_* tables.

    typemethod start {} {
        # FIRST, populate the service_ga table with the defaults.
        rdb eval {
            -- Populate service_ga table
            INSERT INTO service_ga(g,a)
            SELECT C.g, A.a
            FROM local_civgroups AS C
            JOIN actors    AS A;
        }

        # NEXT, populate the service_sg table
        foreach s [eservice names] {
            rdb eval {
                SELECT g FROM local_civgroups
            } {
                rdb eval {
                    -- Populate service_sg table
                    INSERT INTO service_sg(s,g) 
                    VALUES($s,$g);
                }
           }
        }

        # NEXT, initialize abstract services
        set aisnames [eabservice names]

        foreach {g urb s} [rdb eval {
            SELECT G.g                AS g,
                   G.urbanization     AS urb,
                   SG.s               AS s
            FROM local_civgroups AS G 
            JOIN demog_g    AS D   ON (D.g = G.g)
            JOIN service_sg AS SG  ON (SG.g = G.g)
        }] {

            if {$s ni $aisnames} {
                continue
            }

            # NEXT, defaults for actual, required and expected
            set actual [parm get service.$s.actual.$urb]
            set required [parm get service.$s.required.$urb]

            rdb eval {
                UPDATE service_sg
                SET actual=$actual,
                    new_actual=$actual,
                    required=$required,
                    expected=$actual
                WHERE g=$g AND s=$s
            }
        }
    }

    # actual n s los
    #
    # nlist - a list of neighborhoods
    # s     - an abstract infrastructure service; eabservice(n) name
    # los   - the actual level of service for s
    #
    # This method sets the actual level of service 's' to los for
    # each group in neighborhood n.  Satisfaction effects are then
    # based on this level of service when the rule set for this 
    # service fires.

    typemethod actual {nlist s los} {
        # FIRST, los must be in the range [0.0, 1.0]
        require {$los >= 0.0 && $los <= 1.0} \
            "Invalid LOS: $los, must be between 0.0 and 1.0 inclusive."

        # NEXT, grab all groups in the neighborhoods and set
        # their ALOS
        set glist [list]
        foreach n $nlist {
            lappend glist {*}[civgroup gIn $n]
        }

        set gclause "g IN ('[join $glist {','}]') AND s='$s'"

        rdb eval "
            UPDATE service_sg
            SET new_actual = $los
            WHERE $gclause
        "
    }

    # expectf  pdict
    #
    # pdict  - dictionary of data needed to compute expectf
    #
    # Computes the expectations factor given the dictionary of data.
    # Each specific service (ENI, ENERGY, etc...) is responsible for
    # supplying the requisite data.
    #
    # The dictionary must have at least:
    #
    #    gainExpect   - the gain on the expectations factor 
    #    Ag           - the actual level of service 
    #    Xg           - the expected level of service

    typemethod expectf {pdict} {
        # FIRST, extract data from the dictionary
        dict with pdict {}

        # NEXT, the expectations factor
        let expectf {$gainExpect * (min(1.0,$Ag) - $Xg)}

        if {abs($expectf) < 0.01} {
            set expectf 0.0
        }

        return $expectf
    }

    # needs   pdict
    # 
    # pdict   - a dictionary of data needed to compute needs
    #
    # Computes the needs factor given the dictionary of data.
    # Each specific service (ENI, ENERGY, etc...) is responsible
    # for aupplying the requisite data.
    #
    # The dictionary must have at least:
    #
    #    gainNeeds   - the gain on the needs factor
    #    Ag          - the actual level of service
    #    Rg          - the required level of service

    typemethod needs {pdict} {
        # FIRST, extract data from the dictionary
        dict with pdict {}

        # NEXT, the needs factor
        if {$Ag >= $Rg} {
            set needs 0.0
        } elseif {$Ag == 0.0} {
            set needs 1.0
        } else {
            # $Ag < $Rg
            let needs {($Rg - $Ag)/$Rg}
        } 

        let needs {$needs * $gainNeeds}

        if {abs($needs) < 0.01} {
            set needs 0.0
        }

        return $needs
    }


}

