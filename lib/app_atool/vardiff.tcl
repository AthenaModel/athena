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

    constructor {comp_ keydict_} {
        set comp    $comp_
        set keydict $keydict_
        set val1    [my retrieve [$comp s1] [$comp t1]]
        set val2    [my retrieve [$comp s2] [$comp t2]]
    }

    method name {} {
        error "Not overridden"
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
}

oo::class create vardiff::security.n {
    superclass ::vardiff
    meta type security.n

    self method compare {comp} {
        foreach n [$comp s1 nbhood names] {
            $comp add [my type] [my new $comp $n]
        }
    }

    constructor {comp_ n_} {
        next $comp_ [list n $n_]
    }

    method retrieve {s t} {
        set n [my key n]

        return [$s onecolumn {
            SELECT security FROM hist_nbhood WHERE t=$t AND n=$n
        }]
    }

    method significant {} {
        set sym1 [qsecurity name [my val1]]
        set sym2 [qsecurity name [my val2]]

        expr {$sym1 ne $sym2}
    }

    method name {} {
        return "security.[my key n]"
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

    constructor {comp_ n_} {
        next $comp_ [list n $n_]
    }

    method retrieve {s t} {
        set n [my key n]

        return [$s onecolumn {
            SELECT a FROM hist_nbhood WHERE t=$t AND n=$n
        }]
    }

    method significant {} {
        expr {[my val1] ne [my val2]}
    }

    method name {} {
        return "control.[my key n]"
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

    constructor {comp_ n_} {
        next $comp_ [list n $n_]
    }

    method retrieve {s t} {
        set n [my key n]

        return [$s eval {
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
        return "influence.[my key n].*"
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

    constructor {comp_ n_} {
        next $comp_ [list n $n_]
    }

    method retrieve {s t} {
        set n [my key n]
        return [$s onecolumn {
            SELECT nbmood FROM hist_nbhood 
            WHERE t=$t AND n=$n 
        }]
    }

    method name {} {
        return "nbmood.[my key n]"
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