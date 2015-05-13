#-----------------------------------------------------------------------
# TITLE:
#    cap.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Communications Asset Package (CAP) manager.
#
#    This module is responsible for managing CAPs and the operations
#    upon them.
#
# TBD: Global refs: app/messagebox
#
#-----------------------------------------------------------------------

snit::type ::athena::cap {
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
    # Variables
    
    # access array: Array of access lists by CAP.  This array is used
    # transiently between [$adb cap access load]/[$adb cap access save] to record
    # who is being given access.

    variable access -array {}


    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.


    # names
    #
    # Returns the list of CAP names

    method names {} {
        return [$adb eval {
            SELECT k FROM caps 
        }]
    }

    # namedict
    #
    # Returns the ID/longname dictionary.

    method namedict {} {
        return [$adb eval {
            SELECT k, longname FROM caps ORDER BY k
        }]
    }


    # longnames
    #
    # Returns the list of CAP long names

    method longnames {} {
        return [$adb eval {
            SELECT k || ': ' || longname FROM caps
        }]
    }

    # validate k
    #
    # k   - Possibly, a CAP short name.
    #
    # Validates a CAP short name

    method validate {k} {
        if {![$adb exists {SELECT k FROM caps WHERE k=$k}]} {
            set names [join [$adb cap names] ", "]

            if {$names ne ""} {
                set msg "should be one of: $names"
            } else {
                set msg "none are defined"
            }

            return -code error -errorcode INVALID \
                "Invalid CAP, $msg"
        }

        return $k
    }

    # exists k
    #
    # k - A CAP ID.
    #
    # Returns 1 if there's such a CAP, and 0 otherwise.

    method exists {k} {
        $adb exists {
            SELECT * FROM caps WHERE k=$k
        }
    }

    # get id ?parm?
    #
    # k     - An k
    # parm  - An caps column name
    #
    # Retrieves a row dictionary, or a particular column value, from
    # caps.

    method get {k {parm ""}} {
        # FIRST, get the data
        $adb eval {
            SELECT * FROM caps 
            WHERE k=$k
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

    # hasaccess k a
    #
    # k  - A CAP ID
    # a  - An actor ID
    #
    # Returns 1 if a has access to k, and 0 otherwise.

    method hasaccess {k a} {
        expr {[info exists access($k)] && $a in $access($k)}
    }
    
    # nbcov validate id
    #
    # id     A cap_kn ID, [list $k $n]
    #
    # Throws INVALID if id doesn't name a cap_kn_view record.

    method {nbcov validate} {id} {
        lassign $id k n

        set k [$adb cap validate $k]
        set n [$adb nbhood validate $n]

        return [list $k $n]
    }

    # nbcov exists id
    #
    # id     A cap_kn ID, [list $k $n]
    #
    # Returns 1 if there's a record, and 0 otherwise.

    method {nbcov exists} {id} {
        lassign $id k n

        $adb exists {
            SELECT * FROM cap_kn WHERE k=$k AND n=$n
        }
    }

    
    # pen validate id
    #
    # id     A cap_kg ID, [list $k $g]
    #
    # Throws INVALID if id doesn't name a cap_kg_view record.

    method {pen validate} {id} {
        lassign $id k g

        set k [$adb cap validate $k]
        set g [$adb civgroup validate $g]

        return [list $k $g]
    }

    # pen exists id
    #
    # id     A cap_kg ID, [list $k $g]
    #
    # Returns 1 if there's a record, and 0 otherwise.

    method {pen exists} {id} {
        lassign $id k g

        $adb exists {
            SELECT * FROM cap_kg WHERE k=$k AND g=$g
        }
    }

    #-------------------------------------------------------------------
    # Access
    #
    # The following routines are used to manage CAP access.

    # access load
    #
    # Initializes the working_cap_access table at the beginning of strategy 
    # execution.  By default, only the CAP actor has access.

    method {access load} {} {
        # FIRST, clear the access list; then give each owner access to his
        # CAPs.
        array unset access
        
        array set access [$adb eval {
            SELECT k, owner FROM caps
        }]
    }

    # access grant klist alist
    #
    # klist   - A list of CAPs
    # alist   - A list of actors
    #
    # Grants each listed actor access to each listed CAP.
    # The access thus granted will be saved to the caps_access
    # table by [access save].

    method {access grant} {klist alist} {
        foreach k $klist {
            foreach a $alist {
                ladd access($k) $a
            }
        }
    }

    # access save
    #
    # Saves the contents of the access array into
    # the cap_access table at the end of strategy execution.  The
    # actors in the table will have access for the following week.
    # Note that the access() array is the real control; the 
    # cap_access exists so that it can be queried when paused at the
    # end of the time step, and by conditions at the subsequent
    # strategy execution.

    method {access save} {} {
        $adb eval {DELETE FROM cap_access}

        foreach k [array names access] {
            foreach a $access($k) {
                $adb eval {INSERT INTO cap_access(k,a) VALUES($k,$a)}
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
    # parmdict  - A dictionary of CAP parms
    #
    #    k            - The CAP's ID
    #    longname     - The CAP's long name
    #    owner        - The CAP's owning actor
    #    capacity     - The CAP's capacity, 0.0 to 1.0
    #    cost         - The CAP's cost in $/message/week.
    #    nlist        - Neighborhoods with non-zero coverage.
    #    glist       - Civilian groups with non-zero penetration.
    #
    # Creates a CAP given the parms, which are presumed to be
    # valid.  Creating a CAP requires adding entries to the caps, 
    # cap_kn, and cap_kg tables.

    method create {parmdict} {
        dict with parmdict {
            # FIRST, Put the CAP in the database
            $adb eval {
                INSERT INTO caps(k, longname, owner, capacity, cost)
                VALUES($k, 
                       $longname, 
                       nullif($owner,''), 
                       $capacity, 
                       $cost);
            }

            # NEXT, add the covered neighborhoods.  Coverage defaults to
            # 1.0.
            foreach n $nlist {
                $adb eval {
                    INSERT INTO cap_kn(k,n) VALUES($k,$n);
                }
            }

            # NEXT, add the group penetrations.  Penetration defaults to
            # 1.0.
            foreach g $glist {
                $adb eval {
                    INSERT INTO cap_kg(k,g) VALUES($k,$g);
                }
            }

            # NEXT, Return the undo command
            return [mymethod delete $k]
        }
    }

    # delete k
    #
    # k   - A CAP short name
    #
    # Deletes the CAP, including all references.

    method delete {k} {
        # FIRST, Delete the CAP, grabbing the undo information
        set data [$adb delete -grab caps {k=$k}]
        
        # NEXT, Return the undo script
        return [list $adb ungrab $data]
    }

    # update parmdict
    #
    # parmdict   - A dictionary of CAP parms
    #
    #    k            - A CAP short name
    #    longname     - A new long name, or ""
    #    owner        - A new owning actor, or ""
    #    capacity     - A new capacity, or ""
    #    cost         - A new cost, or ""
    #
    # Updates a cap given the parms, which are presumed to be
    # valid.

    method update {parmdict} {
        dict with parmdict {
            # FIRST, grab the CAP data that might change.
            set data [$adb grab caps {k=$k}]

            # NEXT, Update the CAP
            $adb eval {
                UPDATE caps
                SET longname   = nonempty($longname,     longname),
                    owner      = nonempty($owner,        owner),
                    capacity   = nonempty($capacity,     capacity),
                    cost       = nonempty($cost,         cost)
                WHERE k=$k;
            } 

            # NEXT, Return the undo command
            return [list $adb ungrab $data]
        }
    }

    # nbcov create parmdict
    #
    # parmdict  - A dictionary of cap_kn parms
    #
    #    id     - list {k n}
    #    nbcov  - The overridden neighborhood coverage
    #
    # Creates an nbcov record given the parms, which are presumed to be
    # valid.

    method {nbcov create} {parmdict} {
        dict with parmdict {
            lassign $id k n

            # FIRST, default nbcov to 1.0
            if {$nbcov eq ""} {
                set nbcov 1.0
            }

            # NEXT, Put the record into the database
            $adb eval {
                INSERT INTO 
                cap_kn(k,n,nbcov)
                VALUES($k, $n, $nbcov);
            }

            # NEXT, Return the undo command
            return [list $adb delete cap_kn "k='$k' AND n='$n'"]
        }
    }

    # nbcov delete id
    #
    # id   - list {k n}
    #
    # Deletes the override.

    method {nbcov delete} {id} {
        lassign $id k n

        # FIRST, delete the records, grabbing the undo information
        set data [$adb delete -grab cap_kn {k=$k AND n=$n}]

        # NEXT, Return the undo script
        return [list $adb ungrab $data]
    }


    # nbcov update parmdict
    #
    # parmdict   - A dictionary of cap_kn parms
    #
    #    id           - list {k n}
    #    nbcov        - A new neighborhood coverage, or ""
    #
    # Updates a cap_kn given the parms, which are presumed to be
    # valid.

    method {nbcov update} {parmdict} {
        dict with parmdict {
            lassign $id k n

            # FIRST, grab the data that might change.
            set data [$adb grab cap_kn {k=$k AND n=$n}]

            # NEXT, Update the cap_kn
            $adb eval {
                UPDATE cap_kn
                SET nbcov = nonempty($nbcov, nbcov)
                WHERE k=$k AND n=$n
            } 

            # NEXT, Return the undo command
            return [list $adb ungrab $data]
        }
    }

    # pen create parmdict
    #
    # parmdict  - A dictionary of cap_kg parms
    #
    #    id     - list {k g}
    #    pen    - The overridden group penetration
    #
    # Creates a pen record given the parms, which are presumed to be
    # valid.

    method {pen create} {parmdict} {
        dict with parmdict {
            lassign $id k g

            # FIRST, default pen to 1.0
            if {$pen eq ""} {
                set pen 1.0
            }

            # NEXT, Put the record into the database
            $adb eval {
                INSERT INTO 
                cap_kg(k,g,pen)
                VALUES($k, $g, $pen);
            }

            # NEXT, Return the undo command
            return [list $adb delete cap_kg "k='$k' AND g='$g'"]
        }
    }

    # pen delete id
    #
    # id   - list {k g}
    #
    # Deletes the override.

    method {pen delete} {id} {
        lassign $id k g

        # FIRST, delete the records, grabbing the undo information
        set data [$adb delete -grab cap_kg {k=$k AND g=$g}]

        # NEXT, Return the undo script
        return [list $adb ungrab $data]
    }

    # pen update parmdict
    #
    # parmdict   - A dictionary of cap_kg parms
    #
    #    id    - list {k g}
    #    pen   - A new group coverage, or ""
    #
    # Updates a cap_kg given the parms, which are presumed to be
    # valid.

    method {pen update} {parmdict} {
        dict with parmdict {
            lassign $id k g

            # FIRST, grab the data that might change.
            set data [$adb grab cap_kg {k=$k AND g=$g}]

            # NEXT, Update the cap_kg
            $adb eval {
                UPDATE cap_kg
                SET pen = nonempty($pen, pen)
                WHERE k=$k AND g=$g;
            } 

            # NEXT, Return the undo command
            return [list $adb ungrab $data]
        }
    }
}    

#-------------------------------------------------------------------
# Orders: CAP:*

# CAP:CREATE
#
# Creates new CAPs.

::athena::orders define CAP:CREATE {
    meta title "Create Comm. Asset Package"
    
    meta sendstates PREP 

    meta parmlist {
        k 
        longname
        owner
        {capacity 1.0}
        {cost 0}
        nlist
        glist
    }

    meta form {
        rcc "CAP:" -for k
        text k

        rcc "Long Name:" -for longname
        longname longname

        rcc "Owning Actor:" -for owner
        actor owner

        rcc "Capacity:" -for capacity
        frac capacity -defvalue 1.0

        rcc "Cost:" -for cost
        text cost -defvalue 0
        label "$/message/week"

        rcc "Neighborhoods:" -for nlist
        nlist nlist

        rcc "Civ. Groups:" -for glist
        civlist glist
    }


    method _validate {} {
        my prepare k           -toupper   -required -type ident
        my unused k
        my prepare longname    -normalize
        my prepare owner       -toupper   -required -type [list $adb actor]
        my prepare capacity    -num       -required -type rfraction
        my prepare cost        -toupper   -required -type money
        my prepare nlist       -toupper             -listof [list $adb nbhood]
        my prepare glist       -toupper             -listof [list $adb civgroup]
    }

    method _execute {{flunky ""}} {
        if {$parms(longname) eq ""} {
            set parms(longname) $parms(k)
        }
        lappend undo [$adb cap create [array get parms]]
    
        my setundo [join $undo \n]
    }
}

# CAP:DELETE

::athena::orders define CAP:DELETE {
    meta title "Delete Comm. Asset Package"
    meta sendstates PREP

    meta parmlist {k}

    method _validate {} {
        my prepare k -toupper -required -type [list $adb cap]
    }

    method _execute {{flunky ""}} {
        lappend undo [$adb cap delete $parms(k)]
    
        my setundo [join $undo \n]
    }
}


# CAP:UPDATE
#
# Updates existing CAPs.

::athena::orders define CAP:UPDATE {
    meta title "Update Comm. Asset Package"
    meta sendstates PREP 

    meta parmlist {
        k
        longname
        owner
        capacity
        cost
    }

    meta form {
        rcc "Select CAP:" -for k
        dbkey k -table fmt_caps -keys k \
            -loadcmd {$order_ keyload k *}

        rcc "Long Name:" -for longname
        longname longname

        rcc "Owning Actor:" -for owner
        actor owner

        rcc "Capacity:" -for capacity
        frac capacity

        rcc "Cost:" -for cost
        text cost
        label "$/message/week"
    }


    method _validate {} {
        my prepare k           -toupper   -required -type [list $adb cap]
        my prepare longname    -normalize
        my prepare owner       -toupper             -type [list $adb actor]
        my prepare capacity    -num                 -type rfraction
        my prepare cost        -toupper             -type money
    }

    method _execute {{flunky ""}} {
        set undo [list]
        lappend undo [$adb cap update [array get parms]]
    
        my setundo [join $undo \n]
    }
}

# CAP:UPDATE:MULTI
#
# Updates multiple CAPs.

::athena::orders define CAP:UPDATE:MULTI {
    meta title "Update Multiple CAPs"
    meta sendstates PREP

    meta parmlist {
        ids
        owner
        capacity
        cost
    }

    meta form {
        rcc "CAPs:" -for ids
        dbmulti ids -table fmt_caps -key k \
            -loadcmd {$order_ multiload ids *}

        rcc "Owning Actor:" -for owner
        actor owner

        rcc "Capacity:" -for capacity
        frac capacity

        rcc "Cost:" -for cost
        text cost
        label "$/message/week"
    }


    method _validate {} {
        my prepare ids         -toupper  -required -listof [list $adb cap]
        my prepare owner       -toupper            -type   [list $adb actor]
        my prepare capacity    -num                -type   rfraction
        my prepare cost        -toupper            -type   money
    }

    method _execute {{flunky ""}} {
        # FIRST, clear parameters expected by mutator
        set parms(longname) ""
    
        set undo [list]
    
        foreach parms(k) $parms(ids) {
            lappend undo [$adb cap update [array get parms]]
        }
    
        my setundo [join $undo \n]
    }
}

# CAP:CAPACITY
#
# Updates the capacity of an existing CAP.

::athena::orders define CAP:CAPACITY {
    meta title "Set CAP Capacity"
    meta sendstates {PREP PAUSED TACTIC}

    meta parmlist {
        k 
        capacity
    }

    meta form {
        rcc "Select CAP:" -for k
        dbkey k -table fmt_caps -keys k \
            -loadcmd {$order_ keyload k *}

        rcc "Capacity:" -for capacity
        frac capacity
    }


    method _validate {} {
        my prepare k           -toupper   -required -type [list $adb cap]
        my prepare capacity    -num                 -type rfraction
    }

    method _execute {{flunky ""}} {
        # FIRST, clear other parms expected by the mutator
        set parms(longname) ""
        set parms(owner)    ""
        set parms(cost)     ""
    
        set undo [list]
        lappend undo [$adb cap update [array get parms]]
    
        my setundo [join $undo \n]
    }
}

# CAP:CAPACITY:MULTI
#
# Updates capacity for multiple CAPs.

::athena::orders define CAP:CAPACITY:MULTI {
    meta title "Set Multiple CAP Capacities"
    meta sendstates {PREP PAUSED TACTIC}

    meta parmlist {
        ids
        capacity
    }

    meta form {
        rcc "CAPs:" -for ids 
        dbmulti ids -table fmt_caps -key k \
            -loadcmd {$order_ multiload ids *}

        rcc "Capacity:" -for capacity
        frac capacity
    }


    method _validate {} {
        my prepare ids         -toupper  -required -listof [list $adb cap]
        my prepare capacity    -num                -type   rfraction
    }

    method _execute {{flunky ""}} {
        # FIRST, clear other parms expected by the mutator
        set parms(longname) ""
    
        set undo [list]
    
        foreach parms(k) $parms(ids) {
            lappend undo [$adb cap update [array get parms]]
        }
    
        my setundo [join $undo \n]
    }
}


# CAP:NBCOV:SET
#
# Sets nbcov for k,n

::athena::orders define CAP:NBCOV:SET {
    meta title "Set CAP Neighborhood Coverage"
    meta sendstates {PREP PAUSED TACTIC}

    meta parmlist {
        id
        nbcov
    }

    meta form {
        rcc "CAP/Nbhood:" -for id
        dbkey id -table fmt_cap_kn -keys {k n} -labels {Of In} \
            -loadcmd {$order_ keyload id *}

        rcc "Coverage:" -for nbcov
        frac nbcov
    }


    method _validate {} {
        my prepare id       -toupper  -required -type [list $adb cap nbcov]
        my prepare nbcov    -num                -type rfraction
    }

    method _execute {{flunky ""}} {
        if {[$adb cap nbcov exists $parms(id)]} {
            if {$parms(nbcov) > 0.0} {
                my setundo [$adb cap nbcov update [array get parms]]
            } else {
                my setundo [$adb cap nbcov delete $parms(id)]
            }
        } else {
            my setundo [$adb cap nbcov create [array get parms]]
        }
    }
}


# CAP:NBCOV:SET:MULTI
#
# Updates nbcov for multiple k,n

::athena::orders define CAP:NBCOV:SET:MULTI {
    meta title "Set Multiple CAP Neighborhood Coverages"
    meta sendstates {PREP PAUSED TACTIC}

    meta parmlist {
        ids
        nbcov
    }

    meta form {
        rcc "IDs:" -for ids
        dbmulti ids -table fmt_cap_kn -key id \
            -loadcmd {$order_ multiload ids *}

        rcc "Coverage:" -for nbcov
        frac nbcov
    }


    method _validate {} {
        my prepare ids      -toupper  -required -listof [list $adb cap nbcov]
        my prepare nbcov    -num                -type rfraction
    }

    method _execute {{flunky ""}} {
        set undo [list]
    
        foreach parms(id) $parms(ids) {
            if {[$adb cap nbcov exists $parms(id)]} {
                if {$parms(nbcov) > 0.0} {
                    lappend undo [$adb cap nbcov update [array get parms]]
                } else {
                    lappend undo [$adb cap nbcov delete $parms(id)]
                }
            } else {
                lappend undo [$adb cap nbcov create [array get parms]]
            }
        }

        my setundo [join $undo \n]
    }
}

# CAP:PEN:SET
#
# Sets pen for k,n

::athena::orders define CAP:PEN:SET {
    meta title "Set CAP Group Penetration"
    meta sendstates {PREP PAUSED TACTIC}

    meta parmlist {
        id
        pen
    }

    meta form {
        rcc "CAP/Group:" -for id
        dbkey id -table fmt_capcov -keys {k g} -labels {Of Into} \
            -loadcmd {$order_ keyload id *}

        rcc "Penetration:" -for pen
        frac pen
    }


    method _validate {} {
        my prepare id     -toupper  -required -type [list $adb cap pen]
        my prepare pen    -num                -type rfraction
    }

    method _execute {{flunky ""}} {
        if {[$adb cap pen exists $parms(id)]} {
            if {$parms(pen) > 0.0} {
                my setundo [$adb cap pen update [array get parms]]
            } else {
                my setundo [$adb cap pen delete $parms(id)]
            }
        } else {
            my setundo [$adb cap pen create [array get parms]]
        }
    }
}


# CAP:PEN:SET:MULTI
#
# Updates pen for multiple k,g

::athena::orders define CAP:PEN:SET:MULTI {
    meta title "Set Multiple CAP Group Penetrations"
    meta sendstates {PREP PAUSED TACTIC}

    meta parmlist {
        ids
        pen
    }

    meta form {
        rcc "IDs:" -for ids
        dbmulti ids -table fmt_capcov -key id \
            -loadcmd {$order_ multiload ids *}

        rcc "Penetration:" -for pen
        frac pen
    }


    method _validate {} {
        my prepare ids  -toupper  -required -listof [list $adb cap pen]
        my prepare pen  -num                -type rfraction
    }

    method _execute {{flunky ""}} {
        set undo [list]
    
        foreach parms(id) $parms(ids) {
            if {[$adb cap pen exists $parms(id)]} {
                if {$parms(pen) > 0.0} {
                    lappend undo [$adb cap pen update [array get parms]]
                } else {
                    lappend undo [$adb cap pen delete $parms(id)]
                }
            } else {
                lappend undo [$adb cap pen create [array get parms]]
            }
        }
    
        my setundo [join $undo \n]
    }
}

