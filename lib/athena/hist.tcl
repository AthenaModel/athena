#-----------------------------------------------------------------------
# TITLE: 
#    hist.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#   athena(n): Results history manager
#
# History is saved for t=0 on lock and for t > 0 at the end of each
# time-step's activities.  [hist tick] saves all history that is
# saved at every tick; [hist econ] saves all history that is saved
# at each econ tock.
#
#-----------------------------------------------------------------------

snit::type ::athena::hist {
    #-------------------------------------------------------------------
    # Type variables

    # histVars
    #
    # Dictionary of history variables and their keys along with some meta
    # data associated with each variable. These correspond to the 
    # hist_* tables.

    typevariable histVars {
        aam_battle {
            "Attrition History"
            keys {
                n  "Neighborhood"
                f  "Group"
                g  "Against"
            }
        }

        activity_nga {
            "Neighborhood Activities"
            keys {
                n  "Neighborhood"
                g  "Group"
                a  "Activity"
            }
        }

        control {
            "Neighborhood Control"
            keys {
                n "Neighborhood"
            }
        }

        coop {
            "Civilian Group Cooperation"
            keys {
                f {Civilian Group}
                g {Force Group}
            }
        }

        deploy_ng {
            "Force/Org Group Deployments"
            keys {
                n "Neighborhood"
                g "Group"
            }
        }

        econ {
            "Economy"
            keys {}
        }
        
        flow {
            "Civilian Group Population Flow"
            keys {
                f "From Group"
                g "To Group"
            }
        }

        hrel {
            "Horizontal Relationships"
            keys {
                f "Group" 
                g "With Group"
            }
        }

        mood  {
            "Civilian Group Mood"
            keys {
                g "Group"
            }
        }

        nbmood {
            "Neighborhood Mood"
            keys {
                n "Neighborhood"
            }
        }

        nbur {
            "Neighborhood Unemployment"
            keys {
                n "Neighborhood"
            }
        }

        npop {
            "Neighborhood Population"
            keys {
                n "Neighborhood"
            }
        }

        plant_a {
            "Goods Plants by Owner"
            keys {
                a "Owner"
            }
        }

        plant_n {
            "Goods Plants by Neighborhood"
            keys {
                n "Neighborhood"
            }
        }

        plant_na {
            "Goods Plants by Nbhood/Owner"
            keys {
                n "Neighborhood"
                a "Owner"
            }
        }

        pop {
            "Civilian Group Population"
            keys {
                g "Group"
            }
        }

        sat {
            "Civilian Group Satisfaction"
            keys {
                g "Group"
                c "Concern"
            }
        }

        security {
            "Neighborhood/Group Security"
            keys {
                n "Neighborhood"
                g "Group"
            }
        }

        service_sg {
            "Service Levels"
            keys {
                s "Service"
                g "Group"
            }
        }

        support {
            "Political Support"
            keys {
                n "Neighborhood"
                a "Actor"
            }
        }

        volatility {
            "Neighborhood Volatility"
            keys {
                n "Neighborhood"
            }
        }

        vrel {
            "Vertical Relationships"
            keys {
                g "Group"
                a "Actor"
            }
        }
    }    

    #-------------------------------------------------------------------
    # Components

    component adb  ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Construcutor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of this type.

    constructor {adb_} {
        set adb $adb_
    }

    # start
    #
    # Saves time 0 history upon simulation start 

    method start {} {
        $self tick
        $self econ
    }

    # meta huddle
    #
    # Returns meta data about all history variables as huddle. The meta data is
    # built up as the list of history variables is traversed.  The returned
    # data is suitable for conversion to other formats, such as JSON. Rather 
    # than  return all possible key values for each history table key, only 
    # the key values that are present in the table are returned.
    #
    # The structure of the meta data is as follows:
    #
    # name -> history variable name (ie. vrel)
    # desc -> descripion of table (ie. "Vertical Relationship")
    # keys => list of dictionaries of key metadata
    #      -> key    => the key as appears in the table (ie. "g")
    #      -> label  => label to use for key (ie. "Group")
    #      -> values => A list of valid values for the key

    method {meta huddle} {} {
        # FIRST, initialize the list of huddle objects
        set hlist [list]

        # NEXT, traverse the list of history variables supported
        foreach {name meta} $histVars {
            # NEXT, initialize variable dictionary 
            set vdict ""

            # NEXT, number of records in the variables table, pruning out
            # empty variables
            set size [$self GetHistTableSize $name]

            if {$size == 0} {
                continue
            }

            foreach {desc dummy keys} $meta {
                # NEXT compile var name and description to huddle object, keys
                # is initially empty; they are read next
                set vdict \
                    [huddle compile dict \
                        [list name $name desc $desc size $size keys {}]]

                # NEXT, initialize list of keys and read them from meta data
                set klist [list]

                foreach {key lbl} $keys {
                    # NEXT, compile key information and set values as empty, 
                    # we will extract them from the adb.
                    set kdict \
                        [huddle compile dict \
                            [list key $key label $lbl values {}]]

                    # NEXT, get the valid values for the current key    
                    set keyvals [$self GetHistKeyVals $name $key]

                    # NEXT, override values with whatever is returned 
                    huddle append kdict values [huddle compile list $keyvals]

                    # NEXT, append the key dict to the list of key dicts
                    lappend klist $kdict
                }

                # NEXT, override keys with the list just compiled
                huddle append vdict keys [huddle list {*}$klist]
            }

            # NEXT, add current variable metadata to growing list of history
            # variables
            lappend hlist $vdict
        }

        # NEXT compile the list to huddle and return
        return [huddle list {*}$hlist]
    }

    # GetHistTableSize var

    method GetHistTableSize {var} {
        set table hist_$var

        set query "SELECT count(*) FROM $table"

        $adb eval $query
    }

    # GetHistKeyVals var key
    #
    # var  - a history variable
    # key  - a key present in the table corresponding to var
    #
    # This helper method looks up valid values in the given history variable
    # table for the specific key. It is assumed that the variable has a
    # corresponding table formatted as "hist_<var>" where <var> is a history
    # variable.

    method GetHistKeyVals {var key} {
        set table hist_$var

        # FIRST, 'ALL' is always a valid key and it should appear first
        set klist [list ALL]

        set query "SELECT DISTINCT $key FROM $table"

        lappend klist {*}[$adb eval $query]

        return $klist
    }

    #-------------------------------------------------------------------
    # Public Methods

    # purge t
    #
    # t   - The sim time in ticks at which to purge
    #
    # Removes "future history" from the history tables when going
    # backwards in time.  We are paused at time t; all time t 
    # history is behind us.  So purge everything later.
    #
    # On unlock, this will be used to purge all history, including
    # time 0 history, by setting t to -1. NOTE: in the case of t = -1
    # its *much* quicker to leave out the WHERE clause

    method purge {t} {
        if {$t == -1} {
            $adb eval {
                DELETE FROM hist_nbhood;
                DELETE FROM hist_nbgroup;
                DELETE FROM hist_civg;
                DELETE FROM hist_sat_raw;
                DELETE FROM hist_coop;
                DELETE FROM hist_nbcoop;
                DELETE FROM hist_econ;
                DELETE FROM hist_econ_i;
                DELETE FROM hist_econ_ij;
                DELETE FROM hist_plant_na;
                DELETE FROM hist_service_sg;
                DELETE FROM hist_support;
                DELETE FROM hist_hrel;
                DELETE FROM hist_vrel;
                DELETE FROM hist_flow;
                DELETE FROM hist_activity_nga;
                DELETE FROM hist_aam_battle;
            }
        } else {
            $adb eval {
                DELETE FROM hist_nbhood       WHERE t > $t;
                DELETE FROM hist_nbgroup      WHERE t > $t;
                DELETE FROM hist_civg         WHERE t > $t;
                DELETE FROM hist_sat_raw      WHERE t > $t;
                DELETE FROM hist_coop         WHERE t > $t;
                DELETE FROM hist_nbcoop       WHERE t > $t;
                DELETE FROM hist_econ         WHERE t > $t;
                DELETE FROM hist_econ_i       WHERE t > $t;
                DELETE FROM hist_econ_ij      WHERE t > $t;
                DELETE FROM hist_plant_na     WHERE t > $t;
                DELETE FROM hist_service_sg   WHERE t > $t;
                DELETE FROM hist_support      WHERE t > $t;
                DELETE FROM hist_hrel         WHERE t > $t;
                DELETE FROM hist_vrel         WHERE t > $t;
                DELETE FROM hist_flow         WHERE t > $t;
                DELETE FROM hist_activity_nga WHERE t > $t;
                DELETE FROM hist_aam_battle   WHERE t > $t;
            }
        }
    }

    # tick
    #
    # This method is called at each time tick, and preserves data values
    # that change tick-by-tick.  
    #
    # "Significant" outputs (i.e., those used in practice by analysts)
    # are always saved, as are outputs required to construct causal
    # chains.  Other outputs may be disabled by setting the appropriate
    # parameter.

    method tick {} {
        set t [$adb clock now]

        # Attitudes history 
        # SAT
        if {[$adb parm get hist.sat]} {
            $adb eval {
                INSERT INTO hist_sat_raw(t,g,c,sat,base,nat)
                SELECT $t AS t, g, c, sat, bvalue, cvalue 
                FROM uram_sat;
            }
        }

        # COOP
        if {[$adb parm get hist.coop]} {
            $adb eval {
                INSERT INTO hist_coop(t,f,g,coop,base,nat)
                SELECT $t AS t, f, g, coop, bvalue, cvalue
                FROM uram_coop;
            }
        }

        # HREL
        if {[$adb parm get hist.hrel]} {
            $adb eval {
                INSERT INTO hist_hrel(t,f,g,hrel,base,nat)
                SELECT $t AS t, f, g, hrel, bvalue, cvalue
                FROM uram_hrel;
            }
        }

        # VREL 
        if {[$adb parm get hist.vrel]} {
            $adb eval {
                INSERT INTO hist_vrel(t,g,a,vrel,base,nat)
                SELECT $t AS t, g, a, vrel, bvalue, cvalue
                FROM uram_vrel;
            }
        }

        # Neighborhood COOP by FRC group
        if {[$adb parm get hist.nbcoop]} {
            $adb eval {
                INSERT INTO hist_nbcoop(t,n,g,nbcoop)
                SELECT $t AS t, n, g, nbcoop
                FROM uram_nbcoop;
            }
        }

        # Neighborhood history
        $adb eval {
            INSERT INTO hist_nbhood(t,n,a,nbmood,volatility,nbpop,
                                    ur,nbsecurity)
            SELECT $t AS t, n, 
                   C.controller AS a, 
                   U.nbmood, 
                   F.volatility, 
                   D.population,
                   D.ur,
                   F.security
            FROM uram_n    AS U
            JOIN force_n   AS F USING (n)
            JOIN demog_n   AS D USING (n)
            JOIN control_n AS C USING (n);
        }

        # Neighborhood group history
        $adb eval {
            INSERT INTO hist_nbgroup(t,n,g,security,personnel,unassigned)
            SELECT $t AS t, n, g,
                   F.security,
                   F.personnel,
                   coalesce(D.unassigned,0)
            FROM            force_ng   AS F
            LEFT OUTER JOIN deploy_ng  AS D USING (n,g)
        }

        # CIV group history
        $adb eval {
            INSERT INTO hist_civg(t,g,mood,population)
            SELECT $t AS t, g, 
                   U.mood,
                   D.population
            FROM uram_mood AS U
            JOIN demog_g   AS D USING (g);
        }

        if {[$adb parm get hist.plant] && [$adb econ state] eq "ENABLED"} {
            set gpp [money validate [$adb parm get plant.bktsPerYear.goods]]

            $adb eval {
                INSERT INTO hist_plant_na(t,n,a,num,cap)
                SELECT $t AS t, n, a, num, $gpp*num*rho AS cap
                FROM plants_na;
            }
        }

        if {[$adb parm get hist.support]} {
            $adb eval {
                INSERT INTO hist_support(t,n,a,direct_support,support,influence)
                SELECT now(), n, a, direct_support, support, influence
                FROM influence_na;
            }
        }

        if {[$adb parm get hist.service]} {
            $adb eval {
                INSERT INTO hist_service_sg(t,s,g,saturation_funding,required,
                                           funding,actual,expected,expectf,
                                           needs)
                SELECT now(), s, g, saturation_funding, required,
                       funding, actual, expected, expectf, needs
                FROM service_sg
            }
        }

        if {[$adb parm get hist.activity]} {
            $adb eval {
                INSERT INTO hist_activity_nga(t,n,g,a,security_flag,can_do,
                                              nominal,effective,coverage)
                SELECT now(), n, g, a, security_flag, can_do, nominal,
                       effective, coverage
                FROM activity_nga WHERE nominal > 0
            }            
        }
    }

    # Type Method: econ
    #
    # This method is called at each econ tock, and preserves data
    # values that change tock-by-tock.

    method econ {} {
        # FIRST, if the econ model has been disabled we're done.
        if {[$adb econ state] eq "DISABLED"} {
            return
        }

        # NEXT, get the data and save it.
        array set inputs  [$adb econ get In  -bare]
        array set outputs [$adb econ get Out -bare]

        $adb eval {
            -- hist_econ
            INSERT INTO hist_econ(t, consumers, subsisters, labor, 
                                  lsf, csf, rem, cpi, agdp, dgdp, ur)
            VALUES(now(), 
                   $inputs(Consumers), $inputs(Subsisters), $inputs(LF),
                   $inputs(LSF), $inputs(CSF), $inputs(REM),
                   $outputs(CPI), $outputs(AGDP), $outputs(DGDP), 
                   $outputs(UR));
        }

        foreach i {goods pop black actors region world} {
            if {$i in {goods pop black}} {
                $adb eval "
                    -- hist_econ_i
                    INSERT INTO hist_econ_i(t, i, p, qs, rev)
                    VALUES(now(), upper(\$i), \$outputs(P.$i), 
                           \$outputs(QS.$i),\$outputs(REV.$i));
                "
            }

            foreach j {goods pop black actors region world} {
                $adb eval "
                    -- hist_econ_ij
                    INSERT INTO hist_econ_ij(t, i, j, x, qd)
                    VALUES(now(), upper(\$i), upper(\$j), 
                           \$outputs(X.$i.$j), \$outputs(QD.$i.$j)); 
                "
            }
        }
    }

    # vars
    #
    # Returns available history variables and their keys
    # TBD: this should go away once the old web app is gone

    method vars {} {
        foreach {var meta} $histVars {
            set klist [list]
            foreach {dummy dummy keys} $meta {
                foreach {key dummy} $keys {
                    lappend klist $key
                }
            }

            set hvars($var) $klist
        }        
        return [array get hvars]
    }
}
