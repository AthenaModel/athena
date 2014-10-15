#-----------------------------------------------------------------------
# TITLE:
#    snapshot.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_cellide(n) snapshot ensemble.
#
#    This module manages the cellmodel snapshots for the application.  A
#    snapshot is a cell/value dictionary that represents one value of the
#    model as a whole.  Snapshots are produced as a byproduct of working
#    with the cellmodel; they are not saved with the cellmodel, though
#    particular snapshots can be imported and exported.
#
#    Each snapshot has a short, symbolic name (used in URLs), a longer
#    human-readable name, and a timestamp, in addition to its cell/value
#    dictionary.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# snapshot ensemble

snit::type snapshot {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Variables

    # timeFmt: Time stamp display format
    typevariable timeFmt "%I:%M:%S %p"

    # info array: Miscellaneous data
    #
    # impCounter  - Counter used to generate import IDs
    # imports     - List of IDs of imported snapshots, in order of creation.
    # solCounter  - Counter used to generate solution IDs
    # solutions   - List of IDs of solution snapshots, in order of
    #               creation.

    typevariable info -array {
        impCounter 0
        imports    {}
        solCounter 0
        solutions  {}
    }

    # snapshots: nested dictionary of snapshot data.
    #
    #   id -> snapshot dict -> {id stype longname t vdict}
    #
    # id       - The snapshot's unique ID
    # stype    - Snapshot type; an esnapshottype(n) value.
    # longname - The snapshot's human readable name
    # t        - Time in seconds of snapshot's creation
    # vdict    - cell name/value dictionary

    typevariable snapshots {}



    #-------------------------------------------------------------------
    # Public Type Methods

    # init
    #  
    # Initializes the module, setting up notifier bindings so that
    # most snapshots are created automatically.

    typemethod init {} {
        notifier bind ::cmscript <New>   $type [mytypemethod SnapshotClear]
        notifier bind ::cmscript <Open>  $type [mytypemethod SnapshotClear]
        notifier bind ::cmscript <Check> $type [mytypemethod SnapshotCheck]
    }

    # save stype vdict
    #
    # stype - The snapshot type, an esnapshottype(n) value
    # vdict - The cell name/value dictionary.
    # 
    # Fills in the snapshot directory, and saves it as appropriate
    # for the snapshot type.
    #
    # For the import type, there's the timestamped import, plus
    # the "lastimp" snapshot.
    #
    # For the model type, there's only one snapshot: the current set
    # of values as defined in the model.
    #
    # For the solution type, there's the timestamped solution, plus
    # the "lastsol" snapshot.
    #
    # Returns the ID of the saved snapshot

    typemethod save {stype vdict} {
        set sdict [dict create]
        set t     [clock seconds]
        set stamp [clock format $t -format $timeFmt] 

        dict set sdict stype $stype
        dict set sdict t     [clock seconds]
        dict set sdict vdict $vdict

        switch -exact -- $stype {
            import {
                # FIRST, save this solution
                set counter [incr info(impCounter)]

                set id "imp$counter"
                lappend info(imports) $id

                dict set sdict id $id
                dict set sdict longname "Import $counter ($stamp)"
                dict set snapshots $id $sdict

                # NEXT, save the "lastimp" import
                dict set sdict id lastimp
                dict set sdict longname "Last Import ($stamp)"
                dict set snapshots lastimp $sdict
                
            }
            model {
                set id model
                dict set sdict id model
                dict set sdict longname "Model ($stamp)"
                dict set snapshots model $sdict
            }
            solution {
                # FIRST, save this solution
                set counter [incr info(solCounter)]

                set id "sol$counter"
                lappend info(solutions) $id

                dict set sdict id       $id
                dict set sdict longname "Solution $counter ($stamp)"
                dict set snapshots $id $sdict

                # NEXT, save the "lastsol" solution
                dict set sdict id lastsol
                dict set sdict longname "Last Solution ($stamp)"
                dict set snapshots lastsol $sdict
            }
            default {
                error "Unknown solution type: \"$stype\""
            }
        }

        return $id
    }

    # names
    #
    # Returns a list of the valid snapshot names, including magic names
    # "current" and "last"

    typemethod names {} {
        set names [list]

        # FIRST, if the model hasn't been successfully checked, there are
        # no valid snapshots.
        if {[cmscript checkstate] ni {insane checked}} {
            return ""
        }

        # NEXT, add "model".
        if {[dict exists $snapshots model]} {
            lappend names model
        }

        # NEXT, add "current", which is purely magic; it's whatever is
        # in the cellmodel at the moment.
        lappend names current

        # NEXT, add the most recent solution, if any. 
        if {[dict exists $snapshots lastsol]} {
            lappend names lastsol
        }

        # NEXT, add the most recent import, if any.
        if {[dict exists $snapshots lastimp]} {
            lappend names lastimp
        }

        # NEXT, add the imports, most recent first
        if {[llength $info(imports)] > 0} {
            set names [concat $names [lreverse $info(imports)]]
        }

        # NEXT, add the solutions, most recent first
        if {[llength $info(solutions)] > 0} {
            set names [concat $names [lreverse $info(solutions)]]
        }

        return $names
    }

    # validate id
    #
    # Validates a snapshot ID.

    typemethod validate {id} {
        if {$id ni [$type names]} {
            throw INVALID "Unknown snapshot: \"$id\""
        }

        return $id
    }

    # namedict
    #
    # Returns an id/longname dictionary.

    typemethod namedict {} {
        set result [list]

        foreach id [$type names] {
            lappend result $id [$type longname $id]
        }

        return $result
    }

    # longname id
    #
    # id    - A snapshot ID, or "current".
    #
    # Returns the snapshot's longname.

    typemethod longname {id} {
        if {$id eq "current"} {
            set t [clock seconds]
            return "Current Values ([clock format $t -format $timeFmt])"
        }

        if {![dict exists $snapshots $id]} {
            error "No such snapshot: \"$id\""
        }

        return [dict get $snapshots $id longname] 
    }

    # get id
    #
    # id    - A snapshot ID, or "current".
    #
    # Returns the snapshot's vdict given its ID.  Handles the magic 
    # "current" ID.

    typemethod get {id} {
        if {$id eq "current"} {
            return [cm get]
        }

        if {![dict exists $snapshots $id]} {
            error "No such snapshot: \"$id\""
        }

        return [dict get $snapshots $id vdict] 
    }

    # export id filename
    #
    # id        - Snapshot ID
    # filename  - File name
    #
    # Writes the snapshot to the named file.

    typemethod export {id filename} {
        set vdict [$type get $id]

        set f [open $filename w]
        dict for {cell value} $vdict {
            puts $f "$cell $value"
        }
        close $f
    }

    # import filename
    #
    # filename  - File name
    #
    # Reads the snapshot from the file.

    typemethod import {filename} {
        # FIRST, read the data.
        set f [open $filename r]
        set vdict [read $f]
        close $f

        # NEXT, make sure that all of the cell names are known.
        foreach cell [dict keys $vdict] {
            if {$cell ni [cm cells]} {
                throw INVALID "Unknown cell in snapshot file: \"$cell\""
            }
        }

        # Save the snapshot
        set id [$type save import $vdict]

        notifier send ::snapshot <Import>

        return $id
    }

    # last_import
    #
    # Returns the ID of the most recent import snapshot

    typemethod last_import {} {
        return [lindex $info(imports) end]
    }

    # last_solution
    #
    # Returns the ID of the most recent solution snapshot

    typemethod last_solution {} {
        return [lindex $info(solution) end]
    }

    #-------------------------------------------------------------------
    # Snapshot Handlers
    
    # SnapshotClear
    #
    # The model has changed, and the existing snapshots are invalid.

    typemethod SnapshotClear {} {
        set snapshots        [dict create]
        set info(impCounter) 0
        set info(imports)    [list]
        set info(solCounter) 0
        set info(solutions)  [list]
    }

    # SnapshotCheck
    #
    # Save the default initial conditions when the model is checked.

    typemethod SnapshotCheck {} {
        if {[cmscript checkstate] in {insane checked}} {
            $type save model [cm get]
            return
        }
    }

    # SnapshotSolve
    #
    # Save the default initial conditions when the model is checked.

    typemethod SnapshotSolve {} {
        if {[cmscript solvestate] eq "ok"} {
            $type save solution [cm get]
            return
        }
    }
}











