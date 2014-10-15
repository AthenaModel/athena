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

