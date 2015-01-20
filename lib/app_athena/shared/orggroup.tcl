#-----------------------------------------------------------------------
# TITLE:
#    orggroup.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Organization Group Manager
#
#    This module is responsible for managing organization groups and operations
#    upon them.  As such, it is a type ensemble.
#
#-----------------------------------------------------------------------

snit::type orggroup {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.


    # names
    #
    # Returns the list of neighborhood names

    typemethod names {} {
        set names [rdb eval {
            SELECT g FROM orggroups 
        }]
    }


    # validate g
    #
    # g         Possibly, a organization group short name.
    #
    # Validates a organization group short name

    typemethod validate {g} {
        if {![rdb exists {SELECT g FROM orggroups WHERE g=$g}]} {
            set names [join [orggroup names] ", "]

            if {$names ne ""} {
                set msg "should be one of: $names"
            } else {
                set msg "none are defined"
            }

            return -code error -errorcode INVALID \
                "Invalid organization group, $msg"
        }

        return $g
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
    #    g                The group's ID
    #    longname         The group's long name
    #    a                The group's owning actor
    #    color            The group's color
    #    orgtype          The group's eorgtype
    #    base_personnel   The group's base personnel
    #    demeanor         The group's demeanor (edemeanor(n))
    #    cost             The group's maintenance cost, $/person/week
    #
    # Creates a organization group given the parms, which are presumed to be
    # valid.
    #
    # Creating a organization group requires adding entries to the groups and
    # orggroups tables.

    typemethod {mutate create} {parmdict} {
        dict with parmdict {
            # FIRST, Put the group in the database
            rdb eval {
                INSERT INTO 
                groups(g, longname, a, color, demeanor, cost, gtype)
                VALUES($g,
                       $longname,
                       nullif($a,''),
                       $color,
                       $demeanor,
                       $cost,
                       'ORG');

                INSERT INTO orggroups(g,orgtype,base_personnel)
                VALUES($g,
                       $orgtype,
                       $base_personnel);
            }

            # NEXT, Return the undo command
            return [mytypemethod mutate delete $g]
        }
    }


    # mutate delete g
    #
    # g     A group short name
    #
    # Deletes the group, including all references.

    typemethod {mutate delete} {g} {
        # FIRST, delete the records, grabbing the undo information
        set data [rdb delete -grab groups {g=$g} orggroups {g=$g}]

        # NEXT, Return the undo script
        return [list rdb ungrab $data]
    }

    # mutate update parmdict
    #
    # parmdict     A dictionary of group parms
    #
    #    g                A group short name
    #    longname         A new long name, or ""
    #    a                A new owning actor, or ""
    #    color            A new color, or ""
    #    orgtype          A new orgtype, or ""
    #    demeanor         A new demeanor, or ""
    #    cost             A new cost, or ""
    #
    # Updates a orggroup given the parms, which are presumed to be
    # valid.

    typemethod {mutate update} {parmdict} {
        dict with parmdict {
            # FIRST, get the undo information
            set data [rdb grab groups {g=$g} orggroups {g=$g}]

            # NEXT, Update the group
            rdb eval {
                UPDATE groups
                SET longname   = nonempty($longname,     longname),
                    a      = coalesce(nullif($a,''), a),
                    color      = nonempty($color,        color),
                    demeanor   = nonempty($demeanor,     demeanor),
                    cost       = nonempty($cost,         cost)
                WHERE g=$g;

                UPDATE orggroups
                SET orgtype        = nonempty($orgtype,       orgtype),
                    base_personnel = nonempty($base_personnel,base_personnel)
                WHERE g=$g
            } {}

            # NEXT, Return the undo command
            return [list rdb ungrab $data]
        }
    }
}

#-------------------------------------------------------------------
# Orders: ORGGROUP:*

# ORGGROUP:CREATE
#
# Creates new organization groups.

myorders define ORGGROUP:CREATE {
    meta title "Create Organization Group"
    meta sendstates PREP

    meta parmlist {
        g
        longname
        a
        {color          "#B200B3"}
        {orgtype        NGO}
        {base_personnel 0}
        {demeanor       AVERAGE}
        {cost           0}
    }

    meta form {
        rcc "Group:" -for g
        text g

        rcc "Long Name:" -for longname
        longname longname

        rcc "Owning Actor:" -for a    
        actor a    

        rcc "Color:" -for color
        color color -defvalue #B300B3

        rcc "Organization Type" -for orgtype
        enumlong orgtype -dictcmd {eorgtype deflist} -defvalue NGO

        rcc "Base Personnel:" -for base_personnel
        text base_personnel -defvalue 0

        rcc "Demeanor:" -for demeanor
        enumlong demeanor -dictcmd {edemeanor deflist} -defvalue AVERAGE

        rcc "Cost:" -for cost
        text cost -defvalue 0
        label "$/person/week"
    }


    method _validate {} {
        my prepare g              -toupper   -required -type ident
        my unused g
        my prepare longname       -normalize
        my prepare a              -toupper             -type actor
        my prepare color          -tolower   -required -type hexcolor
        my prepare orgtype        -toupper   -required -type eorgtype
        my prepare base_personnel -num       -required -type iquantity
        my prepare demeanor       -toupper   -required -type edemeanor
        my prepare cost           -toupper   -required -type money
    }

    method _execute {{flunky ""}} {
        if {$parms(longname) eq ""} {
            set parms(longname) $parms(g)
        }
    
        lappend undo [orggroup mutate create [array get parms]]
        
        my setundo [join $undo \n]
    }
}

# ORGGROUP:DELETE

myorders define ORGGROUP:DELETE {
    meta title "Delete Organization Group"
    meta sendstates PREP

    meta parmlist {g}

    meta form {
        rcc "Group:" -for g
        orggroup g
    }


    method _validate {} {
        my prepare g -toupper -required -type orggroup
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
                                Are you sure you really want to delete this 
                                group, along with all of the entities that 
                                depend upon it?
                            }]]
    
            if {$answer eq "cancel"} {
                my cancel
            }
        }

        lappend undo [orggroup mutate delete $parms(g)]
        lappend undo [absit mutate reconcile]
        
        my setundo [join $undo \n]
    }
}


