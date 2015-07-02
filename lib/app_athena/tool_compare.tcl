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
    usage       {1 - "<adbfile1> ?<adbfile2>? ?options...?"}
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

    Options:

    -format dump|json  - Output format
    -chain varname     - Variable name to explain.
    -set parm=value    - Set a compdb(5) parameter value.
} {
    #-------------------------------------------------------------------
    # Execution 

    # execute argv
    #
    # Executes the tool given the command line arguments.

    typemethod execute {argv} {
        # FIRST, parse the command line

        # adbfile1
        set adbfile1 [lshift argv]
        set fname1   [file tail $adbfile1]

        # adbfile2
        if {![string match "-*" [lindex $argv 0]]} {
            set adbfile2 [lshift argv]
        } else {
            set adbfile2 ""
        }
        set fname2   [file tail $adbfile2]

        # options
        array set opts {
            -format dump
            -chain   {}
        }

        athena compdb init
        try {
            foroption opt argv -all {
                -format {
                    set opts(-format) [lshift argv]
                    if {$opts(-format) ni {dump json}} {
                        throw INVALID \
                            "Invalid -format value, \"$opts(-format)\""
                    }
                }
                -chain {
                    set opts(-chain) [lshift argv]
                }
                -set {
                    lassign [split [lshift argv] =] parm value
                    athena compdb validate $parm
                    athena compdb set $parm $value
                    puts "$parm = $value"
                }
            }            
        } on error {result} {
            throw FATAL $result
        }

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
        } trap {ATHENA INCOMPARABLE} {result} {
            throw FATAL $result
        }

        # NEXT, get the time parameters
        set t1 [$comp t1]
        set t2 [$comp t2]

        puts ""
        
        if {$s1 eq $s2} {
            puts "Differences in $fname1 between week $t1 and week $t2:"
        } else {
            puts "Differences between $fname1 week $t1 and $fname2 week $t2:"
        }

        puts ""

        # NEXT, explain the -chain variable, so that its chain gets
        # included in the list of vars.
        if {$opts(-chain) ne "" && [$comp exists $opts(-chain)]} {
            $comp explain $opts(-chain)
        }


        # NEXT, output to console.
        puts [$comp diffs $opts(-format)]

        # NEXT, dump chain.
        if {$opts(-chain) ne ""} {
            puts "\nChain for: $opts(-chain)\n"
            if {![$comp exists $opts(-chain)]} {
                puts "Variable $opts(-chain) is not signficant"
            } else {
                puts [$comp chain dump $opts(-chain)]
            }
        }

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
        set s [athena create %AUTO%]

        try {
            $s load $adbfile
        } trap {ATHENA LOAD} {result} {
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




