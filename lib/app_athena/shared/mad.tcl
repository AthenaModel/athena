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

order define MAD:CREATE {
    title "Create Magic Attitude Driver"

    options -sendstates {PREP PAUSED TACTIC}

    form {
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
} {
    # FIRST, prepare and validate the parameters
    prepare narrative          -required
    prepare cause     -toupper -required -type {ptype ecause+unique}
    prepare s         -num     -required -type rfraction
    prepare p         -num     -required -type rfraction
    prepare q         -num     -required -type rfraction

    returnOnError -final

    # NEXT, create the mad
    lappend undo [mad mutate create [array get parms]]

    setundo [join $undo \n]
}


# MAD:DELETE
#
# Deletes a MAD in the initial state

order define MAD:DELETE {
    title "Delete Magic Attitude Driver"
    options \
        -sendstates {PREP PAUSED}

    form {
        rcc "MAD ID:" -for mad_id
        # Can't use "mad" field type, since only unused MADs can be
        # deleted.
        key mad_id -table gui_mads_initial -keys mad_id -dispcols longid
    }
} {
    # FIRST, prepare the parameters
    prepare mad_id -toupper -required -type {mad initial}

    returnOnError -final

    # NEXT, make sure the user knows what he is getting into.

    if {[sender] eq "gui"} {
        set answer [messagebox popup \
                        -title         "Are you sure?"                  \
                        -icon          warning                          \
                        -buttons       {ok "Delete it" cancel "Cancel"} \
                        -default       cancel                           \
                        -onclose       cancel                           \
                        -ignoretag     MAD:DELETE                       \
                        -ignoredefault ok                               \
                        -parent        [app topwin]                     \
                        -message       [normalize {
                            Are you sure you
                            really want to delete this magic attitude
                            driver?
                        }]]

        if {$answer eq "cancel"} {
            cancel
        }
    }

    # NEXT, Delete the mad
    lappend undo [mad mutate delete $parms(mad_id)]

    setundo [join $undo \n]
}


# MAD:UPDATE
#
# Updates an existing mad's description

order define MAD:UPDATE {
    title "Update Magic Attitude Driver"
    options -sendstates {PREP PAUSED TACTIC}

    form {
        rcc "MAD ID:" -for mad_id
        mad mad_id \
            -loadcmd {orderdialog keyload mad_id *}

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
} {
    # FIRST, prepare the parameters
    prepare mad_id    -required -type mad
    prepare narrative
    prepare cause     -toupper  -type {ptype ecause+unique}
    prepare s         -num      -type rfraction
    prepare p         -num      -type rfraction
    prepare q         -num      -type rfraction

    returnOnError -final

    # NEXT, update the MAD
    lappend undo [mad mutate update [array get parms]]

    setundo [join $undo \n]
}

# MAD:HREL
#
# Enters a magic horizontal relationship input.

order define MAD:HREL {
    title "Magic Horizontal Relationship Input"
    options -sendstates {PAUSED TACTIC}

    form {
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
} {
    # FIRST, prepare the parameters
    prepare mad_id             -required -type mad
    prepare mode      -tolower -required -type einputmode
    prepare f         -toupper -required -type group
    prepare g         -toupper -required -type group
    prepare mag  -num -toupper -required -type qmag

    returnOnError

    validate g {
        if {$parms(g) eq $parms(f)} {
            reject g "Cannot change a group's relationship with itself."
        }
    }

    returnOnError -final

    # NEXT, modify the curve
    mad mutate hrel [array get parms]

    return
}

# MAD:VREL
#
# Enters a magic vertical relationship input.

order define MAD:VREL {
    title "Magic Vertical Relationship Input"
    options -sendstates {PAUSED TACTIC}

    form {
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
} {
    # FIRST, prepare the parameters
    prepare mad_id             -required -type mad
    prepare mode      -tolower -required -type einputmode
    prepare g         -toupper -required -type group
    prepare a         -toupper -required -type actor
    prepare mag  -num -toupper -required -type qmag

    returnOnError -final

    # NEXT, modify the curve
    mad mutate vrel [array get parms]

    return
}

# MAD:SAT
#
# Enters a magic satisfaction input.

order define MAD:SAT {
    title "Magic Satisfaction Input"
    options -sendstates {PAUSED TACTIC}

    form {
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
} {
    # FIRST, prepare the parameters
    prepare mad_id             -required -type mad
    prepare mode      -tolower -required -type einputmode
    prepare g         -toupper -required -type civgroup
    prepare c         -toupper -required -type {ptype c}
    prepare mag  -num -toupper -required -type qmag

    returnOnError -final

    # NEXT, modify the curve
    mad mutate sat [array get parms]

    return
}


# MAD:COOP
#
# Enters a magic cooperation input.

order define MAD:COOP {
    title "Magic Cooperation Input"
    options -sendstates {PAUSED TACTIC}

    form {
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
} {
    # FIRST, prepare the parameters
    prepare mad_id             -required -type mad
    prepare mode      -tolower -required -type einputmode
    prepare f         -toupper -required -type civgroup
    prepare g         -toupper -required -type frcgroup
    prepare mag  -num -toupper -required -type qmag

    returnOnError -final

    # NEXT, modify the curve
    mad mutate coop [array get parms]

    return
}


