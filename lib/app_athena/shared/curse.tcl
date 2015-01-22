#-----------------------------------------------------------------------
# TITLE:
#    curse.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena_sim(1): Complex User-defined Role-based Situation and
#                   Events (CURSE) manager
#
#    This module is responsible for managing messages and the operations
#    upon them.  As such, it is a type ensemble.
#
#-----------------------------------------------------------------------

snit::type curse {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.

    # names
    #
    # Returns the list of CURSE IDs

    typemethod names {} {
        return [rdb eval {
            SELECT curse_id FROM curses 
        }]
    }

    # longnames
    #
    # Returns the list of CURSE long names

    typemethod longnames {} {
        return [rdb eval {
            SELECT curse_id || ': ' || longname FROM curses 
        }]
    }

    # narrative curse_id
    #
    # Returns a string description for the CURSE or an
    # appropriate message if there's something wrong

    typemethod narrative {curse_id} {
        set narr "??? (???)"

        if {[curse exists $curse_id]} {
            set narr [curse get $curse_id longname]
            append narr " ($curse_id)"
        }

        return $narr
    }


    # validate curse_id
    #
    # curse_id   - Possibly, a CURSE ID
    #
    # Validates a CURSE ID

    typemethod validate {curse_id} {
        if {![rdb exists {
            SELECT * FROM curses WHERE curse_id = $curse_id
        }]} {
            set names [join [curse names] ", "]

            if {$names ne ""} {
                set msg "should be one of: $names"
            } else {
                set msg "none are defined"
            }

            return -code error -errorcode INVALID \
                "Invalid CURSE, $msg"
        }

        return $curse_id
    }

    # exists curse_id
    #
    # curse_id - A curse ID.
    #
    # Returns 1 if there's such a curse, and 0 otherwise.

    typemethod exists {curse_id} {
        rdb exists {
            SELECT * FROM curses WHERE curse_id=$curse_id
        }
    }

    # get id ?parm?
    #
    # curse_id   - A curse_id
    # parm       - A curses column name
    #
    # Retrieves a row dictionary, or a particular column value, from
    # gui_ioms.
    #
    # NOTE: This is unusual; usually, [get] would retrieve from the
    # base table.  But we need the narrative, which is computed
    # dynamically.

    typemethod get {curse_id {parm ""}} {
        # FIRST, get the data
        rdb eval {
            SELECT * FROM gui_curses 
            WHERE curse_id=$curse_id
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

    # normal names
    #
    # Returns the list of CURSE IDs with state=normal

    typemethod {normal names} {} {
        return [rdb eval {
            SELECT curse_id FROM curses WHERE state='normal'
        }]
    }

    # normal namedict
    #
    # Returns the list of CURSE ID/long name pairs with state=normal

    typemethod {normal namedict} {} {
        return [rdb eval {
            SELECT curse_id, longname FROM curses WHERE state='normal'
            ORDER BY curse_id
        }]
    }
    # normal longnames
    #
    # Returns the list of CURSE long names with state=normal

    typemethod {normal longnames} {} {
        return [rdb eval {
            SELECT curse_id || ': ' || longname FROM curses
            WHERE state='normal'
        }]
    }

    # normal validate curse_id
    #
    # curse_id   - Possibly, a CURSE ID with state=normal
    #
    # Validates a CURSE ID, and ensures that state=normal

    typemethod {normal validate} {curse_id} {
        set names [curse normal names]

        if {$curse_id ni $names} {
            if {$names ne ""} {
                set msg "should be one of: [join $names {, }]"
            } else {
                set msg "no valid CURSEs are defined"
            }

            return -code error -errorcode INVALID \
                "Invalid CURSE, $msg"
        }

        return $curse_id
    }


    # rolenames curse_id 
    #
    # curse_id    - CURSE ID
    #
    # Returns a list of recognized rolenames given a CURSE ID

    typemethod rolenames {curse_id} {
        set roles [rdb eval {
            SELECT DISTINCT f FROM curse_injects
            WHERE f != '' AND curse_id=$curse_id
        }]

        lmerge roles [rdb eval {
            SELECT DISTINCT g FROM curse_injects
            WHERE g != '' AND curse_id=$curse_id
        }]

        lmerge roles [rdb eval {
            SELECT DISTINCT a FROM curse_injects
            WHERE a != '' AND curse_id=$curse_id
        }]

        return $roles
    }

    # rolespec curse_id
    #
    # curse_id    ID of an existing CURSE
    #
    # This method returns a dictionary of role type/gofer pairs
    # to be used by the caller to fill in data for a set of
    # CURSE injects associated with the given CURSE. 

    typemethod rolespec {curse_id} {
        # FIRST, if there's no curse specified, then nothing to
        # return
        if {$curse_id eq ""} {
            return {}
        }

        # NEXT, create the role spec dictionary
        set roleSpec [dict create]

        # NEXT, build up the rolespec based upon the injects associated
        # with this curse
        # HREL is the least restrictive, any group can belong to the
        # roles defined
        rdb eval {
            SELECT * FROM curse_injects 
            WHERE curse_id=$curse_id
            AND inject_type='HREL'
        } row {
            dict set roleSpec $row(f) ::gofer::GROUPS
            dict set roleSpec $row(g) ::gofer::GROUPS
        }

        # VREL is not any more restrictive group wise
        rdb eval {
            SELECT * FROM curse_injects
            WHERE curse_id=$curse_id
            AND inject_type='VREL'
        } row {
            dict set roleSpec $row(g) ::gofer::GROUPS
            dict set roleSpec $row(a) ::gofer::ACTORS
        }

        # SAT restricts the group role to *only* civilians. If an HREL or
        # VREL inject has this role, then those injects will only be able
        # to contain civilian groups
        rdb eval {
            SELECT * FROM curse_injects
            WHERE curse_id=$curse_id
            AND inject_type='SAT'
        } row {
            dict set roleSpec $row(g) ::gofer::CIVGROUPS
        }

        # COOP restricts one role to civilians only and the other role to
        # forces only. Like SAT, if these roles appear in HREL or VREL, then
        # they will be restricted to the same groups
        rdb eval {
            SELECT * FROM curse_injects
            WHERE curse_id=$curse_id
            AND inject_type='COOP'
        } row {
            dict set roleSpec $row(f) ::gofer::CIVGROUPS
            dict set roleSpec $row(g) ::gofer::FRCGROUPS
        }

        return $roleSpec
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

    typemethod checker {{ht ""}} {
        # FIRST, do the inject check.
        set psev [inject checker $ht]
        assert {$psev ne "ERROR"}

        set edict [$type DoSanityCheck]

        if {$psev eq "OK" && [dict size $edict] == 0} {
            return OK
        }

        if {$ht ne ""} {
            $type DoSanityReport $ht $edict
        }
        
        return WARNING
    }

    # DoSanityCheck
    #
    # This routine does the actual sanity check, marking the CURSE
    # records in the RDB and putting error messages in a 
    # nested dictionary, curse_id -> msglist.  Note that a single
    # CURSE can have multiple messages.
    #
    # It is assumed that the inject checker has already been
    # run.
    #
    # Returns the dictionary, which will be empty if there were no
    # errors.

    typemethod DoSanityCheck {} {
        # FIRST, create the empty error dictionary.
        set edict [dict create]

        # NEXT, clear the invalid states, since we're going to 
        # recompute them.

        rdb eval {
            UPDATE curses
            SET state = 'normal'
            WHERE state = 'invalid';
        }

        # NEXT, identify the invalid CURSEs.
        set badlist [list]

        # CURSEs with no valid injects
        rdb eval {
            SELECT C.curse_id           AS curse_id, 
                   count(I.inject_num)  AS num
            FROM curses AS C
            LEFT OUTER JOIN curse_injects AS I 
            ON I.curse_id = C.curse_id AND I.state = 'normal'
            GROUP BY C.curse_id
        } {
            if {$num == 0} {
                dict lappend edict $curse_id "CURSE has no valid injects."
                ladd badlist $curse_id
            }
        }

        # NEXT, mark the bad CURSEs invalid.
        foreach curse_id $badlist {
            rdb eval {
                UPDATE curses
                SET state = 'invalid'
                WHERE curse_id=$curse_id
            }
        }

        notifier send ::curse <Check>

        return $edict
    }


    # DoSanityReport ht edict
    #
    # ht        - An htools buffer to receive a report.
    # edict     - A dictionary iom_id->msglist
    #
    # Writes HTML text of the results of the sanity check to the ht
    # buffer.  This routine assumes that there are errors.

    typemethod DoSanityReport {ht edict} {
        # FIRST, Build the report
        $ht subtitle "CURSE Constraints"

        $ht putln {
            One or more CURSEs failed their checks and have been 
            marked invalid in the
        }
        
        $ht link gui:/tab/curses "CURSE Browser"

        $ht put ".  Please fix them or delete them."
        $ht para

        dict for {curse_id msglist} $edict {
            array set cdata [curse get $curse_id]

            $ht ul
            $ht li 
            $ht put "<b>CURSE $curse_id: $cdata(longname)</b>"

            foreach errmsg $msglist {
                $ht br
                $ht putln "==> <font color=red>Warning: $errmsg</font>"
            }
            
            $ht /ul
        }

        return
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
    # parmdict  - A dictionary of CURSE parms
    #
    #    curse_id - The CURSE's ID
    #    longname - The CURSE's long name
    #    cause    - The CURSE's cause
    #
    # Creates a CURSE given the parms, which are presumed to be
    # valid. 

    typemethod {mutate create} {parmdict} {
        dict with parmdict {
            # FIRST, Put the CURSE in the database
            rdb eval {
                INSERT INTO 
                curses(curse_id, 
                       longname,
                       cause,
                       s,
                       p,
                       q)
                VALUES($curse_id, 
                       $longname,
                       $cause,
                       $s,
                       $p,
                       $q); 
            }

            # NEXT, Return the undo command
            return [list rdb delete curses "curse_id='$curse_id'"]
        }
    }

    # mutate delete curse_id
    #
    # curse_id   - A CURSE ID
    #
    # Deletes the CURSE, including all references.

    typemethod {mutate delete} {curse_id} {
        # FIRST, Delete the CURSE, grabbing the undo information
        set data [rdb delete -grab curses {curse_id=$curse_id}]
        
        # NEXT, Return the undo script
        return [list rdb ungrab $data]
    }

    # mutate update parmdict
    #
    # parmdict   - A dictionary of CURSE parms
    #
    #    curse_id - A CURSE ID
    #    longname - A new long name, or ""
    #    cause    - A new cause
    #
    # Updates a CURSE given the parms, which are presumed to be
    # valid.  

    typemethod {mutate update} {parmdict} {
        dict with parmdict {
            # FIRST, grab the data that might change.
            set data [rdb grab curses {curse_id=$curse_id}]

            # NEXT, Update the record
            rdb eval {
                UPDATE curses
                SET longname = nonempty($longname, longname),
                    cause    = nonempty($cause,    cause),
                    s        = nonempty($s,        s),
                    p        = nonempty($p,        p),
                    q        = nonempty($q,        q)
                WHERE curse_id=$curse_id;
            } 

            # NEXT, Return the undo command
            return [list rdb ungrab $data]
        }
    }

    # mutate state curse_id state
    #
    # curse_id - The CURSE's ID
    # state    - The CURSE's new ecurse_state
    #
    # Updates a CURSE's state.

    typemethod {mutate state} {curse_id state} {
        # FIRST, get the undo information
        set data [rdb grab curses {curse_id=$curse_id}]

        # NEXT, Update the iom.
        rdb eval {
            UPDATE curses
            SET state = $state
            WHERE curse_id=$curse_id
        }

        # NEXT, Return the undo command
        return [list rdb ungrab $data]
    }

}    

#-------------------------------------------------------------------
# Orders: CURSE:*

# CURSE:CREATE
#
# Creates a new CURSE

myorders define CURSE:CREATE {
    meta title "Create CURSE"
    
    meta sendstates PREP

    meta parmlist {
        curse_id
        longname
        {cause UNIQUE}
        {s 1.0}
        {p 0.0}
        {q 0.0}
    }

    meta form {
        rcc "CURSE ID:" -for curse_id
        text curse_id

        rcc "Description:" -for longname
        text longname -width 60

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
        my prepare curse_id  -toupper   -required -type ident
        my unused curse_id
        my prepare longname  -normalize
        my prepare cause     -toupper   -required -type {ptype ecause+unique}
        my prepare s         -num       -required -type rfraction
        my prepare p         -num       -required -type rfraction
        my prepare q         -num       -required -type rfraction
    }

    method _execute {{flunky ""}} {
        if {$parms(longname) eq ""} {
            set parms(longname) $parms(curse_id)
        }

        # NEXT, create the message.
        lappend undo [curse mutate create [array get parms]]

        my setundo [join $undo \n]
    }
}

# CURSE:DELETE
#
# Deletes a CURSE and its inputs.

myorders define CURSE:DELETE {
    meta title "Delete CURSE"
    meta sendstates PREP

    meta form {
        rcc "CURSE ID:" -for curse_id
        dbkey curse_id -table curses -keys curse_id
    }

    meta parmlist {curse_id}


    method _validate {} {
        my prepare curse_id -toupper -required -type curse 
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
                                CURSE, along with all of its inputs?
                            }]]

            if {$answer eq "cancel"} {
                my cancel
            }
        }

        # NEXT, Delete the record and dependent entities
        lappend undo [curse mutate delete $parms(curse_id)]

        my setundo [join $undo \n]
    }
}


