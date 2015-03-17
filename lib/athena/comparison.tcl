#-----------------------------------------------------------------------
# TITLE:
#   comparison.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n): Scenario Comparison class
#
#   A comparison object records the results of comparing two scenarios
#   (or the same scenario at different times).
#
#-----------------------------------------------------------------------

snit::type ::athena::comparison {
    #-------------------------------------------------------------------
    # Instance Variables
    
    variable s1         ;# Scenario 1
    variable t1         ;# Time 1
    variable s2         ;# Scenario 2
    variable t2         ;# Time 2
    variable diffs {}   ;# Dictionary of differences by vartype

    #-------------------------------------------------------------------
    # Constructor
    
    constructor {s1_ t1_ s2_ t2_} {
        set s1 $s1_
        set t1 $t1_
        set s2 $s2_
        set t2 $t2_
        set diffs [dict create]

        if {$s1 ne $s2} {
            $self CheckCompatibility
        }
    }

    destructor {
        # Destroy the difference objects.
        $self reset
    }

    # CheckCompatibility
    #
    # Determine whether the two scenarios are sufficiently similar that
    # comparison is meaningful.  Throws "SCENARIO INCOMPARABLE" if the
    # two scenarios cannot be meaningfully compared.
    #
    # TBD: The current set of checks is preliminary.

    method CheckCompatibility {} {
        if {![lequal [$s1 nbhood names] [$s2 nbhood names]]} {
            throw {SCENARIO INCOMPARABLE} \
                "Scenarios not comparable: different neighborhoods."
        }

        if {![lequal [$s1 actor names] [$s2 actor names]]} {
            throw {SCENARIO INCOMPARABLE} \
                "Scenarios not comparable: different actors."
        }

        if {![lequal [$s1 civgroup names] [$s2 civgroup names]]} {
            throw {SCENARIO INCOMPARABLE} \
                "Scenarios not comparable: different civilian groups."
        }

        if {![lequal [$s1 frcgroup names] [$s2 frcgroup names]]} {
            throw {SCENARIO INCOMPARABLE} \
                "Scenarios not comparable: different force groups."
        }

        if {![lequal [$s1 orggroup names] [$s2 orggroup names]]} {
            throw {SCENARIO INCOMPARABLE} \
                "Scenarios not comparable: different organization groups."
        }
    }

    # add vartype val1 val2 keys...
    #
    # vartype  - An output variable type.
    # val1     - The value from s1/t1
    # val2     - The value from s2/t2
    # keys...  - Key values for the vardiff class
    #
    # Adds the diff to the differences, or throws it away if it isn't
    # significant.  If val1 and val2 are "eq", identical, then the
    # difference is presumed to be insignificant.

    method add {vartype val1 val2 args} {
        # FIRST, exclude identical values.
        if {$val1 eq $val2} {
            return
        }

        # NEXT, create a vardiff object; keep it if the difference
        # proves to be significant, and otherwise throw it away.
        set diff [::athena::vardiff::$vartype new $self $val1 $val2 {*}$args]

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

    #-------------------------------------------------------------------
    # Output of Diffs
    
    # diffs dump
    #
    # Returns a monotext formatted table of the differences.

    method {diffs dump} {} {
        set table [list]
        dict for {vartype difflist} $diffs {
            foreach diff [$self SortByScore $difflist] {
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

    # diffs json
    #
    # Returns the differences formatted as JSON. 

    method {diffs json} {} {
        set hud [huddle list]

        dict for {vartype difflist} $diffs {
            foreach diff [$self SortByScore $difflist] {
                set hvar [huddle compile dict [$diff view]]
                huddle append hud $hvar
            }
        }

        return [huddle jsondump $hud]
    }



    # SortByScore difflist
    #
    # Returns the difflist sorted in order of decreasing score.

    method SortByScore {difflist} {
        return [lsort -command [myproc CompareScores] \
                      -decreasing $difflist]
    } 

    proc CompareScores {diff1 diff2} {
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