#-----------------------------------------------------------------------
# TITLE:
#    coop.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Cooperation Manager
#
#    This module is responsible for managing initial baseline 
#    cooperation records as groups come and ago, and for allowing the 
#    analyst to update particular baseline cooperations.
#
#    Every civ group has a cooperation level with every frc group.
#
# CREATION/DELETION:
#    coop_fg records are created explicitly by the civgroup(sim)
#    and frcgroup(sim) modules when groups of these types are deleted,
#    and are destroyed via cascading delete when groups of these
#    types are destroyed.
#
#-----------------------------------------------------------------------

snit::type ::athena::coop {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        set adb $adb_
    }

    #-------------------------------------------------------------------
    # Queries

    # validate id
    #
    # id     An fg cooperation ID, [list $f $g]
    #
    # Throws INVALID if there's no cooperation for the 
    # specified combination.

    method validate {id} {
        lassign $id f g

        set f [$adb civgroup validate $f]
        set g [$adb frcgroup validate $g]

        return [list $f $g]
    }

    # exists f g
    #
    # f       A group ID
    # g       A group ID
    #
    # Returns 1 if cooperation is tracked between f and g.

    method exists {f g} {
        $adb exists {
            SELECT * FROM coop_fg WHERE f=$f AND g=$g
        }
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
    #    id              list {f g}
    #    base            Cooperation of f with g at time 0.
    #    regress_to      BASELINE or NATURAL
    #    natural         Natural level of cooperation of f with g
    #
    # Updates a cooperation given the parms, which are presumed to be
    # valid.

    method update {parmdict} {
        # FIRST, use the dict
        dict with parmdict {}
        lassign $id f g

        # NEXT, get the undo information
        set data [$adb grab coop_fg {f=$f AND g=$g}]

        # NEXT, Update the group
        $adb eval {
            UPDATE coop_fg
            SET base       = nonempty($base,        base),
                regress_to = nonempty($regress_to,  regress_to),
                natural    = nonempty($natural,     natural)   
            WHERE f=$f AND g=$g
        } {}

        # NEXT, Return the undo command
        return [list $adb ungrab $data]
    }
}


#-------------------------------------------------------------------
# Orders: COOP:*

# COOP:UPDATE
#
# Updates existing cooperations

::athena::orders define COOP:UPDATE {
    meta title "Update Initial Cooperation"
    meta sendstates PREP 

    meta parmlist {
        id
        base
        regress_to
        natural
    }

    meta form {
        rcc "Curve:" -for id
        dbkey id -table fmt_coop -keys {f g} -labels {"Of" "With"} \
            -loadcmd {$order_ keyload id *}

        rcc "Baseline:" -for base
        coop base

        rcc "Regress To:" -for regress_to
        selector regress_to {
            case BASELINE "The Initial Baseline" { }
            case NATURAL  "A Specific Level" {
                rcc "Natural:" -for natural
                coop natural
            }
        }
    }


    method _validate {} {
        my prepare id         -toupper  -required -type [list $adb coop]
        my prepare base       -toupper  -num      -type qcooperation
        my prepare regress_to -toupper  -selector
        my prepare natural    -toupper  -num      -type qcooperation
    }

    method _execute {{flunky ""}} {
        my setundo [$adb coop update [array get parms]]
    }
}


# COOP:UPDATE:MULTI
#
# Updates multiple existing cooperations

::athena::orders define COOP:UPDATE:MULTI {
    meta title "Update Baseline Cooperation (Multi)"
    meta sendstates PREP
 
    meta parmlist {
        ids
        base
        regress_to
        natural
    }

    meta form {
        rcc "IDs:" -for ids
        dbmulti ids -table fmt_coop -key id \
            -loadcmd {$order_ multiload ids *}

        rcc "Baseline:" -for base
        coop base
        
        rcc "Regress To:" -for regress_to
        selector regress_to {
            case BASELINE "The Initial Baseline" { }
            case NATURAL  "A Specific Level" {
                rcc "Natural:" -for natural
                coop natural
            }
        }
    }

    method _validate {} {
        my prepare ids        -toupper  -required -listof [list $adb coop]
        my prepare base       -toupper  -num      -type qcooperation
        my prepare regress_to -toupper  -selector
        my prepare natural    -toupper  -num      -type qcooperation
    }

    method _execute {{flunky ""}} {
        set undo [list]

        foreach parms(id) $parms(ids) {
            lappend undo [$adb coop update [array get parms]]
        }

        my setundo [join $undo \n]
    }
}


