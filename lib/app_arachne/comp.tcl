#-----------------------------------------------------------------------
# TITLE:
#   comp.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# PACKAGE:
#   app_arachne(n): Arachne Implementation Package
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Arachne comparison manager.  Each comp is a comparison of one or
#   two distinct scenarios.
#
#-----------------------------------------------------------------------

snit::type comp {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # comps array: tracks comparison(n) objects
    #
    # ids               - The IDs of the different comps.
    # comp-$id          - The comparison object for $id 
    # cases-$id         - The case names for $id
    # longname-$id      - Comp long name, derived from comparison

    typevariable comps -array {
        ids     {}
    }

    #-------------------------------------------------------------------
    # Initialization

    # init
    #
    # Subscribe to case events.

    typemethod init {} {
        notifier bind ::case <Update> ::comp [mytypemethod CaseChange]
        notifier bind ::case <Delete> ::comp [mytypemethod CaseChange]
    }

    # clear
    #
    # Removes all comparisons.

    typemethod clear {} {
        foreach id $comps(ids) {
            $type Remove $id
        }

        array unset comps
        set comps(ids)     {}
    }

    #-------------------------------------------------------------------
    # Event Handlers

    # CaseChange case
    #
    # case   - A case ID
    #
    # The named case has changed significantly; any comparisons involving
    # it must be destroyed.

    typemethod CaseChange {case} {
        foreach id $comps(ids) {
            if {$case in $comps(cases-$id)} {
                $type Remove $id
            }
        }
    }
    

    #-------------------------------------------------------------------
    # Queries

    # names
    #
    # Returns the list of comp names.

    typemethod names {} {
        return $comps(ids)
    }

    # longname id
    #
    # id - A comp ID
    #
    # Returns the comparison's long name.

    typemethod longname {id} {
        return $comps(longname-$id)
    }

    # exists id
    #
    # id  - A comp ID
    #
    # Returns 1 if there's a comp with this ID, and 0 otherwise.

    typemethod exists {id} {
        expr {$id in $comps(ids)}
    }

    # validate id
    #
    # Validates the comp id.

    typemethod validate {id} {
        if {![comp exists $id]} {
            throw INVALID "Unknown comparison: \"$id\""
        }

        return $id
    }



    # metadata id
    #
    # id - A comparison ID
    #
    # Returns a dictionary of metadata about the comparison.

    typemethod metadata {id} {
        set comp $comps(comp-$id)

        dict set dict id       $id
        dict set dict longname $comps(longname-$id)
        dict set dict case1    [lindex $comps(cases-$id) 0]
        dict set dict case2    [lindex $comps(cases-$id) 1]
        dict set dict t1       [$comp t1]
        dict set dict t2       [$comp t2]
        dict set dict week1    [$comp s1 clock toString [$comp t1]]
        dict set dict week2    [$comp s2 clock toString [$comp t2]]
    }

    # huddle id
    #
    # Returns a huddle(n) string representing the comparison, including
    # all significant outputs.

    typemethod huddle {id} {
        set cdict [huddle compile dict [$type metadata $id]]
        huddle set cdict outputs [$type with $id diffs huddle]
        return $cdict
    }    

    #-------------------------------------------------------------------
    # Operations

    # with id subcommand ...
    #
    # id - A comparison ID
    #
    # Asks the comp to execute the subcommand.

    typemethod with {id args} {
        tailcall $comps(comp-$id) {*}$args
    }

    # get case1 ?case2?
    #
    # case1   - The first case
    # case2   - Optionally, a second case
    #
    # Attempts to retrieve a comparison ID for the specified cases. 
    # If we have a cached valid comparison for the cases, we simply
    # return its ID.  Otherwise, we verify that we can compare the
    # case(s), do so, and return the ID.
    #
    # If one case is given, compares the start and the end of the run.
    # If two cases are given, compares the two as of the end of the run.
    #
    # Throws some flavor of {ARACHNE COMPARE *} on error.

    typemethod get {case1 {case2 ""}} {
        # FIRST, get the ID.  If we already have a comparison with this
        # ID, return the ID.
        if {$case2 ne "" && $case2 ne $case1} {
            set id "$case1/$case2"
        } else {
            set id "$case1"
        }

        if {$id in $comps(ids)} {
            return $id
        }

        # NEXT, verify that we can create a comparison object.
        set s1 [CheckCase $case1]

        if {$case2 eq ""} {
            set case2 $case1
            set s2    $s1
        } else {
            set s2 [CheckCase $case2]
        }

        # NEXT, create a comparison object.
        try {
            set comp [athena diff $s1 $s2]
        } trap {ATHENA INCOMPARABLE} {result} {
            set prefix "Error in constructor: "
            if {[string match "$prefix*" $result]} {
                set len [string length $prefix]
                set result [string range $result $len end]
            }
            throw {ARACHNE COMPARE INCOMPARABLE} $result
        }

        # NEXT, save the data
        lappend comps(ids)      $id
        set comps(comp-$id)     $comp
        set comps(cases-$id)    [list $case1 $case2]
        set comps(longname-$id) \
            "$case1 @ [$comp t1] vs. $case2 @ [$comp t2]"

        return $id
    }

    # CheckCase case
    #
    # case  - A case ID
    #
    # Checks whether the case is ripe for comparison.

    proc CheckCase {case} {
        case validate $case

        set s [case get $case]

        if {![$s is advanced]} {
            throw {ARACHNE COMPARE NORUN} \
                "Time has not been advanced in case \"$case\"."
        }

        if {[$s is busy]} {
            throw {ARACHNE COMPARE BUSY} \
                "Scenario is busy in case \"$case\"."
        }

        return $s
    }

    #-------------------------------------------------------------------
    # Private Helpers

    # Remove id
    #
    # id   - A comp ID
    #
    # Destroys the comp object and its log, and removes any related data
    # from disk.

    typemethod Remove {id} {
        comp with $id destroy

        array unset comps(*-$id)
        ldelete comps(ids) $id
    }
}

