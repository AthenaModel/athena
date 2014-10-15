#-----------------------------------------------------------------------
# TITLE:
#    inject.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena_sim(1): Curse Inject Manager
#
#    This module is responsible for managing CURSE injects and operations
#    upon them.  As such, it is a type ensemble.
#
#    There are a number of different inject types.  
#
#    * All are stored in the curse_injects table.
#
#    * The data inheritance is handled by defining a number of 
#      generic columns to hold type-specific parameters.
#
#    * The mutators work for all inject types.
#
#    * Each inject type has its own CREATE and UPDATE orders; the 
#      DELETE and STATE orders are common to all.
#
#    * scenario(sim) defines a view for each inject type,
#      injects_<type>.
#
#-----------------------------------------------------------------------

snit::type inject {
    # Make it a singleton
    pragma -hasinstances no

    #===================================================================
    # Lookup tables

    # optParms: This variable is a dictionary of all optional parameters
    # with empty values.  The create and update mutators can merge the
    # input parmdict with this to get a parmdict with the full set of
    # parameters.

    typevariable optParms {
        mag  ""
        mode ""
        a    ""
        c    ""
        f    ""
        g    ""
    }

    #===================================================================
    # Inject Types: Definition and Query interface.

    #-------------------------------------------------------------------
    # Uncheckpointed Type variables

    # tinfo array: Type Info
    #
    # names         - List of the names of the inject types.
    # parms-$ttype  - List of the optional parms used by the inject type.

    typevariable tinfo -array {
        names {}
    }

    # type names
    #
    # Returns the inject type names.
    
    typemethod {type names} {} {
        return [lsort $tinfo(names)]
    }

    # type parms ttype
    #
    # Returns a list of the names of the optional parameters used by
    # the inject.
    
    typemethod {type parms} {ttype} {
        return $tinfo(parms-$ttype)
    }

    # type define name optparms defscript
    #
    # name        - The inject name
    # optparms    - List of optional parameters used by this inject type.
    # defscript   - The definition script (a snit::type script)
    #
    # Defines inject::$name as a type ensemble given the typemethods
    # defined in the defscript.  See inject(i) for documentation of the
    # expected typemethods.

    typemethod {type define} {name optparms defscript} {
        # FIRST, define the type.
        set header {
            # Make it a singleton
            pragma -hasinstances no

            typemethod check {pdict} { return }
        }

        snit::type ${type}::${name} "$header\n$defscript"

        # NEXT, save the type metadata
        ladd tinfo(names) $name
        set tinfo(parms-$name) $optparms
    }
    
    #-------------------------------------------------------------------
    # Sanity Check

    # checker ?ht?
    #
    # ht - An htools buffer
    #
    # Computes the sanity check, and formats the results into the buffer
    # for inclusion into an HTML page.  Returns an esanity value, either
    # OK or WARNING.
    #
    # Note: This checker is called from [iom checker], not from
    # [sanity *].

    typemethod checker {{ht ""}} {
        set edict [$type DoSanityCheck]

        if {[dict size $edict] == 0} {
            return OK
        }

        if {$ht ne ""} {
            $type DoSanityReport $ht $edict
        }

        return WARNING
    }

    # DoSanityCheck
    #
    # This routine does the actual sanity check, marking the inject
    # records in the RDB and putting error messages in a 
    # nested dictionary, curse_id -> inject_num -> errmsg.
    #
    # Returns the dictionary, which will be empty if there were no
    # errors.

    typemethod DoSanityCheck {} {
        # FIRST, create the empty error dictionary.
        set edict [dict create]

        # NEXT, clear the invalid states, since we're going to 
        # recompute them.

        rdb eval {
            UPDATE curse_injects
            SET state = 'normal'
            WHERE state = 'invalid';
        }

        # NEXT, identify the invalid injects.
        set badlist [list]

        rdb eval {
            SELECT * FROM curse_injects
        } row {
            set result [inject call check [array get row]]

            if {$result ne ""} {
                dict set edict $row(curse_id) $row(inject_num) $result
                lappend badlist $row(curse_id) $row(inject_num)
            }
        }

        # NEXT, mark the bad injects invalid.
        foreach {curse_id inject_num} $badlist {
            rdb eval {
                UPDATE curse_injects
                SET state = 'invalid'
                WHERE curse_id=$curse_id AND inject_num=$inject_num 
            }
        }

        notifier send ::inject <Check>

        return $edict
    }


    # DoSanityReport ht edict
    #
    # ht        - An htools buffer to receive a report.
    # edict     - A dictionary curse_id->inject_num->errmsg
    #
    # Writes HTML text of the results of the sanity check to the ht
    # buffer.  This routine assumes that there are errors.

    typemethod DoSanityReport {ht edict} {

        # FIRST, Build the report
        $ht subtitle "CURSE Inject Constraints"

        $ht putln {
            Certain CURSE injects failed their checks and have been 
            marked invalid in the
        }
        
        $ht link gui:/tab/curses "CURSE Browser"

        $ht put ".  Please fix them or delete them."
        $ht para

        dict for {curse_id cdict} $edict {
            array set cdata [curse get $curse_id]

            $ht putln "<b>CURSE $curse_id: $cdata(longname)</b>"
            $ht ul

            dict for {inject_num errmsg} $cdict {
                set idict [inject get [list $curse_id $inject_num]]

                dict with idict {
                    $ht li
                    $ht put "Inject #$inject_num: $narrative"
                    $ht br
                    $ht putln "==> <font color=red>Warning: $errmsg</font>"
                }
            }
            
            $ht /ul
        }

        return
    }


    #===================================================================
    # inject Instance: Modification and Query Interace

    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.


    # validate id
    #
    # id - Possibly, an inject ID {curse_id inject_num}
    #
    # Validates an inject ID

    typemethod validate {id} {
        lassign $id curse_id inject_num

        curse validate $curse_id

        if {![inject exists $id]} {
            set nums [rdb eval {
                SELECT inject_num FROM curse_injects
                WHERE curse_id=$curse_id
                ORDER BY inject_num
            }]

            if {[llength $nums] == 0} {
                set msg "no injects are defined for this CURSE"
            } else {
                set msg "inject number should be one of: [join $nums {, }]"
            }

            return -code error -errorcode INVALID \
                "Invalid inject \"$id\", $msg"
        }

        return $id
    }

    # role validate curse_id role_id
    #
    # curse_id    - An ID of a CURSE
    # role_id     - The role that should be in an inject associated with
    #               the CURSE that has curse_id
    #
    # This method validates that the supplied role_id indeed exists in an
    # inject associated with a CURSE that has the supplied curse_id. If
    # the role does not exist in any of the injects associated with the
    # CURSE, an error is returned, otherwise the role_id is returned

    typemethod {role validate} {curse_id role_id} {
        # FIRST, get all roles defined for the CURSE
        set validroles [inject AllRoles $curse_id]

        # NEXT, if the supplied role_id does not exist in this curse
        # error. Otherwise, return the role_id
        if {$role_id ni $validroles} {
            if {[llength $validroles] == 0} {
                set msg "no roles are defined for $curse_id."
            } else {
                set msg "role should be one of: [join $validroles {, }]"
            }

            return -code error -errorcode INVALID \
                "Invalid role \"$role_id\", $msg"
        }

        return $role_id
    }

    # AllRoles curse_id
    #
    # curse_id   - ID of a CURSE
    #
    # This method returns all roles in injects associated with the
    # CURSE with the supplied curse_id. It is a helper typemethod for
    # role validation.

    typemethod AllRoles {curse_id} {
        set rnames {}
        rdb eval {
            SELECT f, g, a FROM curse_injects
            WHERE curse_id=$curse_id
         } idata {
            if {$idata(f) ne ""} {lappend rnames $idata(f)}
            if {$idata(g) ne ""} {lappend rnames $idata(g)}
            if {$idata(a) ne ""} {lappend rnames $idata(a)}
         }
         
         return $rnames
    }

    # exists id
    #
    # id   - Possibly, an inject id, {curse_id inject_num}
    #
    # Returns 1 if the inject exists, and 0 otherwise.

    typemethod exists {id} {
        lassign $id curse_id inject_num

        return [rdb exists {
            SELECT * FROM curse_injects
            WHERE curse_id=$curse_id AND inject_num=$inject_num
        }]
    }

    # role exists
    #
    # role   - The name of role
    #
    # Returns 1 if the role already exists, and 0 otherwise

    typemethod {role exists} {role} {
        set roles [rdb eval {
            SELECT DISTINCT f FROM curse_injects
            WHERE f != ''
        }]

        lmerge roles  [rdb eval {
            SELECT DISTINCT g FROM curse_injects
            WHERE g != ''
        }]

        lmerge roles  [rdb eval {
            SELECT DISTINCT a FROM curse_injects
            WHERE a != ''
        }]

        if {$role in $roles} {
            return 1
        }

        return 0
    }

    # get id ?parm?
    #
    # id   - An inject id
    # parm - A curse_injects column name
    #
    # Retrieves a row dictionary, or a particular column value, from
    # curse_injects.

    typemethod get {id {parm ""}} {
        lassign $id curse_id inject_num

        # FIRST, get the data
        rdb eval {
            SELECT * FROM curse_injects 
            WHERE curse_id=$curse_id AND inject_num=$inject_num
        } row {
            if {$parm eq ""} {
                unset row(*)
                return [array get row]
            } else {
                return $row($parm)
            }
        }

        return ""
    }

    # roletype curse_id role
    #
    # curse_id   - The ID of a CURSE
    # role       - A role in the CURSE
    #
    # This method returns the roletype given the curse_id and a role
    # for a particular curse. The most restrictive role is what is
    # returned since a role can appear in multiple injects.

    typemethod roletype {curse_id role} {
        # FIRST, initialize roletype
        set roletype ""

        # NEXT, go through all the injects associated with
        # this CURSE and figure out the most restrictive type of
        # role from the set of injects
        rdb eval {
            SELECT * FROM curse_injects
            WHERE curse_id=$curse_id
        } data {
            switch -exact -- $data(inject_type) {
                COOP {
                    # COOP is most restrictive, we are done
                    if {$data(f) eq $role} {
                        set roletype "CIVGROUPS"
                        break
                    }

                    if {$data(g) eq $role} {
                        set roletype "FRCGROUPS"
                        break
                    }
                }

                SAT {
                    # SAT is most restrictive, we are done
                    if {$data(g) eq $role} {
                        set roletype "CIVGROUPS"
                        break
                    }
                }

                HREL {
                    # HREL is least restricive, continue to next inject
                    if {$data(g) eq $role || $data(f) eq $role} {
                        set roletype "GROUPS"
                        continue
                    }
                }

                VREL {
                    # VREL: g is least restrictive, continue on, a is
                    # most restrictive, since it's the only roletype for
                    # actors 
                    if {$data(a) eq $role} {
                        set roletype "ACTORS"
                        break
                    }

                    if {$data(g) eq $role} {
                        set roletype "GROUPS"
                        continue
                    }
                }

                default {
                    error "Unrecognized inject_type: $data(inject_type)"
                }
            }
        }

        return $roletype
    }

    # rolenames itype col
    #
    # itype    - inject type: HREL, VREL, SAT or COOP
    # col      - the column in the curse_injects for which valid roles
    #            can be made available
    #
    # This method returns the list of roles that can possibly be assigned
    # to a particular CURSE role given the inject type. Restriction 
    # of exactly which groups can be assigned to a role takes place when 
    # the CURSE tactic is created.

    typemethod rolenames {itype col curse_id} {
        switch -exact -- $itype {
            HREL {
                # HREL: f and g can be any group role and not actor roles
                set roles [rdb eval {
                    SELECT DISTINCT f FROM curse_injects
                    WHERE f != ''
                    AND curse_id=$curse_id
                }]

                lmerge roles  [rdb eval {
                    SELECT DISTINCT g FROM curse_injects
                    WHERE g != ''
                    AND curse_id=$curse_id
                }]

            }

            SAT {
            # SAT: Only roles that could possibly contain
            # civilians
                set roles [rdb eval {
                    SELECT DISTINCT g FROM curse_injects
                    WHERE g != ''
                    AND curse_id=$curse_id
                    AND inject_type IN ('HREL','VREL','SAT')
                }]

                lmerge roles [rdb eval {
                    SELECT DISTINCT f FROM curse_injects
                    WHERE f != ''
                    AND curse_id=$curse_id
                    AND inject_type IN ('HREL','COOP')
                }]

                # It's possible that HREL and/or VREL injects
                # contain roles that are defined as FRC roles
                # only in COOP injects, we need to prune them.
                set frcroles \
                    [rdb eval {
                        SELECT DISTINCT g FROM curse_injects
                        WHERE inject_type = 'COOP'
                    }]

                foreach frc $frcroles {
                    ldelete roles $frc
                }
            }

            COOP {
            # COOP: For "f" only roles that could possibly contain
            # civilians, for "g" only roles that could possibly
            # contain forces
                if {$col eq "f"} {
                    set roles [rdb eval {
                        SELECT DISTINCT f FROM curse_injects
                        WHERE f != '' 
                        AND curse_id=$curse_id
                        AND inject_type IN ('HREL','COOP')
                    }]

                    lmerge roles [rdb eval {
                        SELECT DISTINCT g FROM curse_injects
                        WHERE g != ''
                        AND curse_id=$curse_id
                        AND inject_type IN ('HREL','VREL','SAT')
                    }]

                    # It's possible that HREL and/or VREL injects
                    # contain roles that are defined as FRC roles
                    # only in COOP injects, we need to prune them.
                    set frcroles \
                        [rdb eval {
                            SELECT DISTINCT g FROM curse_injects
                            WHERE inject_type = 'COOP'
                        }]

                    foreach frc $frcroles {
                        ldelete roles $frc
                    }
                } elseif {$col eq "g"} {
                    set roles [rdb eval {
                        SELECT DISTINCT f FROM curse_injects
                        WHERE f != ''
                        AND curse_id=$curse_id
                        AND inject_type IN ('HREL')
                    }]

                    lmerge roles [rdb eval {
                        SELECT DISTINCT g FROM curse_injects
                        WHERE g != ''
                        AND curse_id=$curse_id
                        AND inject_type IN ('HREL','VREL','COOP')
                    }]

                    # It's possible that HREL and/or VREL injects
                    # contain roles that are defined as CIV roles
                    # only in COOP injects, we need to prune them.
                    # Note: don't need to worry about SAT injects
                    # since we never grabbed them.
                    set civroles \
                        [rdb eval {
                            SELECT DISTINCT f FROM curse_injects
                            WHERE inject_type = 'COOP'
                        }]

                    foreach civ $civroles {
                        ldelete roles $civ
                    }
                }
            }

            VREL {
            # VREL: If col is 'a' then any actor role, if 'g' then
            # any group role
                if {$col eq "a"} {
                    set roles [rdb eval {
                        SELECT DISTINCT a FROM curse_injects
                        WHERE a != ''
                        AND curse_id=$curse_id
                    }]
                } elseif {$col eq "g"} {
                    set roles [rdb eval {
                        SELECT DISTINCT g FROM curse_injects
                        WHERE g != ''
                        AND curse_id=$curse_id
                    }]

                    lmerge roles [rdb eval {
                        SELECT DISTINCT f FROM curse_injects
                        WHERE f != ''
                        AND curse_id=$curse_id
                    }]
                }
            }
        }

        return $roles
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
    # parmdict     A dictionary of inject parms
    #
    #    inject_type   The inject type
    #    curse_id      The inject's owning CURSE
    #    a             Actor role name, or ""
    #    c             A Concern, or ""
    #    f             Group role name, or ""
    #    g             Group role name, or ""
    #    mode          transient or persistent
    #    mag           numeric qmag(n) value, or ""
    #
    # Creates an inject given the parms, which are presumed to be
    # valid.

    typemethod {mutate create} {parmdict} {
        # FIRST, make sure the parm dict is complete
        set parmdict [dict merge $optParms $parmdict]

        # NEXT, compute the narrative string.
        set narrative [$type call narrative $parmdict]

        # NEXT, put the inject in the database.
        dict with parmdict {
            # FIRST, get the inject number for this CURSE.
            rdb eval {
                SELECT coalesce(max(inject_num)+1,1) AS inject_num
                FROM curse_injects
                WHERE curse_id=$curse_id
            } {}

            # NEXT, Put the inject in the database
            rdb eval {
                INSERT INTO 
                curse_injects(curse_id, inject_num, inject_type,
                         mode, narrative,
                         a,
                         c,
                         f,
                         g,
                         mag)
                VALUES($curse_id, $inject_num, $inject_type,
                       $mode, $narrative,
                       nullif($a,   ''),
                       nullif($c,   ''),
                       nullif($f,   ''),
                       nullif($g,   ''),
                       nullif($mag, ''));
            }

            # NEXT, Return undo command.
            return [list rdb delete curse_injects \
                "curse_id='$curse_id' AND inject_num=$inject_num"]
        }
    }

    # mutate delete id
    #
    # id     a inject ID, {curse_id inject_num}
    #
    # Deletes the inject.  Note that deleting an inject leaves a 
    # gap in the priority order, but doesn't change the order of
    # the remaining injects; hence, we don't need to worry about it.

    typemethod {mutate delete} {id} {
        lassign $id curse_id inject_num

        # FIRST, get the undo information
        set data [rdb delete -grab curse_injects \
            {curse_id=$curse_id AND inject_num=$inject_num}]

        # NEXT, Return the undo script
        return [list rdb ungrab $data]
    }

    # mutate update parmdict
    #
    # parmdict     A dictionary of inject parms
    #
    #    id         The inject ID, {curse_id inject_num}
    #    a          Actor role name, or ""
    #    c          A Concern, or ""
    #    f          Group role name, or ""
    #    g          Group role name, or ""
    #    mode       transient or persistent
    #    mag        Numeric qmag(n) value, or ""
    #
    # Updates an inject given the parms, which are presumed to be
    # valid.  Note that you can't change the injects's CURSE or
    # type, and the state is set by a different mutator.

    typemethod {mutate update} {parmdict} {
        # FIRST, make sure the parm dict is complete
        set parmdict [dict merge $optParms $parmdict]

        # NEXT, save the changed data.
        dict with parmdict {
            lassign $id curse_id inject_num

            # FIRST, get the undo information
            set data [rdb grab curse_injects \
                {curse_id=$curse_id AND inject_num=$inject_num}]

            # NEXT, Update the inject.  The nullif(nonempty()) pattern
            # is so that the old value of the column will be used
            # if the input is empty, and that empty columns will be
            # NULL rather than "".
            rdb eval {
                UPDATE curse_injects 
                SET a    = nullif(nonempty($a, a), ''),
                    c    = nullif(nonempty($c, c), ''),
                    f    = nullif(nonempty($f, f), ''),
                    g    = nullif(nonempty($g, g), ''),
                    mode = nullif(nonempty($mode, mode), ''),
                    mag  = nullif(nonempty($mag,   mag), '')
                WHERE curse_id=$curse_id AND inject_num=$inject_num
            } {}

            # NEXT, compute and set the narrative
            set pdict [$type get $id]
            set narrative [$type call narrative $pdict]

            rdb eval {
                UPDATE curse_injects
                SET    narrative = $narrative
                WHERE curse_id=$curse_id AND inject_num=$inject_num
            }

            # NEXT, Return the undo command
            return [list rdb ungrab $data]
        }
    }

    # mutate state id state
    #
    # id     - The inject's ID, {curse_id inject_num}
    # state  - The injects's new einject_state
    #
    # Updates an inject's state.

    typemethod {mutate state} {id state} {
        lassign $id curse_id inject_num

        # FIRST, get the undo information
        set data [rdb grab curse_injects \
            {curse_id=$curse_id AND inject_num=$inject_num}]

        # NEXT, Update the inject.
        rdb eval {
            UPDATE curse_injects
            SET state = $state
            WHERE curse_id=$curse_id AND inject_num=$inject_num
        }

        # NEXT, Return the undo command
        return [list rdb ungrab $data]
    }

    #-------------------------------------------------------------------
    # inject Ensemble Interface

    # call op pdict ?args...?
    #
    # op    - One of the inject type subcommands
    # idict - An inject parameter dictionary
    #
    # This is a convenience command that calls the relevant subcommand
    # for the inject.

    typemethod call {op idict args} {
        [dict get $idict inject_type] $op $idict {*}$args
    }

    #-------------------------------------------------------------------
    # Order Helpers

    # RequireType inject_type id
    #
    # inject_type  - The desired inject_type
    # id           - An inject id, {curse_id inject_num}
    #
    # Throws an error if the inject doesn't have the desired type.

    typemethod RequireType {inject_type id} {
        lassign $id curse_id inject_num
        
        if {[rdb onecolumn {
            SELECT inject_type FROM curse_injects 
            WHERE curse_id=$curse_id AND inject_num=$inject_num
        }] ne $inject_type} {
            return -code error -errorcode INVALID \
                "CURSE inject \"$id\" is not a $inject_type inject"
        }
    }
}


#-----------------------------------------------------------------------
# Orders: INJECT:*

# INJECT:DELETE
#
# Deletes an existing inject, of whatever type.

order define INJECT:DELETE {
    # This order dialog isn't usually used.

    title "Delete Inject"
    options -sendstates {PREP PAUSED}

    form {
        rcc "Inject ID:" -for id
        inject id -context yes
    }
} {
    # FIRST, prepare the parameters
    prepare id -toupper -required -type inject

    returnOnError -final

    # NEXT, Delete the inject and dependent entities
    setundo [inject mutate delete $parms(id)]
}

# INJECT:STATE
#
# Sets a injects's state.  Note that this order isn't intended
# for use with a dialog.

order define INJECT:STATE {
    title "Set Inject State"

    options -sendstates {PREP PAUSED}

    form {
        rcc "Inject ID:" -for id
        inject id -context yes

        rcc "State:" -for state
        text state
    }
} {
    # FIRST, prepare and validate the parameters
    prepare id     -required          -type inject
    prepare state  -required -tolower -type einject_state

    returnOnError -final

    setundo [inject mutate state $parms(id) $parms(state)]
}

