#-----------------------------------------------------------------------
# TITLE:
#    payload.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Payload Manager
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
#    * scenario(n) defines a view for each payload type,
#      payloads_<type>.
#
# PARAMETER MAPPING:
#
#  COOP Payloads:    HREL Payloads:  SAT Payloads:   VREL Payloads:
#    g    <= g         g   <= g        c   <= c        a   <= a
#    mag  <= mag       mag <= mag      mag <= mag      mag <= mag
# 
#-----------------------------------------------------------------------

snit::type ::athena::payload {
    #-------------------------------------------------------------------
    # Components
    component  adb;# The athenadb(n) Instance

    #===================================================================
    # Lookup tables

    # optParms: This variable is a dictionary of all optional parameters
    # with empty values.  The create and update mutators can merge the
    # input parmdict with this to get a parmdict with the full set of
    # parameters.

    variable optParms {
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

    variable tinfo -array {
        names {COOP HREL SAT VREL}
    }

    constructor {adb_} {
        set adb $adb_
    }

    # typenames
    #
    # Returns the payload type names.
    
    method typenames {} {
        return [lsort $tinfo(names)]
    }
    
    #-------------------------------------------------------------------
    # Sanity Check

    # checker f
    #
    # f    - A failurelist object
    #
    # Computes the sanity check, adding failures to the failure list
    # object.
    #
    # Note: This checker is called from [iom checker], not from
    # [sanity *].

    method checker {f} {
        # FIRST, clear the invalid states, since we're going to 
        # recompute them.

        $adb eval {
            UPDATE payloads
            SET state = 'normal'
            WHERE state = 'invalid';
        }

        # NEXT, identify the invalid payloads.
        set badlist [list]

        $adb eval {
            SELECT * FROM payloads
        } row {
            set ptype [string tolower $row(payload_type)]
            set result [$self $ptype check [array get row]]

            if {$result ne ""} {
                lappend badlist $row(iom_id) $row(payload_num)

                $f add warning \
                    payload.$row(payload_type) \
                    payload/$row(iom_id)/$row(payload_num) \
                    $result
            }
        }

        # NEXT, mark the bad payloads invalid.
        foreach {iom_id payload_num} $badlist {
            $adb eval {
                UPDATE payloads
                SET state = 'invalid'
                WHERE iom_id=$iom_id AND payload_num=$payload_num 
            }
        }

        $adb notify payload <Check>
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

    method validate {id} {
        lassign $id iom_id payload_num

        $adb iom validate $iom_id

        if {![$self exists $id]} {
            set nums [$adb eval {
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

    method exists {id} {
        lassign $id iom_id payload_num

        return [$adb exists {
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

    method get {id {parm ""}} {
        lassign $id iom_id payload_num

        # FIRST, get the data
        $adb eval {
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

    # create parmdict
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

    method create {parmdict} {
        # FIRST, make sure the parm dict is complete
        set parmdict [dict merge $optParms $parmdict]

        # NEXT, compute the narrative string.
        set ptype [string tolower [dict get $parmdict payload_type]]
        set narrative [$self $ptype narrative $parmdict]

        # NEXT, put the payload in the database.
        dict with parmdict {
            # FIRST, get the payload number for this IOM.
            $adb eval {
                SELECT coalesce(max(payload_num)+1,1) AS payload_num
                FROM payloads
                WHERE iom_id=$iom_id
            } {}

            # NEXT, Put the payload in the database
            $adb eval {
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
            return [list $adb delete payloads \
                "iom_id='$iom_id' AND payload_num=$payload_num"]
        }
    }

    # delete id
    #
    # id     a payload ID, {iom_id payload_num}
    #
    # Deletes the payload.  Note that deleting a payload leaves a 
    # gap in the priority order, but doesn't change the order of
    # the remaining payloads; hence, we don't need to worry about it.

    method delete {id} {
        lassign $id iom_id payload_num

        # FIRST, get the undo information
        set data [$adb delete -grab payloads \
            {iom_id=$iom_id AND payload_num=$payload_num}]

        # NEXT, Return the undo script
        return [list $adb ungrab $data]
    }

    # update parmdict
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

    method update {parmdict} {
        # FIRST, make sure the parm dict is complete
        set parmdict [dict merge $optParms $parmdict]

        # NEXT, save the changed data.
        dict with parmdict {
            lassign $id iom_id payload_num

            # FIRST, get the undo information
            set data [$adb grab payloads \
                {iom_id=$iom_id AND payload_num=$payload_num}]

            # NEXT, Update the payload.  The nullif(nonempty()) pattern
            # is so that the old value of the column will be used
            # if the input is empty, and that empty columns will be
            # NULL rather than "".
            $adb eval {
                UPDATE payloads
                SET a       = nullif(nonempty($a,   a),     ''),
                    c       = nullif(nonempty($c,   c),     ''),
                    g       = nullif(nonempty($g,   g),     ''),
                    mag     = nullif(nonempty($mag, mag),   '')
                WHERE iom_id=$iom_id AND payload_num=$payload_num
            } {}

            # NEXT, compute and set the narrative
            set pdict [$self get $id]
            set ptype [string tolower [dict get $pdict payload_type]]
            set narrative [$self $ptype narrative $pdict]

            $adb eval {
                UPDATE payloads
                SET    narrative = $narrative
                WHERE iom_id=$iom_id AND payload_num=$payload_num
            }

            # NEXT, Return the undo command
            return [list $adb ungrab $data]
        }
    }

    # state id state
    #
    # id     - The payload's ID, {iom_id payload_num}
    # state  - The payload's new epayload_state
    #
    # Updates a payload's state.

    method state {id state} {
        lassign $id iom_id payload_num

        # FIRST, get the undo information
        set data [$adb grab payloads \
            {iom_id=$iom_id AND payload_num=$payload_num}]

        # NEXT, Update the payload.
        $adb eval {
            UPDATE payloads
            SET state = $state
            WHERE iom_id=$iom_id AND payload_num=$payload_num
        }

        # NEXT, Return the undo command
        return [list $adb ungrab $data]
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

    method call {op pdict args} {
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

    method RequireType {payload_type id} {
        lassign $id iom_id payload_num
        
        if {[$adb onecolumn {
            SELECT payload_type FROM payloads 
            WHERE iom_id=$iom_id AND payload_num=$payload_num
        }] ne $payload_type} {
            return -code error -errorcode INVALID \
                "payload \"$id\" is not a $payload_type payload"
        }
    }
    #-------------------------------------------------------------------
    # coop subcommands
    #
    # See the payload(i) man page for the signature and general
    # description of each subcommand.

    method {coop narrative} {pdict} {
        dict with pdict {
            set points [format "%.1f" $mag]
            set symbol [qmag name $mag]
            return "Change cooperation with $g by $points points ($symbol)."
        }
    }

    method {coop check} {pdict} {
        set errors [list]

        dict with pdict {
            if {$g ni [$adb frcgroup names]} {
                lappend errors "Force group $g no longer exists."
            }
        }

        return [join $errors "  "]
    }

    #-------------------------------------------------------------------
    # hrel subcommands
    #
    # See the payload(i) man page for the signature and general
    # description of each subcommand.

    method {hrel narrative} {pdict} {
        dict with pdict {
            set points [format "%.1f" $mag]
            set symbol [qmag name $mag]
            return "Change horizontal relationships with $g by $points points ($symbol)."
        }
    }

    method {hrel check} {pdict} {
        set errors [list]

        dict with pdict {
            if {$g ni [$adb group names]} {
                lappend errors "Group $g no longer exists."
            }
        }

        return [join $errors "  "]
    }

    #-------------------------------------------------------------------
    # sat subcommands
    #
    # See the payload(i) man page for the signature and general
    # description of each subcommand.

    method {sat narrative} {pdict} {
        dict with pdict {
            set points [format "%.1f" $mag]
            set symbol [qmag name $mag]
            return "Change satisfaction with $c by $points points ($symbol)."
        }
    }

    method {sat check} {pdict} {
        # Trivially returns
        return {}
    }

    #-------------------------------------------------------------------
    # vrel subcommands
    #
    # See the payload(i) man page for the signature and general
    # description of each subcommand.

    method {vrel narrative} {pdict} {
        dict with pdict {
            set points [format "%.1f" $mag]
            set symbol [qmag name $mag]
            return "Change vertical relationships with $a by $points points ($symbol)."
        }
    }

    method {vrel check} {pdict} {
        set errors [list]

        dict with pdict {
            if {$a ni [$adb actor names]} {
                lappend errors "Actor $a no longer exists."
            }
        }

        return [join $errors "  "]
    }
}


#-----------------------------------------------------------------------
# Orders: PAYLOAD:*

# PAYLOAD:DELETE
#
# Deletes an existing payload, of whatever type.

::athena::orders define PAYLOAD:DELETE {
    # This order dialog isn't usually used.

    meta title "Delete Payload"
    meta sendstates PREP

    meta parmlist {id}

    meta form {
        rcc "Payload ID:" -for id
        payload id -context yes
    }


    method _validate {} {
        my prepare id -toupper -required -type [list $adb payload]
    }

    method _execute {{flunky ""}} {
        my setundo [$adb payload delete $parms(id)]
    }
}

# PAYLOAD:STATE
#
# Sets a payload's state.  Note that this order isn't intended
# for use with a dialog.

::athena::orders define PAYLOAD:STATE {
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
        my prepare id     -required          -type [list $adb payload]
        my prepare state  -required -tolower -type epayload_state
    }

    method _execute {{flunky ""}} {
        my setundo [$adb payload state $parms(id) $parms(state)]
    }
}

# PAYLOAD:COOP:CREATE
#
# Creates a new COOP payload.

::athena::orders define PAYLOAD:COOP:CREATE {
    meta title "Create Payload: Cooperation"

    meta sendstates PREP

    meta parmlist {iom_id longname g mag}

    meta form {
        rcc "Message ID:" -for iom_id
        text iom_id -context yes

        rcc "Description:" -for longname
        disp longname -width 60

        rcc "With Force Group:" -for g
        frcgroup g

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare iom_id   -toupper   -required -type [list $adb iom]
        my prepare g        -toupper   -required -type [list $adb frcgroup]
        my prepare mag -num -toupper   -required -type qmag
    }

    method _execute {{flunky ""}} {
        set parms(payload_type) COOP
        my setundo [$adb payload create [array get parms]]
    }
}

# PAYLOAD:COOP:UPDATE
#
# Updates existing COOP payload.

::athena::orders define PAYLOAD:COOP:UPDATE {
    meta title "Update Payload: Cooperation"
    meta sendstates PREP 

    meta parmlist {id longname g mag}

    meta form {
        rcc "Payload:" -for id
        dbkey id -context yes -table fmt_payloads_COOP \
            -keys {iom_id payload_num} \
            -loadcmd {$order_ keyload id {g mag}}

        rcc "Description:" -for longname
        disp longname -width 60

        rcc "With Force Group:" -for g
        frcgroup g

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare id         -required -type [list $adb payload]
        my prepare g          -toupper  -type [list $adb frcgroup]
        my prepare mag   -num -toupper  -type qmag
    }

    method _execute {{flunky ""}} {
        my setundo [$adb payload update [array get parms]]
    }
}

# PAYLOAD:HREL:CREATE
#
# Creates a new HREL payload.

::athena::orders define PAYLOAD:HREL:CREATE {
    meta title "Create Payload: Horizontal Relationship"

    meta sendstates PREP

    meta parmlist {iom_id longname g mag}

    meta form {
        rcc "Message ID:" -for iom_id
        text iom_id -context yes

        rcc "Description:" -for longname
        disp longname -width 60

        rcc "With Group:" -for g
        group g

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare iom_id   -toupper   -required -type [list $adb iom]
        my prepare g        -toupper   -required -type [list $adb group]
        my prepare mag -num -toupper   -required -type qmag
    }

    method _execute {{flunky ""}} {
        set parms(payload_type) HREL
    
        my setundo [$adb payload create [array get parms]]
    }
}

# PAYLOAD:HREL:UPDATE
#
# Updates existing HREL payload.

::athena::orders define PAYLOAD:HREL:UPDATE {
    meta title "Update Payload: Horizontal Relationship"
    meta sendstates PREP 

    meta parmlist {id longname g mag}

    meta form {
        rcc "Payload:" -for id
        dbkey id -context yes -table fmt_payloads_HREL \
            -keys {iom_id payload_num} \
            -loadcmd {$order_ keyload id {g mag}}

        rcc "Description:" -for longname
        disp longname -width 60

        rcc "With Group:" -for g
        group g

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare id         -required -type [list $adb payload]
        my prepare g          -toupper  -type [list $adb group]
        my prepare mag   -num -toupper  -type qmag
    }

    method _execute {{flunky ""}} {
        my setundo [$adb payload update [array get parms]]
    }
}

# PAYLOAD:SAT:CREATE
#
# Creates a new SAT payload.

::athena::orders define PAYLOAD:SAT:CREATE {
    meta title "Create Payload: Satisfaction"

    meta sendstates PREP

    meta parmlist {iom_id longname c mag}

    meta form {
        rcc "Message ID:" -for iom_id
        text iom_id -context yes

        rcc "Description:" -for longname
        disp longname -width 60

        rcc "With Concern:" -for c
        concern c

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare iom_id   -toupper   -required -type [list $adb iom]
        my prepare c        -toupper   -required -type econcern
        my prepare mag -num -toupper   -required -type qmag
    }

    method _execute {{flunky ""}} {
        set parms(payload_type) SAT
    
        my setundo [$adb payload create [array get parms]]
    }
}

# PAYLOAD:SAT:UPDATE
#
# Updates existing SAT payload.

::athena::orders define PAYLOAD:SAT:UPDATE {
    meta title "Update Payload: Satisfaction"
    meta sendstates PREP 

    meta parmlist {id longname c mag}

    meta form {
        rcc "Payload:" -for id
        dbkey id -context yes -table fmt_payloads_SAT \
            -keys {iom_id payload_num} \
            -loadcmd {$order_ keyload id {c mag}}

        rcc "Description:" -for longname
        disp longname -width 60

        rcc "With Concern:" -for c
        concern c

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare id         -required -type [list $adb payload]
        my prepare c          -toupper  -type econcern
        my prepare mag   -num -toupper  -type qmag
    }

    method _execute {{flunky ""}} {
        my setundo [$adb payload update [array get parms]]
    }
}

# PAYLOAD:VREL:CREATE
#
# Creates a new VREL payload.

::athena::orders define PAYLOAD:VREL:CREATE {
    meta title "Create Payload: Vertical Relationship"

    meta sendstates PREP

    meta parmlist {iom_id longname a mag}

    meta form {
        rcc "Message ID:" -for iom_id
        text iom_id -context yes

        rcc "Description:" -for longname
        disp longname -width 60

        rcc "With Actor:" -for a
        actor a

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare iom_id   -toupper   -required -type [list $adb iom]
        my prepare a        -toupper   -required -type [list $adb actor]
        my prepare mag -num -toupper   -required -type qmag
    }

    method _execute {{flunky ""}} {
        set parms(payload_type) VREL
    
        my setundo [$adb payload create [array get parms]]
    }
}

# PAYLOAD:VREL:UPDATE
#
# Updates existing VREL payload.

::athena::orders define PAYLOAD:VREL:UPDATE {
    meta title "Update Payload: Vertical Relationship"
    meta sendstates PREP 

    meta parmlist {id longname a mag}

    meta form {
        rcc "Payload:" -for id
        dbkey id -context yes -table fmt_payloads_VREL \
            -keys {iom_id payload_num} \
            -loadcmd {$order_ keyload id {a mag}}

        rcc "Description:" -for longname
        disp longname -width 60

        rcc "With Actor:" -for a
        actor a

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare id         -required -type [list $adb payload]
        my prepare a          -toupper  -type [list $adb actor]
        my prepare mag  -num  -toupper  -type qmag
    }

    method _execute {{flunky ""}} {
        my setundo [$adb payload update [array get parms]]
    }
}

