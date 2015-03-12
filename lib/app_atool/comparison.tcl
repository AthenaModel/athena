#-----------------------------------------------------------------------
# TITLE:
#   comparison.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Scenario Comparison class
#
#-----------------------------------------------------------------------

oo::class create comparison {
    variable s1         ;# Scenario 1
    variable t1         ;# Time 1
    variable s2         ;# Scenario 2
    variable t2         ;# Time 2
    variable diffs      ;# Dictionary of differences by vartype

    constructor {s1_ t1_ s2_ t2_} {
        set s1 $s1_
        set t1 $t1_
        set s2 $s2_
        set t2 $t2_
        set diffs [dict create]

        if {$s1 ne $s2} {
            my CheckCompatibility
        }
    }

    destructor {
        # Destroy the difference objects.
        my reset
    }

    # CheckCompatibility
    #
    # Determine whether the two scenarios are sufficiently similar that
    # comparison is meaningful.
    #
    # TBD: The current set of checks is preliminary.

    method CheckCompatibility {} {
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

    # add vartype args...
    #
    # vartype  - An output variable type.
    # args     - Creation arguments for that vardiff class.
    #
    # Adds the diff to the differences, or throws it away if it isn't
    # significant.

    method add {vartype args} {
        set diff [::vardiff::$vartype new [self] {*}$args]

        if {[$diff significant]} {
            dict lappend diffs [$diff type] $diff
        } else {
            $diff destroy
        }
    }


    # reset
    #
    # Resets the differences.

    method reset {} {
        dict for {vartype difflist} $diffs {
            foreach diff $difflist {
                $diff destroy
            }
        }
        set diffs [dict create]
    }

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

    # dump
    #
    # Returns a formatted table of the differences.

    method dump {} {
        set table [list]
        dict for {vartype difflist} $diffs {
        set difflist [lsort \
            -command [list [self] compareScores] \
            -decreasing $difflist]

            foreach diff $difflist {
                dict set row Variable   [$diff name]
                dict set row A          [$diff fmt1]
                dict set row B          [$diff fmt2]
                dict set row Context    [$diff context]
                dict set row Score      [$diff score]

                lappend table $row
            }
        }

        return [dictab format $table -headers]
    }

    method compareScores {diff1 diff2} {
        set score1 [$diff1 score]
        set score2 [$diff2 score]

        if {$score1 < $score2} {
            return -1
        } elseif {$score1 > $score2} {
            return 1
        } else {
            return 0
        }
    }

}