# ORGGROUP:UPDATE
#
# Updates existing groups.

myorders define ORGGROUP:UPDATE {
    meta title "Update Organization Group"
    meta sendstates PREP

    meta parmlist {
        g
        longname
        a
        color
        orgtype 
        base_personnel
        demeanor
        cost
    }

    meta form {
        rcc "Group:" -for g
        dbkey g -table gui_orggroups -keys g \
            -loadcmd {$order_ keyload g *}

        rcc "Long Name:" -for longname
        longname longname

        rcc "Owning Actor:" -for a    
        actor a    

        rcc "Color:" -for color
        color color

        rcc "Organization Type" -for orgtype
        enumlong orgtype -dictcmd {eorgtype deflist}

        rcc "Base Personnel:" -for base_personnel
        text base_personnel

        rcc "Demeanor:" -for demeanor
        enumlong demeanor -dictcmd {edemeanor deflist}

        rcc "Cost:" -for cost
        text cost
        label "$/person/week"
    }


    method _validate {} {
        my prepare g              -toupper   -required -type orggroup
        my prepare a              -toupper   -type actor
        my prepare longname       -normalize 
        my prepare color          -tolower   -type hexcolor
        my prepare orgtype        -toupper   -type eorgtype
        my prepare base_personnel -num       -type iquantity
        my prepare demeanor       -toupper   -type edemeanor
        my prepare cost           -toupper   -type money
    }

    method _execute {{flunky ""}} {
        my setundo [orggroup mutate update [array get parms]]
    }
}


# ORGGROUP:UPDATE:MULTI
#
# Updates multiple groups.

myorders define ORGGROUP:UPDATE:MULTI {
    meta title "Update Multiple Organization Groups"
    meta sendstates PREP
    meta parmlist {
        ids
        a
        color
        orgtype
        base_personnel
        demeanor
        cost
    }

    meta form {
        rcc "Groups:" -for ids
        dbmulti ids -table gui_orggroups -key g \
            -loadcmd {$order_ multiload ids *}

        rcc "Owning Actor:" -for a    
        actor a    

        rcc "Color:" -for color
        color color

        rcc "Organization Type" -for orgtype
        enumlong orgtype -dictcmd {eorgtype deflist}

        rcc "Base Personnel:" -for base_personnel
        text base_personnel

        rcc "Demeanor:" -for demeanor
        enumlong demeanor -dictcmd {edemeanor deflist}

        rcc "Cost:" -for cost
        text cost
        label "$/person/week"
    }


    method _validate {} {
        my prepare ids            -toupper  -required -listof orggroup
        my prepare a              -toupper            -type   actor
        my prepare color          -tolower            -type   hexcolor
        my prepare orgtype        -toupper            -type   eorgtype
        my prepare base_personnel -num                -type   iquantity
        my prepare demeanor       -toupper            -type   edemeanor
        my prepare cost           -toupper            -type   money
    }

    method _execute {{flunky ""}} {
        # FIRST, clear the other parameters expected by the mutator
        set parms(longname) ""
    
        set undo [list]
        foreach parms(g) $parms(ids) {
            lappend undo [orggroup mutate update [array get parms]]
        }
    
        my setundo [join $undo \n]
    }
}







