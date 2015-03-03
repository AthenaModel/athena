#-----------------------------------------------------------------------
# TITLE:
#    nbrel.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athenan(n): Neighborhood Relationship Manager
#
#    This module is responsible for managing relationships between
#    neighborhoods (proximity and effects delay), and for allowing the 
#    analyst to update particular neighborhood relationships.
#    These relationships come and go as neighborhoods come and go.
#
# CREATION/DELETION:
#    nbrel_mn records are created by nbhood(n) as neighborhoods
#    are created, and deleted by cascading delete.
#
#-----------------------------------------------------------------------

snit::type ::athena::nbrel {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of this type

    constructor {adb_} {
        set adb $adb_
    }

    #-------------------------------------------------------------------
    # Queries

    # validate id
    #
    # id     An mn neighborhood relationship ID, [list $n $f $g]
    #
    # Throws INVALID if there's no neighborhood relationship for the 
    # specified combination.

    method validate {id} {
        lassign $id m n

        set m [$adb nbhood validate $m]
        set n [$adb nbhood validate $n]

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

    # update parmdict
    #
    # parmdict     A dictionary of group parms
    #
    #    id               list {m n}
    #    proximity        Proximity of m to n from m's point of view
    #
    # Updates a neighborhood relationship given the parms, which are 
    # presumed to be valid.

    method update {parmdict} {
        # FIRST, use the dict
        dict with parmdict {
            lassign $id m n

            # FIRST, get the undo information
            set data [$adb grab nbrel_mn {m=$m AND n=$n}]

            # NEXT, Update the group
            $adb eval {
                UPDATE nbrel_mn
                SET proximity = nonempty($proximity, proximity)
                WHERE m=$m AND n=$n
            }

            # NEXT, Return the undo command
            return [list $adb ungrab $data]
        }
    }
}


#-------------------------------------------------------------------
# Orders: NBREL:*

# NBREL:UPDATE
#
# Updates existing neighborhood relationships


::athena::orders define NBREL:UPDATE {
    meta title "Update Neighborhood Relationship"
    meta sendstates PREP

    meta parmlist {id proximity}

    meta form {
        rcc "Neighborhood:" -for id
        dbkey id -table gui_nbrel_mn -keys {m n} -labels {"Of" "With"} \
            -loadcmd {$order_ keyload id *}

        rcc "Proximity:" -for proximity
        enum proximity -listcmd {$adb_ ptype prox-HERE names}
    }


    method _validate {} {
        my prepare id            -toupper  -required -type [list $adb nbrel]
        my prepare proximity     -toupper            -type [list $adb ptype prox-HERE]
    
        my returnOnError
    
        # NEXT, can't change relationship of a neighborhood with itself
        lassign $parms(id) m n
    
        if {$m eq $n} {
            my reject id "Cannot change the relationship of a neighborhood to itself."
        }
    }

    method _execute {{flunky ""}} {
        my setundo [$adb nbrel update [array get parms]]
    }
}


# NBREL:UPDATE:MULTI
#
# Updates multiple existing neighborhood relationships

::athena::orders define NBREL:UPDATE:MULTI {
    meta title "Update Multiple Neighborhood Relationships"
    meta sendstates PREP

    meta parmlist {ids proximity}

    meta form {
        rcc "IDs:" -for ids
        dbmulti ids -table gui_nbrel_mn -key id \
            -loadcmd {$order_ multiload ids *}

        rcc "Proximity:" -for proximity
        enum proximity -listcmd {$adb_ ptype prox-HERE names}
    }


    method _validate {} {
<<<<<<< HEAD
        my prepare ids           -toupper  -required -listof [list $adb nbrel]
        my prepare proximity     -toupper            -type {ptype prox-HERE}
=======
        my prepare ids           -toupper  -required -listof nbrel
        my prepare proximity     -toupper            -type [list $adb ptype prox-HERE]
>>>>>>> master
    
        my returnOnError
    
        # NEXT, make sure that m != n.
        foreach id $parms(ids) {
            lassign $id m n
                
            if {$m eq $n} {
                my reject ids \
                    "Cannot change the relationship of a neighborhood to itself."
            }
        }
    }

    method _execute {{flunky ""}} {
        set undo [list]
    
        foreach parms(id) $parms(ids) {
            lappend undo [$adb nbrel update [array get parms]]
        }
    
        my setundo [join $undo \n]
    }
}


