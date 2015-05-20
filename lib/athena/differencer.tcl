#-----------------------------------------------------------------------
# TITLE:
#   differencer.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n) Scenario differencer module.  Compares two scenario files
#   (or one scenario file at different sim times) and returns the 
#   signficant differences as an athena::comparison object.  This 
#   capability is exposed as the "athena::athena diff" command.
#
#   NOTE: This module has no state data!
#
#-----------------------------------------------------------------------

snit::type ::athena::differencer {
    pragma -hasinstances no

    # diff s1 ?s2? ?options...?
    #
    # s1       - An athena(n) scenario object
    # s2       - Optionally, another athena(n) scenario object
    # options  - As indicated below
    #
    # Finds signficant differences between two scenarios, returning
    # them in a comparison(n) object.
    #
    # If one scenario is given, differences may be found between
    # different simulation times, nominally 0 and the latest sim time
    # in the scenario's history.   If two scenarios are given, 
    # differences may be found between them at any pair of times, nominally
    # the latest sim time found in both sets of history.
    #
    # Options:
    #
    #   -t1   - The sim time for the first scenario.
    #   -t2   - The sim time for the second scenario 
    #
    # Throws {ATHENA INCOMPARABLE} if the two scenarios are not 
    # compatible.

    typemethod diff {s1 args} {
        # FIRST, get the scenarios.
        if {![string match "-*" [lindex $args 0]]} {
            set s2 [lshift args]
        } else {
            set s2 $s1
        }

        # NEXT, set the default times
        if {$s2 eq $s1} {
            set t1 0
            set t2 [$s1 clock now]

            if {$t1 == $t2} {
                error "Trivial: scenario with itself at t=0"
            }
        } else {
            # Find the latest time they have in common
            set t1 [expr {min([$s1 clock now],[$s2 clock now])}]
            set t2 $t1
        }

        foroption opt args {
            -t1 { set t1 [lshift args] }
            -t2 { set t2 [lshift args] }
        }

        if {$s1 eq $s2} {
            if {$t1 >= $t2} {
                error "Invalid times: -t2 < -t1"
            }
        }

        if {$t1 < 0 || $t1 > [$s1 clock now]} {
            error "-t1 out of range: 0...[$s1 clock now]"
        }

        if {$t2 < 0 || $t2 > [$s2 clock now]} {
            error "-t2 out of range: 0...[$s1 clock now]"
        }

        # NEXT, look for differences
        set comp [::athena::comparison create %AUTO% $s1 $t1 $s2 $t2]

        $type FindDiffs $comp

        return $comp
    }

    # FindDiffs comp
    #
    # comp  - A comparison object
    #
    # Queries history to identify significant outputs.

    typemethod FindDiffs {comp} {
        set cdb [sqldocument %AUTO -readonly yes]
        $cdb open :memory:

        set db1 [$comp s1 rdbfile]
        set db2 [$comp s2 rdbfile]
        set t1  [$comp t1]
        set t2  [$comp t2]

        $cdb eval {
            ATTACH $db1 AS s1;
            ATTACH $db2 AS s2;
        }

        $type CompareNbhoodOutputs    $comp $cdb
        $type CompareAttitudeOutputs  $comp $cdb
        $type ComparePoliticalOutputs $comp $cdb
        $type CompareEconomicOutputs  $comp $cdb

        $cdb destroy
    }

    # CompareNbhoodOutputs comp cdb
    #
    # comp   - A comparison object
    # cdb    - The comparison sqldocument(n)
    #
    # This method compares neighborhood specific data for two scenarios
    # or one scenario at different times.

    typemethod CompareNbhoodOutputs {comp cdb} {
        set t1 [$comp t1]
        set t2 [$comp t2]

        # FIRST, mood, security and control by nbhood
        $cdb eval {
            SELECT H1.n          AS n,
                   H1.nbsecurity AS nbsec1,
                   H1.a          AS a1,
                   H1.nbmood     AS nbmood1,
                   H2.nbsecurity AS nbsec2,
                   H2.a          AS a2,
                   H2.nbmood     AS nbmood2
            FROM s1.hist_nbhood  AS H1
            JOIN s2.hist_nbhood  AS H2 
            ON (H1.n = H2.n AND H1.t=$t1 AND H2.t=$t2);
        } {
            $comp add nbsecurity $nbsec1  $nbsec2  $n
            $comp add control    $a1      $a2      $n
            $comp add nbmood     $nbmood1 $nbmood2 $n
        }

        # NEXT, satisfaction by nbhood and concern
        foreach c {AUT CUL SFT QOL} {            
            set d1 [$comp s1 stats satbynb $t1 $c]
            set d2 [$comp s2 stats satbynb $t2 $c]
            dict set sdict $c [list $d1 $d2]
        }

        dict for {c ddict} $sdict {
            set d1 [lindex $ddict 0]
            set d2 [lindex $ddict 1]
            foreach {n1 sat1} [dict get $d1] {n2 sat2} [dict get $d2] {
                $comp add nbsat $sat1 $sat2 $n1 $c
            }
        }
    }

    # CompareAttitudeOutputs comp cdb
    #
    # comp    - A comparison object
    # cdb     - The comparison sqldocument(n)
    #
    # This method compares attitudes of civilian groups for two scenarios
    # or one scenario at different times.

    typemethod CompareAttitudeOutputs {comp cdb} {
        set t1 [$comp t1]
        set t2 [$comp t2]

        # FIRST, CIV mood by group
        $cdb eval {
            SELECT H1.g         AS g,
                   H1.mood      AS mood1,
                   H2.mood      AS mood2
            FROM s1.hist_civg   AS H1
            JOIN s2.hist_civg   AS H2
            ON (H1.g = H2.g AND H1.t=$t1 AND H2.t=$t2);
        } {
            $comp add mood $mood1 $mood2 $g 
        }

        # NEXT, CIV satisfaction by group and concern
        $cdb eval {
            SELECT H1.g         AS g,
                   H1.c         AS c,
                   H1.sat       AS sat1,
                   H2.sat       AS sat2
            FROM s1.hist_sat    AS H1
            JOIN s2.hist_sat    AS H2
            ON (H1.g = H2.g AND H1.c = H2.c AND H1.t=$t1 AND H2.t=$t2)
        } {
            $comp add sat $sat1 $sat2 $g $c
        }

        # NEXT, CIV satisfaction by belief system and concern
        set sdict [dict create]

        foreach c {AUT CUL SFT QOL} {
            set d1 [$comp s1 stats satbybsys $t1 $c]
            set d2 [$comp s2 stats satbybsys $t2 $c]
            dict set sdict $c [list $d1 $d2]
        }

        dict for {c ddict} $sdict {
            set d1 [lindex $ddict 0]
            set d2 [lindex $ddict 1]
            foreach {bsid1 sat1} [dict get $d1] {bsid2 sat2} [dict get $d2] {
                set bsname "B$bsid1"
                $comp add bsyssat $sat1 $sat2 $bsname $c
            }
        }

        # NEXT, CIV satisfaction in the playbox by concern
        foreach c {AUT CUL SFT QOL} {
            set ps1 [$comp s1 stats pbsat $t1 $c]
            set ps2 [$comp s2 stats pbsat $t2 $c]
            $comp add pbsat $ps1 $ps2 $c local
        }

        # NEXT, CIV mood by belief system
        set mbs1 [$comp s1 stats moodbybsys $t1]
        set mbs2 [$comp s2 stats moodbybsys $t2]

        foreach {bsid1 mood1} [dict get $mbs1] {bsid2 mood2} [dict get $mbs2] {
            set bsname "B$bsid1"
            $comp add bsysmood $mood1 $mood2 $bsname
        }

        # NEXT, playbox mood (local CIV groups)
        set pbm1 [$comp s1 stats pbmood $t1]
        set pbm2 [$comp s2 stats pbmood $t2]

        $comp add pbmood $pbm1 $pbm2 local

        # NEXT, vertical relationship 
        $cdb eval {
            SELECT H1.g    AS g,
                   H1.a    AS a,
                   H1.vrel AS vrel1,
                   H2.vrel AS vrel2
            FROM s1.hist_vrel AS H1
            JOIN s2.hist_vrel AS H2
            ON (H1.g = H2.g AND H1.a = H2.a AND H1.t=$t1 AND H2.t=$t2)

        } {
            $comp add vrel $vrel1 $vrel2 $g $a
        }
    }

    # ComparePoliticalOutputs comp cdb
    # 
    # comp    - A comparison object
    # cdb     - A comparison sqldocument(n)
    #
    # This method compares certain political outputs for two scenarios
    # or for one scenario at different times.

    typemethod ComparePoliticalOutputs {comp cdb} {
        set t1 [$comp t1]
        set t2 [$comp t2]

        # FIRST, create dicts to hold influence data 
        set i1 [dict create]
        set i2 [dict create]

        foreach n [$comp s1 nbhood names] {
            dict set i1 $n {}
            dict set i2 $n {}
        }

        # NEXT, influence and support by neighborhood and actor
        $cdb eval {
            SELECT H1.n         AS n,
                   H1.a         AS a,
                   H1.support   AS support1,
                   H1.influence AS influence1,
                   H2.support   AS support2,
                   H2.influence AS influence2
            FROM s1.hist_support AS H1
            JOIN s2.hist_support AS H2 
            ON (H1.n = H2.n AND H1.a = H2.a AND H1.t=$t1 AND H2.t=$t2)
            WHERE support1 > 0.0 OR support2 > 0.0;
        } {
            # influence.n.* works on dictionaries of non-zero influences.
            if {$influence1 > 0.0} {
                dict set i1 $n $a $influence1
            }
            if {$influence2 > 0.0} {
                dict set i2 $n $a $influence2
            }

            $comp add support $support1 $support2 $n $a
        }

        foreach n [$comp s1 nbhood names] {
            $comp add influence [dict get $i1 $n] [dict get $i2 $n] $n
        }
    }

    # CompareEconomicOutputs comp cdb
    #
    # comp    - A comparison object
    # cdb     - A comparsion sqldocument(n)
    #
    # This method compares certain economic model outputs for two
    # scenarios or for one scenario at different times.
    
    typemethod CompareEconomicOutputs {comp cdb} {
        set t1 [$comp t1]
        set t2 [$comp t2]

        # FIRST, GOODS production capacity by nbhood
        $cdb eval {
            SELECT H1.n         AS n,
                   H1.cap       AS cap1,
                   H2.cap       AS cap2
            FROM s1.hist_plant_n AS H1
            JOIN s2.hist_plant_n AS H2
            ON (H1.n = H2.n AND H1.t=$t1 AND H2.t=$t2)
        } {
            $comp add goodscap $cap1 $cap2 $n
        }

        # NEXT, GDP
        $cdb eval {
            SELECT H1.dgdp     AS gdp1,
                   H2.dgdp     AS gdp2
            FROM s1.hist_econ AS H1
            JOIN s2.hist_econ AS H2
            ON (H1.t=$t1 AND H2.t=$t2)
        } {
            $comp add gdp $gdp1 $gdp2
        }

        # NEXT, Playbox unemployment rate
        $cdb eval {
            SELECT H1.ur      AS ur1,
                   H2.ur      AS ur2
            FROM s1.hist_econ AS H1
            JOIN s2.hist_econ AS H2
            ON (H1.t=$t1 AND H2.t=$t2)
        } {
            $comp add unemp $ur1 $ur2
        }

        # NEXT, Nbhood unemployment rate
        $cdb eval {
            SELECT H1.n       AS n,
                   H1.ur      AS ur1,
                   H2.ur      AS ur2
            FROM s1.hist_nbhood AS H1
            JOIN s2.hist_nbhood AS H2
            ON (H1.n = H2.n AND H1.t=$t1 AND H2.t=$t2)
        } {
            $comp add nbunemp $ur1 $ur2 $n
        }
    }
}


