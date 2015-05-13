#-----------------------------------------------------------------------
# TITLE:
#    hrel.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Horizontal Relationship Manager
#
#    By default, the initial baseline horizontal relationships (hrel)
#    are computed from belief systems by the bsys module, an
#    instance of mam(n), with the exception that rel.gg is always 1.0.
#    The analyst is allowed to override any initial baseline relationship 
#    for which f != g.  The natural relationship is always either 1.0 
#    when f=g and the affinity otherwise.
#
#    These overrides are stored in the hrel_fg table and viewed in
#    hrelbrowser(sim).  The hrel_view view pulls all of the data together.
#
#    Because hrel_fg overrides values computed elsewhere, this
#    module follows a rather different pattern than other scenario
#    editing modules.  The relationships come into being automatically
#    with the groups.  Thus, there is no HREL:CREATE order.  Instead,
#    HREL:OVERRIDE and HREL:OVERRIDE:MULTI will create new records as 
#    needed.  HREL:RESTORE will delete overrides.
#
#    Note that overridden relationships are deleted via cascading
#    delete if the relevant groups are deleted.
#
# NOTE:
#    This module concerns itself only with the scenario inputs.  For
#    the dynamic relationship values, see URAM.
#
# TBD: Global refs: group
#
#-----------------------------------------------------------------------

snit::type ::athena::hrel {
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
    # id     An fg relationship ID, [list $f $g]
    #
    # Throws INVALID if id doesn't name an overrideable relationship.

    method validate {id} {
        lassign $id f g

        set f [$adb group validate $f]
        set g [$adb group validate $g]

        if {$f eq $g} {
            return -code error -errorcode INVALID \
                "A group's relationship with itself cannot be overridden."
        }

        return [list $f $g]
    }

    # exists id
    #
    # id     An fg relationship ID, [list $f $g]
    #
    # Returns 1 if there's an overridden relationship 
    # between f and g, and 0 otherwise.

    method exists {id} {
        lassign $id f g

        $adb exists {
            SELECT * FROM hrel_fg WHERE f=$f AND g=$g
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
    # parmdict  - A dictionary of hrel parms
    #
    #    id        - list {f g}
    #    base      - The overridden baseline relationship of f with g
    #    hist_flag - 0 if new scenario, 1 if data from rebased scenario
    #    current   - overridden current relationship if hist_flag=1.
    #
    # Creates a relationship record given the parms, which are presumed to be
    # valid.

    method create {parmdict} {
        dict with parmdict {
            lassign $id f g

            # FIRST, default hrel to 0.0
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
                hrel_fg(f, g, base, hist_flag, current)
                VALUES($f, $g, $base, $hist_flag, $current);
            }

            # NEXT, Return the undo command
            return [list $adb delete hrel_fg "f='$f' AND g='$g'"]
        }
    }


    # delete id
    #
    # id   - list {f g}
    #
    # Deletes the relationship override.

    method delete {id} {
        lassign $id f g

        # FIRST, delete the records, grabbing the undo information
        set data [$adb delete -grab hrel_fg {f=$f AND g=$g}]

        # NEXT, Return the undo script
        return [list $adb ungrab $data]
    }


    # update parmdict
    #
    # parmdict  - A dictionary of group parms
    #
    #    id        - list {f g}
    #    base      - The overridden baseline relationship of f with g
    #    hist_flag - 0 if new scenario, 1 if data from rebased scenario
    #    current   - overridden current relationship if hist_flag=1.
    #
    # Updates a baseline relationship override given the parms, which
    # are presumed to be valid.

    method update {parmdict} {
        # FIRST, use the dict
        dict with parmdict {
            lassign $id f g

            # FIRST, get the undo information
            set data [$adb grab hrel_fg {f=$f AND g=$g}]

            # NEXT, Update the group
            $adb eval {
                UPDATE hrel_fg
                SET base      = nonempty($base,      base),
                    hist_flag = nonempty($hist_flag, hist_flag),
                    current   = nonempty($current,   current)
                WHERE f=$f AND g=$g
            } {}

            # NEXT, Return the undo command
            return [list $adb ungrab $data]
        }
    }
}


#-------------------------------------------------------------------
# Orders: HREL:*

# HREL:RESTORE
#
# Deletes existing relationship override

::athena::orders define HREL:RESTORE {
    meta title      "Restore Baseline Horizontal Relationship"
    meta sendstates PREP
    meta parmlist   {id}

    method _validate {} {
        # FIRST, prepare the parameters
        my prepare id  -toupper  -required -type [list $adb hrel]
    }

    method _execute {{flunky ""}} {
        # NEXT, delete the record
        my setundo [$adb hrel delete $parms(id)]
    }
}

# HREL:OVERRIDE
#
# Updates existing override

::athena::orders define HREL:OVERRIDE {
    meta title      "Override Baseline Horizontal Relationship"
    meta sendstates PREP
    meta parmlist {
        id 
        base 
        {hist_flag 0}
        current
    }

    meta form {
        rcc "Groups:" -for id
        dbkey id -table fmt_hrel_view -keys {f g} -labels {Of With} \
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
        # FIRST, prepare the parameters
        my prepare id        -toupper  -required -type [list $adb hrel]
        my prepare base      -toupper  -num      -type qaffinity
        my prepare hist_flag           -num      -type snit::boolean
        my prepare current   -toupper  -num      -type qaffinity 
    }

    method _execute {{flunky ""}} {
        if {[$adb hrel exists $parms(id)]} {
            my setundo [$adb hrel update [array get parms]]
        } else {
            my setundo [$adb hrel create [array get parms]]
        }
    }
}


# HREL:OVERRIDE:MULTI
#
# Updates multiple existing relationship overrides

::athena::orders define HREL:OVERRIDE:MULTI {
    meta title      "Override Multiple Baseline Horizontal Relationships"
    meta sendstates PREP 
    meta parmlist {
        ids 
        base
        {hist_flag 0}
        current
    }

    meta form {
        rcc "IDs:" -for ids
        dbmulti ids -table fmt_hrel_view -key id \
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
        # FIRST, prepare the parameters
        my prepare ids       -toupper  -required -listof [list $adb hrel]
        my prepare base      -toupper  -num      -type qaffinity
        my prepare hist_flag           -num      -type snit::boolean
        my prepare current   -toupper  -num      -type qaffinity 
    }

    method _execute {{flunky ""}} {
        set undo [list]
    
        foreach parms(id) $parms(ids) {
            if {[$adb hrel exists $parms(id)]} {
                lappend undo [$adb hrel update [array get parms]]
            } else {
                lappend undo [$adb hrel create [array get parms]]
            }
        }
    
        my setundo [join $undo \n]
    }
}



