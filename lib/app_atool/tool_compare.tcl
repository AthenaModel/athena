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




    #-------------------------------------------------------------------
    # Difference Checkers

    # compare security.n comp
    #
    # Find differences in nbhood security.
    # Two security values are different if they have different symbols.

    typemethod {compare security.n} {comp} {
        set t1 [$comp t1]
        set t2 [$comp t2]

        array set val1 [$comp s1 eval {
            SELECT n, security FROM hist_nbhood WHERE t=$t1
        }]

        array set val2 [$comp s2 eval {
            SELECT n, security FROM hist_nbhood WHERE t=$t2
        }]

        foreach n [$comp s1 nbhood names] {
            set sym1 [qsecurity name $val1($n)]
            set sym2 [qsecurity name $val2($n)]

            if {$sym1 eq $sym2} {
                continue
            }

            $comp add security.n \
                [::vardiff::security.n new $n $val1($n) $val2($n)]
        }
    }

    # compare control.n comp
    #
    # Find differences in nbhood control.

    typemethod {compare control.n} {comp} {
        set t1 [$comp t1]
        set t2 [$comp t2]

        array set val1 [$comp s1 eval {
            SELECT n, a FROM hist_nbhood WHERE t=$t1
        }]

        array set val2 [$comp s2 eval {
            SELECT n, a FROM hist_nbhood WHERE t=$t2
        }]

        foreach n [$comp s1 nbhood names] {
            if {$val1($n) eq $val2($n)} {
                continue
            }

            $comp add control.n \
                [::vardiff::control.n new $n $val1($n) $val2($n)]
        }
    }

    # compare influence.n.* comp
    #
    # Find differences in nbhood influence.

    typemethod {compare influence.n.*} {comp} {
        set t1 [$comp t1]
        set t2 [$comp t2]

        foreach n [$comp s1 nbhood names] {
            set actors1($n) {}
            set actors2($n) {}
        }

        $comp s1 eval {
            SELECT n, a, influence FROM hist_support 
            WHERE t=$t1
            ORDER BY influence DESC
        } {
            if {$influence > 0} {
                lappend actors1($n) $a
            }
            set inf1($n,$a) $influence
        }

        $comp s2 eval {
            SELECT n, a, influence FROM hist_support 
            WHERE t=$t2
            ORDER BY influence DESC
        } {
            if {$influence > 0} {
                lappend actors2($n) $a
            }
            set inf2($n,$a) $influence
        }

        foreach n [$comp s1 nbhood names] {
            defset actors1($n) "*NONE*"
            defset actors2($n) "*NONE*"

            if {$actors1($n) eq $actors2($n)} {
                continue
            }

            $comp add influence.n.* \
                [::vardiff::influence.n.* new $n $actors1($n) $actors2($n)]
        }
    }


    # compare nbmood.n comp
    #
    # Find differences in nbhood control.

    typemethod {compare nbmood.n} {comp} {
        set t1 [$comp t1]
        set t2 [$comp t2]

        array set val1 [$comp s1 eval {
            SELECT n, nbmood FROM hist_nbhood WHERE t=$t1
        }]

        array set val2 [$comp s2 eval {
            SELECT n, nbmood FROM hist_nbhood WHERE t=$t2
        }]

        foreach n [$comp s1 nbhood names] {
            if {abs($val1($n) - $val2($n)) < 10.0} {
                continue
            }

            $comp add nbmood.n \
                [vardiff::nbmood.n new $n $val1($n) $val2($n)]
        }
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





