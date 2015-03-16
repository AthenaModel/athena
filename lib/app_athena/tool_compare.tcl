#-----------------------------------------------------------------------
# TITLE:
#   tool_compare.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Athena "compare" tool.  This tool compares scenario files.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# tool::COMPARE

tool define COMPARE {
    usage       {1 2 "<adbfile1> ?<adbfile2>?"}
    description "Scenario comparison"
} {
    EXPERIMENTAL.  The 'athena compare' tool compares scenario outcomes and 
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
        set fname1   [file tail $adbfile1]
        set fname2   [file tail $adbfile2]

        # NEXT, get the scenario objects.
        set s1 [$type LoadScenario $adbfile1]

        if {$adbfile2 ne ""} {
            set s2 [$type LoadScenario $adbfile2]
        } else {
            set s2 $s1
        }

        # NEXT, look for differences
        try {
            set comp [athena diff $s1 $s2]
        } trap {SCENARIO INCOMPARABLE} {result} {
            throw FATAL $result
        }

        # NEXT, get the time parameters
        set t1 [$comp t1]
        set t2 [$comp t2]

        if {$s1 eq $s2} {
            puts "Differences in $fname1 between week $t1 and week $t2:"
        } else {
            puts "Differences between $fname1 week $t1 and $fname2 week $t2:"
        }

        puts ""

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
}




