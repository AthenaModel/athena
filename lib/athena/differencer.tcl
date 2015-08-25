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
#   NOTE: This module has no state data!  It exists because it's
#   preferable to do validation prior to calling the comparison(n)
#   constructor.
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
        # FIRST, initialize the compdb(n) 
        athena::compdb     init

        # NEXT, get the scenarios.
        if {![string match "-*" [lindex $args 0]]} {
            set s2 [lshift args]
        } else {
            set s2 $s1
        }

        # NEXT, make sure they are comparable.
        ::athena::comparison check $s1 $s2

        # NEXT, set the default times
        if {$s2 eq $s1} {
            set t1 0
            set t2 [$s1 clock now]

            if {$t1 == $t2} {
                error "Trivial: scenario with itself at t=0"
            }
        } else {
            set t1 [$s1 clock now]
            set t2 [$s2 clock now]
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
            error "-t2 out of range: 0...[$s2 clock now]"
        }

        # NEXT, create the comparison and look for
        # differences.
        set comp [::athena::comparison new $s1 $t1 $s2 $t2]

        $comp compare

        return $comp
    }


}


