#-----------------------------------------------------------------------
# TITLE:
#    iom.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Info Operations Message (IOM) manager
#
#    This module is responsible for managing messages and the operations
#    upon them.  As such, it is a type ensemble.
#
#-----------------------------------------------------------------------

snit::type ::athena::iom {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_      - The athenadb(n) that owns this instance.
    #
    # Initializes instances of this type

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
    # Returns the list of IOM IDs

    method names {} {
        return [$adb eval {
            SELECT iom_id FROM ioms 
        }]
    }

    # namedict
    #
    # Returns the list of IOM IDs

    method namedict {} {
        return [$adb eval {
            SELECT iom_id, longname FROM ioms 
        }]
    }

    # longnames
    #
    # Returns the list of IOM long names

    method longnames {} {
        return [$adb eval {
            SELECT iom_id || ': ' || longname FROM ioms 
        }]
    }

    # validate iom_id
    #
    # iom_id   - Possibly, an IOM ID
    #
    # Validates an IOM ID

    method validate {iom_id} {
        if {![$adb exists {
            SELECT * FROM ioms WHERE iom_id = $iom_id
        }]} {
            set names [join [$self names] ", "]

            if {$names ne ""} {
                set msg "should be one of: $names"
            } else {
                set msg "none are defined"
            }

            return -code error -errorcode INVALID \
                "Invalid IOM, $msg"
        }

        return $iom_id
    }

    # exists iom_id
    #
    # iom_id - A message ID.
    #
    # Returns 1 if there's such a message, and 0 otherwise.

    method exists {iom_id} {
        $adb exists {
            SELECT * FROM ioms WHERE iom_id=$iom_id
        }
    }

    # get id ?parm?
    #
    # iom_id   - An iom_id
    # parm     - An ioms column name
    #
    # Retrieves a row dictionary, or a particular column value, from
    # gui_ioms.
    #
    # NOTE: This is unusual; usually, [get] would retrieve from the
    # base table.  But we need the narrative, which is computed
    # dynamically.

    method get {iom_id {parm ""}} {
        # FIRST, get the data
        $adb eval {
            SELECT * FROM fmt_ioms 
            WHERE iom_id=$iom_id
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
    # Returns the list of IOM IDs with state=normal

    method {normal names} {} {
        return [$adb eval {
            SELECT iom_id FROM ioms WHERE state='normal'
        }]
    }

    # normal namedict
    #
    # Returns the list of IOM ID/long name pairs with state=normal

    method {normal namedict} {} {
        return [$adb eval {
            SELECT iom_id, longname FROM ioms WHERE state='normal'
            ORDER BY iom_id
        }]
    }

    # normal longnames
    #
    # Returns the list of IOM long names with state=normal

    method {normal longnames} {} {
        return [$adb eval {
            SELECT iom_id || ': ' || longname FROM ioms
            WHERE state='normal'
        }]
    }

    # normal validate iom_id
    #
    # iom_id   - Possibly, an IOM ID with state=normal
    #
    # Validates an IOM ID, and ensures that state=normal

    method {normal validate} {iom_id} {
        set names [$self normal names]

        if {$iom_id ni $names} {
            if {$names ne ""} {
                set msg "should be one of: [join $names {, }]"
            } else {
                set msg "no valid IOMs are defined"
            }

            return -code error -errorcode INVALID \
                "Invalid IOM, $msg"
        }

        return $iom_id
    }

    #-------------------------------------------------------------------
    # Sanity Check

    # check
    #
    # Computes the sanity check, returing OK or WARNING.

    method check {} {
        try {
            set f [failurelist new]
            $self checker $f
            return [list [$f severity] [$f dicts]]
        } finally {
            $f destroy
        }
    }

    # checker f
    #
    # f    - A failurelist object
    #
    # Computes the sanity check, adding failures to f.

    method checker {f} {
        $adb payload checker $f
        $self DoSanityCheck $f

        $adb notify iom <Check>
    }

    # DoSanityCheck f
    #
    # f    - If given, a sanity.tcl failure dictlist object
    #
    # This routine does the actual sanity check, adding any
    # failures to f.
    #
    # It is assumed that the payload checker has already been
    # run.

    method DoSanityCheck {f} {
        # FIRST, clear the invalid states, since we're going to 
        # recompute them.

        $adb eval {
            UPDATE ioms
            SET state = 'normal'
            WHERE state = 'invalid';
        }

        # NEXT, identify the invalid IOMs.
        set badlist [list]

        # IOMs with no valid payloads
        $adb eval {
            SELECT I.iom_id             AS iom_id, 
                   count(P.payload_num) AS num
            FROM ioms AS I
            LEFT OUTER JOIN payloads AS P 
            ON P.iom_id = I.iom_id AND P.state = 'normal'
            GROUP BY I.iom_id
        } {
            if {$num == 0} {
                ladd badlist $iom_id
                $f add warning iom.nopayloads iom/$iom_id \
                    "IOM has no valid payloads."
            }
        }

        # IOMs with no hook
        $adb eval {
            SELECT iom_id
            FROM ioms 
            WHERE hook_id IS NULL
        } {
            ladd badlist $iom_id
            $f add warning iom.nohook iom/$iom_id \
                "IOM has no semantic hook."
        }

        # IOMs with hooks with no valid hook_topics
        $adb eval {
            SELECT iom_id, count(topic_id) AS num
            FROM ioms AS I
            LEFT OUTER JOIN hook_topics AS HT 
            ON HT.hook_id = I.hook_id AND HT.state = 'normal'
            WHERE I.hook_id IS NOT NULL
            GROUP BY iom_id
        } {
            if {$num == 0} {
                ladd badlist $iom_id

                $f add warning iom.notopics iom/$iom_id \
                    "IOM's semantic hook has no valid topics."
            }
        }
        

        # NEXT, mark the bad IOMs invalid.
        foreach iom_id $badlist {
            $adb eval {
                UPDATE ioms
                SET state = 'invalid'
                WHERE iom_id=$iom_id
            }
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
    # parmdict  - A dictionary of IOM parms
    #
    #    iom_id   - The IOM's ID
    #    longname - The IOM's long name
    #    hook_id  - The hook_id, or ""
    #
    # Creates an IOM given the parms, which are presumed to be
    # valid.  Note that you can't change the payload's state, which
    # has its own mutator.

    method create {parmdict} {
        dict with parmdict {
            # FIRST, Put the IOM in the database
            $adb eval {
                INSERT INTO 
                ioms(iom_id, 
                     longname,
                     hook_id)
                VALUES($iom_id, 
                       $longname,
                       nullif($hook_id,'')); 
            }

            # NEXT, Return the undo command
            return [list $adb delete ioms "iom_id='$iom_id'"]
        }
    }

    # delete iom_id
    #
    # iom_id   - An IOM ID
    #
    # Deletes the message, including all references.

    method delete {iom_id} {
        # FIRST, Delete the IOM, grabbing the undo information
        set data [$adb delete -grab ioms {iom_id=$iom_id}]
        
        # NEXT, Return the undo script
        return [list $adb ungrab $data]
    }

    # update parmdict
    #
    # parmdict   - A dictionary of IOM parms
    #
    #    iom_id   - An IOM ID
    #    longname - A new long name, or ""
    #    hook_id  - A new hook_id, or ""
    #
    # Updates an IOM given the parms, which are presumed to be
    # valid.  An empty hook_id remains NULL.

    method update {parmdict} {
        dict with parmdict {
            # FIRST, grab the data that might change.
            set data [$adb grab ioms {iom_id=$iom_id}]

            # NEXT, Update the record
            $adb eval {
                UPDATE ioms
                SET longname = nonempty($longname, longname),
                    hook_id  = nullif(nonempty($hook_id, hook_id), '')
                WHERE iom_id=$iom_id;
            } 

            # NEXT, Return the undo command
            return [list $adb ungrab $data]
        }
    }

    # state iom_id state
    #
    # iom_id - The IOM's ID
    # state  - The iom's new eiom_state
    #
    # Updates a iom's state.

    method state {iom_id state} {
        # FIRST, get the undo information
        set data [$adb grab ioms {iom_id=$iom_id}]

        # NEXT, Update the iom.
        $adb eval {
            UPDATE ioms
            SET state = $state
            WHERE iom_id=$iom_id
        }

        # NEXT, Return the undo command
        return [list $adb ungrab $data]
    }

}    

#-------------------------------------------------------------------
# Orders: IOM:*

# IOM:CREATE
#
# Creates a new IOM

::athena::orders define IOM:CREATE {
    meta title "Create Info Ops Message"
    
    meta sendstates PREP

    meta parmlist {iom_id longname hook_id}

    meta form {
        rcc "Message ID:" -for iom_id
        text iom_id

        rcc "Description:" -for longname
        text longname -width 60

        rcc "Semantic Hook:" -for hook_id
        enumlong hook_id -dictcmd {$adb_ hook namedict} -showkeys yes
    }


    method _validate {} {
        my prepare iom_id    -toupper   -required -type ident
        my unused iom_id
        my prepare longname  -normalize
        my prepare hook_id   -toupper             -type [list $adb hook]
    }

    method _execute {{flunky ""}} {
        if {$parms(longname) eq ""} {
            set parms(longname) $parms(iom_id)
        }

        lappend undo [$adb iom create [array get parms]]
        my setundo [join $undo \n]
    }
}

# IOM:DELETE
#
# Deletes an IOM and its payloads.

::athena::orders define IOM:DELETE {
    meta title "Delete Info Ops Message"
    meta sendstates PREP

    meta parmlist {iom_id}

    meta form {
        rcc "Message ID:" -for iom_id
        dbkey iom_id -table ioms -keys iom_id
    }


    method _validate {} {
        my prepare iom_id -toupper -required -type [list $adb iom]
    }

    method _execute {{flunky ""}} {
        lappend undo [$adb iom delete $parms(iom_id)]
    
        my setundo [join $undo \n]
    }
}


# IOM:UPDATE
#
# Updates an existing IOM.

::athena::orders define IOM:UPDATE {
    meta title "Update Info Ops Message"
    meta sendstates PREP

    meta parmlist {iom_id longname hook_id}

    meta form {
        rcc "Message ID" -for iom_id
        dbkey iom_id -table ioms -keys iom_id \
            -loadcmd {$order_ keyload iom_id *}

        rcc "Description:" -for longname
        text longname -width 60

        rcc "Semantic Hook:" -for hook_id
        enumlong hook_id -dictcmd {$adb_ hook namedict} -showkeys yes
    }


    method _validate {} {
        my prepare iom_id      -toupper   -required -type [list $adb iom]
        my prepare longname    -normalize
        my prepare hook_id     -toupper             -type [list $adb hook]
    }

    method _execute {{flunky ""}} {
        my setundo [$adb iom update [array get parms]]
    }
}


# IOM:STATE
#
# Sets a iom's state.  Note that this order isn't intended
# for use with a dialog.

::athena::orders define IOM:STATE {
    meta title "Set IOM State"

    meta sendstates PREP 

    meta parmlist {iom_id state}

    meta form {
        # Not used for dialog.
        dbkey iom_id -table ioms -keys iom_id
        text state
    }


    method _validate {} {
        my prepare iom_id -required          -type [list $adb iom]
        my prepare state  -required -tolower -type eiom_state
    }

    method _execute {{flunky ""}} {
        my setundo [$adb iom state $parms(iom_id) $parms(state)]
    }
}

