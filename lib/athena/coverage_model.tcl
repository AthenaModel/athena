#-----------------------------------------------------------------------
# TITLE:
#    coverage_model.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Activity Coverage model 
#
#    This module is responsible for computing activity coverage.
#
#-----------------------------------------------------------------------

snit::type ::athena::coverage_model {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Variables

    # strictSecurity: caches strict security level by security level
    variable strictSecurity -array {}

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of this type

    constructor {adb_} {
        set adb $adb_

        # NEXT, store strict security.
        for {set i -100} {$i <= 100} {incr i} {
            set strictSecurity($i) [qsecurity strictvalue $i]
        }    
    }

    # start
    #
    # Initializes the module before the simulation first starts to run.

    method start {} {
        # FIRST, Initialize activity_nga.
        $adb eval {
            DELETE FROM activity_nga;
        }

        # NEXT, Add groups and activities for each neighborhood.
        $adb eval {
            SELECT n, g, A.a AS a
            FROM nbhoods 
            JOIN groups 
            JOIN activity_gtype AS A USING (gtype)
            WHERE A.a != 'NONE'
        } {
            $adb eval {
                INSERT INTO activity_nga(n,g,a)
                VALUES($n,$g,$a)
            }
        }
    }


    #-------------------------------------------------------------------
    # Analysis: Coverage


    # analyze
    #
    # Computes activity coverage given staffing and activity
    # effectiveness. Must follow [security analyze].

    method analyze {} {
        $adb profile 2 $self InitializeActivityTable
        $adb profile 2 $self ComputeActivityPersonnel
        $adb profile 2 $self ComputeForceActivityFlags
        $adb profile 2 $self ComputeOrgActivityFlags
        $adb profile 2 $self ComputeCoverage
    }

    # InitializeActivityTable
    #
    # Initializes the activity_nga table prior to computing 
    # FRC and ORG activities.

    method InitializeActivityTable {} {
        # FIRST, clear the previous results.
        $adb eval {
            UPDATE activity_nga
            SET security_flag = 0,
                can_do        = 1,
                nominal       = 0,
                effective     = 0,
                coverage      = 0.0;
        }
    }

    # ComputeActivityPersonnel
    #
    # Computes the activity personnel for FRC and ORG groups.

    method ComputeActivityPersonnel {} {
        # FIRST, Run through all of the deployed units and compute
        # nominal and active personnel.
        $adb eval {
            SELECT n, 
                   g, 
                   a,
                   total(personnel) AS nominal,
                   gtype
            FROM units
            JOIN activity_gtype USING (a,gtype)
            WHERE a != 'NONE'
            AND personnel > 0
            GROUP BY n,g,a
        } {
            $adb eval {
                UPDATE activity_nga
                SET nominal = $nominal
                WHERE n=$n AND g=$g AND a=$a;
            }
        }
    }

    # ComputeForceActivityFlags
    #
    # Computes the effectiveness of force activities based on security.

    method ComputeForceActivityFlags {} {
        # FIRST, load up the min security values into an array
        # NOTE: this is for performance reasons
        $adb eval {
            SELECT a
            FROM activity_gtype
            WHERE gtype = 'FRC' AND a != 'NONE'
        } {
            set minFrcSecurity($a) \
                [qsecurity value \
                    [$adb parm get activity.FRC.$a.minSecurity]]
        }
        
        # NEXT, clear security flags when security is too low
        $adb eval {
            SELECT activity_nga.n      AS n,
                   activity_nga.g      AS g,
                   activity_nga.a      AS a,
                   force_ng.security   AS security
            FROM activity_nga 
            JOIN force_ng USING (n, g)
            JOIN frcgroups USING (g)
            WHERE activity_nga.nominal > 0
        } {
            # Compare using the symbolic values.
            if {$strictSecurity($security) >= $minFrcSecurity($a)} {
                set security_flag 1
            } else {
                set security_flag 0
            }

            $adb eval {
                UPDATE activity_nga
                SET security_flag = $security_flag
                WHERE n=$n AND g=$g AND a=$a
            }
        }
    }

    # ComputeOrgActivityFlags
    #
    # Computes effectiveness of ORG activities based on security and mood.

    method ComputeOrgActivityFlags {} {
        # FIRST, Clear security_flag when security is too low.
        $adb eval {
            SELECT activity_nga.n      AS n,
                   activity_nga.g      AS g,
                   activity_nga.a      AS a,
                   orggroups.orgtype   AS orgtype,
                   force_ng.security   AS security
            FROM activity_nga 
            JOIN force_ng USING (n, g)
            JOIN orggroups USING (g)
        } {
            # security
            set minSecurity \
                [qsecurity value [$adb parm get \
                    activity.ORG.$a.minSecurity.$orgtype]]

            set security [qsecurity strictvalue $security]

            if {$security < $minSecurity} {
                set security_flag 0
            } else {
                set security_flag 1
            }

            # Save values
            $adb eval {
                UPDATE activity_nga
                SET security_flag = $security_flag
                WHERE n=$n AND g=$g AND a=$a
            }
        }
    }




    # ComputeCoverage
    #
    # Computes activity coverage for all activities, both FRC and ORG>

    method ComputeCoverage {} {
        # FIRST, compute effective staff for each activity
        $adb eval {
            UPDATE activity_nga
            SET effective = nominal
            WHERE can_do AND security_flag
        }

        # NEXT, compute coverage
        $adb eval {
            SELECT activity_nga.n      AS n,
                   activity_nga.g      AS g,
                   activity_nga.a      AS a,
                   effective           AS personnel,
                   demog_n.population  AS population,
                   groups.gtype        AS gtype
            FROM activity_nga JOIN demog_n JOIN groups
            WHERE demog_n.n=activity_nga.n
            AND   activity_nga.g=groups.g
            AND   effective > 0
        } {
            set cov [coverage eval \
                         [$adb parm get activity.$gtype.$a.coverage] \
                         $personnel                               \
                         $population]

            $adb eval {
                UPDATE activity_nga
                SET coverage = $cov
                WHERE n=$n AND g=$g AND a=$a
            }
        }
    }
}


