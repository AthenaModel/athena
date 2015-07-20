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

snit::type ::athena::comparison {
    #-------------------------------------------------------------------
    # Lookup Tables

    # "A" values for comparing scores of significant
    # outputs of different types
    # TBD: Should probably be in compdb
    typevariable A -array {
        bsysmood     1.0
        bsyssat      1.0
        control      1.0
        gdp          1.0
        goodscap     1.0
        mood         1.0
        nbinfluence  1.0
        nbmood       1.0
        nbsat        1.0
        nbsecurity   1.0
        nbunemp      1.0
        pbmood       1.0
        pbsat        1.0
        sat          1.0
        support      1.0
        unemp        1.0
        vrel         1.0
    }
    
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
    variable scores            ;# Array of scores of toplevel vardiffs by
                                # vardiff object

    # Transient Variables
    variable valueCache {}     ;# Saved values, by vartype


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

    delegate method eval  to cdb
    delegate method query to cdb

    # reset
    #
    # Destroys all dependent vardiffs and resets the instance variables.
    # This is usually only done in the destructor.

    method reset {} {
        dict for {varname diff} $byname {
            $diff destroy
        }
        set byname   [dict create]
        set bytype   [dict create]
        set toplevel [list]
        array unset scores
    }

    #-------------------------------------------------------------------
    # Queries

    # t1
    #
    # Return time t1

    method t1 {} {
        return $t1
    }

    # t2
    #
    # Return time t2

    method t2 {} {
        return $t2
    }

    # s1 args
    #
    # Executes the args as a subcommand of s1.

    method s1 {args} {
        if {[llength $args] == 0} {
            return $s1
        } else {
            tailcall $s1 {*}$args            
        }
    }

    # s2 args
    #
    # Executes the args as a subcommand of s2.

    method s2 {args} {
        if {[llength $args] == 0} {
            return $s2
        } else {
            tailcall $s2 {*}$args            
        }
    }

    # list ?-all?
    #
    # Returns a list of the significant output vardiffs.  
    # If -all is given, returns all cached vardiffs..

    method list {{opt "-toplevel"}} {
        if {$opt eq "-all"} {
            return [dict values $byname]
        } else {
            return $toplevel
        }        
    }

    # exists varname
    #
    # varname  - A vardiff variable name
    #
    # Returns 1 if there is a significant variable with the given 
    # name, and 0 otherwise.

    method exists {varname} {
        dict exists $byname $varname
    }

    # validate varname
    #
    # varname  - A vardiff variable name
    #
    # Throws INVALID if varname isn't a significant variable, and
    # returns the varname otherwise.

    method validate {varname} {
        if {![$self exists $varname]} {
            throw INVALID "Variable is not significant: $varname"
        }
        return $varname
    }


    # getdiff name
    #
    # name   - A vardiff object name
    #
    # Returns the vardiff object given its name, or "" if none.

    method getdiff {name} {
        if {[dict exists $byname $name]} {
            return [dict get $byname $name]
        } else {
            return ""
        }
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
        $self CompareAttitudeOutputs
        $self ComparePoliticalOutputs
        $self CompareEconomicOutputs

        $self ScoreOutputs
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

        if {![string is double -strict [$T normfunc]]} {
            dict lappend valueCache $vartype $val1 $val2
        }

        # NEXT, get the diff
        set diff [$self add $vartype $val1 $val2 {*}$args]

        # NEXT, remember that it is a top-level variable if the difference
        # is non-trivial, and save it by type so that we can do scoring.
        if {$diff ne "" && $diff ni $toplevel} {
            lappend toplevel $diff
            dict lappend bytype [$diff type] $diff
        }

        return $diff
    }

    # ScoreOutputs
    #
    # Scores each of the output vardiffs, adding its score to the 
    # scores() array.  The vardiffs can now be ranked by relative score.
    # The maximum score is always 100.0.

    method ScoreOutputs {} {
        # FIRST, score all of the outputs by type, so that each is 
        # properly ranked within its type.  Adds a vardiff/score to the
        # scores() array.
        dict for {vartype diffs} $bytype {
            $self ScoreByType $vartype $diffs
        }

        # NEXT, normalize the scores so that the max is 100.0
        $self NormalizeScores

        foreach name [lsort [array names scores]] {
            puts "Scored $name: [format %.1f $scores($name)]"
        }
    }

    # ScoreByType vartype diffs
    #
    # vartype   - A vardiff type name, without namespace
    # diffs     - A list of diffs of that type.
    #
    # Scores the diffs so that they can be ranked within the type.

    method ScoreByType {vartype diffs} {
        # FIRST, get the type object.
        set T ::athena::vardiff::$vartype

        # NEXT, get the normalization function
        set normfunc [$T normfunc]

        # NEXT, it's either a numeric or symbolic constant.  Use it
        # to get the normalization constant.
        if {[string is double -strict $normfunc]} {
            set normalizer $normfunc
        } else {
            assert {[dict exists $valueCache $vartype]}
            set values [dict get $valueCache $vartype]
            dict unset valueCache $vartype

            switch -exact -- $normfunc {
                maxmax  { set normalizer [$self maxmax $values] }
                maxsum  { set normalizer [$self maxsum $values] }
                default { error "Unknown normalizer: \"$normfunc\""}
            }
        }

        # NEXT, set the scores.
        foreach diff $diffs {
            let scores($diff) {
                [$diff delta] * 100.0 / $normalizer
            }
        }
    }

    # maxmax values
    #
    # values    - A flat list of val1 val2 pairs
    #
    # Finds the maximum value.  The result is used
    # for normalizing scores of a given type.

    method maxmax {values} {
        lappend values 0.0 ;# So we know it isn't empty.

        return [tcl::mathfunc::max {*}$values]
    }

    # maxsum values
    #
    # values    - A flat list of val1 val2 pairs
    #
    # Finds the sum of the values by scenario across the list of diffs,
    # and then returns the maximum of the two sums.  The result is used
    # for normalizing scores of a given type.

    method maxsum {values} {
        set sum1 0.0
        set sum2 0.0

        foreach {x1 x2} $values {
            set sum1 [expr {$sum1 + $x1}]
            set sum2 [expr {$sum2 + $x2}]
        }

        return [expr {max($sum1,$sum2)}]
    }

    # NormalizeScores 
    #
    # Normalizes the scores so that the max score is 100.0.

    method NormalizeScores {} {
        # FIRST, apply the "A"'s
        foreach diff [array names scores] {
            let scores($diff) {$scores($diff) * $A([$diff type])} 
        }

        # NEXT, get the maximum score
        set allScores [dict values [array get scores]]

        if {[llength $allScores] == 0.0} {
            return

        }
        set max [tcl::mathfunc::max {*}$allScores]

        if {$max == 0.0} {
            return
        }

        # NEXT, scale the scores to 100.0
        foreach diff [array names scores] {
            let scores($diff) {
                $scores($diff)*100.0 / $max
            }
        }
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
        # FIRST, if the values are identical we don't want to keep it.
        if {$val1 eq $val2} {
            return ""
        }

        # NEXT, get the class
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



    #-------------------------------------------------------------------
    # Contributions to curves
    
    # contribs sub keys...
    #
    # Calls the contribs command for both scenarios, retrieving the
    # contributions for the given contribs subcommand (e.g., mood)
    # and the given keys.  Looks up the DRID for each driver.  Returns
    # a flat list {drid val1 val2 ...}, where the value is 0 if the
    # driver is undefined for one scenario.

    method contribs {sub args} {
        # FIRST, get the scenario 1 contribs
        $s1 contribs $sub {*}$args -start 0 -end $t1

        $s1 eval {
            SELECT driver_id, contrib, dtype, signature
            FROM uram_contribs AS U
            JOIN drivers AS D
            ON (U.driver = D.driver_id)
        } {
            set drid $dtype/[join $signature /]
            set c($drid) $contrib
        }

        # NEXT, get the scenario 2 contribs
        $s2 contribs $sub {*}$args -start 0 -end $t2

        $s2 eval {
            SELECT driver_id, contrib, dtype, signature
            FROM uram_contribs AS U
            JOIN drivers AS D
            ON (U.driver = D.driver_id)
        } {
            set drid $dtype/[join $signature /]
            if {[info exists c($drid)]} {
                lappend c($drid) $contrib                
            }  else {
                set c($drid) [list 0.0 $contrib]
            }
        }

        # NEXT, build and return the list
        set result [list]

        foreach drid [array names c] {
            if {[llength $c($drid)] == 2} {
                lappend result $drid {*}$c($drid)
            } else {
                lappend result $drid $c($drid) 0.0
            }
        }

        return $result
    }



    #-------------------------------------------------------------------
    # Output of outputs in various formats
    

    # diffs dump ?-all?
    #
    # Returns a monotext formatted table of the significant outputs.
    # If -all is given, all cached vardiffs are

    method {diffs dump} {{opt ""}} {
        set vardiffs [$self list $opt]
        set vardiffs [$self SortByScore $vardiffs]

        return [$self DumpList $vardiffs]
    }

    # DumpList vardiffs
    #
    # vardiffs - A list of vardiff names
    #
    # Produces a monotext formatted table of the differences in the 
    # list.

    method DumpList {vardiffs} {
        set table [list]
        foreach diff $vardiffs {
            dict set row Variable   [$diff name]
            dict set row A          [$diff fmt1]
            dict set row B          [$diff fmt2]
            dict set row Narrative  [$diff narrative]
            dict set row Score      $scores($diff)
            dict set row Delta      [$diff delta]

            lappend table $row
        }

        return [dictab format $table -headers]
    }

    # diffs json ?-toplevel?
    #
    # Returns the differences formatted as JSON. 

    method {diffs json} {{opt ""}} {
        return [huddle jsondump [$self diffs huddle $opt]]
    }

    # diffs huddle ?-toplevel?
    #
    # Returns the differences formatted as a huddle(n) object.

    method {diffs huddle} {{opt ""}} {
        set hud [huddle list]

        forach diff [$self SortByScore [$self list $opt]] {
            # Add score to the record
            set hdiff [$diff huddle]
            huddle set hdiff score $scores($diff)
            huddle append hud $hdiff
        }

        return $hud
    }


    # SortByScore difflist
    #
    # Returns the difflist sorted in order of decreasing score.

    method SortByScore {difflist} {
        return [lsort -command [mymethod CompareScores] \
                      -decreasing $difflist]
    } 

    method CompareScores {diff1 diff2} {
        set score1 $scores($diff1)
        set score2 $scores($diff2)

        if {$score1 < $score2} {
            return -1
        } elseif {$score1 > $score2} {
            return 1
        } else {
            return 0
        }
    }

    #-------------------------------------------------------------------
    # Actual Comparisons
    
    # CompareNbhoodOutputs comp
    #
    # comp   - A comparison object
    #
    # This method compares neighborhood specific data for two scenarios
    # or one scenario at different times.

    method CompareNbhoodOutputs {} {
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

        # NEXT, satisfaction by nbhood and concern
        foreach c {AUT CUL SFT QOL} {            
            set d1 [$s1 stats satbynb $t1 $c]
            set d2 [$s2 stats satbynb $t2 $c]
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

    # CompareAttitudeOutputs
    #
    # This method compares attitudes of civilian groups for two scenarios
    # or one scenario at different times.

    method CompareAttitudeOutputs {} {
        # FIRST, CIV mood by group
        $cdb eval {
            SELECT g, mood1, mood2 FROM comp_civg
        } {
            $self AddTop mood $mood1 $mood2 $g 
        }

        # NEXT, CIV satisfaction by group and concern
        $cdb eval {
            SELECT g, c, sat1, sat2
            FROM comp_sat;
        } {
            $self AddTop sat $sat1 $sat2 $g $c
        }

        # NEXT, CIV satisfaction by belief system and concern
        set sdict [dict create]

        foreach c {AUT CUL SFT QOL} {
            set d1 [$s1 stats satbybsys $t1 $c]
            set d2 [$s2 stats satbybsys $t2 $c]
            dict set sdict $c [list $d1 $d2]
        }

        dict for {c ddict} $sdict {
            set d1 [lindex $ddict 0]
            set d2 [lindex $ddict 1]
            foreach {bsid1 sat1} [dict get $d1] {bsid2 sat2} [dict get $d2] {
                set bsname "B$bsid1"
                $self AddTop bsyssat $sat1 $sat2 $bsname $c
            }
        }

        # NEXT, CIV satisfaction in the playbox by concern
        foreach c {AUT CUL SFT QOL} {
            set ps1 [$s1 stats pbsat $t1 $c]
            set ps2 [$s2 stats pbsat $t2 $c]
            $self AddTop pbsat $ps1 $ps2 $c local
        }

        # NEXT, CIV mood by belief system
        set mbs1 [$s1 stats moodbybsys $t1]
        set mbs2 [$s2 stats moodbybsys $t2]

        foreach {bsid1 mood1} [dict get $mbs1] {bsid2 mood2} [dict get $mbs2] {
            set bsname "B$bsid1"
            $self AddTop bsysmood $mood1 $mood2 $bsname
        }

        # NEXT, playbox mood (local CIV groups)
        set pbm1 [$s1 stats pbmood $t1]
        set pbm2 [$s2 stats pbmood $t2]

        $self AddTop pbmood $pbm1 $pbm2 local

        # NEXT, vertical relationship 
        $cdb eval {
            SELECT g, a, vrel1, vrel2 FROM comp_vrel
        } {
            $self AddTop vrel $vrel1 $vrel2 $g $a
        }
    }

    # ComparePoliticalOutputs
    #
    # This method compares certain political outputs for two scenarios
    # or for one scenario at different times.

    method ComparePoliticalOutputs {} {
        # FIRST, create dicts to hold influence data 
        set i1 [dict create]
        set i2 [dict create]

        foreach n [$s1 nbhood names] {
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

            $self AddTop support $support1 $support2 $n $a
        }

        foreach n [$s1 nbhood names] {
            $self AddTop nbinfluence [dict get $i1 $n] [dict get $i2 $n] $n
        }
    }

    # CompareEconomicOutputs
    #
    # This method compares certain economic model outputs for two
    # scenarios or for one scenario at different times.
    
    method CompareEconomicOutputs {} {
        # FIRST, GOODS production capacity by nbhood
        $cdb eval {
            SELECT H1.n         AS n,
                   H1.cap       AS cap1,
                   H2.cap       AS cap2
            FROM s1.hist_plant_n AS H1
            JOIN s2.hist_plant_n AS H2
            ON (H1.n = H2.n AND H1.t=$t1 AND H2.t=$t2)
        } {
            $self AddTop goodscap $cap1 $cap2 $n
        }

        # NEXT, GDP
        $cdb eval {
            SELECT H1.dgdp     AS gdp1,
                   H2.dgdp     AS gdp2
            FROM s1.hist_econ AS H1
            JOIN s2.hist_econ AS H2
            ON (H1.t=$t1 AND H2.t=$t2)
        } {
            $self AddTop gdp $gdp1 $gdp2
        }

        # NEXT, Playbox unemployment rate
        $cdb eval {
            SELECT H1.ur      AS ur1,
                   H2.ur      AS ur2
            FROM s1.hist_econ AS H1
            JOIN s2.hist_econ AS H2
            ON (H1.t=$t1 AND H2.t=$t2)
        } {
            $self AddTop unemp $ur1 $ur2
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
            $self AddTop nbunemp $ur1 $ur2 $n
        }
    }
}