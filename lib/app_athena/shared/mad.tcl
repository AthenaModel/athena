#-----------------------------------------------------------------------
# TITLE:
#    mad.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Magic Attitude Driver (MAD) Manager
#
#    This module is responsible for managing the creation, editing,
#    and deletion of MADs.
#
#-----------------------------------------------------------------------

snit::type mad {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # modeChar: The mode character used by [dam]
    typevariable modeChar -array {
        persistent P
        transient  T
    }
    
    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.


    # names
    #
    # Returns the list of MAD ids

    typemethod names {} {
        rdb eval {SELECT mad_id FROM mads}
    }


    # longnames
    #
    # Returns the list of extended MAD ids

    typemethod longnames {} {
        rdb eval {SELECT mad_id || ' - ' || narrative FROM mads}
    }


    # validate id
    #
    # id  - Possibly, a MAD ID.
    #
    # Validates a MAD id

    typemethod validate {id} {
        if {![rdb exists {SELECT mad_id FROM mads WHERE mad_id=$id}]} {
            return -code error -errorcode INVALID \
                "MAD does not exist: \"$id\""
        }

        return $id
    }

    # initial names
    #
    # Returns the list of MAD ids for MADs in the initial state

    typemethod {initial names} {} {
        rdb eval {SELECT mad_id FROM gui_mads_initial}
    }


    # initial validate id
    #
    # id         Possibly, a MAD ID.
    #
    # Validates a MAD id for a MAD in the initial state

    typemethod {initial validate} {id} {
        if {![rdb exists {
            SELECT mad_id FROM gui_mads_initial WHERE mad_id=$id
        }]} {
            return -code error -errorcode INVALID \
                "MAD does not exist or is not in initial state: \"$id\""
        }

        return $id
    }

    #-------------------------------------------------------------------
    # Mutators
    #
    # Mutators are used to implement orders that change the scenario in
    # some way.  Mutators assume that their inputs are valid, and returns
    # a script of one or more commands that will undo the change.  When
    # change cannot be undone, the mutator returns the empty string.


    # mutate create parmdict
    #
    # parmdict  -  A dictionary of MAD parms
    #
    #    narrative    - The MAD's description.
    #    cause        - "UNIQUE", or an ecause(n) value
    #    s            - A fraction
    #    p            - A fraction
    #    q            - A fraction
    #
    # Creates a MAD given the parms, which are presumed to be
    # valid.

    typemethod {mutate create} {parmdict} {
        dict with parmdict {
            # FIRST, Put the MAD in the database
            rdb eval {
                INSERT INTO mads(narrative,cause,s,p,q)
                VALUES($narrative,
                       $cause,
                       $s,
                       $p,
                       $q);
            }

            set id [rdb last_insert_rowid]

            # NEXT, Return the undo command
            lappend undo [mytypemethod mutate delete $id]

            return [join $undo \n]
        }
    }

    # mutate delete id
    #
    # id -  A MAD ID
    #
    # Deletes the MAD.

    typemethod {mutate delete} {id} {
        # FIRST, get the undo information
        rdb eval {SELECT * FROM mads WHERE mad_id=$id} row { 
            unset row(*) 
        }

        # NEXT, delete it.
        rdb eval {DELETE FROM mads WHERE mad_id=$id}

        # NEXT, Return the undo script
        return [mytypemethod RestoreDeletedMAD [array get row]]
    }

    # RestoreDeletedMAD dict
    #
    # dict  - row dict for deleted entity in mads
    #
    # Restores the row to the database

    typemethod RestoreDeletedMAD {dict} {
        rdb insert mads  $dict
    }

    # mutate update parmdict
    #
    # parmdict   - A dictionary of order parms
    #
    #   mad_id     - The MAD's ID
    #   narrative  - A new description, or ""
    #   cause      - "UNIQUE", or an ecause(n) value, or ""
    #   s          - A fraction, or ""
    #   p          - A fraction, or ""
    #   q          - A fraction, or ""
    #
    # Updates the MAD given the parms, which are presumed to be
    # valid.
    #
    # Changes to cause, s, p, and q only affect new inputs entered
    # for this MAD.

    typemethod {mutate update} {parmdict} {
        dict with parmdict {
            # FIRST, get the undo information
            rdb eval {
                SELECT * FROM mads
                WHERE mad_id=$mad_id
            } row {
                unset row(*)
            }
            
            # NEXT, Update the MAD
            rdb eval {
                UPDATE mads
                SET cause     = nonempty($cause,     cause),
                    narrative = nonempty($narrative, narrative),
                    s         = nonempty($s,         s),
                    p         = nonempty($p,         p),
                    q         = nonempty($q,         q)
                WHERE mad_id=$mad_id
            }

            # NEXT, Return the undo command
            return [mytypemethod mutate update [array get row]]
        }
    }


    # mutate hrel parmdict
    #
    # parmdict    A dictionary of order parameters
    #
    #    mad_id  - The MAD ID
    #    mode    - An einputmode value
    #    f       - A Group
    #    g       - Another Group
    #    mag     - A qmag(n) value
    #
    # Makes the MAGIC-1-1 rule fire for the given input.
    
    typemethod {mutate hrel} {parmdict} {
        # FIRST, get the dict data.
        dict with parmdict {}

        # NEXT, set up the firing data
        set fdict [dict create       \
            dtype   MAGIC            \
            mad_id  $mad_id          \
            atype   hrel             \
            mode    $modeChar($mode) \
            mag     $mag             \
            f       $f               \
            g       $g               ]

        # NEXT, call the rule set.
        driver::MAGIC assess $fdict

        # NEXT, cannot be undone.
        return
    }


    # mutate vrel parmdict
    #
    # parmdict    A dictionary of order parameters
    #
    #    mad_id  - The MAD ID
    #    mode       - An einputmode value
    #    g          - A group
    #    a          - An actor
    #    mag        - A qmag(n) value
    #
    # Makes the MAGIC-2-1 rule fire for the given input.
    
    typemethod {mutate vrel} {parmdict} {
        # FIRST, get the dict parameters
        dict with parmdict {}

        # NEXT, set up the firing data
        set fdict [dict create       \
            dtype   MAGIC            \
            mad_id  $mad_id          \
            atype   vrel             \
            mode    $modeChar($mode) \
            mag     $mag             \
            g       $g               \
            a       $a               ]

        # NEXT, call the rule set.
        driver::MAGIC assess $fdict

        # NEXT, cannot be undone.
        return
    }

    # mutate sat parmdict
    #
    # parmdict  - A dictionary of order parameters
    #
    #    mad_id  - The MAD ID
    #    mode       - An einputmode value
    #    g          - Group ID
    #    c          - Concern
    #    mag        - A qmag(n) value
    #
    # Makes the MAGIC-3-1 rule fire for the given input.
    
    typemethod {mutate sat} {parmdict} {
        # FIRST, get the dict parameters.
        dict with parmdict {}

        # NEXT, set up the firing data
        set fdict [dict create       \
            dtype   MAGIC            \
            mad_id  $mad_id          \
            atype   sat              \
            mode    $modeChar($mode) \
            mag     $mag             \
            g       $g               \
            c       $c               ]

        # NEXT, call the rule set.
        driver::MAGIC assess $fdict

        # NEXT, cannot be undone.
        return
    }

    # mutate coop parmdict
    #
    # parmdict    A dictionary of order parameters
    #
    #    mad_id  - The MAD ID
    #    mode       - An einputmode value
    #    f          - Civilian Group
    #    g          - Force Group
    #    mag        - A qmag(n) value
    #
    # Makes the MAGIC-4-1 rule fire for the given input.
    
    typemethod {mutate coop} {parmdict} {
        # FIRST, get the dict parameters
        dict with parmdict {}

        # NEXT, set up the firing data
        set fdict [dict create       \
            dtype   MAGIC            \
            mad_id  $mad_id          \
            atype   coop             \
            mode    $modeChar($mode) \
            mag     $mag             \
            f       $f               \
            g       $g               ]

        # NEXT, call the rule set.
        driver::MAGIC assess $fdict

        # NEXT, cannot be undone.
        return
    }

    #------------------------------------------------------------------
    # Order Helpers

    proc AllGroupsBut {g} {
        return [rdb eval {
            SELECT g FROM groups
            WHERE g != $g
            ORDER BY g
        }]
    }
}

