#-----------------------------------------------------------------------
# TITLE:
#    inject.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena(n): Curse Inject Manager
#
#    This module is responsible for managing CURSE injects and operations
#    upon them. There are four inject types that are managed by this
#    module: COOP, HREL, SAT and VREL
#
#    Injects are handled in the following ways:
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
#    * scenario(n) defines a view for each inject type,
#      injects_<type>.
#
# PARAMETER MAPPING:
#
#  COOP Injects:    HREL Injects:  SAT Injects:   VREL Injects:
#    f    <= f        f   <= f       g   <= g       g   <= g
#    g    <= g        g   <= g       c   <= c       a   <= a
#    mag  <= mag      mag <= mag     mag <= mag     mag <= mag
# 
# TBD:
#    * Global entities in use: curse
#
#-----------------------------------------------------------------------

snit::type ::athena::inject {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) Instance

    # optParms: This variable is a dictionary of all optional parameters
    # with empty values.  The create and update mutators can merge the
    # input parmdict with this to get a parmdict with the full set of
    # parameters.

    variable optParms {
        mag  ""
        mode ""
        a    ""
        c    ""
        f    ""
        g    ""
    }

    # tinfo array: Type Info
    #
    # names         - List of the names of the inject types.

    variable tinfo -array {
        names {COOP HREL SAT VREL}
    }

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of this type.

    constructor {adb_} {
        set adb $adb_
    }

    # type names
    #
    # Returns the inject type names.
    
    method {type names} {} {
        return [lsort $tinfo(names)]
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

    method checker {{ht ""}} {
        set edict [$self DoSanityCheck]

        if {[dict size $edict] == 0} {
            return OK
        }

        if {$ht ne ""} {
            $self DoSanityReport $ht $edict
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

    method DoSanityCheck {} {
        # FIRST, create the empty error dictionary.
        set edict [dict create]

        # NEXT, clear the invalid states, since we're going to 
        # recompute them.

        $adb eval {
            UPDATE curse_injects
            SET state = 'normal'
            WHERE state = 'invalid';
        }

        # NEXT, identify the invalid injects.
        set badlist [list]

        $adb eval {
            SELECT * FROM curse_injects
        } row {
            set itype [string tolower $row(inject_type)]
            set result [$self $itype check [array get row]]

            if {$result ne ""} {
                dict set edict $row(curse_id) $row(inject_num) $result
                lappend badlist $row(curse_id) $row(inject_num)
            }
        }

        # NEXT, mark the bad injects invalid.
        foreach {curse_id inject_num} $badlist {
            $adb eval {
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

    method DoSanityReport {ht edict} {

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
            array set cdata [$adb curse get $curse_id]

            $ht putln "<b>CURSE $curse_id: $cdata(longname)</b>"
            $ht ul

            dict for {inject_num errmsg} $cdict {
                set idict [$self get [list $curse_id $inject_num]]

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

    method validate {id} {
        lassign $id curse_id inject_num

        $adb curse validate $curse_id

        if {![$self exists $id]} {
            set nums [$adb eval {
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

    method {role validate} {curse_id role_id} {
        # FIRST, get all roles defined for the CURSE
        set validroles [$self AllRoles $curse_id]

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
    # CURSE with the supplied curse_id. It is a helper method for
    # role validation.

    method AllRoles {curse_id} {
        set rnames {}
        $adb eval {
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

    method exists {id} {
        lassign $id curse_id inject_num

        return [$adb exists {
            SELECT * FROM curse_injects
            WHERE curse_id=$curse_id AND inject_num=$inject_num
        }]
    }

    # role exists
    #
    # role   - The name of role
    #
    # Returns 1 if the role already exists, and 0 otherwise

    method {role exists} {role} {
        set roles [$adb eval {
            SELECT DISTINCT f FROM curse_injects
            WHERE f != ''
        }]

        lmerge roles  [$adb eval {
            SELECT DISTINCT g FROM curse_injects
            WHERE g != ''
        }]

        lmerge roles  [$adb eval {
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

    method get {id {parm ""}} {
        lassign $id curse_id inject_num

        # FIRST, get the data
        $adb eval {
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

    method roletype {curse_id role} {
        # FIRST, initialize roletype
        set roletype ""

        # NEXT, go through all the injects associated with
        # this CURSE and figure out the most restrictive type of
        # role from the set of injects
        $adb eval {
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

    method rolenames {itype col curse_id} {
        switch -exact -- $itype {
            HREL {
                # HREL: f and g can be any group role and not actor roles
                set roles [$adb eval {
                    SELECT DISTINCT f FROM curse_injects
                    WHERE f != ''
                    AND curse_id=$curse_id
                }]

                lmerge roles  [$adb eval {
                    SELECT DISTINCT g FROM curse_injects
                    WHERE g != ''
                    AND curse_id=$curse_id
                }]

            }

            SAT {
            # SAT: Only roles that could possibly contain
            # civilians
                set roles [$adb eval {
                    SELECT DISTINCT g FROM curse_injects
                    WHERE g != ''
                    AND curse_id=$curse_id
                    AND inject_type IN ('HREL','VREL','SAT')
                }]

                lmerge roles [$adb eval {
                    SELECT DISTINCT f FROM curse_injects
                    WHERE f != ''
                    AND curse_id=$curse_id
                    AND inject_type IN ('HREL','COOP')
                }]

                # It's possible that HREL and/or VREL injects
                # contain roles that are defined as FRC roles
                # only in COOP injects, we need to prune them.
                set frcroles \
                    [$adb eval {
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
                    set roles [$adb eval {
                        SELECT DISTINCT f FROM curse_injects
                        WHERE f != '' 
                        AND curse_id=$curse_id
                        AND inject_type IN ('HREL','COOP')
                    }]

                    lmerge roles [$adb eval {
                        SELECT DISTINCT g FROM curse_injects
                        WHERE g != ''
                        AND curse_id=$curse_id
                        AND inject_type IN ('HREL','VREL','SAT')
                    }]

                    # It's possible that HREL and/or VREL injects
                    # contain roles that are defined as FRC roles
                    # only in COOP injects, we need to prune them.
                    set frcroles \
                        [$adb eval {
                            SELECT DISTINCT g FROM curse_injects
                            WHERE inject_type = 'COOP'
                        }]

                    foreach frc $frcroles {
                        ldelete roles $frc
                    }
                } elseif {$col eq "g"} {
                    set roles [$adb eval {
                        SELECT DISTINCT f FROM curse_injects
                        WHERE f != ''
                        AND curse_id=$curse_id
                        AND inject_type IN ('HREL')
                    }]

                    lmerge roles [$adb eval {
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
                        [$adb eval {
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
                    set roles [$adb eval {
                        SELECT DISTINCT a FROM curse_injects
                        WHERE a != ''
                        AND curse_id=$curse_id
                    }]
                } elseif {$col eq "g"} {
                    set roles [$adb eval {
                        SELECT DISTINCT g FROM curse_injects
                        WHERE g != ''
                        AND curse_id=$curse_id
                    }]

                    lmerge roles [$adb eval {
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

    # create parmdict
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

    method create {parmdict} {
        # FIRST, make sure the parm dict is complete
        set parmdict [dict merge $optParms $parmdict]

        # NEXT, compute the narrative string.
        set itype [string tolower [dict get $parmdict inject_type]]
        set narrative [$self $itype narrative $parmdict]

        # NEXT, put the inject in the database.
        dict with parmdict {
            # FIRST, get the inject number for this CURSE.
            $adb eval {
                SELECT coalesce(max(inject_num)+1,1) AS inject_num
                FROM curse_injects
                WHERE curse_id=$curse_id
            } {}

            # NEXT, Put the inject in the database
            $adb eval {
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
            return [list $adb delete curse_injects \
                "curse_id='$curse_id' AND inject_num=$inject_num"]
        }
    }

    # delete id
    #
    # id     a inject ID, {curse_id inject_num}
    #
    # Deletes the inject.  Note that deleting an inject leaves a 
    # gap in the priority order, but doesn't change the order of
    # the remaining injects; hence, we don't need to worry about it.

    method delete {id} {
        lassign $id curse_id inject_num

        # FIRST, get the undo information
        set data [$adb delete -grab curse_injects \
            {curse_id=$curse_id AND inject_num=$inject_num}]

        # NEXT, Return the undo script
        return [list $adb ungrab $data]
    }

    # update parmdict
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

    method update {parmdict} {
        # FIRST, make sure the parm dict is complete
        set parmdict [dict merge $optParms $parmdict]

        # NEXT, save the changed data.
        dict with parmdict {
            lassign $id curse_id inject_num

            # FIRST, get the undo information
            set data [$adb grab curse_injects \
                {curse_id=$curse_id AND inject_num=$inject_num}]

            # NEXT, Update the inject.  The nullif(nonempty()) pattern
            # is so that the old value of the column will be used
            # if the input is empty, and that empty columns will be
            # NULL rather than "".
            $adb eval {
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
            set pdict [$self get $id]
            set itype [string tolower [dict get $pdict inject_type]]
            set narrative [$self $itype narrative $pdict]

            $adb eval {
                UPDATE curse_injects
                SET    narrative = $narrative
                WHERE curse_id=$curse_id AND inject_num=$inject_num
            }

            # NEXT, Return the undo command
            return [list $adb ungrab $data]
        }
    }

    # state id state
    #
    # id     - The inject's ID, {curse_id inject_num}
    # state  - The injects's new einject_state
    #
    # Updates an inject's state.

    method state {id state} {
        lassign $id curse_id inject_num

        # FIRST, get the undo information
        set data [$adb grab curse_injects \
            {curse_id=$curse_id AND inject_num=$inject_num}]

        # NEXT, Update the inject.
        $adb eval {
            UPDATE curse_injects
            SET state = $state
            WHERE curse_id=$curse_id AND inject_num=$inject_num
        }

        # NEXT, Return the undo command
        return [list $adb ungrab $data]
    }

    #-------------------------------------------------------------------
    # Order Helpers

    # RequireType inject_type id
    #
    # inject_type  - The desired inject_type
    # id           - An inject id, {curse_id inject_num}
    #
    # Throws an error if the inject doesn't have the desired type.

    method RequireType {inject_type id} {
        lassign $id curse_id inject_num
        
        if {[$adb onecolumn {
            SELECT inject_type FROM curse_injects 
            WHERE curse_id=$curse_id AND inject_num=$inject_num
        }] ne $inject_type} {
            return -code error -errorcode INVALID \
                "CURSE inject \"$id\" is not a $inject_type inject"
        }
    }

    #-------------------------------------------------------------------
    # COOP

    method {coop narrative} {pdict} {
        dict with pdict {
            set points [format "%.1f" $mag]
            set symbol [qmag name $mag]
            return "Change cooperation of civilians in $f with forces in $g by $points points ($symbol)."
        }
    }

    method {coop check} {pdict} {
        set errors [list]

        dict with pdict {}

        # FIRST, 'f' must be a CIVGROUPS role
        set rtype [$self roletype $curse_id $f]
        
        if {$rtype ne "CIVGROUPS"} {
            lappend errors \
                "Role $f is $rtype role, must be CIVGROUPS role."
        }

        # NEXT, 'g' must be a FRCGROUPS role
        set rtype [$self roletype $curse_id $g]

        if {$rtype ne "FRCGROUPS"} {
            lappend errors \
                "Role $g is $rtype role, must be FRCGROUPS role."
        }

        return [join $errors "  "]
    }

    #-------------------------------------------------------------------
    # HREL

    method {hrel narrative} {pdict} {
        dict with pdict {
            set points [format "%.1f" $mag]
            set symbol [qmag name $mag]
            return "Change horizontal relationships of groups in $f with groups in $g by $points points ($symbol)."
        }
    }

    method {hrel check} {pdict} {
        set errors [list]

        dict with pdict {}

        set rtype [$self roletype $curse_id $g]

        # FIRST, 'g' must be a GROUPS role
        if {$rtype eq "ACTORS"} {
            lappend errors \
                "Role $g is ACTORS role, must be GROUPS role."
        }

        set rtype [$self roletype $curse_id $f]

        # NEXT, 'f' must alos be a GROUPS role
        if {$rtype eq "ACTORS"} {
            lappend errors \
                "Role $f is ACTORS role, must be GROUPS role."
        }

        return [join $errors "  "]
    }

    #-------------------------------------------------------------------
    # SAT

    method {sat narrative} {pdict} {
        dict with pdict {
            set points [format "%.1f" $mag]
            set symbol [qmag name $mag]
            return "Change satisfaction of civilians in $g with $c by $points points ($symbol)."
        }
    }

    method {sat check} {pdict} {
        set errors [list]

        dict with pdict {}

        # FIRST, only CIVGROUPS role can appear in this inject
        set rtype [$self roletype $curse_id $g]

        if {$rtype ne "CIVGROUPS"} {
            lappend errors \
                "Role $g is $rtype role, must be a CIVGROUPS role."
        }

        return [join $errors "  "]
    }

    #-------------------------------------------------------------------
    # VREL

    method {vrel narrative} {pdict} {
        dict with pdict {
            set points [format "%.1f" $mag]
            set symbol [qmag name $mag]
            return "Change vertical relationships of groups in role $g with actors in role $a by $points points ($symbol)."
        }
    }

    method {vrel check} {pdict} {
        set errors [list]

        dict with pdict {}

        set rtype [$self roletype $curse_id $a]

        # FIRST, 'a' must me an ACTORS role
        if {$rtype ne "ACTORS"} {
            lappend errors \
                "Role $a is $rtype role, must be an ACTORS role."
        }

        set rtype [$self roletype $curse_id $g]

        # NEXT, 'g' must be a GROUPS role
        if {$rtype eq "ACTORS"} {
            lappend errors \
                "Role $g is ACTORS role, must be GROUPS role."
        }

        return [join $errors "  "]
    }
}

#-----------------------------------------------------------------------
# Orders: INJECT:*

# INJECT:DELETE
#
# Deletes an existing inject, of whatever type.

::athena::orders define INJECT:DELETE {
    # This order dialog isn't usually used.

    meta title "Delete Inject"
    meta sendstates {PREP PAUSED}

    meta parmlist {id}

    meta form {
        rcc "Inject ID:" -for id
        inject id -context yes
    }


    method _validate {} {
        my prepare id -toupper -required -type inject
    }

    method _execute {{flunky ""}} {
        my setundo [$adb inject delete $parms(id)]
    }
}

# INJECT:STATE
#
# Sets a injects's state.  Note that this order isn't intended
# for use with a dialog.

::athena::orders define INJECT:STATE {
    meta title "Set Inject State"

    meta sendstates {PREP PAUSED}

    meta parmlist {id state}

    meta form {
        rcc "Inject ID:" -for id
        inject id -context yes

        rcc "State:" -for state
        text state
    }


    method _validate {} {
        my prepare id     -required          -type inject
        my prepare state  -required -tolower -type einject_state
    }

    method _execute {{flunky ""}} {
        my setundo [$adb inject state $parms(id) $parms(state)]
    }
}


# INJECT:COOP:CREATE
#
# Creates a new COOP inject.

::athena::orders define INJECT:COOP:CREATE {
    meta title "Create Inject: Cooperation"

    meta sendstates PREP

    meta parmlist {
        curse_id
        longname
        {mode transient}
        {ftype NEW}
        f
        {gtype NEW}
        g
        mag
    }

    meta form {
        rcc "CURSE ID:" -for curse_id
        text curse_id -context yes

        rcc "Description:" -for longname -span 4
        disp longname -width 60

        rcc "Mode:" -for mode -span 4
        enumlong mode -dictcmd {einputmode deflist} -defvalue transient

        rcc "Of Civ Group Role:" -for f
        selector ftype -defvalue "NEW" {
            case NEW "Define new role" {
                cc "Role:" -for f
                label "@"
                text f
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for f
                enum f -listcmd {$adb_ inject rolenames COOP f $curse_id}
            }
        }

        rcc "With Force Group Role:" -for g
        selector gtype -defvalue "NEW" {
            case NEW "Define new role" {
                cc "Role:" -for g
                label "@"
                text g
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for g
                enum g -listcmd {$adb_ inject rolenames COOP g $curse_id}
            }
        }

        rcc "Magnitude:" -for mag -span 4
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare curse_id -toupper  -required -type curse
        my prepare mode     -tolower  -required -type einputmode
        my prepare ftype    -toupper  -required -selector
        my prepare gtype    -toupper  -required -selector
        my prepare f        -toupper  -required -type roleid
        my prepare g        -toupper  -required -type roleid
        my prepare mag -num -toupper  -required -type qmag
    
        my checkon g {
            if {$parms(f) eq $parms(g)} {
                my reject g "Inject requires two distinct roles"
            }
        }
    }

    method _execute {{flunky ""}} {
        set parms(inject_type) COOP
    
        my setundo [$adb inject create [array get parms]]
    }
}

# INJECT:COOP:UPDATE
#
# Updates existing COOP inject.

::athena::orders define INJECT:COOP:UPDATE {
    meta title "Update Inject: Cooperation"
    meta sendstates PREP

    meta parmlist {
        id
        longname
        mode
        {ftype EXISTING}
        f
        {gtype EXISTING}
        g
        mag
    }

    meta form {
        rcc "Inject:" -for id
        dbkey id -context yes -table gui_injects_COOP \
            -keys {curse_id inject_num} \
            -loadcmd {$order_ keyload id {f g mag mode}}

        rcc "Description:" -for longname -span 4
        disp longname -width 60

        rcc "Mode:" -for mode -span 4
        enumlong mode -dictcmd {einputmode deflist}

        rcc "Of Civ Group Role:" -for f
        selector ftype -defvalue "EXISTING" {
            case NEW "Rename role" {
                cc "Role:" -for f
                label "@"
                text f
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for f
                enum f -listcmd {$adb_ inject rolenames COOP f [lindex $id 0]}
            }
        }

        rcc "With Force Group Role:" -for g
        selector gtype -defvalue "EXISTING" {
            case NEW "Rename role" {
                cc "Role:" -for g
                label "@"
                text g
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for g
                enum g -listcmd {$adb_ inject rolenames COOP g [lindex $id 0]}
            }
        }

        rcc "Magnitude:" -for mag -span 4
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare id  -required           -type inject
        my prepare mode          -tolower  -type einputmode
        my prepare ftype         -toupper  -selector
        my prepare gtype         -toupper  -selector
        my prepare f             -toupper  -type roleid
        my prepare g             -toupper  -type roleid
        my prepare mag -num      -toupper  -type qmag
    
        my checkon g {
            if {$parms(f) eq $parms(g)} {
                my reject g "Inject requires two distinct roles"
            }
        }
    }

    method _execute {{flunky ""}} {
        my setundo [$adb inject update [array get parms]]
    }
}

# INJECT:HREL:CREATE
#
# Creates a new HREL inject.

::athena::orders define INJECT:HREL:CREATE {
    meta title "Create Inject: Horizontal Relationship"

    meta sendstates PREP

    meta parmlist {
        curse_id
        longname
        {mode transient}
        {ftype NEW}
        f
        {gtype NEW}
        g
        mag
    }

    meta form {
        rcc "CURSE ID:" -for curse_id 
        text curse_id -context yes

        rcc "Description:" -for longname -span 4
        disp longname -width 60

        rcc "Mode:" -for mode -span 4
        enumlong mode -dictcmd {einputmode deflist} -defvalue transient

        rcc "Of Group Role:" -for ftype
        selector ftype -defvalue "NEW" {
            case NEW "Define new role" {
                cc "Role:" -for f
                label "@"
                text f
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for f
                enum f -listcmd {$adb_ inject rolenames HREL f $curse_id}
            }
        }

        rcc "With Group Role:" -for gtype 
        selector gtype -defvalue "NEW" {
            case NEW "Define new role" {
                cc "Role:" -for g
                label "@"
                text g
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for g
                enum g -listcmd {$adb_ inject rolenames HREL g $curse_id}
            }
        }

        rcc "Magnitude:" -for mag -span 4
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare curse_id -toupper   -required -type curse
        my prepare mode     -tolower   -required -type einputmode
        my prepare ftype    -toupper   -required -selector
        my prepare gtype    -toupper   -required -selector
        my prepare f        -toupper   -required -type roleid
        my prepare g        -toupper   -required -type roleid
        my prepare mag -num -toupper   -required -type qmag
    
        my checkon g {
            if {$parms(f) eq $parms(g)} {
                my reject g "Inject requires two distinct roles"
            }
        }
    }

    method _execute {{flunky ""}} {
        set parms(inject_type) HREL
        my setundo [$adb inject create [array get parms]]
    }
}

# INJECT:HREL:UPDATE
#
# Updates existing HREL inject.

::athena::orders define INJECT:HREL:UPDATE {
    meta title "Update Inject: Horizontal Relationship"
    meta sendstates PREP 

    meta parmlist {
        id
        longname
        mode
        {ftype EXISTING}
        f
        {gtype EXISTING}
        g
        mag
    }

    meta form {
        rcc "Inject:" -for id
        dbkey id -context yes -table gui_injects_HREL \
            -keys {curse_id inject_num} \
            -loadcmd {$order_ keyload id {f g mag mode}}

        rcc "Description:" -for longname -span 4
        disp longname -width 60

        rcc "Mode:" -for mode -span 4
        enumlong mode -dictcmd {einputmode deflist}

        rcc "Of Group Role:" -for f
        selector ftype -defvalue "EXISTING" {
            case NEW "Rename role" {
                cc "Role:" -for f
                label "@"
                text f
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for f
                enum f -listcmd {$adb_ inject rolenames HREL f [lindex $id 0]}
            }
        }

        rcc "With Group Role:" -for g 
        selector gtype -defvalue "EXISTING" {
            case NEW "Rename role" {
                cc "Role:" -for g
                label "@"
                text g
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for g
                enum g -listcmd {$adb_ inject rolenames HREL g [lindex $id 0]}
            }
        }

        rcc "Magnitude:" -for mag -span 4
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare id         -required -type inject
        my prepare mode       -tolower  -type einputmode
        my prepare ftype      -toupper  -selector
        my prepare gtype      -toupper  -selector
        my prepare f          -toupper  -type roleid
        my prepare g          -toupper  -type roleid
        my prepare mag   -num -toupper  -type qmag
    
        my checkon g {
            if {$parms(f) eq $parms(g)} {
                my reject g "Inject requires two distinct roles"
            }
        }
    }

    method _execute {{flunky ""}} {
        my setundo [$adb inject update [array get parms]]
    }
}

# INJECT:SAT:CREATE
#
# Creates a new SAT inject.

::athena::orders define INJECT:SAT:CREATE {
    meta title "Create Inject: Satisfaction"

    meta sendstates PREP

    meta parmlist {
        curse_id
        longname
        {mode transient}
        {gtype NEW}
        g
        c
        mag
    }

    meta form {
        rcc "CURSE ID:" -for curse_id
        text curse_id -context yes

        rcc "Description:" -for longname -span 4
        disp longname -width 60

        rcc "Mode:" -for mode -span 4
        enumlong mode -dictcmd {einputmode deflist} -defvalue transient

        rcc "Civ Group Role:" -for gtype
        selector gtype -defvalue "NEW" {
            case NEW "Define new role" {
                cc "Role:" -for g
                label "@"
                text g
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for g
                enum g -listcmd {$adb_ inject rolenames SAT g $curse_id}
            }
        }

        rcc "With:" -for c -span 4
        concern c 

        rcc "Magnitude:" -for mag -span 4
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare curse_id   -toupper   -required -type curse
        my prepare mode       -tolower   -required -type einputmode
        my prepare gtype      -toupper   -required -selector
        my prepare g          -toupper   -required -type roleid
        my prepare c          -toupper   -required -type econcern
        my prepare mag -num   -toupper   -required -type qmag
    }

    method _execute {{flunky ""}} {
        set parms(inject_type) SAT
        my setundo [$adb inject create [array get parms]]
    }
}

# INJECT:SAT:UPDATE
#
# Updates existing SAT inject.

::athena::orders define INJECT:SAT:UPDATE {
    meta title "Update Inject: Satisfaction"
    meta sendstates PREP 

    meta parmlist {
        id
        longname
        mode
        {gtype EXISTING}
        g
        c
        mag
    }

    meta form {
        rcc "Inject:" -for id
        dbkey id -context yes -table gui_injects_SAT \
            -keys {curse_id inject_num} \
            -loadcmd {$order_ keyload id {g c mode mag}}

        rcc "Description:" -for longname -span 4
        disp longname -width 60

        rcc "Mode:" -for mode -span 4
        enumlong mode -dictcmd {einputmode deflist} 

        rcc "Civ Group Role:" -for rtype
        selector gtype -defvalue "EXISTING" {
            case NEW "Rename role" {
                cc "Role:" -for g
                label "@"
                text g
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for g
                enum g -listcmd {$adb_ inject rolenames SAT g [lindex $id 0]}
            }
        }

        rcc "With:" -for c -span 4
        concern c

        rcc "Magnitude:" -for mag -span 4
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare id    -required           -type  inject
        my prepare mode            -tolower  -type  einputmode
        my prepare gtype           -toupper  -selector
        my prepare g               -toupper  -type  roleid
        my prepare c               -toupper  -type  econcern
        my prepare mag   -num      -toupper  -type  qmag
    }

    method _execute {{flunky ""}} {
        my setundo [$adb inject update [array get parms]]
    }
}

# INJECT:VREL:CREATE
#
# Creates a new VREL inject.

::athena::orders define INJECT:VREL:CREATE {
    meta title "Create Inject: Vertical Relationship"

    meta sendstates PREP

    meta parmlist {
        curse_id
        longname
        {mode transient}
        {gtype NEW}
        g
        {atype NEW}
        a
        mag
    }

    meta form {
        rcc "CURSE ID:" -for curse_id
        text curse_id -context yes

        rcc "Description:" -for longname -span 4
        disp longname -width 60

        rcc "Mode:" -for mode -span 4
        enumlong mode -dictcmd {einputmode deflist} -defvalue transient

        rcc "Of Group Role:" -for g 
        selector gtype -defvalue "NEW" {
            case NEW "Define new role" {
                cc "Role:" -for g
                label "@"
                text g
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for g
                enum g -listcmd {$adb_ inject rolenames VREL g $curse_id}
            }
        }

        rcc "With Actor Role:" -for a
        selector atype -defvalue "NEW" {
            case NEW "Define new role" {
                cc "Role:" -for a
                label "@"
                text a
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for a
                enum a -listcmd {$adb_ inject rolenames VREL a $curse_id}
            }
        }

        rcc "Magnitude:" -for mag -span 4
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare curse_id -toupper   -required -type curse
        my prepare mode     -tolower   -required -type einputmode
        my prepare gtype    -toupper   -required -selector
        my prepare atype    -toupper   -required -selector
        my prepare g        -toupper   -required -type roleid
        my prepare a        -toupper   -required -type roleid
        my prepare mag -num -toupper   -required -type qmag
     
        my checkon a {
            if {$parms(g) eq $parms(a)} {
                my reject a "Inject requires two distinct roles"
            }
        }
    }

    method _execute {{flunky ""}} {
        set parms(inject_type) VREL
        my setundo [$adb inject create [array get parms]]
    }
}

# INJECT:VREL:UPDATE
#
# Updates existing VREL inject.

::athena::orders define INJECT:VREL:UPDATE {
    meta title "Update Inject: Vertical Relationship"
    meta sendstates PREP 

    meta parmlist {
        id
        longname
        mode
        {gtype EXISTING}
        g
        {atype EXISTING}
        a
        mag
    }

    meta form {
        rcc "Inject:" -for id
        dbkey id -context yes -table gui_injects_VREL \
            -keys {curse_id inject_num} \
            -loadcmd {$order_ keyload id {g a mode mag}}

        rcc "Description:" -for longname -span 4
        disp longname -width 60

        rcc "Mode:" -for mode -span 4
        enumlong mode -dictcmd {einputmode deflist}

        rcc "Of Group Role:" -for g 
        selector gtype -defvalue "EXISTING" {
            case NEW "Rename role" {
                cc "Role:" -for g
                label "@"
                text g
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for g
                enum g -listcmd {$adb_ inject rolenames VREL g [lindex $id 0]}
            }
        }

        rcc "With Actor Role:" -for a
        selector atype -defvalue "EXISTING" {
            case NEW "Rename role" {
                cc "Role:" -for a
                label "@"
                text a
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for a
                enum a -listcmd {$adb_ inject rolenames VREL a [lindex $id 0]}
            }
        }

        rcc "Magnitude:" -for mag -span 4
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare id    -required           -type inject
        my prepare mode            -tolower  -type  einputmode
        my prepare gtype           -toupper  -selector
        my prepare atype           -toupper  -selector
        my prepare g               -toupper  -type roleid
        my prepare a               -toupper  -type roleid
        my prepare mag   -num      -toupper  -type qmag
    }

    method _execute {{flunky ""}} {
        my setundo [$adb inject update [array get parms]]
    }
}





