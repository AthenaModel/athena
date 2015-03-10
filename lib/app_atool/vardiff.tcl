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
    mixin ::record
    meta type *      ;# Type is undefined

    variable val1    ;# Value 1, formatted for display 
    variable val2    ;# Value 2, formatted for display

    constructor {val1_ val2_} {
        set val1 $val1_
        set val2 $val2_
    }

    method name {} {
        error "Not overridden"
    }

    method context {} {
        return ""
    }
}

oo::class create vardiff_security_n {
    superclass ::vardiff
    meta type security.n

    variable n
    variable raw1
    variable raw2

    constructor {n_ raw1_ raw2_} {
        set n    $n_
        set raw1 $raw1_
        set raw2 $raw2_

        next [qsecurity name $raw1] [qsecurity name $raw2]
    }

    method name {} {
        return "security.$n"
    }

    method context {} {
        return [format "%4d vs %4d" $raw1 $raw2]
    }
}