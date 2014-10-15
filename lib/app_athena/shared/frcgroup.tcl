#-----------------------------------------------------------------------
# TITLE:
#    frcgroup.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Force Group Manager
#
#    This module is responsible for managing force groups and operations
#    upon them.  As such, it is a type ensemble.
#
#-----------------------------------------------------------------------

snit::type frcgroup {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.


    # names
    #
    # Returns the list of force group names

    typemethod names {} {
        set names [rdb eval {
            SELECT g FROM frcgroups 
        }]
    }


    # namedict
    #
    # Returns a dictionary of force groups short/long names

    typemethod namedict {} {
        return [rdb eval {
            SELECT g, longname FROM groups
            WHERE gtype='FRC'
        }]
    }

    # validate g
    #
    # g         Possibly, a force group short name.
    #
    # Validates a force group short name

    typemethod validate {g} {
        if {![rdb exists {SELECT g FROM frcgroups WHERE g=$g}]} {
            set names [join [frcgroup names] ", "]

            if {$names ne ""} {
                set msg "should be one of: $names"
            } else {
                set msg "none are defined"
            }

            return -code error -errorcode INVALID \
                "Invalid force group, $msg"
        }

        return $g
    }

    # get g ?parm?
    #
    # g      - A force group
    # parm   - A frcgroups_view column name
    #
    # Retrieves a row dictionary, or a particular column value, from
    # frcgroups; or "" if not found.

    typemethod get {g {parm ""}} {
        # FIRST, get the data
        rdb eval {SELECT * FROM frcgroups_view WHERE g=$g} row {
            if {$parm ne ""} {
                return $row($parm)
            } else {
                unset row(*)
                return [array get row]
            }
        }

        return ""
    }

    # ownedby a
    #
    # a - An actor
    #
    # Returns a list of the force groups owned by actor a.

    typemethod ownedby {a} {
        return [rdb eval {
            SELECT g FROM frcgroups_view
            WHERE a=$a
        }]
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
    # parmdict     A dictionary of group parms
    #
    #    g              The group's ID
    #    longname       The group's long name
    #    a              The group's owning actor
    #    color          The group's color
    #    forcetype      The group's eforcetype
    #    training       The group's training level (etraining(n))
    #    base_personnel The group's base personnel
    #    demeanor       The group's demeanor (edemeanor(n))
    #    cost           The group's maintenance cost, $/person/week
    #    local          The group's local flag
    #
    # Creates a force group given the parms, which are presumed to be
    # valid.
    #
    # Creating a force group requires adding entries to the groups and
    # frcgroups tables.

    typemethod {mutate create} {parmdict} {
        # FIRST, bring the parameters into scope.
        dict with parmdict {}

        # NEXT, Put the group in the database
        rdb eval {
            INSERT INTO 
            groups(g, longname, a, color, demeanor, cost, gtype)
            VALUES($g,
                   $longname,
                   nullif($a,''),
                   $color,
                   $demeanor,
                   $cost,
                   'FRC');

            INSERT INTO frcgroups(g, forcetype, training,
                                  base_personnel, local)
            VALUES($g,
                   $forcetype,
                   $training,
                   $base_personnel,
                   $local);

            INSERT INTO coop_fg(f,g)
            SELECT g, $g FROM civgroups;
        }

        # NEXT, Return the undo command
        return [mytypemethod mutate delete $g]
    }

    # mutate delete g
    #
    # g     A group short name
    #
    # Deletes the group, including all references.

    typemethod {mutate delete} {g} {
        # FIRST, Delete the group, grabbing the undo information
        set data [rdb delete -grab groups {g=$g} frcgroups {g=$g}]

        # NEXT, Return the undo script
        return [list rdb ungrab $data]
    }

    # mutate update parmdict
    #
    # parmdict     A dictionary of group parms
    #
    #    g              A group short name
    #    longname       A new long name, or ""
    #    a              A new owning actor, or ""
    #    color          A new color, or ""
    #    forcetype      A new eforcetype, or ""
    #    training       A new training level, or ""
    #    base_personnel A new base personnel, or ""
    #    demeanor       A new demeanor, or ""
    #    cost           A new cost, or ""
    #    local          A new local flag, or ""
    #
    # Updates a frcgroup given the parms, which are presumed to be
    # valid.

    typemethod {mutate update} {parmdict} {
        # FIRST, bring the parameters into scope.
        dict with parmdict {}

        # NEXT, grab the group data that might change.
        set data [rdb grab groups {g=$g} frcgroups {g=$g}]

        # NEXT, Update the group
        rdb eval {
            UPDATE groups
            SET longname   = nonempty($longname,     longname),
                a          = coalesce(nullif($a,''), a),
                color      = nonempty($color,        color),
                demeanor   = nonempty($demeanor,     demeanor),
                cost       = nonempty($cost,         cost)
            WHERE g=$g;

            UPDATE frcgroups
            SET forcetype      = nonempty($forcetype,      forcetype),
                training       = nonempty($training,       training),
                base_personnel = nonempty($base_personnel, base_personnel),
                local          = nonempty($local,          local)
            WHERE g=$g
        } {}

        # NEXT, Return the undo command
        return [list rdb ungrab $data]
    }
}

#-------------------------------------------------------------------
# Orders: FRCGROUP:*

# FRCGROUP:CREATE
#
# Creates new force groups.

order define FRCGROUP:CREATE {
    title "Create Force Group"
    
    options -sendstates PREP

    form {
        rcc "Group:" -for g
        text g

        rcc "Long Name:" -for longname
        longname longname

        rcc "Owning Actor:" -for a    
        actor a    

        rcc "Color:" -for color
        color color -defvalue #AA7744

        rcc "Force Type" -for forcetype
        enumlong forcetype -dictcmd {eforcetype deflist} -defvalue REGULAR

        rcc "Training" -for training
        enumlong training -dictcmd {etraining deflist} -defvalue FULL

        rcc "Base Personnel:" -for base_personnel
        text base_personnel -defvalue 0

        rcc "Demeanor:" -for demeanor
        enumlong demeanor -dictcmd {edemeanor deflist} -defvalue AVERAGE

        rcc "Cost:" -for cost
        text cost -defvalue 0
        label "$/person/week"

        rcc "Local Group?" -for local
        yesno local -defvalue 0
    }
} {
    # FIRST, prepare and validate the parameters
    prepare g              -toupper   -required -unused -type ident
    prepare longname       -normalize
    prepare a              -toupper             -type actor
    prepare color          -tolower   -required -type hexcolor
    prepare forcetype      -toupper   -required -type eforcetype
    prepare training       -toupper   -required -type etraining
    prepare base_personnel -num       -required -type iquantity
    prepare demeanor       -toupper   -required -type edemeanor
    prepare cost           -toupper   -required -type money
    prepare local          -toupper   -required -type boolean

    returnOnError -final

    # NEXT, If longname is "", defaults to ID.
    if {$parms(longname) eq ""} {
        set parms(longname) $parms(g)
    }

    # NEXT, create the group and dependent entities
    lappend undo [frcgroup mutate create [array get parms]]

    setundo [join $undo \n]
}

# FRCGROUP:DELETE

order define FRCGROUP:DELETE {
    title "Delete Force Group"
    options -sendstates PREP

    form {
        rcc "Group:" -for g
        frcgroup g
    }
} {
    # FIRST, prepare the parameters
    prepare g -toupper -required -type frcgroup

    returnOnError -final

    # NEXT, make sure the user knows what he is getting into.

    if {[sender] eq "gui"} {
        set answer [messagebox popup \
                        -title         "Are you sure?"                  \
                        -icon          warning                          \
                        -buttons       {ok "Delete it" cancel "Cancel"} \
                        -default       cancel                           \
                        -onclose       cancel                           \
                        -ignoretag     FRCGROUP:DELETE                  \
                        -ignoredefault ok                               \
                        -parent        [app topwin]                     \
                        -message       [normalize {
                            Are you sure you
                            really want to delete this group, along
                            with all of the entities that depend upon it?
                        }]]

        if {$answer eq "cancel"} {
            cancel
        }
    }

    # NEXT, Delete the group and dependent entities
    lappend undo [frcgroup mutate delete $parms(g)]
    lappend undo [absit mutate reconcile]

    setundo [join $undo \n]
}


# FRCGROUP:UPDATE
#
# Updates existing groups.

order define FRCGROUP:UPDATE {
    title "Update Force Group"
    options -sendstates PREP

    form {
        rcc "Group:" -for g
        key g -table gui_frcgroups -keys g \
            -loadcmd {orderdialog keyload g *}

        rcc "Long Name:" -for longname
        longname longname

        rcc "Owning Actor:" -for a    
        actor a    

        rcc "Color:" -for color
        color color

        rcc "Force Type" -for forcetype
        enumlong forcetype -dictcmd {eforcetype deflist}

        rcc "Training" -for training
        enumlong training -dictcmd {etraining deflist}

        rcc "Base Personnel:" -for base_personnel
        text base_personnel

        rcc "Demeanor:" -for demeanor
        enumlong demeanor -dictcmd {edemeanor deflist}

        rcc "Cost:" -for cost
        text cost
        label "$/person/week"

        rcc "Local Group?" -for local
        yesno local
    }
} {
    # FIRST, prepare the parameters
    prepare g              -toupper   -required -type frcgroup
    prepare a              -toupper   -type actor
    prepare longname       -normalize
    prepare color          -tolower   -type hexcolor
    prepare forcetype      -toupper   -type eforcetype
    prepare training       -toupper   -type etraining
    prepare base_personnel -num       -type iquantity
    prepare demeanor       -toupper   -type edemeanor
    prepare cost           -toupper   -type money
    prepare local          -toupper   -type boolean

    returnOnError -final

    # NEXT, modify the group.
    set undo [list]
    lappend undo [frcgroup mutate update [array get parms]]

    setundo [join $undo \n]
}

# FRCGROUP:UPDATE:MULTI
#
# Updates multiple groups.

order define FRCGROUP:UPDATE:MULTI {
    title "Update Multiple Force Groups"
    options -sendstates PREP

    form {
        rcc "Groups:" -for ids
        multi ids -table gui_frcgroups -key g \
            -loadcmd {orderdialog multiload ids *}

        rcc "Owning Actor:" -for a    
        actor a    

        rcc "Color:" -for color
        color color

        rcc "Force Type" -for forcetype
        enumlong forcetype -dictcmd {eforcetype deflist}

        rcc "Training" -for training
        enumlong training -dictcmd {etraining deflist}

        rcc "Base Personnel:" -for base_personnel
        text base_personnel

        rcc "Demeanor:" -for demeanor
        enumlong demeanor -dictcmd {edemeanor deflist}

        rcc "Cost:" -for cost
        text cost
        label "$/person/week"

        rcc "Local Group?" -for local
        yesno local
    }
} {
    # FIRST, prepare the parameters
    prepare ids            -toupper  -required -listof frcgroup
    prepare a              -toupper            -type   actor
    prepare color          -tolower            -type   hexcolor
    prepare forcetype      -toupper            -type   eforcetype
    prepare training       -toupper            -type   etraining
    prepare base_personnel -num                -type   iquantity
    prepare demeanor       -toupper            -type   edemeanor
    prepare cost           -toupper            -type   money
    prepare local          -toupper            -type   boolean

    returnOnError -final

    # NEXT, clear the other parameters expected by the mutator
    prepare longname

    # NEXT, modify the group
    set undo [list]

    foreach parms(g) $parms(ids) {
        lappend undo [frcgroup mutate update [array get parms]]
    }

    setundo [join $undo \n]
}




