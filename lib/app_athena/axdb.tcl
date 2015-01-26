#-----------------------------------------------------------------------
# TITLE:
#    axdb.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Athena eXperiment DataBase manager
#
#-----------------------------------------------------------------------

snit::type axdb {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Components

    typecomponent db ;# The experimentdb(n) object
    

    #-------------------------------------------------------------------
    # Initialization

    typemethod init {} {
        log detail axdb "init"

        # Create the axdb object; but don't open a database.
        set db [experimentdb db]
    }

    #===================================================================
    # Public Methods
    #
    # These will mostly be used as executive commands.

    delegate typemethod eval  to db
    delegate typemethod query to db
    delegate typemethod safequery to db

    #-------------------------------------------------------------------
    # Experiment file management

    # create filename
    #
    # filename   - .axdb file name
    #
    # Creates a new .axdb with the given file name.

    typemethod create {filename} {
        # FIRST, close any existing axdb
        if {[$db isopen]} {
            $db close 
        }

        # NEXT, add the file type.
        if {[file extension $filename] eq ""} {
            append filename .axdb
        }

        # NEXT, open and clear it.
        $db open $filename
        $db clear

        $type AddFunctions

        return "Created [$db dbfile]"
    }

    # open filename
    #
    # filename   - .axdb file name
    #
    # Opens the named file, if it exists.

    typemethod open {filename} {
        # FIRST, close any existing axdb
        if {[$db isopen]} {
            $db close 
        }

        # NEXT, add the file type.
        if {[file extension $filename] eq ""} {
            append filename .axdb
        }

        # NEXT, does it exist?
        if {![file exists $filename]} {
            error "No such file: \"$filename\""
        }

        # NEXT, open it.
        $db open $filename

        $type AddFunctions

        return "Opened [$db dbfile]"
    }

    typemethod AddFunctions {} {
        $db function normalize ::marsutil::normalize
    }


    # clear
    #
    # Clear the open axdb

    typemethod clear {} {
        require {[$db isopen]} "No .axdb file is open."
        $db clear

        return "Cleared [$db dbfile]"
    }

    # close
    #
    # Close the open axdb

    typemethod close {} {
        require {[$db isopen]} "No .axdb file is open."
        set filename [$db dbfile]
        $db close

        return "Closed $filename"
    }

    #-------------------------------------------------------------------
    # Experiment definition
    

    # parm names
    #
    # Returns a list of the names of the defined parms.

    typemethod {parm names} {} {
        return [$db eval {SELECT name FROM case_parms ORDER BY name}]
    }

    # parm list
    #
    # Returns a table of the parameter names and docstrings.

    typemethod {parm list} {} {
        return [$db query {
            SELECT name as 'Parm', normalize(docstring) AS 'Description'
            FROM case_parms ORDER BY name
        } -maxcolwidth 50]
    }

    # parm define name docstring script
    #
    # name      - The parameter name
    # docstring - Human-readable description
    # script    - Executive script that sets the parameter value in the
    #             scenario. 
    #
    # Defines an experiment parameter.  The script may refer to the 
    # parameter as a Tcl variable.  If the parameter is already defined,
    # the old definition is replaced.

    typemethod {parm define} {name docstring script} {
        identifier validate $name

        $db eval {
            INSERT OR REPLACE INTO case_parms(name,docstring,script)
            VALUES($name,$docstring,$script)
        }
    }

    # parm dump ?name? 
    #
    # name   - A case parameter name
    #
    # Dumps info about each parm, or the given parm.

    typemethod {parm dump} {{name ""}} {
        set query {
            SELECT * FROM case_parms
        }

        if {$name ne ""} {
            append query {WHERE name=$name}
        }

        set output ""

        $db eval $query row {
            if {$output ne ""} {
                append output "\n"
            }

            append output \
                "$row(name): $row(docstring)\n" \
                "<<<\n[string trim $row(script)]\n>>>\n"
        }

        return $output
    }

    # case add parm value ?parm value...?
    # case add parmdict
    #
    # parm      - A case parameter name
    # value     - Its value
    # parmdict  - A dictionary of case parameter names and values
    #
    # Adds a case to the experiment.  The parameter names must be
    # defined.

    typemethod {case add} {args} {
        if {[llength $args] == 1} {
            set args [lindex $args 0]
        }

        foreach {parm value} $args {
            if {![$db exists {SELECT * FROM case_parms WHERE name=$parm}]} {
                error "No such case parameter: $parm"
            }
        }

        $db eval {
            INSERT INTO cases(case_dict) VALUES($args)
        }
    }

    # case dump id
    #
    # id   - A case ID
    #
    # Dumps info about the case.

    typemethod {case dump} {id} {
        set output ""
        $db eval {SELECT * FROM cases WHERE case_id=$id} row {
            append output "$row(case_id): $row(case_dict)\n"

            if {$row(outcome) ne ""} {
                append output "Outcome: $row(outcome)\n"
            }

            if {$row(context) ne ""} {
                append output "<<<\n$row(context)\n>>>\n"
            }

            return $output
        }

        return "No such case: $id"
    }

    # case list
    #
    # Lists the defined cases

    typemethod {case list} {} {
        return [$db query {
            SELECT case_id                  AS "ID",
                   coalesce(outcome, "n/a") AS "Outcome", 
                   case_dict                AS "Parms"
            FROM cases
            ORDER BY case_id
        }]
    }

    #-------------------------------------------------------------------
    # Experiment Execution

    # prepare case_id
    #
    # case_id     - The case to prepare for
    #
    # Prepares to run the given case: i.e., reverts to the base scenario,
    # and makes the changes specific to the given case.  

    typemethod prepare {case_id} {
        # FIRST, get the case.
        if {![$db exists {
            SELECT case_id FROM cases WHERE case_id=$case_id
        }]} {
            error "No such case: \"$case_id\""
        }

        set case_dict [$db onecolumn {
            SELECT case_dict FROM cases WHERE case_id=$case_id
        }]
        
        # NEXT, revert the scenario
        scenario revert

        # NEXT, if it's locked unlock it.
        if {[sim state] ne "PREP"} {
            sim mutate unlock
        }

        # NEXT, reset the executive, giving us a clean starting point
        # and loading any necessary executive scripts.
        executive reset

        # NEXT, run the case parm scripts
        array set cpscripts [$db eval {
            SELECT name, script FROM case_parms
        }]

        dict for {parm value} $case_dict {
            # FIRST, set the case parameters.  We'll do this each time,
            # in case a case-parm script changed one of the values.
            executive eval [list set case_dict $case_dict]
            executive eval {dict with case_dict {}}

            # NEXT, execute the case parm script
            if {[catch {executive eval $cpscripts($parm)} result eopts]} {
                return -code error {*}$eopts "Error in \"$parm\" script: $result"
            }
        }

        # NEXT, clear any results for this case.
        $db transaction {
            $db eval {
                UPDATE cases
                SET outcome = NULL,
                    context = NULL
                WHERE case_id = $case_id;
            }

            foreach table [$db tables] {
                # Skip non-history tables
                if {![string match {hist_*} $table]} {
                    continue
                }

                $db eval "DELETE FROM $table WHERE case_id = \$case_id"
            }
        }
    }


    # run ?options...?
    #
    #   -start case_id   - First case_id to run; defaults to 1
    #   -end case_id     - Last case_id to run; defaults to N
    #   -weeks weeks     - How many weeks to run; defaults to 1
    #
    # Runs the specified cases, and saves the results in the 
    # AXDB.  Leaves the scenario in its base state.

    typemethod run {args} {
        # FIRST, get the options
        set maxcase [$db onecolumn {SELECT count(*) FROM cases}]

        set opts(-start) 1
        set opts(-end)   $maxcase
        set opts(-weeks) 1

        while {[llength $args] > 0} {
            set opt [lshift args]
            switch -exact -- $opt {
                -start -
                -end   {
                    set value [lshift args]
                    snit::integer validate $value

                    if {$value < 1 || $value > $maxcase} {
                        error "expected a case ID between 1 and $maxcase"
                    }

                    set opts($opt) $value
                }
                -weeks {
                    set value [lshift args]
                    ipositive validate $value
                    set opts($opt) $value
                }
                default {
                    error "Unknown option: \"$opt\""
                }
            }
        }

        for {set id $opts(-start)} {$id <= $opts(-end)} {incr id} {
            profile $type RunCase $id $opts(-weeks)
        }
    }

    # runcase case_id ?options...?
    #
    # case_id   - The case to run
    # 
    #   -weeks weeks   - How many weeks to run; defaults to 1
    #
    # Runs the specified case, and saves the results in the 
    # AXDB.  Leaves the scenario with time advanced.

    typemethod runcase {case_id args} {
        # FIRST, get the options
        set opts(-weeks) 1

        while {[llength $args] > 0} {
            set opt [lshift args]
            switch -exact -- $opt {
                -weeks {
                    set value [lshift args]
                    ipositive validate $value
                    set opts($opt) $value
                }
                default {
                    error "Unknown option: \"$opt\""
                }
            }
        }

        profile $type RunCase $case_id $opts(-weeks)
    }

    # RunCase case_id weeks
    #
    # case_id   - The case to run
    # weeks     - The number of weeks to run for
    #
    # Runs the specified case, and saves the results in the 
    # AXDB.  Leaves the scenario with time advanced.

    typemethod RunCase {case_id weeks} {
        log normal axdb "Running case $case_id"
        # FIRST, prepare the case.
        $type prepare $case_id

        # NEXT, do the sanity check
        if {[sanity onlock check] != "OK"} {
            $type SetCaseOutcome $case_id FAILURE [sanity onlock text]
            return "FAILURE; see my://app/sanity/onlock."
        }

        # NEXT, lock the scenario
        if {[catch {
            flunky send private SIM:LOCK
        } result eopts]} {
            $type SetCaseOutcome $case_id ERROR [dict get $eopts -errorinfo]
            return "ERROR: case $case_id, $result"
        }

        # NEXT, run for the specified number of weeks
        if {[catch {
            flunky send private SIM:RUN -weeks $weeks -block 1
        } result eopts]} {
            $type SetCaseOutcome $case_id ERROR [dict get $eopts -errorinfo]
            return "ERROR: case $case_id, $result"
        }

        # NEXT, determine the outcome
        if {[sim stopreason] eq "OK"} {
            if {[catch {
                $type SetCaseOutcome $case_id OK {}
                $type SaveOutputs $case_id
            } result]} {
                $type SetCaseOutcome $case_id ERROR \
                    "Error, unknown reason for stopping: $result"
                return "ERROR: reason= $result"
            }

            return "OK"
        } 

        if {[sim stopreason] eq "FAILURE"} {
            $type SetCaseOutcome $case_id FAILURE [sanity ontick text]
            return "FAILURE; see my://app/sanity/ontick."
        }

        $type SetCaseOutcome $case_id ERROR \
            "Error, unknown reason for stopping: \"[sim stopreason]\""

        return "ERROR: reason=[sim stopreason]"
    }

    # SetCaseOutcome case_id outcome context
    #
    # case_id    - The case being run
    # outcome    - The outcome code
    # context    - Any context info
    #
    # Saves the case outcome to the cases table.

    typemethod SetCaseOutcome {case_id outcome context} {
        $db eval {
            UPDATE cases
            SET outcome = $outcome,
                context = $context
            WHERE case_id = $case_id
        }
    }

    # SaveOutputs case_id
    #
    # case_id   - The case ID for which history is to be saved.
    #
    # Saves the current outputs in the RDB to the experiment file
    # for the given case.

    typemethod SaveOutputs {case_id} {
        # FIRST, attach the RDB to the experiment table.
        set rdbfile [rdb dbfile]

        $db eval {ATTACH DATABASE $rdbfile AS rdb}

        $db transaction {
            foreach table [$db tables] {
                # Skip non-history tables
                if {![string match {hist_*} $table]} {
                    continue
                }

                $db eval "
                    -- Insert the content from the RDB into the AXDB.  It
                    -- will have case_id=0.
                    INSERT INTO $table SELECT * FROM rdb.$table;

                    -- Update the case_id column to the correct number.
                    UPDATE $table SET case_id = \$case_id WHERE case_id = 0;
                "
            }
        }

        $db eval {DETACH DATABASE rdb}
    }
}