#-------------------------------------------------------------------
# Orders: MAD:*

# MAD:CREATE
#
# Creates a new MAD.

myorders define MAD:CREATE {
    meta title "Create Magic Attitude Driver"

    meta sendstates {PREP PAUSED TACTIC}

    meta parmlist {
        narrative
        {cause UNIQUE}
        {s     1.0}
        {p     0.0}
        {q     0.0}
    }

    meta form {
        rcc "Narrative:" -for narrative
        text narrative -width 40

        rcc "Cause:" -for cause
        enum cause -listcmd {ptype ecause+unique names} -defvalue UNIQUE

        rcc "Here Factor:" -for s
        frac s -defvalue 1.0

        rcc "Near Factor:" -for p
        frac p -defvalue 0.0

        rcc "Far Factor:" -for q
        frac q -defvalue 0.0
    }


    method _validate {} {
        my prepare narrative          -required
        my prepare cause     -toupper -required -type {ptype ecause+unique}
        my prepare s         -num     -required -type rfraction
        my prepare p         -num     -required -type rfraction
        my prepare q         -num     -required -type rfraction
    }

    method _execute {{flunky ""}} {
        lappend undo [mad mutate create [array get parms]]
    
        my setundo [join $undo \n]
    }
}


# MAD:DELETE
#
# Deletes a MAD in the initial state

