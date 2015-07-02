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
#   The initial comparison looks for significant differences between
#   the two scenarios, and records them as a series of "vardiff" objects.
#   These objects are catalogued by "vartype", e.g., "nbmood", and by 
#   name, "nbmood.N1".
#
#   Then, the comparison object can be asked to provide a causal chain
#   for a particular variable.  It will drill down, looking for
#   explanations of the difference in that particular variable; these
#   explanations take the form of vardiffs for the inputs to the variable,
#   and vardiffs on the inputs to those inputs, until we can go no 
#   farther.  Each vardiff is catalogued like its predecessors, and the
#   tree of significant inputs to a particular vardiff can be traced
#   by querying the vardiff.
#
#-----------------------------------------------------------------------

snit::type ::athena::comparison {
    #-------------------------------------------------------------------
    # Instance Variables
    
    variable s1           ;# Scenario 1
    variable t1           ;# Time 1
    variable s2           ;# Scenario 2
    variable t2           ;# Time 2
    variable cdb          ;# Comparison database
    variable byname {}    ;# Dictionary of differences by varname
    variable toplevel {}  ;# List of toplevel vardiff objects. 

    #-------------------------------------------------------------------
    # Constructor
    
    constructor {s1_ t1_ s2_ t2_} {
        # FIRST, save the constructor arguments.
        set s1 $s1_
        set t1 $t1_
        set s2 $s2_
        set t2 $t2_

        # NEXT, make sure comparison is possible.
        if {$s1 ne $s2} {
            $self CheckCompatibility
        }


        # NEXT, create the CDB.
        set cdb [sqldocument ${selfns}::cdb -readonly yes]
        $cdb open :memory:
        $cdb function t1 [mymethod t1]
        $cdb function t2 [mymethod t2]

        set db1 [$s1 rdbfile]
        set db2 [$s2 rdbfile]

        $cdb eval {
            ATTACH $db1 AS s1;
            ATTACH $db2 AS s2;            
        }

        $cdb eval [readfile [file join $::athena::library sql comparison.sql]]

        # NEXT, initialize the vardiff cache.
        set byname   [dict create]
        set toplevel [list]
    }

    destructor {
        # Destroy the difference objects.
        $self reset
    }

    #-------------------------------------------------------------------
    # Private Routines
    
    # CheckCompatibility
    #
    # Determine whether the two scenarios are sufficiently similar that
    # comparison is meaningful.  Throws "ATHENA INCOMPARABLE" if the
    # two scenarios cannot be meaningfully compared.
    #
    # TBD: The current set of checks is preliminary.

    method CheckCompatibility {} {
        if {![lequal [$s1 nbhood names] [$s2 nbhood names]]} {
            throw {ATHENA INCOMPARABLE} \
                "Scenarios not comparable: different neighborhoods."
        }

        if {![lequal [$s1 actor names] [$s2 actor names]]} {
            throw {ATHENA INCOMPARABLE} \
                "Scenarios not comparable: different actors."
        }

        if {![lequal [$s1 civgroup names] [$s2 civgroup names]]} {
            throw {ATHENA INCOMPARABLE} \
                "Scenarios not comparable: different civilian groups."
        }

        if {![lequal [$s1 frcgroup names] [$s2 frcgroup names]]} {
            throw {ATHENA INCOMPARABLE} \
                "Scenarios not comparable: different force groups."
        }

        if {![lequal [$s1 orggroup names] [$s2 orggroup names]]} {
            throw {ATHENA INCOMPARABLE} \
                "Scenarios not comparable: different organization groups."
        }

        if {![lequal [$s1 bsys system namedict] [$s2 bsys system namedict]]} {
            throw {ATHENA INCOMPARABLE} \
                "Scenarios not comparable: different belief systems."
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method eval  to cdb
    delegate method query to cdb
    

    # addtop vartype val1 val2 keys...
    #
    # vartype  - An output variable type.
    # val1     - The value from s1/t1
    # val2     - The value from s2/t2
    # keys...  - Key values for the vardiff class
    #
    # Given a vardiff type and a pair of values, saves a significant output
    # diff if the difference between the two values is significant.  
    #
    # Returns the diff if it was significant, and "" otherwise. 

    method addtop {vartype val1 val2 args} {
        # FIRST, get the diff
        set diff [$self add $vartype $val1 $val2 {*}$args]

        # NEXT, if it was significant, remember that it was a toplevel
        # vardiff.
        if {$diff ne ""} {
            ladd toplevel $diff
        }

        return $diff
    }

    # add vartype val1 val2 keys...
    #
    # vartype  - An output variable type.
    # val1     - The value from s1/t1
    # val2     - The value from s2/t2
    # keys...  - Key values for the vardiff class
    #
    # Determines if the difference is significant, and returns a vardiff
    # object if so.  If the vardiff already exists, returns the existing
    # object rather than saving a new one.
    #
    # If val1 and val2 are "eq", identical, then the difference is 
    # presumed to be insignificant.  Otherwise, it is left up to the
    # vartype.

    method add {vartype val1 val2 args} {
        # FIRST, exclude identical values; they can never be significant.
        if {$val1 eq $val2} {
            return ""
        }

        # NEXT, create a vardiff object.
        set diff [::athena::vardiff::$vartype new $self $val1 $val2 {*}$args]

        # NEXT, if we've already got this vardiff, return the old copy.
        set name [$diff name]

        if {[dict exists $byname $name]} {
            $diff destroy
            return [dict get $byname $name]
        }

        # NEXT, if it's insignificant, destroy it and return nothing.
        if {![$diff significant]} {
            $diff destroy
            return ""
        }

        # NEXT, it's significant and hadn't existed previously; save 
        # and return it.
        dict set byname [$diff name] $diff
        return $diff
    }


    # reset
    #
    # Resets the differences.

    method reset {} {
        dict for {varname diff} $byname {
            $diff destroy
        }
        set byname   [dict create]
        set toplevel [list]
    }

    #-------------------------------------------------------------------
    # Variable chaining

    # explain varname
    #
    # varname   - A significant vardiff name
    #
    # Starting with the varname, which must name an existing vardiff,
    # drills down the tree as far as possible to populate the vardiff's
    # causality chain.  If the chain has already been computed, does
    # nothing.
    #
    # The algorithm assumes that if a given vardiff's inputs have been
    # computed, then the inputs of those inputs have also been recruited.
    #
    # Returns nothing; use "chain" to retrieve the chain.

    method explain {varname} {
        require {[$self exists $varname]} "No such vardiff in memory"

        set diffs [list [$self getdiff $varname]]
        while {[llength $diffs] > 0} {
            set diff [lshift diffs]

            if {![$diff gotdiffs]} {
                set these [$diff diffs]
                lappend diffs {*}$these
            }
        }
    }

    # getchain varname
    #
    # varname   - A significant vardiff name
    #
    # Computes the causality chain for the named variable.  Returns
    # the vardiffs in the chain.
    #
    # It is common for a vardiff to be an input for multiple vardiffs.
    # Each vardiff appears in the chain once, in breadth-first-search
    # order.

    method getchain {varname} {
        require {[$self exists $varname]} "No such vardiff in memory"

        set chain [dict create]

        set root [$self getdiff $varname]

        if {![$root gotdiffs]} {
            $self explain $varname
        }

        set diffs [list $root]
        while {[llength $diffs] > 0} {
            set diff [lshift diffs]

            if {![dict exists chain $diff]} {
                dict set chain $diff 1
                lappend diffs {*}[$diff diffs]
            }
        }

        return [dict keys $chain]
    }

    #-------------------------------------------------------------------
    # Queries

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

    # list ?-toplevel?
    #
    # Returns a list of the known vardiffs.  If -toplevel is given, only
    # topleve vardiffs (i.e., significant outputs) are included.

    method list {{opt -toplevel}} {
        if {$opt eq "-toplevel"} {
            return $toplevel
        } else {
            return [dict values $byname]
        }        
    }

    # exists varname
    #
    # varname  - A vardiff variable name
    #
    # Returns 1 if there is a significant variable with the given 
    # name, and 0 otherwise.

    method exists {varname} {
        dict exists $byname $varname
    }

    # validate varname
    #
    # varname  - A vardiff variable name
    #
    # Throws INVALID if varname isn't a significant variable, and
    # returns the varname otherwise.

    method validate {varname} {
        if {![$self exists $varname]} {
            throw INVALID "Variable is not significant: $varname"
        }
        return $varname
    }


    # getdiff name
    #
    # name   - A vardiff object name
    #
    # Returns the vardiff object given its name, or "" if none.

    method getdiff {name} {
        if {[dict exists $byname $name]} {
            return [dict get $byname $name]
        } else {
            return ""
        }
    }

    # getbytype ?-toplevel?
    #
    # Returns a dictionary of lists of vardiffs by 
    # vartype.  If -toplevel is given, only toplevel vardiffs are
    # included.

    method getbytype {{opt ""}} {
        set result [dict create]

        foreach diff [$self list $opt] {
            dict lappend result [$diff type] $diff
        }

        return $result
    }

    # contribs sub keys...
    #
    # Calls the contribs command for both scenarios, retrieving the
    # contributions for the given contribs subcommand (e.g., mood)
    # and the given keys.  Looks up the DRID for each driver.  Returns
    # a flat list {drid val1 val2 ...}, where the value is 0 if the
    # driver is undefined for one scenario.

    method contribs {sub args} {
        # FIRST, get the scenario 1 contribs
        $s1 contribs $sub {*}$args -start 0 -end $t1

        $s1 eval {
            SELECT driver_id, contrib, dtype, signature
            FROM uram_contribs AS U
            JOIN drivers AS D
            ON (U.driver = D.driver_id)
        } {
            set drid $dtype/[join $signature /]
            set c($drid) $contrib
        }

        # NEXT, get the scenario 2 contribs
        $s2 contribs $sub {*}$args -start 0 -end $t2

        $s2 eval {
            SELECT driver_id, contrib, dtype, signature
            FROM uram_contribs AS U
            JOIN drivers AS D
            ON (U.driver = D.driver_id)
        } {
            set drid $dtype/[join $signature /]
            if {[info exists c($drid)]} {
                lappend c($drid) $contrib                
            }  else {
                set c($drid) [list 0.0 $contrib]
            }
        }

        # NEXT, build and return the list
        set result [list]

        foreach drid [array names c] {
            if {[llength $c($drid)] == 2} {
                lappend result $drid {*}$c($drid)
            } else {
                lappend result $drid $c($drid) 0.0
            }
        }

        return $result
    }

    #-------------------------------------------------------------------
    # Output of Diffs

    # chain dump varname
    #
    # Returns a text string showing the structure of the chain.

    method {chain dump} {varname} {
        $self DumpChain [$self getdiff $varname] ""
    }

    # DumpChain diff leader
    #
    # diff   - A vardiff
    # leader - Leader spaces
    #
    # Dumps a text string showing the tree structure of the diff's chain.

    method DumpChain {diff leader} {
        lappend result "$leader[$diff name] ([$diff score])"

        if {$leader eq ""} {
            set leader "+-> "
        } else {
            set leader "    $leader"
        }

        foreach d [$diff diffs] {
            lappend result [$self DumpChain $d $leader]
        }

        return [join $result \n]
    }

    # chain huddle varname
    #
    # Returns the chain's differences formatted as a huddle(n) object.

    method {chain huddle} {varname} {
        set hud [huddle list]
    
        foreach diff [$self getchain $varname] {
            huddle append hud [$diff huddle]
        }

        return $hud
    }

    # chain json varname
    #
    # Returns the chain's differences formatted as a JSON string.

    method {chain json} {varname} {
        return [huddle jsondump [$self chain huddle $varname]]
    }
    
    # diffs dump ?-toplevel?
    #
    # Returns a monotext formatted table of the differences.
    # If -toplevel is given, only toplevel vardiffs are
    # included.

    method {diffs dump} {{opt ""}} {
        set vardiffs [list]

        dict for {vartype difflist} [$self getbytype $opt] {
            lappend vardiffs {*}[$self SortByScore $difflist]
        }

        return [$self DumpList $vardiffs]
    }

    # DumpList vardiffs
    #
    # vardiffs - A list of vardiff names
    #
    # Produces a monotext formatted table of the differences in the 
    # list.

    method DumpList {vardiffs} {
        set table [list]
        foreach diff $vardiffs {
            dict set row Variable   [$diff name]
            dict set row A          [$diff fmt1]
            dict set row B          [$diff fmt2]
            dict set row Context    [$diff context]
            dict set row Score      [$diff score]
            dict set row Inputs     [$diff inputs]

            lappend table $row
        }

        return [dictab format $table -headers]
    }

    # diffs json ?-toplevel?
    #
    # Returns the differences formatted as JSON. 

    method {diffs json} {{opt ""}} {
        return [huddle jsondump [$self diffs huddle $opt]]
    }

    # diffs huddle ?-toplevel?
    #
    # Returns the differences formatted as a huddle(n) object.

    method {diffs huddle} {{opt ""}} {
        set hud [huddle list]

        dict for {vartype difflist} [$self getbytype $opt] {
            foreach diff [$self SortByScore $difflist] {
                huddle append hud [$diff huddle]
            }
        }

        return $hud
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