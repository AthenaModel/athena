#-----------------------------------------------------------------------
# TITLE:
#    vrel.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Vertical Relationship Manager
#
#    By default, the initial baseline vertical group relationships (base)
#    are computed from belief systems by the bsys module, an
#    instance of mam(n), with the exception that vrel.ga is always 1.0
#    when g is a group owned by actor a. The analyst is allowed to override 
#    any initial baseline relationship.  The natural relationship is always 
#    1.0 when a owns g, and the affinity otherwise.
#
#    These overrides are stored in the vrel_ga table and viewed in
#    vrelbrowser(sim).  The vrel_view view pulls all of the data together.
#
#    Because vrel_ga overrides values computed elsewhere, this
#    module follows a rather different pattern than other scenario
#    editing modules.  The relationships come into being automatically
#    with the groups.  Thus, there is no VREL:CREATE order.  Instead,
#    VREL:OVERRIDE and VREL:OVERRIDE:MULTI will create new records as 
#    needed.  VREL:RESTORE will delete overrides.
#
#    Note that overridden relationships are deleted via cascading
#    delete if the relevant groups are deleted.
#
# NOTE:
#    This module concerns itself only with the scenario inputs.  For
#    the dynamic relationship values, see URAM.
#
# TBD: Global refs: group, actor, $adb, vrel
#
#-----------------------------------------------------------------------

snit::type ::athena::vrel {
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
    # id     An fg relationship ID, [list $g $a]
    #
    # Throws INVALID if id doesn't name an overrideable relationship.

    method validate {id} {
        lassign $id g a

        set g [$adb group validate $g]
        set a [$adb actor validate $a]

        return [list $g $a]
    }

    # exists id
    #
    # id     A ga relationship ID, [list $g $a]
    #
    # Returns 1 if there's an overridden relationship 
    # between g and a, and 0 otherwise.

    method exists {id} {
        lassign $id g a

        $adb exists {
            SELECT * FROM vrel_ga WHERE g=$g AND a=$a
        }
    }

    #-------------------------------------------------------------------
    # Mutators
    #
    # Mutators are used to implement orders that change the scenario in
    # some way.  Mutators assume that their inputs are valid, and returns
    # a script of one or more commands that will undo the change.  When
    # change cannot be undone, the mutator returns the empty string.


    # create parmdict
    #
    # parmdict  - A dictionary of vrel parms
    #
    #    id        - list {g a}
    #    base      - The relationship of g with a
    #    hist_flag - 0 if new scenario, 1 if data from rebased scenario
    #    current   - overridden current relationship if hist_flag=1.
    #
    # Creates a relationship record given the parms, which are presumed to be
    # valid.

    method create {parmdict} {
        dict with parmdict {
            lassign $id g a

            # FIRST, default base to 0.0
            if {$base eq ""} {
                set base 0.0
            }

            if {$hist_flag eq ""} {
                set hist_flag 0
            }

            if {$current eq ""} {
                set current $base
            }

            # NEXT, Put the group in the database
            $adb eval {
                INSERT INTO 
                vrel_ga(g, a, base, hist_flag, current)
                VALUES($g, $a, $base, $hist_flag, $current);
            }

            # NEXT, Return the undo command
            return [list $adb delete vrel_ga "g='$g' AND a='$a'"]
        }
    }


    # delete id
    #
    # id   - list {g a}
    #
    # Deletes the relationship override.

    method delete {id} {
        lassign $id g a

        # FIRST, delete the records, grabbing the undo information
        set data [$adb delete -grab vrel_ga {g=$g AND a=$a}]

        # NEXT, Return the undo script
        return [list $adb ungrab $data]
    }


    # update parmdict
    #
    # parmdict  - A dictionary og aroup parms
    #
    #    id        - list {g a}
    #    base      - Relationship of g with a
    #    hist_flag - 0 if new scenario, 1 if data from rebased scenario
    #    current   - overridden current relationship if hist_flag=1.
    #
    # Updates a relationship given the parms, which are presumed to be
    # valid.

    method update {parmdict} {
        # FIRST, use the dict
        dict with parmdict {
            lassign $id g a

            # FIRST, get the undo information
            set data [$adb grab vrel_ga {g=$g AND a=$a}]

            # NEXT, Update the group
            $adb eval {
                UPDATE vrel_ga
                SET base      = nonempty($base,      base),
                    hist_flag = nonempty($hist_flag, hist_flag),
                    current   = nonempty($current,   current)
                WHERE g=$g AND a=$a
            } {}

            # NEXT, Return the undo command
            return [list $adb ungrab $data]
        }
    }
}


