#-----------------------------------------------------------------------
# TITLE:
#    condition_compare.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Mark II Condition, COMPARE
#
# TBD: Global refs: gofer*
#
#-----------------------------------------------------------------------

# FIRST, create the class.
::athena::condition define COMPARE "Compare Numbers" {
    #-------------------------------------------------------------------
    # Instance Variables

    variable x          ;# A gofer::NUMBER value
    variable comp       ;# An ecomparator value
    variable y          ;# A gofer::NUMBER value
    
    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # Initialize as tactic bean.
        next

        # Initialize state variables
        set x     [gofer construct NUMBER BY_VALUE 0]
        set comp  EQ
        set y     [gofer construct NUMBER BY_VALUE 0]

        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    method narrative {} {
        set xt    [gofer::NUMBER narrative $x]
        set compt [ecomparator longname $comp]
        set yt    [gofer::NUMBER narrative $y]

        return [normalize "Compare whether $xt is $compt $yt"]
    }

    method SanityCheck {errdict} {
        if {[catch {gofer validate $x} result]} {
            dict set errdict x $result
        }

        if {[catch {gofer validate $y} result]} {
            dict set errdict y $result
        }

        return [next $errdict]
    }

    method Evaluate {} {
        set xval [gofer eval $x]
        set yval [gofer eval $y]

        return [ecomparatorx compare $xval $comp $yval]
    }
}

#-----------------------------------------------------------------------
# CONDITION:* Orders


# CONDITION:COMPARE
#
# Updates the condition's parameters

::athena::orders define CONDITION:COMPARE {
    meta title      "Condition: Compare Numbers"
    meta sendstates PREP
    meta parmlist   {condition_id name x comp y}

    meta form {
        rcc "Condition ID:" -for condition_id
        text condition_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc ""
        label {
            This condition is met when
        }

        rcc "X Value:" -for x
        gofer x -typename gofer::NUMBER

        rcc "Is:" -for comp
        comparator comp

        rcc "Y Value:" -for y
        gofer y -typename gofer::NUMBER
    }


    method _validate {} {
        my prepare condition_id -required -with [list $adb strategy valclass ::athena::condition::COMPARE]
        my returnOnError

        set cond [$adb pot get $parms(condition_id)]

        my prepare name         -toupper  -with [list $cond valName]
        my prepare x                      
        my prepare comp         -toupper  -type ecomparatorx
        my prepare y                      
    }

    method _execute {{flunky ""}} {
        set cond [$adb pot get $parms(condition_id)]
        my setundo [$cond update_ {name x comp y} [array get parms]]\
    }
}





