#-----------------------------------------------------------------------
# TITLE:
#    sat.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Satisfaction Curve Inputs Manager
#
#    This module is responsible for managing the scenario's satisfaction
#    curve inputs as CIV groups come and ago, and for allowing the analyst
#    to update baseline satisfaction levels and saliencies.  Curves are 
#    created and deleted when civ groups are created and deleted.
#
#-----------------------------------------------------------------------

snit::type sat {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Queries

    # validate id
    #
    # id     A curve ID, [list $g $c]
    #
    # Throws INVALID if there's no satisfaction level for the 
    # specified combination.

    typemethod validate {id} {
        lassign $id g c

        set g [civgroup validate $g]
        set c [econcern validate $c]

        return [list $g $c]
    }

    # exists g c
    #
    # g       A group ID
    # c       A concern ID
    #
    # Returns 1 if there is such a satisfaction curve, and 0 otherwise.

    typemethod exists {g c} {
        rdb exists {
            SELECT * FROM sat_gc WHERE g=$g AND c=$c
        }
    }

    #-------------------------------------------------------------------
    # Mutators
    #
    # Mutators are used to implement orders that change the scenario in
    # some way.  Mutators assume that their inputs are valid, and returns
    # a script of one or more commands that will undo the change.  When
    # change cannot be undone, the mutator returns the empty string.

    # mutate update parmdict
    #
    # parmdict     A dictionary of group parms
    #
    #    id             - list {g c}
    #    base           - A new initial satisfaction, or ""
    #    saliency       - A new saliency, or ""
    #    hist_flag      - History flag, or ""
    #    current        - New initial current level, or ""
    #
    # Updates a satisfaction level given the parms, which are presumed to be
    # valid.

    typemethod {mutate update} {parmdict} {
        # FIRST, use the dict
        dict with parmdict {
            lassign $id g c

            # FIRST, get the undo information
            set data [rdb grab sat_gc {g=$g AND c=$c}]

            # NEXT, Update the group
            rdb eval {
                UPDATE sat_gc
                SET base      = nonempty($base,      base),
                    saliency  = nonempty($saliency,  saliency),
                    hist_flag = nonempty($hist_flag, hist_flag),
                    current   = nonempty($current,   current)
                WHERE g=$g AND c=$c
            } {}

            # NEXT, Return the undo command
            return [list rdb ungrab $data]
        }
    }
}

#-------------------------------------------------------------------
# Orders: SAT:*

# SAT:UPDATE
::athena::orders define SAT:UPDATE {
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
::athena::orders define SAT:UPDATE:MULTI {
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