#-----------------------------------------------------------------------
# TITLE:
#    nbrel.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Neighborhood Relationship Manager
#
#    This module is responsible for managing relationships between
#    neighborhoods (proximity and effects delay), and for allowing the 
#    analyst to update particular neighborhood relationships.
#    These relationships come and go as neighborhoods come and go.
#
# CREATION/DELETION:
#    nbrel_mn records are created by nbhood(sim) as neighborhoods
#    are created, and deleted by cascading delete.
#
#-----------------------------------------------------------------------

snit::type nbrel {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Queries

    # validate id
    #
    # id     An mn neighborhood relationship ID, [list $n $f $g]
    #
    # Throws INVALID if there's no neighborhood relationship for the 
    # specified combination.

    typemethod validate {id} {
        lassign $id m n

        set m [nbhood validate $m]
        set n [nbhood validate $n]

        # No need to check for existence of the record in nbrel_mn; 
        # there are relationships for every pair of neighborhoods.

        return [list $m $n]
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
    #    id               list {m n}
    #    proximity        Proximity of m to n from m's point of view
    #
    # Updates a neighborhood relationship given the parms, which are 
    # presumed to be valid.

    typemethod {mutate update} {parmdict} {
        # FIRST, use the dict
        dict with parmdict {
            lassign $id m n

            # FIRST, get the undo information
            set data [rdb grab nbrel_mn {m=$m AND n=$n}]

            # NEXT, Update the group
            rdb eval {
                UPDATE nbrel_mn
                SET proximity     = nonempty($proximity,     proximity)
                WHERE m=$m AND n=$n
            }

            # NEXT, Return the undo command
            return [list rdb ungrab $data]
        }
    }
}


#-------------------------------------------------------------------
# Orders: NBREL:*

# NBREL:UPDATE
#
# Updates existing neighborhood relationships


order define NBREL:UPDATE {
    title "Update Neighborhood Relationship"
    options -sendstates PREP

    form {
        rcc "Neighborhood:" -for id
        key id -table gui_nbrel_mn -keys {m n} -labels {"Of" "With"} \
            -loadcmd {orderdialog keyload id *}

        rcc "Proximity:" -for proximity
        enum proximity -listcmd {ptype prox-HERE names}
    }
} {
    # FIRST, prepare the parameters
    prepare id            -toupper  -required -type nbrel
    prepare proximity     -toupper            -type {ptype prox-HERE}

    returnOnError

    # NEXT, can't change relationship of a neighborhood with itself
    lassign $parms(id) m n

    if {$m eq $n} {
        reject id "Cannot change the relationship of a neighborhood to itself."
    }

    returnOnError -final

    # NEXT, modify the curve
    setundo [nbrel mutate update [array get parms]]
}


# NBREL:UPDATE:MULTI
#
# Updates multiple existing neighborhood relationships

order define NBREL:UPDATE:MULTI {
    title "Update Multiple Neighborhood Relationships"
    options -sendstates PREP

    form {
        rcc "IDs:" -for ids
        multi ids -table gui_nbrel_mn -key id \
            -loadcmd {orderdialog multiload ids *}

        rcc "Proximity:" -for proximity
        enum proximity -listcmd {ptype prox-HERE names}
    }
} {
    # FIRST, prepare the parameters
    prepare ids           -toupper  -required -listof nbrel
    prepare proximity     -toupper            -type {ptype prox-HERE}

    returnOnError

    # NEXT, make sure that m != n.
    foreach id $parms(ids) {
        lassign $id m n
            
        if {$m eq $n} {
            reject ids \
                "Cannot change the relationship of a neighborhood to itself."
        }
    }

    returnOnError -final

    # NEXT, modify the curves
    set undo [list]

    foreach parms(id) $parms(ids) {
        lappend undo [nbrel mutate update [array get parms]]
    }

    setundo [join $undo \n]
}


