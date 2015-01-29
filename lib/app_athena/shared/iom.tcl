#-----------------------------------------------------------------------
# TITLE:
#    iom.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Info Operations Message (IOM) manager
#
#    This module is responsible for managing messages and the operations
#    upon them.  As such, it is a type ensemble.
#
#-----------------------------------------------------------------------

snit::type iom {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.

    # names
    #
    # Returns the list of IOM IDs

    typemethod names {} {
        return [rdb eval {
            SELECT iom_id FROM ioms 
        }]
    }

    # longnames
    #
    # Returns the list of IOM long names

    typemethod longnames {} {
        return [rdb eval {
            SELECT iom_id || ': ' || longname FROM ioms 
        }]
    }

    # validate iom_id
    #
    # iom_id   - Possibly, an IOM ID
    #
    # Validates an IOM ID

    typemethod validate {iom_id} {
        if {![rdb exists {
            SELECT * FROM ioms WHERE iom_id = $iom_id
        }]} {
            set names [join [iom names] ", "]

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

    typemethod exists {iom_id} {
        rdb exists {
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

    typemethod get {iom_id {parm ""}} {
        # FIRST, get the data
        rdb eval {
            SELECT * FROM gui_ioms 
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

    typemethod {normal names} {} {
        return [rdb eval {
            SELECT iom_id FROM ioms WHERE state='normal'
        }]
    }

    # normal namedict
    #
    # Returns the list of IOM ID/long name pairs with state=normal

    typemethod {normal namedict} {} {
        return [rdb eval {
            SELECT iom_id, longname FROM ioms WHERE state='normal'
            ORDER BY iom_id
        }]
    }
    # normal longnames
    #
    # Returns the list of IOM long names with state=normal

    typemethod {normal longnames} {} {
        return [rdb eval {
            SELECT iom_id || ': ' || longname FROM ioms
            WHERE state='normal'
        }]
    }

    # normal validate iom_id
    #
    # iom_id   - Possibly, an IOM ID with state=normal
    #
    # Validates an IOM ID, and ensures that state=normal

    typemethod {normal validate} {iom_id} {
        set names [iom normal names]

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

    # checker ?ht?
    #
    # ht - An htools buffer
    #
    # Computes the sanity check, and formats the results into the buffer
    # for inclusion into an HTML page.  Returns an esanity value, either
    # OK or WARNING.

    typemethod checker {{ht ""}} {
        # FIRST, do the payload check.
        set psev [payload checker $ht]
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
    # This routine does the actual sanity check, marking the IOM
    # records in the RDB and putting error messages in a 
    # nested dictionary, iom_id -> msglist.  Note that a single
    # IOM can have multiple messages.
    #
    # It is assumed that the payload checker has already been
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
            UPDATE ioms
            SET state = 'normal'
            WHERE state = 'invalid';
        }

        # NEXT, identify the invalid IOMs.
        set badlist [list]

        # IOMs with no valid payloads
        rdb eval {
            SELECT I.iom_id             AS iom_id, 
                   count(P.payload_num) AS num
            FROM ioms AS I
            LEFT OUTER JOIN payloads AS P 
            ON P.iom_id = I.iom_id AND P.state = 'normal'
            GROUP BY I.iom_id
        } {
            if {$num == 0} {
                dict lappend edict $iom_id "IOM has no valid payloads."
                ladd badlist $iom_id
            }
        }

        # IOMs with no hook
        rdb eval {
            SELECT iom_id
            FROM ioms 
            WHERE hook_id IS NULL
        } {
            dict lappend edict $iom_id "IOM has no semantic hook."
            ladd badlist $iom_id
        }

        # IOMs with hooks with no valid hook_topics
        rdb eval {
            SELECT iom_id, count(topic_id) AS num
            FROM ioms AS I
            LEFT OUTER JOIN hook_topics AS HT 
            ON HT.hook_id = I.hook_id AND HT.state = 'normal'
            WHERE I.hook_id IS NOT NULL
            GROUP BY iom_id
        } {
            if {$num == 0} {
                dict lappend edict $iom_id \
                    "IOM's semantic hook has no valid topics."
                ladd badlist $iom_id
            }
        }
        

        # NEXT, mark the bad IOMs invalid.
        foreach iom_id $badlist {
            rdb eval {
                UPDATE ioms
                SET state = 'invalid'
                WHERE iom_id=$iom_id
            }
        }

        notifier send ::iom <Check>

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
        $ht subtitle "IOM Constraints"

        $ht putln {
            One or more IOMs failed their checks and have been 
            marked invalid in the
        }
        
        $ht link gui:/tab/ioms "IOM Browser"

        $ht put ".  Please fix them or delete them."
        $ht para

        dict for {iom_id msglist} $edict {
            array set idata [iom get $iom_id]

            $ht ul
            $ht li 
            $ht put "<b>IOM $iom_id: $idata(longname)</b>"

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
    # parmdict  - A dictionary of IOM parms
    #
    #    iom_id   - The IOM's ID
    #    longname - The IOM's long name
    #    hook_id  - The hook_id, or ""
    #
    # Creates an IOM given the parms, which are presumed to be
    # valid.  Note that you can't change the payload's state, which
    # has its own mutator.

    typemethod {mutate create} {parmdict} {
        dict with parmdict {
            # FIRST, Put the IOM in the database
            rdb eval {
                INSERT INTO 
                ioms(iom_id, 
                     longname,
                     hook_id)
                VALUES($iom_id, 
                       $longname,
                       nullif($hook_id,'')); 
            }

            # NEXT, Return the undo command
            return [list rdb delete ioms "iom_id='$iom_id'"]
        }
    }

    # mutate delete iom_id
    #
    # iom_id   - An IOM ID
    #
    # Deletes the message, including all references.

    typemethod {mutate delete} {iom_id} {
        # FIRST, Delete the IOM, grabbing the undo information
        set data [rdb delete -grab ioms {iom_id=$iom_id}]
        
        # NEXT, Return the undo script
        return [list rdb ungrab $data]
    }

    # mutate update parmdict
    #
    # parmdict   - A dictionary of IOM parms
    #
    #    iom_id   - An IOM ID
    #    longname - A new long name, or ""
    #    hook_id  - A new hook_id, or ""
    #
    # Updates an IOM given the parms, which are presumed to be
    # valid.  An empty hook_id remains NULL.

    typemethod {mutate update} {parmdict} {
        dict with parmdict {
            # FIRST, grab the data that might change.
            set data [rdb grab ioms {iom_id=$iom_id}]

            # NEXT, Update the record
            rdb eval {
                UPDATE ioms
                SET longname = nonempty($longname, longname),
                    hook_id  = nullif(nonempty($hook_id, hook_id), '')
                WHERE iom_id=$iom_id;
            } 

            # NEXT, Return the undo command
            return [list rdb ungrab $data]
        }
    }

    # mutate state iom_id state
    #
    # iom_id - The IOM's ID
    # state  - The iom's new eiom_state
    #
    # Updates a iom's state.

    typemethod {mutate state} {iom_id state} {
        # FIRST, get the undo information
        set data [rdb grab ioms {iom_id=$iom_id}]

        # NEXT, Update the iom.
        rdb eval {
            UPDATE ioms
            SET state = $state
            WHERE iom_id=$iom_id
        }

        # NEXT, Return the undo command
        return [list rdb ungrab $data]
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
        enumlong hook_id -dictcmd {::hook namedict} -showkeys yes
    }


    method _validate {} {
        my prepare iom_id    -toupper   -required -type ident
        my unused iom_id
        my prepare longname  -normalize
        my prepare hook_id   -toupper             -type hook
    }

    method _execute {{flunky ""}} {
        if {$parms(longname) eq ""} {
            set parms(longname) $parms(iom_id)
        }

        lappend undo [iom mutate create [array get parms]]
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
        my prepare iom_id -toupper -required -type iom
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
                                Info Ops Message, along with all of its 
                                payloads?
                            }]]
    
            if {$answer eq "cancel"} {
                my cancel
            }
        }
    
        # NEXT, Delete the record and dependent entities
        lappend undo [iom mutate delete $parms(iom_id)]
    
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
        enumlong hook_id -dictcmd {::hook namedict} -showkeys yes
    }


    method _validate {} {
        my prepare iom_id      -toupper   -required -type iom
        my prepare longname    -normalize
        my prepare hook_id     -toupper             -type hook
    }

    method _execute {{flunky ""}} {
        my setundo [iom mutate update [array get parms]]
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
        my prepare iom_id -required          -type iom
        my prepare state  -required -tolower -type eiom_state
    }

    method _execute {{flunky ""}} {
        my setundo [iom mutate state $parms(iom_id) $parms(state)]
    }
}

