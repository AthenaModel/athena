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
    usage       {1 "<file1>"}
    description "Scenario comparison"
} {
    EXPERIMENTAL.  The 'atool compare' tool compares two scenarios and 
    computes the significant differences in the outputs.

    For now, this tool outputs the significant deltas between time 0 and
    time T for a single scenario.  Ultimately we will enable comparison
    of any two times and any two scenarios, and we will determine causal
    chains.
} {
    #-------------------------------------------------------------------
    # Execution 

    # execute argv
    #
    # Executes the tool given the command line arguments.

    typemethod execute {argv} {
        # FIRST, get the output file name.
        set infile [lshift argv]

        if {![string match "*.adb" $infile]} {
            throw FATAL \
                "Missing input file: expected *.adb, got \"$infile\""
        }

        # NEXT, create a scenario.
        puts "Loading scenario: $infile"

        try {
            athena create ::sdb \
                -adbfile $infile
        } trap {SCENARIO OPEN} {result} {
            throw FATAL "Could not load $infile:\n$result"
        }

        if {![sdb locked]} {
            throw FATAL "Scenario is not locked; nothing to compare."
        }

        # NEXT, get the time parameters
        set t1 0
        set t2 [sdb clock now]

        puts "Differences from week $t1 to week $t2:\n"

        # NEXT, look for differences
        $type DiffNbhoodSecurity  ::sdb $t1 ::sdb $t2
        $type DiffNbhoodControl   ::sdb $t1 ::sdb $t2
        $type DiffNbhoodInfluence ::sdb $t1 ::sdb $t2
        $type DiffNbhoodMood      ::sdb $t1 ::sdb $t2
    }

    #-------------------------------------------------------------------
    # Difference Checkers

    # DiffNbhoodSecurity s1 t1 s2 t2
    #
    # Find differences in nbhood security.
    # Two security values are different if they have different symbols.

    typemethod DiffNbhoodSecurity {s1 t1 s2 t2} {
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
                puts [format "%-15s: %-8s => %-8s (%4d => %4d)" \
                    security.$n $asym $bsym $a($n) $b($n)]
            }
        }
    }

    # DiffNbhoodControl s1 t1 s2 t2
    #
    # Find differences in nbhood control.

    typemethod DiffNbhoodControl {s1 t1 s2 t2} {
        array set a [$s1 eval {
            SELECT n, a FROM hist_nbhood WHERE t=$t1
        }]

        array set b [$s2 eval {
            SELECT n, a FROM hist_nbhood WHERE t=$t2
        }]

        foreach n [$s1 nbhood names] {
            if {$a($n) ne $b($n)} {
                puts [format "%-15s: %-8s => %-8s" \
                    control.$n $a($n) $b($n)]
            }
        }
    }

    # DiffNbhoodInfluence s1 t1 s2 t2
    #
    # Find differences in nbhood influence.

    typemethod DiffNbhoodInfluence {s1 t1 s2 t2} {
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
                puts [format "%-15s: %s => %s" \
                    influence.$n $actors1($n) $actors2($n)]
            }
        }
    }


    # DiffNbhoodMood s1 t1 s2 t2
    #
    # Find differences in nbhood control.

    typemethod DiffNbhoodMood {s1 t1 s2 t2} {
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
                puts [format "%-15s: %-8s => %-8s (%6.1f => %6.1f)" \
                    nbmood.$n $asym $bsym $a($n) $b($n)]
            }
        }
    }

    proc defset {varname value} {
        upvar 1 $varname var

        if {$var eq ""} {
            set var $value
        }
    }

}






