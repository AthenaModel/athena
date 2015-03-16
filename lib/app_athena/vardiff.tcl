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

oo::class create vardiff {
    meta type *      ;# Type is undefined

    variable comp    ;# comparison object
    variable keydict ;# Key dictionary
    variable val1    ;# Value from case 1
    variable val2    ;# Value from case 2

    constructor {comp_ keydict_ val1_ val2_} {
        set comp    $comp_
        set keydict $keydict_
        set val1    $val1_
        set val2    $val2_
    }

    method name {} {
        set prefix [lindex [split [my type] .] 0]

        dict for {key val} $keydict {
            append prefix .$val
        }
        return $prefix
    }

    method keydict {} {
        return $keydict
    }

    method keys {} {
        return [dict keys $keydict]
    }

    method key {name} {
        return [dict get $keydict $name]
    }

    method val1 {} {
        return $val1
    }

    method val2 {} {
        return $val2
    }

    method fmt1 {} {
        return [my format $val1]
    }

    method fmt2 {} {
        return [my format $val2]
    }

    method format {val} {
        return $val
    }

    method context {} {
        return "n/a"
    }

    # score
    #
    # A ranking score.  By default, it's the absolute difference of the
    # two values, which are assumed to be numeric.  
    #
    # Subclasses should override this if necessary.

    method score {} {
        expr {abs([my val1] - [my val2])}
    }

    # different
    #
    # Returns 1 if val1 isn't trivially identical to val2, and 0
    # otherwise.  This is used to filter out trivial instances.

    method different {} {
        expr {$val1 ne $val2}
    }

    # significant
    #
    # Returns 1 if val1 is significantly different than val2, and 0
    # otherwise.  By default, two values are significantly different
    # if they are trivally different.  Subclasses should override this
    # accordingly.
    
    method significant {} {
        my different
    }
}

oo::class create vardiff::nbsecurity.n {
    superclass ::vardiff
    meta type nbsecurity.n

    constructor {comp_ n_ val1_ val2_} {
        next $comp_ [list n $n_] $val1_ $val2_
    }

    method significant {} {
        set lim 20 ;# TBD: Need parm

        set sym1 [qsecurity name [my val1]]
        set sym2 [qsecurity name [my val2]]

        expr {$sym1 ne $sym2 || [my score] >= $lim}
    }

    method format {val} {
        return [qsecurity longname $val]
    }

    method context {} {
        format "%d vs %d" [my val1] [my val2]
    }
}

oo::class create vardiff::control.n {
    superclass ::vardiff
    meta type control.n

    constructor {comp_ n_ val1_ val2_} {
        next $comp_ [list n $n_]  $val1_ $val2_
    }

    method significant {} {
        expr {[my val1] ne [my val2]}
    }

    method score {} {
        return 1
    }

    method format {val} {
        if {$val ne ""} {
            return $val
        } else {
            return "*NONE*"
        }
    }
}

oo::class create vardiff::influence.n.* {
    superclass ::vardiff
    meta type influence.n.*

    constructor {comp_ n_ val1_ val2_} {
        next $comp_ [list n $n_] $val1_ $val2_
    }

    method significant {} {
        expr {[my fmt1] ne [my fmt2]}
    }

    method score {} {
        return 1
    }

    method format {val} {
        if {[dict size $val] > 0} {
            return [dict keys $val]
        } else {
            return "*NONE*"
        }
    }
}

oo::class create vardiff::support.n.a {
    superclass ::vardiff
    meta type support.n.a

    constructor {comp_ n_ a_ val1_ val2_} {
        next $comp_ [list n $n_ a $a_] $val1_ $val2_
    }

    method significant {} {
        expr {[my fmt1] != [my fmt2]}
    }

    method score {} {
        expr {abs([my val1] - [my val2])}
    }

    method format {val} {
        format %.1f $val
    }
}

oo::class create vardiff::nbmood.n {
    superclass ::vardiff
    meta type nbmood.n

    constructor {comp_ n_ val1_ val2_} {
        next $comp_ [list n $n_] $val1_ $val2_
    }

    method significant {} {
        expr {[my score] >= 10.0}
    }

    method score {} {
        expr {abs([my val1] - [my val2])}
    }



    method format {val} {
        return [qsat longname $val]
    }

    method context {} {
        format "%.1f vs %.1f" [my val1] [my val2]
    }
}