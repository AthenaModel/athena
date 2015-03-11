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
    superclass ::record
    meta type *      ;# Type is undefined

    variable comp    ;# comparison object
    variable val1
    variable val2

    constructor {comp_} {
        next
        set comp $comp_
        set val1 ""
        set val2 ""
    }

    method name {} {
        error "Not overridden"
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
}

oo::class create vardiff::security.n {
    superclass ::vardiff
    meta type security.n

    self method compare {comp} {
        foreach n [$comp s1 nbhood names] {
            $comp add [my type] [my new $comp $n]
        }
    }

    variable comp ;# Consider definer to add this automatically

    variable n 

    constructor {comp_ n_} {
        next $comp_
        my readonly n $n_
        my readonly val1 [my GetValue s1 t1]
        my readonly val2 [my GetValue s2 t2]
    }

    # TBD: hist method?
    method GetValue {s t} {
        set t [$comp $t]
        return [$comp $s onecolumn {
            SELECT security FROM hist_nbhood WHERE t=$t AND n=$n
        }]
    }

    method significant {} {
        set sym1 [qsecurity name [my val1]]
        set sym2 [qsecurity name [my val2]]

        expr {$sym1 ne $sym2}
    }

    method name {} {
        return "security.$n"
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

    self method compare {comp} {
        foreach n [$comp s1 nbhood names] {
            $comp add [my type] [my new $comp $n]
        }
    }

    variable comp ;# Consider definer to add this automatically
    variable n 

    constructor {comp_ n_} {
        next $comp_
        my readonly n    $n_
        my readonly val1 [my GetValue s1 t1]
        my readonly val2 [my GetValue s2 t2]
    }

    method GetValue {s t} {
        set t [$comp $t]
        return [$comp $s onecolumn {
            SELECT a FROM hist_nbhood WHERE t=$t AND n=$n
        }]
    }

    method significant {} {
        expr {[my val1] ne [my val2]}
    }

    method name {} {
        return "control.$n"
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

    self method compare {comp} {
        foreach n [$comp s1 nbhood names] {
            $comp add [my type] [my new $comp $n]
        }
    }

    variable comp ;# Consider definer to add this automatically
    variable n 

    constructor {comp_ n_} {
        next $comp_
        my readonly n    $n_
        my readonly val1 [my GetValue s1 t1]
        my readonly val2 [my GetValue s2 t2]
    }

    method GetValue {s t} {
        set t [$comp $t]
        return [$comp $s eval {
            SELECT a, influence FROM hist_support 
            WHERE t=$t AND n=$n AND influence > 0 
            ORDER BY influence DESC
        }]
    }

    method significant {} {
        expr {[my fmt1] ne [my fmt2]}
    }


    method format {val} {
        if {[dict size $val] > 0} {
            return [dict keys $val]
        } else {
            return "*NONE*"
        }
    }

    method name {} {
        return "influence.$n.*"
    }
}

oo::class create vardiff::nbmood.n {
    superclass ::vardiff
    meta type nbmood.n

    self method compare {comp} {
        foreach n [$comp s1 nbhood names] {
            $comp add [my type] [my new $comp $n]
        }
    }

    variable comp ;# Consider definer to add this automatically
    variable n 

    constructor {comp_ n_} {
        next $comp_
        my readonly n  $n_
        my readonly val1 [my GetValue 1]
        my readonly val2 [my GetValue 2]
    }

    method GetValue {case} {
        set t [$comp t$case]
        return [$comp s$case eval {
            SELECT nbmood FROM hist_nbhood 
            WHERE t=$t AND n=$n 
        }]
    }

    method name {} {
        return "nbmood.$n"
    }

    method significant {} {
        expr {abs([my val1] - [my val2]) >= 10.0}
    }

    method format {val} {
        return [qsat longname $val]
    }

    method context {} {
        format "%.1f vs %.1f" [my val1] [my val2]
    }
}