myorders define MAD:DELETE {
    meta title "Delete Magic Attitude Driver"
    meta sendstates {PREP PAUSED}

    meta parmlist {mad_id}

    meta form {
        rcc "MAD ID:" -for mad_id
        # Can't use "mad" field type, since only unused MADs can be
        # deleted.
        dbkey mad_id -table gui_mads_initial -keys mad_id -dispcols longid
    }


    method _validate {} {
        my prepare mad_id -toupper -required -type {mad initial}
    }

    method _execute {{flunky ""}} {
        if {[my mode] eq "gui"} {
            set answer [messagebox popup \
                            -title         "Are you sure?"                  \
                            -icon          warning                          \
                            -buttons       {ok "Delete it" cancel "Cancel"} \
                            -default       cancel                           \
                            -onclose       cancel                           \
                            -ignoretag     [my name]                        \
                            -ignoredefault ok                               \
                            -parent        [app topwin]                     \
                            -message       [normalize {
                                Are you sure you
                                really want to delete this magic attitude
                                driver?
                            }]]
    
            if {$answer eq "cancel"} {
                my cancel
            }
        }
    
        lappend undo [mad mutate delete $parms(mad_id)]
    
        my setundo [join $undo \n]
    }
}


# MAD:UPDATE
#
# Updates an existing mad's description

myorders define MAD:UPDATE {
    meta title "Update Magic Attitude Driver"
    meta sendstates {PREP PAUSED TACTIC}

    meta parmlist {
        mad_id narrative cause s p q
    }

    meta form {
        rcc "MAD ID:" -for mad_id
        mad mad_id \
            -loadcmd {$order_ keyload mad_id *}

        rcc "Narrative:" -for narrative
        text narrative -width 40

        rcc "Cause:" -for cause
        enum cause -listcmd {ptype ecause+unique names}

        rcc "Here Factor:" -for s
        frac s

        rcc "Near Factor:" -for p
        frac p

        rcc "Far Factor:" -for q
        frac q

    }


    method _validate {} {
        my prepare mad_id    -required -type mad
        my prepare narrative
        my prepare cause     -toupper  -type {ptype ecause+unique}
        my prepare s         -num      -type rfraction
        my prepare p         -num      -type rfraction
        my prepare q         -num      -type rfraction
    }

    method _execute {{flunky ""}} {
        lappend undo [mad mutate update [array get parms]]
    
        my setundo [join $undo \n]
    }
}

