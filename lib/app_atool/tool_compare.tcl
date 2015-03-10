#-----------------------------------------------------------------------
# TITLE:
#   tool_compare.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Atool "compare" tool.  This tool compares scenario files.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# tool::COMPARE

tool define COMPARE {
    usage       {1 2 "<adbfile1> ?<adbfile2>?"}
    description "Scenario comparison"
} {
    EXPERIMENTAL.  The 'atool compare' tool compares scenario outcomes and 
    computes the significant differences in the outputs.

    If only a single scenario file is given, then the tool compares the
    states of the scenario at times T=0 and T=latest.

    If two scenarios are given, then the tool compares the states of the
    two scenarios at time T=latest.  In this case, the two scenarios
    must be compatible.  Precise conditions for compatibility are TBD,
    but at least include the following:

    * Identical neighborhood names
    * Identical actor names
    * Identical group names 
} {
    # Type Variables

    typevariable varnames {
        security.n
        control.n
        influence.n.*
        nbmood.n
    }

    #-------------------------------------------------------------------
    # Execution 

    # execute argv
    #
    # Executes the tool given the command line arguments.

    typemethod execute {argv} {
        # FIRST, get the output file name.
        set adbfile1 [lshift argv]
        set adbfile2 [lshift argv]

        # NEXT, get the scenario objects.
        set s1 [$type LoadScenario $adbfile1]

        if {$adbfile2 ne ""} {
            set s2 [$type LoadScenario $adbfile2]
            $type CheckCompatibility $s1 $s2
        } else {
            set s2 $s1
        }

        # NEXT, get the time parameters
        set fname1 [file tail $adbfile1]
        set fname2 [file tail $adbfile2]

        if {$s1 eq $s2} {
            set t1 0
            set t2 [$s1 clock now]

            puts "Differences in $fname1 between week $t1 and week $t2:"
        } else {
            set t1 [$s1 clock now]
            set t2 [$s2 clock now]

            puts "Differences between $fname1 week $t1 and $fname2 week $t2:"
        }

        puts ""


        # NEXT, look for differences
        foreach var $varnames {
            $type compare $var $s1 $t1 $s2 $t2
        }
    }

    # LoadScenario adbfile
    #
    # adbfile    - A scenario file name
    #
    # Loads the scenario into a scenario object, and does some basic
    # checks.  Halts on error.

    typemethod LoadScenario {adbfile} {
        # FIRST, check the file name.
        if {![string match "*.adb" $adbfile]} {
            throw FATAL \
                "Bad scenario file: expected *.adb, got \"$adbfile\""
        }

        # NEXT, load the file.
        try {
            set s [athena create %AUTO% -adbfile $adbfile]
        } trap {SCENARIO OPEN} {result} {
            throw FATAL "Could not load $adbfile:\n$result"
        }

        # NEXT, check the latest time.
        if {[$s clock now] < 1} {
            throw FATAL \
                "T=0; no simulation results to analyze in $adbfile."
        }

        return $s
    }

    # CheckCompatibility s1 s2
    #
    # s1   - A scenario object
    # s2   - A scenario object
    #
    # Determine whether the two scenarios are sufficiently similar that
    # comparison is meaningful.
    #
    # TBD: The current set of checks is preliminary.

    typemethod CheckCompatibility {s1 s2} {
        if {![lequal [$s1 nbhood names] [$s2 nbhood names]]} {
            throw FATAL \
                "Scenarios not comparable: different neighborhoods."
        }

        if {![lequal [$s1 actor names] [$s2 actor names]]} {
            throw FATAL \
                "Scenarios not comparable: different actors."
        }

        if {![lequal [$s1 civgroup names] [$s2 civgroup names]]} {
            throw FATAL \
                "Scenarios not comparable: different civilian groups."
        }

        if {![lequal [$s1 frcgroup names] [$s2 frcgroup names]]} {
            throw FATAL \
                "Scenarios not comparable: different force groups."
        }

        if {![lequal [$s1 orggroup names] [$s2 orggroup names]]} {
            throw FATAL \
                "Scenarios not comparable: different organization groups."
        }
    }    

    #-------------------------------------------------------------------
    # Difference Checkers

    # compare security.n s1 t1 s2 t2
    #
    # Find differences in nbhood security.
    # Two security values are different if they have different symbols.

    typemethod {compare security.n} {s1 t1 s2 t2} {
        # NOTE: Secret of general comparisons: two queries that produce
        # a vector of items to compare.  It doesn't matter whether the
        # queries are from one scenario or two.
        array set a [$s1 eval {
            SELECT n, security FROM hist_nbhood WHERE t=$t1
        }]

        array set b [$s2 eval {
            SELECT n, security FROM hist_nbhood WHERE t=$t2
        }]

        foreach n [$s1 nbhood names] {
            set asym [qsecurity name $a($n)]
            set bsym [qsecurity name $b($n)]

            if {$asym ne $bsym} {
                printf "%-20s: %-8s => %-8s (%4d => %4d)" \
                    security.$n $asym $bsym $a($n) $b($n)
            }
        }
    }

    # compare control.n s1 t1 s2 t2
    #
    # Find differences in nbhood control.

    typemethod {compare control.n} {s1 t1 s2 t2} {
        array set a [$s1 eval {
            SELECT n, a FROM hist_nbhood WHERE t=$t1
        }]

        array set b [$s2 eval {
            SELECT n, a FROM hist_nbhood WHERE t=$t2
        }]

        foreach n [$s1 nbhood names] {
            if {$a($n) ne $b($n)} {
                printf "%-20s: %-8s => %-8s" \
                    control.$n $a($n) $b($n)
            }
        }
    }

    # compare influence.n.* s1 t1 s2 t2
    #
    # Find differences in nbhood influence.

    typemethod {compare influence.n.*} {s1 t1 s2 t2} {
        foreach n [$s1 nbhood names] {
            set actors1($n) {}
            set actors2($n) {}
        }

        $s1 eval {
            SELECT n, a, influence FROM hist_support 
            WHERE t=$t1
            ORDER BY influence DESC
        } {
            if {$influence > 0} {
                lappend actors1($n) $a
            }
            set inf1($n,$a) $influence
        }

        $s2 eval {
            SELECT n, a, influence FROM hist_support 
            WHERE t=$t2
            ORDER BY influence DESC
        } {
            if {$influence > 0} {
                lappend actors2($n) $a
            }
            set inf2($n,$a) $influence
        }

        foreach n [$s1 nbhood names] {
            defset actors1($n) "*NONE*"
            defset actors2($n) "*NONE*"

            if {$actors1($n) ne $actors2($n)} {
                printf "%-20s: %s => %s" \
                    influence.$n.* $actors1($n) $actors2($n)
            }
        }
    }


    # compare nbmood.n s1 t1 s2 t2
    #
    # Find differences in nbhood control.

    typemethod {compare nbmood.n} {s1 t1 s2 t2} {
        array set a [$s1 eval {
            SELECT n, nbmood FROM hist_nbhood WHERE t=$t1
        }]

        array set b [$s2 eval {
            SELECT n, nbmood FROM hist_nbhood WHERE t=$t2
        }]

        foreach n [$s1 nbhood names] {
            set asym [qsat name $a($n)]
            set bsym [qsat name $b($n)]

            if {abs($a($n) - $b($n)) > 10.0} {
                printf "%-20s: %-8s => %-8s (%6.1f => %6.1f)" \
                    nbmood.$n $asym $bsym $a($n) $b($n)
            }
        }
    }

    #-------------------------------------------------------------------
    # Helper Procs

    # printf fmt args
    #
    # fmt  - a format string
    # 
    # puts [format ...]

    proc printf {fmt args} {
        puts [uplevel 1 [list format $fmt {*}$args]]
    }
    
    # defset varname value
    #
    # varname   - A variable name
    # value     - value
    #
    # Assigns the value to the variable only if the variable's value
    # is currently the empty string.

    proc defset {varname value} {
        upvar 1 $varname var

        if {$var eq ""} {
            set var $value
        }
    }

    # lequal list1 list2
    #
    # Returns 1 if the lists are equal and 2 otherwise.
    # Sorts the lists before comparing.

    proc lequal {list1 list2} {
        expr {[lsort $list1] eq [lsort $list2]}
    }

}






