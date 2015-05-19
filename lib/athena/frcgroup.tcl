#-----------------------------------------------------------------------
# TITLE:
#    frcgroup.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Force Group Manager
#
#    This module is responsible for managing force groups and operations
#    upon them.
#
# TBD: Global refs: app/messagebox
#
#-----------------------------------------------------------------------

snit::type ::athena::frcgroup {
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
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.


    # names
    #
    # Returns the list of force group names

    method names {} {
        set names [$adb eval {
            SELECT g FROM frcgroups 
        }]
    }


    # namedict
    #
    # Returns a dictionary of force groups short/long names

    method namedict {} {
        return [$adb eval {
            SELECT g, longname FROM groups
            WHERE gtype='FRC'
        }]
    }

    # validate g
    #
    # g         Possibly, a force group short name.
    #
    # Validates a force group short name

    method validate {g} {
        if {![$self exists $g]} {
            set names [join [$self names] ", "]

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

    # exists g
    #
    # g      - A force group
    # 
    # Returns 1 if the group exists, and 0 otherwise.

    method exists {g} {
        return [dbexists $adb frcgroups g $g]
    }

    # get g ?parm?
    #
    # g      - A force group
    # parm   - A frcgroups_view column name
    #
    # Retrieves a row dictionary, or a particular column value, from
    # frcgroups; or "" if not found.

    method get {g {parm ""}} {
        return [dbget $adb frcgroups_view g $g $parm]
    }

    # view g ?tag?
    #
    # g    - A force group
    # tag  - A view tag 
    #
    # Retrieves a view dictionary for the group; uses the formatted view by
    # default otherwise it prepends the tag to '_frcgroups' and uses that
    # as the SQL table for the lookup.

    method view {g {tag ""}} {
        if {$tag eq ""} {
            set table fmt_frcgroups
        } else {
            append table $tag _frcgroups
        }
        return [dbget $adb $table g $g]        
    }


    # ownedby a
    #
    # a - An actor
    #
    # Returns a list of the force groups owned by actor a.

    method ownedby {a} {
        return [$adb eval {
            SELECT g FROM frcgroups_view
            WHERE a=$a
        }]
    }

    # notownedby a
    #
    # a - An actor
    #
    # Returns a list of the force groups not owned by actor a.

    method notownedby {a} {
        return [$adb eval {
            SELECT g FROM frcgroups_view
            WHERE a!=$a
        }]
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
    # parmdict     A dictionary of group parms
    #
    #    g              The group's ID
    #    longname       The group's long name
    #    a              The group's owning actor
    #    color          The group's color
    #    forcetype      The group's eforcetype
    #    training       The group's training level (etraining(n))
    #    equip_level    The group's equipment level (eequiplevel(n))
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

    method create {parmdict} {
        # FIRST, bring the parameters into scope.
        dict with parmdict {}

        # NEXT, Put the group in the database
        $adb eval {
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
                                  equip_level, base_personnel, local)
            VALUES($g,
                   $forcetype,
                   $training,
                   $equip_level,
                   $base_personnel,
                   $local);

            INSERT INTO coop_fg(f,g)
            SELECT g, $g FROM civgroups;
        }

        # NEXT, Return the undo command
        return [mymethod delete $g]
    }

    # delete g
    #
    # g     A group short name
    #
    # Deletes the group, including all references.

    method delete {g} {
        # FIRST, Delete the group, grabbing the undo information
        set data [$adb delete -grab groups {g=$g} frcgroups {g=$g}]

        # NEXT, Return the undo script
        return [list $adb ungrab $data]
    }

    # update parmdict
    #
    # parmdict     A dictionary of group parms
    #
    #    g              A group short name
    #    longname       A new long name, or ""
    #    a              A new owning actor, or ""
    #    color          A new color, or ""
    #    forcetype      A new eforcetype, or ""
    #    training       A new training level, or ""
    #    equip_level    A new equipment level, or ""
    #    base_personnel A new base personnel, or ""
    #    demeanor       A new demeanor, or ""
    #    cost           A new cost, or ""
    #    local          A new local flag, or ""
    #
    # Updates a frcgroup given the parms, which are presumed to be
    # valid.

    method update {parmdict} {
        # FIRST, bring the parameters into scope.
        dict with parmdict {}

        # NEXT, grab the group data that might change.
        set data [$adb grab groups {g=$g} frcgroups {g=$g}]

        # NEXT, Update the group
        $adb eval {
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
                equip_level    = nonempty($equip_level,    equip_level),
                base_personnel = nonempty($base_personnel, base_personnel),
                local          = nonempty($local,          local)
            WHERE g=$g
        } {}

        # NEXT, Return the undo command
        return [list $adb ungrab $data]
    }
}

#-------------------------------------------------------------------
# Orders: FRCGROUP:*

# FRCGROUP:CREATE
#
# Creates new force groups.

::athena::orders define FRCGROUP:CREATE {
    meta title "Create Force Group"
    
    meta sendstates PREP
    meta parmlist {
        g 
        longname 
        a 
        {color          "#AA7744"}
        {forcetype      REGULAR}
        {training       FULL}
        {equip_level    GOOD}
        {base_personnel 0}
        {demeanor       AVERAGE}
        {cost           0}
        {local          0}
    }

    meta form {
        rcc "Group:" -for g
        text g

        rcc "Long Name:" -for longname
        longname longname

        rcc "Owning Actor:" -for a    
        actor a    

        rcc "Color:" -for color
        color color -defvalue #AA7744

        rcc "Force Type:" -for forcetype
        enumlong forcetype -dictcmd {eforcetype deflist} -defvalue REGULAR

        rcc "Training:" -for training
        enumlong training -dictcmd {etraining deflist} -defvalue FULL

        rcc "Equipment Level:" -for equip_level
        enumlong equip_level -dictcmd {eequiplevel deflist} -defvalue GOOD

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

    method narrative {} {
        if {$parms(g) ne ""} {
            return "[my title]: $parms(g)"
        } else {
            return "[my title]"
        }
    }

    method _validate {} {
        my prepare g              -toupper   -required -type ident
        my unused g
        my prepare longname       -normalize
        my prepare a              -toupper             -type [list $adb actor]
        my prepare color          -tolower   -required -type hexcolor
        my prepare forcetype      -toupper   -required -type eforcetype
        my prepare training       -toupper   -required -type etraining
        my prepare equip_level    -toupper   -required -type eequiplevel
        my prepare base_personnel -num       -required -type iquantity
        my prepare demeanor       -toupper   -required -type edemeanor
        my prepare cost           -toupper   -required -type money
        my prepare local          -toupper   -required -type boolean
    }

    method _execute {{flunky ""}} {
        # NEXT, If longname is "", defaults to ID.
        if {$parms(longname) eq ""} {
            set parms(longname) $parms(g)
        }
    
        # NEXT, create the group and dependent entities
        lappend undo [$adb frcgroup create [array get parms]]
    
        my setundo [join $undo \n]
    }
}

# FRCGROUP:DELETE

::athena::orders define FRCGROUP:DELETE {
    meta title "Delete Force Group"
    meta sendstates PREP

    meta parmlist {g}

    meta form {
        rcc "Group:" -for g
        frcgroup g
    }

    method narrative {} {
        if {$parms(g) ne ""} {
            return "[my title]: $parms(g)"
        } else {
            return "[my title]"
        }
    }

    method _validate {} {
        # FIRST, prepare the parameters
        my prepare g -toupper -required -type [list $adb frcgroup]
    }

    method _execute {{flunky ""}} {
        lappend undo [$adb frcgroup delete $parms(g)]
        lappend undo [$adb absit reconcile]
    
        my setundo [join $undo \n]
    }
}


# FRCGROUP:UPDATE
#
# Updates existing groups.

::athena::orders define FRCGROUP:UPDATE {
    meta title "Update Force Group"
    meta sendstates PREP

    meta parmlist {
        g longname a color forcetype training equip_level base_personnel 
        demeanor cost local
    }

    meta form {
        rcc "Group:" -for g
        dbkey g -table fmt_frcgroups -keys g \
            -loadcmd {$order_ keyload g *}

        rcc "Long Name:" -for longname
        longname longname

        rcc "Owning Actor:" -for a    
        actor a    

        rcc "Color:" -for color
        color color

        rcc "Force Type:" -for forcetype
        enumlong forcetype -dictcmd {eforcetype deflist}

        rcc "Training:" -for training
        enumlong training -dictcmd {etraining deflist}

        rcc "Equipment Level:" -for equip_level
        enumlong equip_level -dictcmd {eequiplevel deflist}

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


    method _validate {} {
        # FIRST, prepare the parameters
        my prepare g              -toupper   -required -type [list $adb frcgroup]
        my prepare a              -toupper   -type [list $adb actor]
        my prepare longname       -normalize
        my prepare color          -tolower   -type hexcolor
        my prepare forcetype      -toupper   -type eforcetype
        my prepare training       -toupper   -type etraining
        my prepare equip_level    -toupper   -type eequiplevel
        my prepare base_personnel -num       -type iquantity
        my prepare demeanor       -toupper   -type edemeanor
        my prepare cost           -toupper   -type money
        my prepare local          -toupper   -type boolean
    }

    method _execute {{flunky ""}} {
        # NEXT, modify the group.
        set undo [list]
        lappend undo [$adb frcgroup update [array get parms]]
    
        my setundo [join $undo \n]
    }
}

# FRCGROUP:UPDATE:MULTI
#
# Updates multiple groups.

::athena::orders define FRCGROUP:UPDATE:MULTI {
    meta title "Update Multiple Force Groups"
    meta sendstates PREP

    meta parmlist {
        ids a color forcetype training equip_level base_personnel demeanor 
        cost local
    }

    meta form {
        rcc "Groups:" -for ids
        dbmulti ids -table fmt_frcgroups -key g \
            -loadcmd {$order_ multiload ids *}

        rcc "Owning Actor:" -for a    
        actor a    

        rcc "Color:" -for color
        color color

        rcc "Force Type:" -for forcetype
        enumlong forcetype -dictcmd {eforcetype deflist}

        rcc "Training:" -for training
        enumlong training -dictcmd {etraining deflist}

        rcc "Equipment Level:" -for equip_level
        enumlong equip_level -dictcmd {eequiplevel deflist}

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


    method _validate {} {
        my prepare ids -required  -toupper  -listof [list $adb frcgroup]
        my prepare a              -toupper  -type   [list $adb actor]
        my prepare color          -tolower  -type   hexcolor
        my prepare forcetype      -toupper  -type   eforcetype
        my prepare training       -toupper  -type   etraining
        my prepare equip_level    -toupper  -type   eequiplevel
        my prepare base_personnel -num      -type   iquantity
        my prepare demeanor       -toupper  -type   edemeanor
        my prepare cost           -toupper  -type   money
        my prepare local          -toupper  -type   boolean

    }

    method _execute {{flunky ""}} {
        # FIRST, clear the other parameters expected by the mutator
        set parms(longname) ""

        # NEXT, modify the group
        set undo [list]
    
        foreach parms(g) $parms(ids) {
            lappend undo [$adb frcgroup update [array get parms]]
        }

        my setundo [join $undo \n]
    }
}