# MAD:HREL
#
# Enters a magic horizontal relationship input.

myorders define MAD:HREL {
    meta title "Magic Horizontal Relationship Input"
    meta sendstates {PAUSED TACTIC}

    meta parmlist {
        mad_id {mode transient} f g mag
    }

    meta form {
        rcc "MAD ID:" -for mad_id
        mad mad_id

        rcc "Mode:" -for mode
        enumlong mode -dictcmd {einputmode deflist} -defvalue transient

        rcc "Of Group:" -for f
        group f

        rcc "With Group:" -for g
        enum g -listcmd {mad::AllGroupsBut $f}

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare mad_id             -required -type mad
        my prepare mode      -tolower -required -type einputmode
        my prepare f         -toupper -required -type group
        my prepare g         -toupper -required -type group
        my prepare mag  -num -toupper -required -type qmag
    
        my returnOnError
    
        my checkon g {
            if {$parms(g) eq $parms(f)} {
                my reject g "Cannot change a group's relationship with itself."
            }
        }
    }

    method _execute {{flunky ""}} {
        mad mutate hrel [array get parms]
    }
}

# MAD:VREL
#
# Enters a magic vertical relationship input.

myorders define MAD:VREL {
    meta title "Magic Vertical Relationship Input"
    meta sendstates {PAUSED TACTIC}

    meta parmlist {
        mad_id {mode transient} g a mag
    }

    meta form {
        rcc "MAD ID:" -for mad_id
        mad mad_id

        rcc "Mode:" -for mode
        enumlong mode -dictcmd {einputmode deflist} -defvalue transient

        rcc "Of Group:" -for g
        group g

        rcc "With Actor:" -for a
        actor a

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare mad_id             -required -type mad
        my prepare mode      -tolower -required -type einputmode
        my prepare g         -toupper -required -type group
        my prepare a         -toupper -required -type actor
        my prepare mag  -num -toupper -required -type qmag
    }

    method _execute {{flunky ""}} {
        mad mutate vrel [array get parms]
    }
}

# MAD:SAT
#
# Enters a magic satisfaction input.

myorders define MAD:SAT {
    meta title "Magic Satisfaction Input"
    meta sendstates {PAUSED TACTIC}

    meta parmlist {
        mad_id {mode transient} g c mag
    }

    meta form {
        rcc "MAD ID:" -for mad_id
        mad mad_id

        rcc "Mode:" -for mode
        enumlong mode -dictcmd {einputmode deflist} -defvalue transient

        rcc "Of Group:" -for g
        civgroup g

        rcc "With Concern:" -for c
        enum c -listcmd {ptype c names}

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare mad_id             -required -type mad
        my prepare mode      -tolower -required -type einputmode
        my prepare g         -toupper -required -type civgroup
        my prepare c         -toupper -required -type {ptype c}
        my prepare mag  -num -toupper -required -type qmag
    }

    method _execute {{flunky ""}} {
        mad mutate sat [array get parms]
    }
}


# MAD:COOP
#
# Enters a magic cooperation input.

myorders define MAD:COOP {
    meta title "Magic Cooperation Input"
    meta sendstates {PAUSED TACTIC}

    meta parmlist {
        mad_id {mode transient} f g mag
    }

    meta form {
        rcc "MAD ID:" -for mad_id
        mad mad_id

        rcc "Mode:" -for mode
        enumlong mode -dictcmd {einputmode deflist} -defvalue transient

        rcc "Of Group:" -for f
        civgroup f 

        rcc "With Group:" -for g
        frcgroup g

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare mad_id             -required -type mad
        my prepare mode      -tolower -required -type einputmode
        my prepare f         -toupper -required -type civgroup
        my prepare g         -toupper -required -type frcgroup
        my prepare mag  -num -toupper -required -type qmag
    }

    method _execute {{flunky ""}} {
        mad mutate coop [array get parms]
    }
}


