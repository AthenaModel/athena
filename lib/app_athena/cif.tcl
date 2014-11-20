#-----------------------------------------------------------------------
# TITLE:
#    cif.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Critical Input File manager.  Granted, it's now a 
#    database table rather than a file, but "cif" is hallowed by time.
#
#    This module is responsible for adding orders to the cif table and
#    for supporting application undo/redo.
#
#-----------------------------------------------------------------------

snit::type cif {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Uncheckpointed Type Variables

    # info  -- scalar data
    #
    # redoing    - If 1, we're in the middle of [cif redo].  If 0,
    #              we're not.
    #
    # redoStack  - Stack of redo records.  Item "end" is the head of the
    #              stack.  The variable contains the empty list if there
    #              is nothing to redo.  Each record is a dictionary
    #              containing one item to redo.
    #
    # Redo Stack Records
    #
    # Every record has the following keys:
    #
    #   narrative - The text returned by [cif canredo] for use by the GUI.
    #   orders    - A list of name/parmdict pairs, in the order to be redone.

    typevariable info -array {
        redoing   0
        redoStack {}
    }


    #-------------------------------------------------------------------
    # Initialization

    typemethod init {} {
        log detail cif "init"

        # FIRST, prepare to receive events
        notifier bind ::scenario <Saving>  $type [mytypemethod ClearUndo]
        notifier bind ::sim      <Tick>    $type [mytypemethod ClearUndo]
        notifier bind ::sim      <DbSyncA> $type [mytypemethod DbSync]

        # NEXT, log that we're saved.
        log detail cif "init complete"
    }

    #-------------------------------------------------------------------
    # Event handlers

    # ClearUndo
    #
    # Clears all undo information, and gets rid of undone orders that
    # are waiting to be redone

    typemethod ClearUndo {} {
        # FIRST, clear the undo information from the cif table.
        rdb eval {
            DELETE FROM cif WHERE kind != 'order';
            UPDATE cif SET undo='';
        }

        # NEXT, get rid of the redo stack.
        set info(redoStack) [list]

        notifier send ::cif <Update>
    }

    # DbSync
    #
    # Syncs the CIF stack with the database.

    typemethod DbSync {} {
        # FIRST, clear the redoStack.
        set info(redoStack) [list]
    }

    #-------------------------------------------------------------------
    # Public Typemethods

    # clear
    #
    # Clears all data from the CIF.

    typemethod clear {} {
        set info(redoStack) [list]
        rdb eval {DELETE FROM cif}
    }

    # startblock narrative
    #
    # narrative - Narrative text for the block as a whole.
    #
    # Begins a block of orders to be undone and redone together.

    typemethod startblock {narrative} {
        rdb eval {
            INSERT INTO cif(time,kind,narrative)
            VALUES(now(), 'start', $narrative);
        }
    }

    # endblock narrative
    #
    # narrative - Narrative text for the block as a whole.
    #
    # Ends a block of orders to be undone and redone together.

    typemethod endblock {narrative} {
        # FIRST, verify that there's a matching start block
        set found 0

        rdb eval {
            SELECT * FROM cif
            WHERE kind != 'order'
            ORDER BY id DESC
            LIMIT 1
        } row {
            if {$row(kind) eq "start" && $row(narrative) eq $narrative } {
                set found 1
            }
        }

        if {!$found} {
            error "Start marker not found for block <$narrative>"
        }

        # NEXT, add the end block.
        rdb eval {
            INSERT INTO cif(time,kind,narrative)
            VALUES(now(), 'end', $narrative);
        }
    }

    # transaction narrative script
    #
    # narrative   - A startblock/endblock narrative string
    # script      - A script that will send multiple orders.
    #
    # Executes the script, enclosing it in startblock/endblock.
    # If there is an error, the block is closed and any successful
    # orders are undone; then the error is rethrown.

    typemethod transaction {narrative script} {
        # FIRST, start the block.
        cif startblock $narrative

        # NEXT, execute the script
        set code [catch {
            uplevel 1 $script
        } result eopts]

        # NEXT, close the block
        cif endblock $narrative

        # NEXT, if there was an error, undo the successful orders,
        # and clear the redo stack: you can't redo the error.
        if {$code} {
            cif undo
            set info(redoStack) [list]

            return {*}$eopts $result 
        } else {
            return $result
        }
    }

    # add order parmdict ?undo? ?redo?
    #
    # order      The name of the order to be saved
    # parmdict   The order's parameter dictionary
    # undo       A script that will undo the order
    # redo       A script that prepares for redoing the order.
    #
    # Saves the order in the CIF.

    typemethod add {order parmdict {undo ""} {redo ""}} {
        # FIRST, clear the redo stack, unless we're redoing an order.
        # In that case, [cif redo] has already made the necessary
        # changes.
        if {!$info(redoing)} {
            set info(redoStack) [list]
        }
        
        # NEXT, insert the new order.
        set now [simclock now]

        set narrative [order narrative $order $parmdict]

        rdb eval {
            INSERT INTO cif(time,name,narrative,parmdict,undo,redo)
            VALUES($now, $order, $narrative, $parmdict, $undo,$redo);
        }

        notifier send ::cif <Update>
    }

    # top
    #
    # Returns the ID of the top entry in the CIF, or "" if none.

    typemethod top {} {
        rdb eval {
            SELECT max(id) AS top FROM cif
        } {
            return $top
        }

        return ""
    }

    # canundo
    #
    # If the top order on the stack can be undone, returns its title;
    # and "" otherwise.

    typemethod canundo {} {
        # FIRST, we can only undo when the simulation is "stable", i.e.,
        # when normal orders are possible.
        if {![sim stable]} {
            return ""
        }

        # NEXT, get the undo information
        set top [cif top]

        if {$top eq ""} {
            return ""
        }

        rdb eval {
            SELECT kind,
                   narrative,
                   coalesce(undo,'') == '' AS noUndo
            FROM cif 
            WHERE id=$top
        } {
            if {$kind eq "order" && $noUndo} {
                return ""
            }

            return $narrative
        }

        return ""
    }

    # undo ?-test?
    #
    # -test        Throw an error instead of popping up a dialog.
    #
    # Undo the previous command, if possible.  If not, throw an
    # error.

    typemethod undo {{opt ""}} {
        # FIRST, set testflag
        let testflag {$opt eq "-test"}

        # NEXT, can we undo?
        if {[cif canundo] eq ""} {
            error "Nothing to undo."
        }

        # NEXT, Handle the undo based on what's on top of the stack.
        set id [cif top]
        set kind [rdb onecolumn {
            SELECT kind FROM cif WHERE id=$id
        }]

        if {$kind eq "order"} {
            $type UndoOneOrder $testflag
        } else {
            $type UndoOneBlock $testflag
        }
    }

    # UndoOneBlock testflag
    # 
    # testflag   - If true, rethrow errors.  Otherwise, report to GUI.
    #
    # Undoes one block of orders from end to start, placing the block on
    # the redo stack.

    typemethod UndoOneBlock {testflag} {
        # FIRST, there's a block of orders on top of the stack.
        # Get the id of the start of the block.
        rdb eval {
            SELECT id        AS start,
                   narrative AS narrative 
            FROM cif
            WHERE kind = 'start'
            ORDER BY id DESC
            LIMIT 1
        } {}

        # NEXT, undo the orders.
        foreach id [rdb eval {
            SELECT id FROM cif
            WHERE id > $start AND kind == 'order'
            ORDER BY id DESC
        }] {
            if {![$type UndoOrder $id $testflag]} {
                return
            }
        }

        # NEXT, put the undo data on the redo stack.

        set record [dict create narrative $narrative]

        dict set record orders [rdb eval {
            SELECT name, parmdict, redo
            FROM cif
            WHERE id > $start AND kind == 'order'
            ORDER BY id ASC
        }]        

        lappend info(redoStack) $record

        # NEXT, delete the entries.
        rdb eval {
            DELETE FROM cif WHERE id >= $start
        }

        notifier send ::cif <Update>
        return
    }

    # UndoOneOrder testflag
    # 
    # testflag   - If true, rethrow errors.  Otherwise, report to GUI.
    #
    # Undo the order on the top of the stack, handling undo errors.
    # Delete the undo order from the undo stack, and add it to the
    # redo stack.

    typemethod UndoOneOrder {testflag} {
        # FIRST, get the order to undo.
        set id [cif top]

        # NEXT, get the undo information
        rdb eval {
            SELECT id, name, narrative, parmdict, undo, redo
            FROM cif 
            WHERE id=$id
        } {}

        # NEXT, undo the order; add it do the redo stack on
        # success.

        if {[$type UndoOrder $id $testflag]} {
            # FIRST, delete the entry; we're done with it.
            rdb eval {
                DELETE FROM cif WHERE id = $id
            }

            # NEXT, add it to the redo stack.
            set record [dict create                \
                 narrative $narrative              \
                 orders    [list $name $parmdict $redo]]

            lappend info(redoStack) $record

        }

        notifier send ::cif <Update>

        return
    }

    # UndoOrder id testflag
    #
    # id       - The ID of the entry to undo.
    # testflag - If 1, throw an error; otherwise, pop up a dialog.
    #
    # Undo the given order, handling errors.  Return 1 on success
    # and 0 on handled error.  (Rethrown errors naturally propagate
    # as errors.)

    typemethod UndoOrder {id testflag} {
        # FIRST, get the undo information
        rdb eval {
            SELECT id, name, narrative, parmdict, undo
            FROM cif 
            WHERE id=$id
        } {}

        # NEXT, Undo the order
        log normal cif "undo: $name $parmdict"

        if {[catch {
            rdb monitor transaction {
                uplevel \#0 $undo
            }
        } result opts]} {
            # FIRST, If we're testing, rethrow the error.
            if {$testflag} {
                return {*}$opts $result
            }

            # NEXT, Log all of the details
            set einfo [dict get $opts -errorinfo]

            log error cif [tsubst {
                |<--
                Error during undo (changes have been rolled back):

                Stack Trace:
                $einfo
            }]

            log error cif [tsubst {
                |<--
                CIF Dump:

                [cif dump]
            }]

            # NEXT, clear all undo information; we can't undo, and
            # we've logged the problem entry.
            $type ClearUndo

            # NEXT, tell the user what happened.
            app error {
                |<--
                Undo $name

                There was an unexpected error while undoing 
                this order.  The scenario has been rolled back 
                to its previous state, so the application data
                should not be corrupted.  However:

                * You should probably save the scenario under
                a new name, just in case.

                * The error has been logged in detail.  Please
                contact JPL to get the problem fixed. 
            }

            # NEXT, Reconfigure all modules from the database: 
            # this should clean up any problems in Tcl memory.
            sim dbsync

            return 0
        }

        return 1
    }

    # canredo
    #
    # If there's an undone order on the stack, returns its narrative;
    # and "" otherwise.

    typemethod canredo {} {
        # FIRST, we can only redo when the simulation is "stable", i.e.,
        # when normal orders are possible.
        if {![sim stable]} {
            return ""
        }

        # NEXT, get the redo information
        set record [lindex $info(redoStack) end]

        if {[dict size $record] > 0} {
            return [dict get $record narrative]
        }

        return ""
    }

    # redo
    #
    # Redo the previous command, if possible.  If not, throw an
    # error.

    typemethod redo {} {
        # FIRST, get the redo information
        set record [lindex $info(redoStack) end]
        set info(redoStack) [lrange $info(redoStack) 0 end-1]

        if {[dict size $record] == 0} {
            error "Nothing to redo"
        }

        # NEXT, Using try/finally might be overkill here, but it shouldn't
        # hurt anything.
        try {
            set info(redoing) 1
            bgcatch {
                $type RedoOrders $record
            }
        } finally {
            set info(redoing) 0
        }

        return
    }

    # RedoOrders record
    #
    # record   - A redo record
    #
    # Redoes the order or orders in the record.

    typemethod RedoOrders {record} {
        dict with record {}

        log normal cif "redo: $narrative"

        # Each order to be undone adds three elements to the list.
        set gotBlock [expr {[llength $orders] > 3}]

        if {$gotBlock} {
            $type startblock $narrative
        }

        foreach {name parmdict redo} $orders {
            if {$redo ne ""} {
                uplevel #0 $redo
            }
            order send gui $name $parmdict
        }

        if {$gotBlock} {
            $type endblock $narrative
        }
    }

    # dump ?-count n?"
    #
    # -count n     Number of entries to dump, starting from the most recent.
    #              Defaults to 1
    #
    # Returns a dump of the CIF in human-readable form.  Defaults to
    # the entry on the top of the stack.

    typemethod dump {args} {
        # FIRST, get the options
        array set opts {
            -count 1
        }

        while {[llength $args] > 0} {
            set opt [lshift args]

            switch -exact -- $opt {
                -count {
                    set opts(-count) [lshift args]
                }

                default {
                    error "Unrecognized option: \"$opt\""
                }
            }
        }

        require {$opts(-count) > 0} "-count is less than 1."

        set result [list]

        rdb eval [tsubst {
            SELECT * FROM cif
            ORDER BY id DESC
            LIMIT $opts(-count)
        }] row {
            # FIRST, handle markers
            if {$row(kind) ne "order"} {
                lappend result \
                    "Marker: $row(id) $row(kind) <$row(narrative)> @ $row(time)\n"
                continue
            }

            # NEXT, handler orders.
            set out "\#$row(id) $row(name) @ $row(time): \n"


            append out "Parameters:\n"

            # Get the width of the longest parameter name, plus the colon.
            set wid [lmaxlen [dict keys $row(parmdict)]]
            incr wid 

            set parmlist [order parms $row(name)]

            foreach parm [order parms $row(name)] {
                if {[dict exists $row(parmdict) $parm]} {
                    set value [dict get $row(parmdict) $parm]
                    append out [format "    %-*s %s\n" $wid $parm: $value]
                }
            }

            if {$row(undo) ne ""} {
                append out "Undo Script:\n"
                foreach line [split $row(undo) "\n"] {
                    append out "    $line\n"
                }
            }

            if {$row(redo) ne ""} {
                append out "Redo Script:\n"
                foreach line [split $row(redo) "\n"] {
                    append out "    $line\n"
                }
            }

            lappend result $out
        }

        return [join $result "\n"]
    }
}



