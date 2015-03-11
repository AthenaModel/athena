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

    typevariable vartypes {
        security.n
        control.n
        support.n.a
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

        foreach var $vartypes {
            ::vardiff::$var compare $comp
        }

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





