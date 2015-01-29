#-----------------------------------------------------------------------
# TITLE:
#    payload.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Payload Manager
#
#    This module is responsible for managing payloads and operations
#    upon them.  As such, it is a type ensemble.
#
#    There are a number of different payload types.  
#
#    * All are stored in the payloads table.
#
#    * The data inheritance is handled by defining a number of 
#      generic columns to hold type-specific parameters.
#
#    * The mutators work for all payload types.
#
#    * Each payload type has its own CREATE and UPDATE orders; the 
#      DELETE and STATE orders are common to all.
#
#    * scenario(sim) defines a view for each payload type,
#      payloads_<type>.
#
#-----------------------------------------------------------------------

snit::type payload {
    # Make it a singleton
    pragma -hasinstances no

    #===================================================================
    # Lookup tables

    # optParms: This variable is a dictionary of all optional parameters
    # with empty values.  The create and update mutators can merge the
    # input parmdict with this to get a parmdict with the full set of
    # parameters.

    typevariable optParms {
        mag      ""
        a        ""
        c        ""
        g        ""
    }

    #===================================================================
    # Payload Types: Definition and Query interface.

    #-------------------------------------------------------------------
    # Uncheckpointed Type variables

    # tinfo array: Type Info
    #
    # names         - List of the names of the payload types.
    # parms-$ttype  - List of the optional parms used by the payload type.

    typevariable tinfo -array {
        names {}
    }

    # type names
    #
    # Returns the payload type names.
    
    typemethod {type names} {} {
        return [lsort $tinfo(names)]
    }

    # type parms ttype
    #
    # Returns a list of the names of the optional parameters used by
    # the payload.
    
    typemethod {type parms} {ttype} {
        return $tinfo(parms-$ttype)
    }

    # type define name optparms defscript
    #
    # name        - The payload name
    # optparms    - List of optional parameters used by this payload type.
    # defscript   - The definition script (a snit::type script)
    #
    # Defines payload::$name as a type ensemble given the typemethods
    # defined in the defscript.  See payload(i) for documentation of the
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
    # This routine does the actual sanity check, marking the payload
    # records in the RDB and putting error messages in a 
    # nested dictionary, iom_id -> payload_num -> errmsg.
    #
    # Returns the dictionary, which will be empty if there were no
    # errors.

    typemethod DoSanityCheck {} {
        # FIRST, create the empty error dictionary.
        set edict [dict create]

        # NEXT, clear the invalid states, since we're going to 
        # recompute them.

        rdb eval {
            UPDATE payloads
            SET state = 'normal'
            WHERE state = 'invalid';
        }

        # NEXT, identify the invalid payloads.
        set badlist [list]

        rdb eval {
            SELECT * FROM payloads
        } row {
            set result [payload call check [array get row]]

            if {$result ne ""} {
                dict set edict $row(iom_id) $row(payload_num) $result
                lappend badlist $row(iom_id) $row(payload_num)
            }
        }

        # NEXT, mark the bad payloads invalid.
        foreach {iom_id payload_num} $badlist {
            rdb eval {
                UPDATE payloads
                SET state = 'invalid'
                WHERE iom_id=$iom_id AND payload_num=$payload_num 
            }
        }

        notifier send ::payload <Check>

        return $edict
    }


    # DoSanityReport ht edict
    #
    # ht        - An htools buffer to receive a report.
    # edict     - A dictionary iom_id->payload_num->errmsg
    #
    # Writes HTML text of the results of the sanity check to the ht
    # buffer.  This routine assumes that there are errors.

    typemethod DoSanityReport {ht edict} {
        # FIRST, Build the report
        $ht subtitle "IOM Payload Constraints"

        $ht putln {
            Certain IOM payloads failed their checks and have been 
            marked invalid in the
        }
        
        $ht link gui:/tab/ioms "IOM Browser"

        $ht put ".  Please fix them or delete them."
        $ht para

        dict for {iom_id idict} $edict {
            array set idata [iom get $iom_id]

            $ht putln "<b>IOM $iom_id: $idata(longname)</b>"
            $ht ul

            dict for {payload_num errmsg} $idict {
                set pdict [payload get [list $iom_id $payload_num]]

                dict with pdict {
                    $ht li
                    $ht put "Payload #$payload_num: $narrative"
                    $ht br
                    $ht putln "==> <font color=red>Warning: $errmsg</font>"
                }
            }
            
            $ht /ul
        }

        return
    }


    #===================================================================
    # payload Instance: Modification and Query Interace

    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.


    # validate id
    #
    # id - Possibly, a payload ID {iom_id payload_num}
    #
    # Validates a payload ID

    typemethod validate {id} {
        lassign $id iom_id payload_num

        iom validate $iom_id

        if {![payload exists $id]} {
            set nums [rdb eval {
                SELECT payload_num FROM payloads
                WHERE iom_id=$iom_id
                ORDER BY payload_num
            }]

            if {[llength $nums] == 0} {
                set msg "no payloads are defined for this IOM"
            } else {
                set msg "payload number should be one of: [join $nums {, }]"
            }

            return -code error -errorcode INVALID \
                "Invalid payload \"$id\", $msg"
        }

        return $id
    }

    # exists id
    #
    # id   - Possibly, a payload id, {iom_id payload_num}
    #
    # Returns 1 if the payload exists, and 0 otherwise.

    typemethod exists {id} {
        lassign $id iom_id payload_num

        return [rdb exists {
            SELECT * FROM payloads 
            WHERE iom_id=$iom_id AND payload_num=$payload_num
        }]
    }

    # get id ?parm?
    #
    # id   - A payload id
    # parm - A payloads column name
    #
    # Retrieves a row dictionary, or a particular column value, from
    # payloads.

    typemethod get {id {parm ""}} {
        lassign $id iom_id payload_num

        # FIRST, get the data
        rdb eval {
            SELECT * FROM payloads 
            WHERE iom_id=$iom_id AND payload_num=$payload_num
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

    #-------------------------------------------------------------------
    # Mutators
    #
    # Mutators are used to implement orders that change the scenario in
    # some way.  Mutators assume that their inputs are valid, and returns
    # a script of one or more commands that will undo the change.  When
    # change cannot be undone, the mutator returns the empty string.

    # mutate create parmdict
    #
    # parmdict     A dictionary of payload parms
    #
    #    payload_type   The payload type
    #    iom_id         The payload's owning IOM
    #    a              Actor, or ""
    #    c              Concern, or ""
    #    g              Groups, or ""
    #    mag            numeric qmag(n) value, or ""
    #
    # Creates a payload given the parms, which are presumed to be
    # valid.

    typemethod {mutate create} {parmdict} {
        # FIRST, make sure the parm dict is complete
        set parmdict [dict merge $optParms $parmdict]

        # NEXT, compute the narrative string.
        set narrative [$type call narrative $parmdict]

        # NEXT, put the payload in the database.
        dict with parmdict {
            # FIRST, get the payload number for this IOM.
            rdb eval {
                SELECT coalesce(max(payload_num)+1,1) AS payload_num
                FROM payloads
                WHERE iom_id=$iom_id
            } {}

            # NEXT, Put the payload in the database
            rdb eval {
                INSERT INTO 
                payloads(iom_id, payload_num, payload_type, narrative,
                         a,
                         c,
                         g,
                         mag)
                VALUES($iom_id, $payload_num, $payload_type, $narrative,
                       nullif($a,     ''),
                       nullif($c,     ''),
                       nullif($g,     ''),
                       nullif($mag,   ''));
            }

            # NEXT, Return undo command.
            return [list rdb delete payloads \
                "iom_id='$iom_id' AND payload_num=$payload_num"]
        }
    }

    # mutate delete id
    #
    # id     a payload ID, {iom_id payload_num}
    #
    # Deletes the payload.  Note that deleting a payload leaves a 
    # gap in the priority order, but doesn't change the order of
    # the remaining payloads; hence, we don't need to worry about it.

    typemethod {mutate delete} {id} {
        lassign $id iom_id payload_num

        # FIRST, get the undo information
        set data [rdb delete -grab payloads \
            {iom_id=$iom_id AND payload_num=$payload_num}]

        # NEXT, Return the undo script
        return [list rdb ungrab $data]
    }

    # mutate update parmdict
    #
    # parmdict     A dictionary of payload parms
    #
    #    id             The payload ID, {iom_id payload_num}
    #    a              Actor, or ""
    #    c              Concern, or ""
    #    g              Group, or ""
    #    mag            Numeric qmag(n) value, or ""
    #
    # Updates a payload given the parms, which are presumed to be
    # valid.  Note that you can't change the payload's IOM or
    # type, and the state is set by a different mutator.

    typemethod {mutate update} {parmdict} {
        # FIRST, make sure the parm dict is complete
        set parmdict [dict merge $optParms $parmdict]

        # NEXT, save the changed data.
        dict with parmdict {
            lassign $id iom_id payload_num

            # FIRST, get the undo information
            set data [rdb grab payloads \
                {iom_id=$iom_id AND payload_num=$payload_num}]

            # NEXT, Update the payload.  The nullif(nonempty()) pattern
            # is so that the old value of the column will be used
            # if the input is empty, and that empty columns will be
            # NULL rather than "".
            rdb eval {
                UPDATE payloads
                SET a       = nullif(nonempty($a,   a),     ''),
                    c       = nullif(nonempty($c,   c),     ''),
                    g       = nullif(nonempty($g,   g),     ''),
                    mag     = nullif(nonempty($mag, mag),   '')
                WHERE iom_id=$iom_id AND payload_num=$payload_num
            } {}

            # NEXT, compute and set the narrative
            set pdict [$type get $id]
            set narrative [$type call narrative $pdict]

            rdb eval {
                UPDATE payloads
                SET    narrative = $narrative
                WHERE iom_id=$iom_id AND payload_num=$payload_num
            }

            # NEXT, Return the undo command
            return [list rdb ungrab $data]
        }
    }

    # mutate state id state
    #
    # id     - The payload's ID, {iom_id payload_num}
    # state  - The payload's new epayload_state
    #
    # Updates a payload's state.

    typemethod {mutate state} {id state} {
        lassign $id iom_id payload_num

        # FIRST, get the undo information
        set data [rdb grab payloads \
            {iom_id=$iom_id AND payload_num=$payload_num}]

        # NEXT, Update the payload.
        rdb eval {
            UPDATE payloads
            SET state = $state
            WHERE iom_id=$iom_id AND payload_num=$payload_num
        }

        # NEXT, Return the undo command
        return [list rdb ungrab $data]
    }

    #-------------------------------------------------------------------
    # payload Ensemble Interface

    # call op pdict ?args...?
    #
    # op    - One of the payload type subcommands
    # pdict - A payload parameter dictionary
    #
    # This is a convenience command that calls the relevant subcommand
    # for the payload.

    typemethod call {op pdict args} {
        [dict get $pdict payload_type] $op $pdict {*}$args
    }

    #-------------------------------------------------------------------
    # Order Helpers

    # RequireType payload_type id
    #
    # payload_type  - The desired payload_type
    # id           - A payload id, {iom_id payload_num}
    #
    # Throws an error if the payload doesn't have the desired type.

    typemethod RequireType {payload_type id} {
        lassign $id iom_id payload_num
        
        if {[rdb onecolumn {
            SELECT payload_type FROM payloads 
            WHERE iom_id=$iom_id AND payload_num=$payload_num
        }] ne $payload_type} {
            return -code error -errorcode INVALID \
                "payload \"$id\" is not a $payload_type payload"
        }
    }
}


#-----------------------------------------------------------------------
# Orders: PAYLOAD:*

# PAYLOAD:DELETE
#
# Deletes an existing payload, of whatever type.

myorders define PAYLOAD:DELETE {
    # This order dialog isn't usually used.

    meta title "Delete Payload"
    meta sendstates PREP

    meta parmlist {id}

    meta form {
        rcc "Payload ID:" -for id
        payload id -context yes
    }


    method _validate {} {
        my prepare id -toupper -required -type payload
    }

    method _execute {{flunky ""}} {
        my setundo [payload mutate delete $parms(id)]
    }
}

# PAYLOAD:STATE
#
# Sets a payload's state.  Note that this order isn't intended
# for use with a dialog.

myorders define PAYLOAD:STATE {
    meta title "Set Payload State"

    meta sendstates PREP
    
    meta parmlist {id state}

    meta form {
        rcc "Payload ID:" -for id
        payload id -context yes

        rcc "State:" -for state
        text state
    }


    method _validate {} {
        my prepare id     -required          -type payload
        my prepare state  -required -tolower -type epayload_state
    }

    method _execute {{flunky ""}} {
        my setundo [payload mutate state $parms(id) $parms(state)]
    }
}

