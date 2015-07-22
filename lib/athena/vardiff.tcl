#-----------------------------------------------------------------------
# TITLE:
#   vardiff.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Variable difference base class
#
#-----------------------------------------------------------------------

oo::class create ::athena::vardiff {
    meta type *            ;# Type is undefined; subclasses should override.
    meta category "???"    ;# PMESII category is undefined; subclasses 
                            # should override.
    meta normfunc 1.0      ;# Default normalization function
    meta afactors {}       ;# A factors, used to relate scores of different 
                            # types

    variable comp          ;# comparison object
    variable keydict       ;# Key dictionary
    variable val1          ;# Value from case 1
    variable val2          ;# Value from case 2
    variable gotInputs     ;# 1 if we've computed diffs, and 0 otherwise.
    variable iscores       ;# Array of scores by vardiff object for
                            # significant inputs.

    # Transient variables, used during input scoring.
    variable byType        ;# Array of input vardiffs by vartype.
    variable valueCache    ;# Array of value lists by vartype.

    # constructor comp_ keydict_ val1_ val2_
    #
    # comp_     - The comparison(n) object that owns this difference.
    # keydict_  - A dictionary of variable keys and values.
    # val1_     - The value of the variable for the first scenario/time
    #             pair
    # val2_     - The value of the variable for the second scenario/time
    #             pair.
    #
    # Saves the inputs into instance variables.

    constructor {comp_ keydict_ val1_ val2_} {
        set comp      $comp_
        set keydict   $keydict_
        set val1      $val1_
        set val2      $val2_
        set gotInputs 0
    }

    # name
    #
    # Computes the variable name from the variable type and the 
    # key dictionary.

    method name {} {
        set prefix [lindex [split [my type] .] 0]

        dict for {key val} $keydict {
            append prefix .$val
        }
        return $prefix
    }

    # keydict
    #
    # Returns the dictionary of key names and values.

    method keydict {} {
        return $keydict
    }

    # keys
    #
    # Returns the names of the keys in the keydict, 
    # e.g., {g c} for a satisfaction level

    method keys {} {
        return [dict keys $keydict]
    }

    # key name
    #
    # Returns the value of the named key, e.g., "AUT" for key "c".

    method key {name} {
        return [dict get $keydict $name]
    }

    # val1
    #
    # Returns the raw value of the variable for the first scenario/time 
    # pair.

    method val1 {} {
        return $val1
    }

    # val2
    #
    # Returns the raw value of the variable for the second scenario/time 
    # pair.

    method val2 {} {
        return $val2
    }

    # fmt1
    #
    # Returns the formatted value of the variable for the first 
    # scenario/time pair.

    method fmt1 {} {
        return [my format $val1]
    }

    # fmt2
    #
    # Returns the formatted value of the variable for the second 
    # scenario/time pair.

    method fmt2 {} {
        return [my format $val2]
    }

    # format val
    #
    # val   - A value of the variable's type
    #
    # Returns the formatted value.  This can be overridden by
    # subclasses; it is intended to return a minimal formatted
    # value for display.  Override in subclasses

    method format {val} {
        return $val
    }

    # fancy1
    #
    # Returns the fancy value of the variable for the first 
    # scenario/time pair, i.e., formatted with elaborations 
    # (symbolic value, units, etc.).

    method fancy1 {} {
        return [my fancy $val1]
    }

    # fancy2
    #
    # Returns the fancy value of the variable for the second 
    # scenario/time pair, i.e., formatted with elaborations 
    # (symbolic value, units, etc.).

    method fancy2 {} {
        return [my fancy $val2]
    }

    # fancy val
    #
    # val   - A value of the variable's type
    #
    # Returns the formatted value with elaborations, e.g.,
    # including a symbolic value, units, etc.  Defaults to the
    # 'format'.  Override in subclasses as needed.

    method fancy {val} {
        return [my format $val]
    }

    # context
    #
    # Any additional info that might be useful to the analyst.
    # Override in subclasses as needed.

    method context {} {
        return ""
    }

    # delta
    #
    # The absolute difference of the two values, only if that makes
    # sense.  Subclasses should override this if necessary.

    method delta {} {
        expr {abs([my val1] - [my val2])}
    }

    # trivial
    #
    # Returns 1 if the difference is trivial and not worth retaining,
    # and 0 otherwise.  By default we presume the difference is 
    # non-trivial.  It should be overridden
    # by vardiff types that have some additional criterion for 
    # non-triviality, i.e., an epsilon check.

    method trivial {} {
        return 0
    }

    # view
    #
    # Returns a view on the difference record.

    method view {} {
        dict set result type     [my type]
        dict set result name     [my name]
        dict set result category [my category]

        dict for {key value} $keydict {
            dict set result $key $value
        }
        
        dict set result val1      $val1
        dict set result fmt1      [my fmt1]
        dict set result fancy1    [my fancy1]
        dict set result val2      $val2
        dict set result fmt2      [my fmt2]
        dict set result fancy2    [my fancy2]
        dict set result delta     [my delta]
        dict set result narrative [my narrative]
        dict set result context   [my context]

        return $result
    }

    # huddle
    #
    # Returns a huddle object corresponding to this vardiff.  It 
    # contains the view plus the inputs.

    method huddle {} {
        # FIRST, get a dictionary of scores by diff name
        set inputs [dict create]

        foreach diff [array names iscores] {
            dict set inputs [$diff name] $iscores($diff)
        }

        set hvar [huddle compile dict [my view]]
        huddle set hvar inputs [huddle compile dict $inputs]
        
        return $hvar
    }


    # gotInputs
    #
    # Returns 1 if we've scored inputs for this vardiff, and 0 otherwise.

    method gotInputs {} {
        return $gotInputs
    }

    # inputs
    #
    # Computes vardiffs for significant differences in variable
    # inputs, adding them to the comparison object and scoring them
    # as inputs.  Returns the dictionary of scores by vardiff.

    method inputs {} {
        # FIRST, simply return inputs if we already have them.
        if {$gotInputs} {
            return [my SortDict [array get iscores]]
        }

        # NEXT, call the subclass method to populate the byType and
        # valueCache variables.
        my FindInputs 
        my ScoreInputs

        set gotInputs 1
        array unset valueCache
        array unset byType

        return [my SortDict [array get iscores]]
    }

    # FindInputs
    #
    # Subclasses should override this if drilling down is possible.

    method FindInputs {} {
        return
    }


    # AddInput vartype val1 val2 keys...
    #
    # vartype  - A vardiff type.
    # val1     - The value from s1/t1
    # val2     - The value from s2/t2
    # keys...  - Key values for the vardiff class
    #
    # Given a vardiff type and a pair of values, saves a significant input
    # diff if the difference between the two values is significant.  
    #
    # Returns the diff if it was significant, and "" otherwise. 
    #
    # This method is for use by subclasses in their FindInputs methods.

    method AddInput {vartype val1 val2 args} {
        # FIRST, save the values for the normalizer, if they are needed.
        # They will be needed if the normalizer function isn't a 
        # constant number.
        set T ::athena::vardiff::$vartype

        if {![string is double -strict [$T normfunc]]} {
            lappend valueCache($vartype) $val1 $val2
        }

        # NEXT, get the diff.
        set diff [$comp add $vartype $val1 $val2 {*}$args]

        # NEXT, save it by type so that we can do scoring.  Note that 
        # trivial differences are filtered out by the previous step.
        if {$diff ne ""} {
            lappend byType($vartype) $diff
        }
    }

    # ScoreInputs
    #
    # Scores each of the input vardiffs, adding its score to the 
    # scores array.  The vardiffs can now be ranked by relative score.
    # The maximum score is always 100.0.

    method ScoreInputs {} {
        # FIRST, score all of the outputs by type, so that each is 
        # properly ranked within its type.  Adds a vardiff/score to the
        # scores array.
        foreach vartype [array names byType] {
            if {[info exists valueCache($vartype)]} {
                set values $valueCache($vartype)
            } else {
                set values [list]
            }

            set normalizer [$comp normalizer $vartype $values]
            $comp scoreByType iscores $normalizer $byType($vartype)
        }

        # NEXT, normalize the scores so that the max is 100.0
        array set A [my afactors]
        $comp normalizeScores iscores A
    }

    # SortDict dict
    #
    # dict   - A dictionary with numeric values.
    #
    # Returns the same dictionary with the keys sorted in order
    # of descending value.

    method SortDict {dict} {
        return [lsort -real -decreasing -stride 2 -index 1 $dict]
    }

    #-------------------------------------------------------------------
    # Narrative Tools

    # narrative
    #
    # Returns a narrative string for the vardiff.  This should be
    # overridden by subclasses.

    method narrative {} {
        return [my DeltaNarrative]
    }

    method DeltaNarrative {{title "Value"} {units ""}} {
        set text "$title "

        if {[my val2] > [my val1]} {
            append text "increased"
        } else {
            append text "decreased"
        }

        append text " by [my format [my delta]]"

        if {$units ne ""} {
            append text " $units"
        }

        append text "."

        return $text
    }

}
