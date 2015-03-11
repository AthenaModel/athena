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

    variable val1    ;# Value 1
    variable val2    ;# Value 2

    constructor {} {
        next
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

    variable n 

    constructor {n_ val1_ val2_} {
        next
        my readonly n    $n_
        my readonly val1 $val1_
        my readonly val2 $val2_
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

    variable n 

    constructor {n_ val1_ val2_} {
        next
        my readonly n    $n_
        my readonly val1 $val1_
        my readonly val2 $val2_
    }

    method name {} {
        return "control.$n"
    }
}

oo::class create vardiff::influence.n.* {
    superclass ::vardiff
    meta type influence.n.*

    variable n 

    # TBD: val1, val2 should probably be dictionaries of actors and 
    # influences.
    constructor {n_ val1_ val2_} {
        next
        my readonly n    $n_
        my readonly val1 $val1_
        my readonly val2 $val2_
    }

    method name {} {
        return "influence.$n.*"
    }
}

oo::class create vardiff::nbmood.n {
    superclass ::vardiff
    meta type nbmood.n

    variable n 

    constructor {n_ val1_ val2_} {
        next
        my readonly n    $n_
        my readonly val1 $val1_
        my readonly val2 $val2_
    }

    method name {} {
        return "nbmood.$n"
    }

    method format {val} {
        return [qsat longname $val]
    }

    method context {} {
        format "%.1f vs %.1f" [my val1] [my val2]
    }
}