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
        set comp [comparison new $s1 $t1 $s2 $t2]

        $type DoComparisons $comp

        # NEXT, output to console.
        puts [$comp dump]

        $comp destroy
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

    # DoComparisons comp
    #
    # comp  - A comparison object
    #
    # Queries history to identify significant outputs.

    typemethod DoComparisons {comp} {
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

        # hist_nbhood data
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
            $comp add nbsecurity.n $n $nbsec1  $nbsec2
            $comp add control.n    $n $a1      $a2
            $comp add nbmood.n     $n $nbmood1 $nbmood2
        }

        # hist_support data
        set idict1 [dict create]
        set idict2 [dict create]

        foreach n [$comp s1 nbhood names] {
            dict set idict1 $n {}
            dict set idict2 $n {}
        }

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
                dict set idict1 $n $a $influence1
            }
            if {$influence2 > 0.0} {
                dict set idict2 $n $a $influence2
            }

            $comp add support.n.a $n $a $support1 $support2
        }

        foreach n [$comp s1 nbhood names] {
            $comp add influence.n.* $n \
                [dict get $idict1 $n]  \
                [dict get $idict2 $n]
        }

        $cdb destroy
    }
}



#-------------------------------------------------------------------
# Helper Procs
#
# These should go in a library, probably in Kite.

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