#-------------------------------------------------------------------
# Orders: VREL:*

# VREL:RESTORE
#
# Deletes existing relationship override

::athena::orders define VREL:RESTORE {
    meta title      "Restore Baseline Vertical Relationship"
    meta sendstates PREP
    meta parmlist   {id}

    method _validate {} {
        my prepare id       -toupper  -required -type [list $adb vrel]
    }

    method _execute {{flunky ""}} {
        my setundo [$adb vrel delete $parms(id)]
    }
}

# VREL:OVERRIDE
#
# Updates existing override

::athena::orders define VREL:OVERRIDE {
    meta title      "Override Baseline Vertical Relationship"
    meta sendstates PREP 
    meta parmlist {
        id
        base
        {hist_flag 0}
        current
    }

    meta form {
        rcc "Group/Actor:" -for id
        dbkey id -table gui_vrel_view -keys {g a} -labels {Of With} \
            -loadcmd {$order_ keyload id *}

        rcc "Baseline:" -for base
        rel base

        rcc "Start Mode:" -for hist_flag
        selector hist_flag -defvalue 0 {
            case 0 "New Scenario" {}
            case 1 "From Previous Scenario" {
                rcc "Current:" -for current
                rel current
            }
        }
    }

    method _validate {} {
        my prepare id        -toupper  -required -type [list $adb vrel]
        my prepare base -num -toupper            -type qaffinity
        my prepare hist_flag           -num      -type snit::boolean
        my prepare current   -toupper  -num      -type qaffinity 
    }

    method _execute {{flunky ""}} {
        if {[vrel exists $parms(id)]} {
            my setundo [$adb vrel update [array get parms]]
        } else {
            my setundo [$adb vrel create [array get parms]]
        }
    }
}


# VREL:OVERRIDE:MULTI
#
# Updates multiple existing relationship overrides

::athena::orders define VREL:OVERRIDE:MULTI {
    meta title      "Override Multiple Baseline Vertical Relationships"
    meta sendstates PREP
    meta parmlist {
        ids
        base
        {hist_flag 0}
        current
    }

    meta form {
        rcc "IDs:" -for id
        dbmulti ids -table gui_vrel_view -key id \
            -loadcmd {$order_ multiload ids *}

        rcc "Baseline:" -for base
        rel base

        rcc "Start Mode:" -for hist_flag
        selector hist_flag -defvalue 0 {
            case 0 "New Scenario" {}
            case 1 "From Previous Scenario" {
                rcc "Current:" -for current
                rel current
            }
        }
    }

    method _validate {} {
        my prepare ids       -toupper  -required -listof [list $adb vrel]
        my prepare base -num -toupper            -type qaffinity
        my prepare hist_flag           -num      -type snit::boolean
        my prepare current   -toupper  -num      -type qaffinity 
    }

    method _execute {{flunky ""}} {
        set undo [list]
    
        foreach parms(id) $parms(ids) {
            if {[vrel exists $parms(id)]} {
                lappend undo [$adb vrel update [array get parms]]
            } else {
                lappend undo [$adb vrel create [array get parms]]
            }
        }

        my setundo [join $undo \n]
    }
}



