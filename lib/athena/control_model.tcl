#-----------------------------------------------------------------------
# TITLE:
#    control_model.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Neighborhood Control manager
#
#    This module is part of the political model.  It is responsible for
#    computing, at initialization and each tock, 
#
#    * The vertical relationship of each group with each actor.
#    * The support each actor has in each neighborhood.
#    * The influence of each actor in each neighborhood, relative to 
#      other actors.
#    * Which actor is in control in each neighborhood (if any).
#
#    In addition, this module is responsible for the bookkeeping when
#    control of a neighborhood shifts.  The relevant DAM rules are 
#    found in driver_control.tcl.
#
#-----------------------------------------------------------------------

snit::type ::athena::control_model {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of this type

    constructor {adb_} {
        set adb $adb_
    }

    #-------------------------------------------------------------------
    # Simulation Start

    # start
    #
    # This command is called when the scenario is locked to initialize
    # the model and populate the relevant tables.

    method start {} {
        log normal control_model "start"

        # FIRST, initialize the control tables
        $self PopulateNbhoodControl
        $self PopulateActorSupports
        $self PopulateActorInfluence

        log normal control_model "start complete"
    }

    # PopulateNbhoodControl
    #
    # The actor initially in control in the neighborhood is specified
    # in the nbhoods table.  This routine, consequently, simply 
    # populates the control_n table with that information.  Note
    # that "controller" is NULL if no actor controls the neighborhood.

    method PopulateNbhoodControl {} {
        $adb eval {
            INSERT INTO control_n(n, controller, since)
            SELECT n, controller, 0 FROM nbhoods
        }
    }

    # PopulateActorSupports
    #
    # Each actor can give his political support to himself, another actor,
    # or no one.  This routine populates the supports_na table with the 
    # default supports from actors.

    method PopulateActorSupports {} {
        $adb eval {
            INSERT INTO supports_na(n, a, supports)
            SELECT n, a, supports
            FROM nbhoods JOIN actors
        }
    }

    # PopulateActorInfluence
    #
    # Populates the influence_na table, and computes the
    # initial influence of each actor.
    
    method PopulateActorInfluence {} {
        # FIRST, populate the influence_na table
        $adb eval {
            INSERT INTO influence_na(n, a)
            SELECT n, a FROM nbhoods JOIN actors
        }

        # NEXT, compute the actor's initial influence.
        $self ComputeActorInfluence
    }


    #-------------------------------------------------------------------
    # Analysis
    #
    # These routines are called to determine the support and influence 
    # of every actor in every neighborhood.

    # analyze
    #
    # Update influence.

    method analyze {} {
        # FIRST, Compute each actor's support and influence in each 
        # neighborhood.
        $self ComputeActorInfluence
    }

    # ComputeActorInfluence
    #
    # Computes the support for and influence of each actor in
    # each neighborhood.

    method ComputeActorInfluence {} {
        # FIRST, set support and influence to 0.
        $adb eval {
            UPDATE influence_na
            SET direct_support = 0,
                support        = 0,
                influence      = 0;
   
            DELETE FROM support_nga;
        }

        # NEXT, get the total number of personnel in each neighborhood.
        array set tp [$adb eval {
            SELECT n, total(personnel)
            FROM force_ng
            GROUP BY n
        }]

        # NEXT, add the support of each group in each neighborhood
        # to each actor's direct support
        set minSupport [$adb parm get control.support.min]
        set vrelMin    [$adb parm get control.support.vrelMin]
        set Zsecurity  [$adb parm get control.support.Zsecurity]

        foreach {n g personnel security a vrel} [$adb eval {
            SELECT NG.n,
                   NG.g,
                   NG.personnel,
                   NG.security,
                   A.a,
                   V.vrel
            FROM force_ng  AS NG
            JOIN actors    AS A
            JOIN uram_vrel AS V ON (V.g=NG.g AND V.a=A.a)
            WHERE NG.personnel > 0
        }] {
            set factor [zcurve eval $Zsecurity $security]

            if {$vrel >= $vrelMin && $factor > 0.0} {
                let contrib {$vrel * $personnel * $factor / $tp($n) }
            } else {
                set contrib 0.0
            }

            $adb eval {
                UPDATE influence_na
                SET direct_support = direct_support + $contrib
                WHERE n=$n AND a=$a;

                INSERT INTO 
                support_nga(n,g,a,vrel,personnel,security,direct_support)
                VALUES($n,$g,$a,$vrel,$personnel,$security,$contrib);
            }
        }

        # NEXT, compute a's actual support, given the support relationships
        # in support_na.
        foreach {n g a direct_support supports} [$adb eval {
            SELECT G.n                  AS n,
                   G.g                  AS g,
                   G.a                  AS a,
                   G.direct_support     AS direct_support,
                   S.supports           AS supports
            FROM support_nga AS G
            JOIN supports_na AS S USING (n,a)
            WHERE S.supports IS NOT NULL
        }] {
            # FIRST, update the supported actor's support from this group.
            # Also, update the actor's actual support.
            $adb eval {
                UPDATE support_nga 
                SET support = support + $direct_support
                WHERE n=$n AND g=$g AND a=$supports;

                UPDATE influence_na
                SET support = support + $direct_support
                WHERE n=$n AND a=$supports;
            }
        }

        # NEXT, compute the total support for each neighborhood.
        # Exclude actors with less than the minimum required support.
        $adb eval {
            SELECT n, total(support) AS denom
            FROM influence_na
            WHERE support >= $minSupport
            GROUP BY n
        } {
            set nsupport($n) $denom
        }

        # NEXT, compute the contribution to influence of each group
        foreach n [array names nsupport] {
            set denom $nsupport($n)

            if {$denom > 0} {
                $adb eval {
                    UPDATE support_nga
                    SET influence = support/$denom
                    WHERE n=$n
                }
            }
        }

        # NEXT, compute the influence of each actor in the 
        # neighborhood.  The actor requires a minimum level of
        # support to have any influence.

        $adb eval {
            SELECT n, a, support FROM influence_na
        } {
            if {![info exists nsupport($n)] || $nsupport($n) == 0} {
                # Nobody has any support
                set influence 0.0
            } elseif {$support < $minSupport} {
                # Actor has too little support to be influential
                set influence 0.0
            } else {
                # At least one actor has support in the neighborhood
                set influence [expr {double($support) / $nsupport($n)}]
            }

            $adb eval {
                UPDATE influence_na
                SET influence=$influence
                WHERE n=$n AND a=$a
            }
        }
    }


    #-------------------------------------------------------------------
    # Assessment
    #
    # These routines are called during the strategy tock to determine
    # who's in control before strategy execution

    # assess
    #
    # Looks for shifts of control in all neighborhoods, and takes the
    # action that follows from that.
    
    method assess {} {
        # FIRST, get the actor in control of each neighborhood,
        # and their influence, and then see if control has shifted
        # for that neighborhood.
        #
        # Note that a neighborhood can be in a state of chaos; the
        # controller will be NULL and his influence 0.0.

        foreach {n controller influence} [$adb eval {
            SELECT C.n                        AS n,
                   C.controller               AS controller,
                   COALESCE(I.influence, 0.0) AS influence
            FROM control_n               AS C
            LEFT OUTER JOIN influence_na AS I
            ON (I.n=C.n AND I.a=C.controller)
        }] {
            $self DetectControlShift $n $controller $influence
        }
    }

    # DetectControlShift n controller cInfluence
    #
    # n           - A neighborhood
    # controller  - The actor currently in control, or ""
    # cInfluence  - The current controller's influence in n, or 0 if none.
    # 
    # Determines whether there is a shift in control in the neighborhood.

    method DetectControlShift {n controller cInfluence} {
        # FIRST, get the actor with the most influence in the neighborhood,
        # and see how much it is.
        $adb eval {
            SELECT a         AS maxA,
                   influence AS maxInf
            FROM influence_na
            WHERE n=$n
            ORDER BY influence DESC
            LIMIT 1
        } {}

        # NEXT, if the current controller has the most influence in the
        # neighborhood, then he is still in control.  Control has not
        # shifted; we're done.

        if {$cInfluence >= $maxInf} {
            return
        }

        # NEXT, maxA is NOT the current controller.  If he has more than
        # the control threshold, he's the new controller; control has
        # shifted.

        if {$maxInf > [$adb parm get control.threshold]} {
            $self ShiftControl $n $maxA $controller
            return
        }

        # NEXT, actor maxA has more influence than the current controller,
        # but not enough to actually be "in control".  We now have a
        # state of chaos.  Unless we were already in a state of chaos,
        # control has shifted.

        if {$controller ne ""} {
            $self ShiftControl $n "" $controller
            return
        }

        # NEXT, we were already in a state of chaos; control has not
        # shifted.
        return
    }

    # ShiftControl n cNew cOld
    #
    # n      - A neighborhood
    # cNew   - The new controller, or ""
    # cOld   - The old controller, or ""
    #
    # Handles the shift in control from cOld to cNew in n.
    
    method ShiftControl {n cNew cOld} {
        log normal control_model "shift in $n to <$cNew> from <$cOld>"

        if {$cNew eq ""} {
            $adb sigevent log 1 control "
                Actor {actor:$cOld} has lost control of {nbhood:$n}; 
                no actor has control.
            " $n $cOld
        } elseif {$cOld eq ""} {
            $adb sigevent log 1 control "
                Actor {actor:$cNew} has won control of {nbhood:$n}; 
                no actor had been in control previously.
            " $n $cNew 
        } else {
            $adb sigevent log 1 control "
                Actor {actor:$cNew} has won control of {nbhood:$n}
                from {actor:$cOld}.
            " $n $cNew $cOld
        }

        # FIRST, update control_n.
        $adb eval {
            UPDATE control_n 
            SET controller = nullif($cNew,''),
                since      = now()
            WHERE n=$n;
        }

        # NEXT, Get a driver ID for this event with signature $n.
        # TBD: This vrel change is unique; no other drivers do this
        # kind of thing.  But we should probably move it to the 
        # driver_control module anyway.
        set driver_id [$adb ruleset getid CONTROL [list n $n]]

        # NEXT, set the vrel baseline to the current level for 
        # all non-empty civ groups in n.
        foreach {g a vrel} [$adb eval {
            SELECT V.g,
            V.a,
            V.vrel
            FROM uram_vrel AS V
            JOIN civgroups AS C USING (g)
            JOIN demog_g AS D USING (g)
            WHERE C.n=$n AND D.population > 0
        }] {
            # TBD: We might want a routine to do this in bulk.
            $adb aram vrel bset $driver_id $g $a $vrel
        }


        # NEXT, invoke the CONTROL rule set for this transition.
        dict set fdict n $n
        dict set fdict a $cOld
        dict set fdict b $cNew

        $adb ruleset CONTROL assess $fdict
    }
}

