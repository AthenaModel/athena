#-----------------------------------------------------------------------
# TITLE:
#    scenario.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n) Scenario Ensemble
#
#    This module does all scenario file for the application.  It is
#    responsible for the open/save/save as/new scenario functionality;
#    as such, it manages the scenariodb(n).
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# scenario ensemble

snit::type scenario {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Components

    typecomponent rdb                ;# The scenario RDB

    #-------------------------------------------------------------------
    # Type Variables

    # scenarioTables
    #
    # A list of the tables that are part of the scenario proper.
    # All other (non-sqlite) tables will be purged as part of 
    # doing a [scenario rebase].

    typevariable scenarioTables {
        activity
        activity_gtype
        actors
        beans
        bookmarks
        cap_kg
        cap_kn
        caps
        cif
        civgroups
        concerns
        coop_fg
        drivers
        econ_n
        absits
        frcgroups
        groups
        hook_topics
        hooks
        hrel_fg
        ioms
        mads
        maps
        nbhoods
        nbrel_mn
        orggroups
        payloads
        sat_gc
        scenario
        scripts
        undostack_stack
        vrel_ga
    }

    # nonSnapshotTables
    #
    # A list of the tables that are excluded from snapshots.
    #
    # WARNING: The excluded tables should not define foreign key
    # constraints with cascading deletes on non-excluded tables.
    # On import, all tables in the exported data will be cleared
    # before being re-populated, and cascading deletes would
    # depopulated the excluded tables.

    typevariable nonSnapshotTables {
        snapshots
        maps
        bookmarks
        hist_control
        hist_coop
        hist_econ
        hist_econ_i
        hist_econ_ij
        hist_hrel
        hist_mood
        hist_nbcoop
        hist_nbmood
        hist_sat
        hist_security
        hist_service_sg
        hist_support
        hist_volatility
        hist_vrel
        rule_firings
        rule_inputs
        scripts
        sigevents
        sigevent_tags
        ucurve_adjustments_t
        ucurve_contribs_t
        ucurve_effects_t
        uram_civrel_t
        uram_frcrel_t
    }

    # Info Array: most scalars are stored here
    #
    # dbfile              Name of the current scenario file
    # saveable            List of saveables.

    typevariable info -array {
        dbfile             ""
        saveables          {}
    }

    #-------------------------------------------------------------------
    # Singleton Initializer

    # init
    #
    # Initializes the scenario RDB.

    typemethod init {} {
        log normal scenario "init"

        # FIRST, create a clean working RDB.
        scenariodb ::rdb \
            -clock      ::simclock \
            -explaincmd [mytypemethod ExplainCmd]
        set rdb ::rdb

        rdb register ::service

        # NEXT, monitor tables.
        rdb monitor add actors        {a}
        rdb monitor add bookmarks     {bookmark_id}
        rdb monitor add caps          {k}
        rdb monitor add cap_kn        {k n}
        rdb monitor add cap_kg        {k g}
        rdb monitor add civgroups     {g}
        rdb monitor add coop_fg       {f g}
        rdb monitor add curses        {curse_id}
        rdb monitor add deploy_ng     {n g}
        rdb monitor add drivers       {driver_id}
        rdb monitor add econ_n        {n}
        rdb monitor add absits        {s}
        rdb monitor add frcgroups     {g}
        rdb monitor add groups        {g}
        rdb monitor add hooks         {hook_id}
        rdb monitor add hook_topics   {hook_id topic_id}
        rdb monitor add hrel_fg       {f g}
        rdb monitor add curse_injects {curse_id inject_num}
        rdb monitor add ioms          {iom_id}
        rdb monitor add mads          {mad_id}
        rdb monitor add nbhoods       {n}
        rdb monitor add nbrel_mn      {m n}
        rdb monitor add orggroups     {g}
        rdb monitor add payloads      {iom_id payload_num}
        rdb monitor add plants_shares {n a}
        rdb monitor add sat_gc        {g c}
        rdb monitor add units         {u}
        rdb monitor add vrel_ga       {g a}

        InitializeRuntimeData

        log normal scenario "init complete"
    }

    # ExplainCmd query explanation
    #
    # query       - An sql query
    # explanation -  Result of calling EXPLAIN QUERY PLAN on the query.
    #
    # Logs the query and its explanation.

    typemethod ExplainCmd {query explanation} {
        log normal rdb "EXPLAIN QUERY PLAN {$query}\n---\n$explanation"
    }

    #-------------------------------------------------------------------
    # Scenario Management Methods

    # new
    #
    # Creates a new, blank scenario.

    typemethod new {} {
        require {[sim stable]} "A new scenario cannot be created in this state."

        # FIRST, unlock the scenario if it is locked; this
        # will reinitialize modules like URAM.
        if {[sim state] ne "PREP"} {
            sim mutate unlock
        }

        # NEXT, Create a blank scenario
        $type MakeBlankScenario

        # NEXT, log it.
        log newlog new
        log normal scenario "New Scenario: Untitled"

        # NEXT, reset the executive, getting rid of any script
        # definitions from the previous scenario.
        executive reset

        app puts "New scenario created"
    }

    # MakeBlankScenario
    #
    # Creates a new, blank, scenario.  This is used on
    # "scenario new", and when "scenario open" tries and fails.

    typemethod MakeBlankScenario {} {
        # FIRST, initialize the runtime database
        InitializeRuntimeData

        # NEXT, initialize the beans
        pot reset

        # NEXT, there is no dbfile.
        set info(dbfile) ""

        # NEXT, Restart the simulation.  This also resyncs the app
        # with the RDB.
        sim new
    }

    # open filename
    #
    # filename       An .adb scenario file
    #
    # Opens the specified file name, replacing the existing file.

    typemethod open {filename} {
        require {[sim stable]} "A new scenario cannot be opened in this state."

        # FIRST, load the file.
        if {[catch {
            rdb load $filename
        } result]} {
            $type MakeBlankScenario

            app error {
                |<--
                Could not open scenario

                    $filename

                $result
            }

            return
        }

        $type FinishOpeningScenario $filename

        return
    }

    # FinishOpeningScenario filename
    #
    # filename       Name of the file being opened.
    #
    # Once the data has been loaded into the RDB, this routine
    # completes the process.

    typemethod FinishOpeningScenario {filename} {
        # FIRST, set the current working directory to the scenario
        # file location.
        catch {cd [file dirname [file normalize $filename]]}

        # NEXT, define the temporary schema definitions
        DefineTempSchema

        # NEXT, restore the saveables
        $type RestoreSaveables -saved

        # NEXT, save the name.
        set info(dbfile) $filename

        # NEXT, log it.
        log newlog open
        log normal scenario "Open Scenario: $filename"

        app puts "Opened Scenario [file tail $filename]"

        # NEXT, reset the executive, loading any user scripts.
        executive reset

        # NEXT, Resync the app with the RDB.
        sim dbsync
    }

    # revert
    #
    # Revert to the last saved scenario.

    typemethod revert {} {
        require {$info(dbfile) != ""} "No scenario to which to revert"
        $type open $info(dbfile)
    }

    # save ?filename?
    #
    # filename       Name for the new save file
    #
    # Saves the file, notify the application on success.  If no
    # file name is specified, the dbfile is used.  Returns 1 if
    # the save is successful and 0 otherwise.

    typemethod save {{filename ""}} {
        require {[sim stable]} "The scenario cannot be saved in this state."

        # FIRST, if filename is not specified, get the dbfile
        if {$filename eq ""} {
            if {$info(dbfile) eq ""} {
                error "Cannot save: no file name"
            }

            set dbfile $info(dbfile)
        } else {
            set dbfile $filename
        }

        # NEXT, make sure it has a .adb extension.
        if {[file extension $dbfile] ne ".adb"} {
            append dbfile ".adb"
        }

        # NEXT, save the saveables
        $type SaveSaveables -saved

        # NEXT, notify the simulation that we're saving, so other
        # modules can prepare.
        notifier send ::scenario <Saving>

        # NEXT, Save, and check for errors.
        if {[catch {
            if {[file exists $dbfile]} {
                file rename -force $dbfile [file rootname $dbfile].bak
            }

            rdb saveas $dbfile
        } result opts]} {
            log warning scenario "Could not save: $result"
            log error scenario [dict get $opts -errorinfo]
            app error {
                |<--
                Could not save as

                    $dbfile

                $result
            }
            return 0
        }

        # NEXT, set the current working directory to the scenario
        # file location.
        catch {cd [file dirname [file normalize $filename]]}

        # NEXT, save the name
        set info(dbfile) $dbfile

        # NEXT, log it.
        if {$filename ne ""} {
            log newlog saveas
        }

        log normal scenario "Save Scenario: $info(dbfile)"

        app puts "Saved Scenario [file tail $info(dbfile)]"

        notifier send $type <ScenarioSaved>

        return 1
    }


    # dbfile
    #
    # Returns the name of the current scenario file

    typemethod dbfile {} {
        return $info(dbfile)
    }

    # unsaved
    #
    # Returns 1 if there are unsaved changes, and 0 otherwise.

    typemethod unsaved {} {
        if {[rdb unsaved]} {
            return 1
        }

        foreach saveable $info(saveables) {
            if {[{*}$saveable changed]} {
                return 1
            }
        }

        return 0
    }


    #-------------------------------------------------------------------
    # Snapshot Management

    # snapshot save
    #
    # Saves an on-lock snapshot of the scenario, so that we can 
    # return to it on-lock.  See nonSnapshotTables, above, for the
    # excluded tables.

    typemethod {snapshot save} {} {
        # FIRST, save the saveables
        $type SaveSaveables

        # NEXT, get the snapshot text
        set snapshot [GrabAllBut $nonSnapshotTables]

        # NEXT, save it into the RDB
        rdb eval {
            INSERT OR REPLACE INTO snapshots(tick,snapshot)
            VALUES(-1,$snapshot)
        }

        log normal scenario "snapshot saved: [string length $snapshot] bytes"
    }

    # GrabAllBut exclude
    #
    # exclude  - Names of tables to exclude from the snapshot.
    #
    # Grabs all but the named tables.

    proc GrabAllBut {exclude} {
        # FIRST, Get the list of tables to include
        set tables [list]

        rdb eval {
            SELECT name FROM sqlite_master WHERE type='table'
        } {
            if {$name ni $exclude} {
                lappend tables $name
            }
        }

        # NEXT, export each of the required tables.
        set snapshot [list]

        foreach name $tables {
            lassign [rdb grab $name {}] grabbedName content

            # grab returns the empty list if there was nothing to
            # grab; we want to have the table name present with
            # an empty content string, indicated that the table
            # should be empty.  Adds the INSERT tag, so that
            # ungrab will do the right thing.
            lappend snapshot [list $name INSERT] $content
        }

        # NEXT, return the document
        return $snapshot
    }

    # snapshot load
    #
    # Loads the on-lock snapshot.  The caller should
    # dbsync the sim.

    typemethod {snapshot load} {} {
        set snapshot [rdb onecolumn {
            SELECT snapshot FROM snapshots
            WHERE tick = -1
        }]

        # NEXT, import it.
        log normal scenario \
            "Loading on-lock snapshot: [string length $snapshot] bytes"

        rdb transaction {
            # NEXT, clear the tables being loaded.
            foreach {tableSpec content} $snapshot {
                lassign $tableSpec table tag
                rdb eval "DELETE FROM $table;"
            }

            # NEXT, import the tables
            rdb ungrab $snapshot
        }

        # NEXT, restore the saveables
        $type RestoreSaveables
    }

    # snapshot purge
    #
    # Purges the on-lock snapshot and all history.

    typemethod {snapshot purge} {} {
        profile rdb eval {
            DELETE FROM snapshots;
            DELETE FROM ucurve_contribs_t;
            DELETE FROM rule_firings;
            DELETE FROM rule_inputs;
        }

        hist purge -1
    }


    #-------------------------------------------------------------------
    # Save current simulation state as new baseline scenario.
    
    typemethod rebase {} {
        # FIRST, allow all modules to rebase.
        rebase save
        
        # NEXT, purge history.  (Do this second, in case the modules
        # needed the history to do their work.)
        scenario snapshot purge
        sigevent purge 0

        # NEXT, update the clock
        simclock configure -tick0 [simclock now]

        # NEXT, reinitialize modules that depend on the time.

        aram clear

        # NEXT, purge simulation tables
        foreach table [rdb tables] {
            if {$table ni $scenarioTables} {
                rdb eval "DELETE FROM $table"
            } 
        }
        
        # NEXT, this is a new scenario; it has no name.
        set info(dbfile) ""
    }
    
    #-------------------------------------------------------------------
    # Configure RDB

    # InitializeRuntimeData
    #
    # Clears the RDB, inserts the schema, and loads initial data:
    #
    # * Blank map

    proc InitializeRuntimeData {} {
        # FIRST, create and clear the RDB
        if {[rdb isopen]} {
            rdb close
        }

        set rdbfile [workdir join rdb working.rdb]
        file delete -force $rdbfile
        rdb open $rdbfile
        rdb clear

        # NEXT, enable write-ahead logging on the RDB
        rdb eval { PRAGMA journal_mode = WAL; }

        # NEXT, define the temp schema
        DefineTempSchema

        # NEXT, create the neutral belief system.
        bsys clear

        # NEXT, Reset the model parameters to their defaults, and
        # mark them saved.
        parm reset

        parm checkpoint -saved

        # NEXT, mark it saved; there's no reason to save a scenario
        # that has only these things in it.
        rdb marksaved
    }

    # DefineTempSchema
    #
    # Adds the temporary schema definitions into the RDB

    proc DefineTempSchema {} {
        # FIRST, define SQL functions
        # TBD: qsecurity should be added to scenariodb(n).
        # TBD: moneyfmt should be added to sqldocument(n).
        rdb function locked               [myproc Locked]
        rdb function m2ref                [myproc M2Ref]
        rdb function qsecurity            ::projectlib::qsecurity
        rdb function moneyfmt             ::marsutil::moneyfmt
        rdb function mklinks              [list ::link html]
        rdb function uram_gamma           [myproc UramGamma]
        rdb function sigline              [myproc Sigline]
        rdb function firing_narrative     [myproc FiringNarrative]
        rdb function elink                [myproc EntityLink]
        rdb function yesno                [myproc YesNo]
        rdb function bsysname             ::bsys::bsysname
        rdb function topicname            ::bsys::topicname
        rdb function affinity             ::bsys::affinity
        rdb function qposition            [myproc QPosition]
        rdb function hook_narrative       ::hook::hook_narrative
        rdb function service              [myproc Service]

        # NEXT, define the GUI Views
        RdbEvalFile gui_scenario.sql       ;# Scenario Entities
        RdbEvalFile gui_attitude.sql       ;# Attitude Area
        RdbEvalFile gui_econ.sql           ;# Economics Area
        RdbEvalFile gui_ground.sql         ;# Ground Area
        RdbEvalFile gui_info.sql           ;# Information Area
        RdbEvalFile gui_curses.sql         ;# User-defined CURSEs Area
        RdbEvalFile gui_politics.sql       ;# Politics Area
        RdbEvalFile gui_infrastructure.sql ;# Infrastructure Area
        RdbEvalFile gui_application.sql    ;# Application Views
    }

    # RdbEvalFile filename
    #
    # filename   - An SQL file
    #
    # Reads the file from the application library directory and
    # passes it to the RDB for evaluation.

    proc RdbEvalFile {filename} {
        rdb eval [readfile [file join $::app_athena::library $filename]]
    }

    #-------------------------------------------------------------------
    # SQL Functions

    # Service  service which urb
    #
    # service    - an eabservice(n) value
    # which      - either 'ACTUAL' or 'REQUIRED'
    # urb        - an eurbanization(n) value
    #
    # Returns the proper parmdb parameter value for an abstract
    # infrastructure service based on urbanization and type of LOS

    proc Service {service which urb} {
        return [parm get service.$service.$which.$urb]
    }

    # Locked
    #
    # Returns 1 if the scenario is locked, and 0 otherwise.

    proc Locked {} {
        expr {[sim state] ne "PREP"}
    }

    # M2Ref args
    #
    # args    map coordinates of one or more points as a flat list
    #
    # Returns a list of one or more map reference strings corrresponding
    # to the coords

    proc M2Ref {args} {
        if {[llength $args] == 1} {
            set args [lindex $args 0]
        }

        map m2ref {*}$args
    }

    # UramGamma ctype
    #
    # ctype - A URAM curve type: HREL, VREL, COOP, AUT, CUL, QOL.
    #
    # Returns the "gamma" parameter for curves of that type from
    # parmdb(5).

    proc UramGamma {ctype} {
        # The [expr] converts it to a number.
        return [expr [lindex [parm get uram.factors.$ctype] 1]]
    }

    # Sigline dtype signature
    #
    # dtype     - A driver type
    # signature - The driver's signature
    #
    # Returns the driver's signature line.

    proc Sigline {dtype signature} {
        driver::$dtype sigline $signature
    }

    # FiringNarrative fdict
    #
    # fdict   - A rule firing dictionary
    #
    # Returns the rule firing's narrative string.

    proc FiringNarrative {fdict} {
        driver call narrative $fdict
    }

    # EntityLink etype name
    #
    # etype   - An entity type, e.g., "group"
    # name    - An entity name
    #
    # Translates the args into 
    #
    #   <a href="my://app/$etype/$name">$name</a>

    proc EntityLink {etype name} {
        return "<a href=\"my://app/$etype/$name\">$name</a>"
    }

    # YesNo value
    #
    # value - An integer flag
    #
    # Returns "YES" or "NO".

    proc YesNo {value} {
        if {$value} {
            return "YES"
        } else {
            return "NO"
        }
    }

    # QPosition position
    #
    # position   - A qposition(n) value
    #
    # Returns the human-readable equivalent as a string.

    proc QPosition {position} {
        set ptext [qposition longname $position]

        if {$ptext eq "Ambivalent"} {
            append ptext " Towards"
        }

        return $ptext
    }


    #-------------------------------------------------------------------
    # Registration of saveable objects

    # register saveable
    #
    # saveable     A saveable(i) command or command prefix
    #
    # Registers the saveable(i); its data will be included in
    # the scenario and restored as appropriate.

    typemethod register {saveable} {
        if {$saveable ni $info(saveables)} {
            lappend info(saveables) $saveable
        }
    }

    # SaveSaveables ?-saved?
    #
    # Save all saveable data to the checkpoint table, optionally
    # clearing the "changed" flag for all of the saveables.

    typemethod SaveSaveables {{option ""}} {
        foreach saveable $info(saveables) {
            # Forget and skip saveables that no longer exist
            if {[llength [info commands [lindex $saveable 0]]] == 0} {
                ldelete info(saveables) $saveable
                continue
            }

            set checkpoint [{*}$saveable checkpoint $option]

            rdb eval {
                INSERT OR REPLACE
                INTO saveables(saveable,checkpoint)
                VALUES($saveable,$checkpoint)
            }
        }
    }

    # RestoreSaveables ?-saved?
    #
    # Restore all saveable data from the checkpoint table, optionally
    # clearing the "changed" flag for all of the saveables.

    typemethod RestoreSaveables {{option ""}} {
        rdb eval {
            SELECT saveable,checkpoint FROM saveables
        } {
            if {[llength [info commands [lindex $saveable 0]]] != 0} {
                {*}$saveable restore $checkpoint $option
            } else {
                log warning scenario \
                    "Unknown saveable found in checkpoint: \"$saveable\""
            }
        }
    }
}