# CURSE:UPDATE
#
# Updates an existing CURSE.

myorders define CURSE:UPDATE {
    meta title "Update CURSE"
    meta sendstates PREP

    meta parmlist {
        curse_id
        longname
        cause
        s
        p
        q
    }

    meta form {
        rcc "CURSE ID" -for curse_id
        dbkey curse_id -table curses -keys curse_id \
            -loadcmd {$order_ keyload curse_id *}

        rcc "Description:" -for longname
        text longname -width 60

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
        my prepare curse_id  -toupper   -required -type curse
        my prepare longname  -normalize
        my prepare cause     -toupper             -type {ptype ecause+unique}
        my prepare s         -num                 -type rfraction
        my prepare p         -num                 -type rfraction
        my prepare q         -num                 -type rfraction
    }

    method _execute {{flunky ""}} {
        my setundo [curse mutate update [array get parms]]
    }
}


# CURSE:STATE
#
# Sets a CURSE's state.  Note that this order isn't intended
# for use with a dialog.

myorders define CURSE:STATE {
    meta title "Set CURSE State"

    meta sendstates PREP 

    meta parmlist {curse_id state}

    meta form {
        # Not used for dialog.
        dbkey curse_id -table curses -keys curse_id
        text state
    }


    method _validate {} {
        my prepare curse_id -required -toupper -type curse
        my prepare state    -required -tolower -type ecurse_state
    }

    method _execute {{flunky ""}} {
        my setundo [curse mutate state $parms(curse_id) $parms(state)]
    }
}

