#-----------------------------------------------------------------------
# TITLE:
#   comparison.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n): Scenario Comparison class
#
#   A comparison object records the results of comparing two scenarios
#   (or the same scenario at different times).  
#
#   The initial comparison looks for significant differences between
#   the two scenarios, and records them as a series of "vardiff" objects.
#   These objects are catalogued by "vartype", e.g., "nbmood", and by 
#   name, "nbmood.N1".
#
#   Then, the comparison object can be asked to provide a causal chain
#   for a particular variable.  It will drill down, looking for
#   explanations of the difference in that particular variable; these
#   explanations take the form of vardiffs for the inputs to the variable,
#   and vardiffs on the inputs to those inputs, until we can go no 
#   farther.  Each vardiff is catalogued like its predecessors, and the
#   tree of significant inputs to a particular vardiff can be traced
#   by querying the vardiff.
#
#-----------------------------------------------------------------------

snit::type ::athena::comparison2 {
    #-------------------------------------------------------------------
    # Type Methods

    # new s1 t1 s2 t2
    #
    # s1    - A locked scenario
    # t1    - A time <= s1.now
    # s2    - A locked scenario
    # t2    - A time <= s2.now
    #
    # Creates a new instance with an arbitrary name, returning the name.
    # It is assumed that s1 and s2 are locked and comparable according to 
    # [comparison check].

    typemethod new {s1 t1 s2 t2} {
        return [$type create %AUTO% $s1 $t1 $s2 $t2]
    } 

    # check s1 s2
    #
    # s1   - A scenario
    # s2   - A scenario
    #
    # Throws {ATHENA INCOMPARABLE} with an appropriate error message 
    # if the two scenarios cannot be reasonably compared.  It is usually

    typemethod check {s1 s2} {
        if {![lequal [$s1 nbhood names] [$s2 nbhood names]]} {
            throw {ATHENA INCOMPARABLE} \
                "Scenarios not comparable: different neighborhoods."
        }

        if {![lequal [$s1 actor names] [$s2 actor names]]} {
            throw {ATHENA INCOMPARABLE} \
                "Scenarios not comparable: different actors."
        }

        if {![lequal [$s1 civgroup names] [$s2 civgroup names]]} {
            throw {ATHENA INCOMPARABLE} \
                "Scenarios not comparable: different civilian groups."
        }

        if {![lequal [$s1 frcgroup names] [$s2 frcgroup names]]} {
            throw {ATHENA INCOMPARABLE} \
                "Scenarios not comparable: different force groups."
        }

        if {![lequal [$s1 orggroup names] [$s2 orggroup names]]} {
            throw {ATHENA INCOMPARABLE} \
                "Scenarios not comparable: different organization groups."
        }

        if {![lequal [$s1 bsys system namedict] [$s2 bsys system namedict]]} {
            throw {ATHENA INCOMPARABLE} \
                "Scenarios not comparable: different belief systems."
        }

    }
    
    #-------------------------------------------------------------------
    # Instance Variables
    
    variable s1                ;# Scenario 1
    variable t1                ;# Time 1
    variable s2                ;# Scenario 2
    variable t2                ;# Time 2
    variable cdb               ;# Comparison database
    variable byname {}         ;# Dict, vardiffs by varname
    variable bytype {}         ;# Dict, list of vardiffs by vartype.
    variable toplevel {}       ;# List, toplevel vardiffs.

    variable values -array {}  ;# Accumulates pairs of values by vardiff
                               ;# type, to compute the normalizers.

    #-------------------------------------------------------------------
    # Constructor
    
    # constructor name s1 t1 s2 t2
    #
    # Creates an instances; except for name, the arguments are as for 
    # [comparison new], above.

    constructor {s1_ t1_ s2_ t2_} {
        # FIRST, save the constructor arguments.
        set s1 $s1_
        set t1 $t1_
        set s2 $s2_
        set t2 $t2_

        # NEXT, create the CDB.
        set cdb [sqldocument ${selfns}::cdb -readonly yes]
        $cdb open :memory:
        $cdb function t1 [mymethod t1]
        $cdb function t2 [mymethod t2]

        set db1 [$s1 rdbfile]
        set db2 [$s2 rdbfile]

        $cdb eval {
            ATTACH $db1 AS s1;
            ATTACH $db2 AS s2;            
        }

        $cdb eval [readfile [file join $::athena::library sql comparison.sql]]

        # NEXT, initialize the vardiff cache.
        set byname   [dict create]
        set toplevel [list]
    }

    destructor {
        # Destroy the difference objects.
        $self reset
    }

    #-------------------------------------------------------------------
    # Public Methods

    # reset
    #
    # Destroys all dependent vardiffs and resets the instance variables.
    # This is usually only done in the destructor.

    method reset {} {
        dict for {varname diff} $byname {
            $diff destroy
        }
        set byname   [dict create]
        set toplevel [list]
    }

    #-------------------------------------------------------------------
    # Comparison of significant outputs

    # compare
    #
    # Computes the significant outputs for the two scenarios, i.e., the
    # "toplevel" vardiffs, querying the history of the scenarios to 
    # identify the significant outputs.

    method compare {} {
        $self CompareNbhoodOutputs
        # $self CompareAttitudeOutputs
        # $self ComparePoliticalOutputs
        # $self CompareEconomicOutputs

        $self MergeScores
    }

    # AddTop vartype val1 val2 keys...
    #
    # vartype  - An output variable type.
    # val1     - The value from s1/t1
    # val2     - The value from s2/t2
    # keys...  - Key values for the vardiff class
    #
    # Given a vardiff type and a pair of values, saves a significant output
    # diff if the difference between the two values is significant.  
    #
    # Returns the diff if it was significant, and "" otherwise. 

    method AddTop {vartype val1 val2 args} {
        # FIRST, save the values for the normalizer, if they are needed.
        # They will be needed if the normalizer function isn't a 
        # constant number.
        set T ::athena::vardiff::$vartype

        if {![string is double -string [$T normalizer]]} {
            # save the values
            lappend values($vartype) $val1 $val2
        }

        # NEXT, get the diff
        set diff [$self add $vartype $val1 $val2 {*}$args]

        # NEXT, remember that it is a top-level variable if the difference
        # is non-trivial, and save the type.
        if {$diff ne "" && $diff ne $toplevel} {
            lappend toplevel $diff
            dict lappend bytype [info object class $diff] $diff
        }

        return $diff
    }

    # add vartype val1 val2 keys...
    #
    # vartype  - An output variable type.
    # val1     - The value from s1/t1
    # val2     - The value from s2/t2
    # keys...  - Key values for the vardiff class
    #
    # Caches the variable of the given type provided that the variable's
    # value is actually different between the two cases.  Returns the
    # new vardiff object, or "" if none.

    method add {vartype val1 val2 args} {
        # FIRST, get the class
        set T ::athena::vardiff::$vartype

        # NEXT, create a vardiff object.
        set diff [::athena::vardiff::$vartype new $self $val1 $val2 {*}$args]

        # NEXT, if we've already got this vardiff, return the old copy.
        set name [$diff name]

        if {[dict exists $byname $name]} {
            $diff destroy
            return [dict get $byname $name]
        }

        # NEXT, if it's trivial (i.e., no change or a very small change)
        # destroy it and return nothing.
        if {[$diff trivial]} {
            $diff destroy
            return ""
        }

        # NEXT, it's non-trivial and hadn't existed previously; save 
        # and return it.
        dict set byname [$diff name] $diff
        return $diff
    }


    # CompareNbhoodOutputs comp
    #
    # comp   - A comparison object
    #
    # This method compares neighborhood specific data for two scenarios
    # or one scenario at different times.

    typemethod CompareNbhoodOutputs {} {
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
            $self AddTop nbsecurity $nbsec1  $nbsec2  $n
            $self AddTop control    $a1      $a2      $n
            $self AddTop nbmood     $nbmood1 $nbmood2 $n
        }

        $self TypeScore nbsecurity
        $self TypeScore control
        $self TypeScore nbhood 

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
                $self AddTop nbsat $sat1 $sat2 $n1 $c
            }
        }
    }

    # CompareAttitudeOutputs comp
    #
    # comp    - A comparison object
    # cdb     - The comparison sqldocument(n)
    #
    # This method compares attitudes of civilian groups for two scenarios
    # or one scenario at different times.

    typemethod CompareAttitudeOutputs {comp} {
        set t1 [$comp t1]
        set t2 [$comp t2]

        # FIRST, CIV mood by group
        $comp eval {
            SELECT g, mood1, mood2 FROM comp_civg
        } {
            $comp AddTop mood $mood1 $mood2 $g 
        }

        # NEXT, CIV satisfaction by group and concern
        $comp eval {
            SELECT g, c, sat1, sat2
            FROM comp_sat;
        } {
            $comp AddTop sat $sat1 $sat2 $g $c
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
                $comp AddTop bsyssat $sat1 $sat2 $bsname $c
            }
        }

        # NEXT, CIV satisfaction in the playbox by concern
        foreach c {AUT CUL SFT QOL} {
            set ps1 [$comp s1 stats pbsat $t1 $c]
            set ps2 [$comp s2 stats pbsat $t2 $c]
            $comp AddTop pbsat $ps1 $ps2 $c local
        }

        # NEXT, CIV mood by belief system
        set mbs1 [$comp s1 stats moodbybsys $t1]
        set mbs2 [$comp s2 stats moodbybsys $t2]

        foreach {bsid1 mood1} [dict get $mbs1] {bsid2 mood2} [dict get $mbs2] {
            set bsname "B$bsid1"
            $comp AddTop bsysmood $mood1 $mood2 $bsname
        }

        # NEXT, playbox mood (local CIV groups)
        set pbm1 [$comp s1 stats pbmood $t1]
        set pbm2 [$comp s2 stats pbmood $t2]

        $comp AddTop pbmood $pbm1 $pbm2 local

        # NEXT, vertical relationship 
        $comp eval {
            SELECT g, a, vrel1, vrel2 FROM comp_vrel
        } {
            $comp AddTop vrel $vrel1 $vrel2 $g $a
        }
    }

    # ComparePoliticalOutputs comp
    # 
    # comp    - A comparison object
    # cdb     - A comparison sqldocument(n)
    #
    # This method compares certain political outputs for two scenarios
    # or for one scenario at different times.

    typemethod ComparePoliticalOutputs {comp} {
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
        $comp eval {
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

            $comp AddTop support $support1 $support2 $n $a
        }

        foreach n [$comp s1 nbhood names] {
            $comp AddTop nbinfluence [dict get $i1 $n] [dict get $i2 $n] $n
        }
    }

    # CompareEconomicOutputs comp
    #
    # comp    - A comparison object
    # cdb     - A comparsion sqldocument(n)
    #
    # This method compares certain economic model outputs for two
    # scenarios or for one scenario at different times.
    
    typemethod CompareEconomicOutputs {comp} {
        set t1 [$comp t1]
        set t2 [$comp t2]

        # FIRST, GOODS production capacity by nbhood
        $comp eval {
            SELECT H1.n         AS n,
                   H1.cap       AS cap1,
                   H2.cap       AS cap2
            FROM s1.hist_plant_n AS H1
            JOIN s2.hist_plant_n AS H2
            ON (H1.n = H2.n AND H1.t=$t1 AND H2.t=$t2)
        } {
            $comp AddTop goodscap $cap1 $cap2 $n
        }

        # NEXT, GDP
        $comp eval {
            SELECT H1.dgdp     AS gdp1,
                   H2.dgdp     AS gdp2
            FROM s1.hist_econ AS H1
            JOIN s2.hist_econ AS H2
            ON (H1.t=$t1 AND H2.t=$t2)
        } {
            $comp AddTop gdp $gdp1 $gdp2
        }

        # NEXT, Playbox unemployment rate
        $comp eval {
            SELECT H1.ur      AS ur1,
                   H2.ur      AS ur2
            FROM s1.hist_econ AS H1
            JOIN s2.hist_econ AS H2
            ON (H1.t=$t1 AND H2.t=$t2)
        } {
            $comp AddTop unemp $ur1 $ur2
        }

        # NEXT, Nbhood unemployment rate
        $comp eval {
            SELECT H1.n       AS n,
                   H1.ur      AS ur1,
                   H2.ur      AS ur2
            FROM s1.hist_nbhood AS H1
            JOIN s2.hist_nbhood AS H2
            ON (H1.n = H2.n AND H1.t=$t1 AND H2.t=$t2)
        } {
            $comp AddTop nbunemp $ur1 $ur2 $n
        }
    }
}