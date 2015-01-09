#-----------------------------------------------------------------------
# TITLE:
#    sat_orderx.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_athena(n): SAT:* Orders
#
#    This is an experimental mock-up of what the SAT:* group orders
#    might look like using the orderx order processing scheme.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# SAT:* Order Classes

# SAT:UPDATE
myorders define SAT:UPDATE {
    meta title "Update Baseline Satisfaction"
    meta sendstates PREP 

    meta defaults {
        id        ""
        base      ""
        saliency  ""
        hist_flag 0
        current   ""
    }

    meta form {
        rcc "Curve:" -for id
        dbkey id -table gui_sat_view -keys {g c} -labels {"Grp" "Con"} \
            -loadcmd {$order_ keyload id *}

        rcc "Baseline:" -for base
        sat base
        
        rcc "Saliency:" -for saliency
        sal saliency

        rcc "Start Mode:" -for hist_flag
        selector hist_flag -defvalue 0 {
            case 0 "New Scenario" {}
            case 1 "From Previous Scenario" {
                rcc "Current:" -for current
                sat current
            }
        }
    }

    method _validate {} {
        my prepare id        -toupper  -required -type ::sat
        my prepare base      -num -toupper -type qsat
        my prepare saliency  -num -toupper -type qsaliency
        my prepare hist_flag -num          -type snit::boolean
        my prepare current   -num -toupper -type qsat 
    }

    method _execute {{flunky ""}} {
        my setundo [sat mutate update [array get parms]]
    }
}


# SAT:UPDATE:MULTI
myorders define SAT:UPDATE:MULTI {
    meta title "Update Baseline Satisfaction (Multi)"
    meta sendstates PREP

    meta defaults {
        ids       ""
        base      ""
        saliency  ""
        hist_flag 0
        current   ""
    }

    meta form {
        rcc "Curves:" -for id
        dbmulti ids -table gui_sat_view -key id \
            -loadcmd {$order_ multiload ids *}

        rcc "Baseline:" -for base
        sat base
        
        rcc "Saliency:" -for saliency
        sal saliency

        rcc "Start Mode:" -for hist_flag
        selector hist_flag -defvalue 0 {
            case 0 "New Scenario" {}
            case 1 "From Previous Scenario" {
                rcc "Current:" -for current
                sat current
            }
        }
    }

    method _validate {} {
        my prepare ids       -toupper  -required -listof sat
        my prepare base      -num -toupper -type qsat
        my prepare saliency  -num -toupper -type qsaliency
        my prepare hist_flag -num          -type snit::boolean
        my prepare current   -num -toupper -type qsat 
    }

    method _execute {{flunky ""}} {
        set undo [list]

        foreach parms(id) $parms(ids) {
            lappend undo [sat mutate update [array get parms]]
        }

        my setundo [join $undo \n]
        return
    }
}


