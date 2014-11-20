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
# TODO:
#    * Move saving to instance
#    * Move saveable saving and restore to methods.
#      * Leave registration in place until all saveables are owned by
#        the grand scenario object.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# scenario ensemble

snit::type scenario {
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
    # saveable            List of saveables.

    typevariable meta -array {
        saveables {}
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
        if {$saveable ni $meta(saveables)} {
            lappend meta(saveables) $saveable
        }
    }


    #===================================================================
    # Instance Code

    #-------------------------------------------------------------------
    # Components
    
    component rdb ;# The scenario db component

    #-------------------------------------------------------------------
    # Instance Variables

    # Scenario working info.

    variable info -array {
        dbfile ""
    }
    

    #-------------------------------------------------------------------
    # Constructor/Destructor

    # constructor filename ?options...?
    #
    # filename - An .adb filename or ""
    #
    # Creates a new scenario object.  If a valid .adb file name is given,
    # the .adb file will be loaded; otherwise, the new scenario will
    # be empty.  

    constructor {filename} {
        # FIRST, create the RDB component.
        $self CreateRDB

        # NEXT, either load file name or create empty database.
        if {$filename ne ""} {
            try {
                $rdb load $filename
            } on error {result eopts} {
                throw {SCENARIO OPEN} $result
            }

            # NEXT, restore the saveables
            $self RestoreSaveables -saved

            # NEXT, save the name.
            # TODO: Add this variable.
            set info(dbfile) $filename
        } else {
            set info(dbfile) ""

            # NEXT, load the blank map, but only if we have a GUI
            # TODO: Take this out once Dave has changed the blank map
            # handling.
            if {[app tkloaded]} {
                map load [file join $::app_athena::library blank.png]
            }


            # Initialize external packages
            bsys clear
            parm reset
            parm checkpoint -saved
        }

        # NEXT, finish up
        $self DefineTempSchema
        executive reset

        $rdb marksaved
    } 

    # CreateRDB
    #
    # Creates the RDB Component.
    #
    # TODO:
    #   * Make ::simclock a true component
    #   * Merge scenariodb(n) into this object.
    #     * Merge "marksaved" code in scenariodb(n) into sqldocument(n).
    #   * Consider where SQL sections should be registered.
    #   * Consider where table monitoring should be done.  I don't
    #     think the grand scenario object will need it internally.
    #   * Consider how to clean up sqldocument so that the temp schema
    #     can be defined in an sqlsection.
    #   * Add -subject option (passed to RDB) so that we can be a source
    #     of notifier events.
    #   * Remove ::rdb alias when it is no longer needed.
    #   

    method CreateRDB {} {
        # FIRST, create a clean working RDB.
        # 
        # TODO: Make ::simclock ${selfns}::clock

        set rdb ${selfns}::rdb

        scenariodb $rdb \
            -clock      ::simclock \
            -explaincmd [mymethod ExplainCmd] \
            -subject    ::rdb
        bean configure -rdb $rdb

        # NEXT, for now, alias it into the global namespace.
        interp alias {} ::rdb {} $rdb

        # NEXT, register SQL sections
        $rdb register ::service

        # NEXT, monitor tables.
        $rdb monitor add actors        {a}
        $rdb monitor add bookmarks     {bookmark_id}
        $rdb monitor add caps          {k}
        $rdb monitor add cap_kn        {k n}
        $rdb monitor add cap_kg        {k g}
        $rdb monitor add civgroups     {g}
        $rdb monitor add coop_fg       {f g}
        $rdb monitor add curses        {curse_id}
        $rdb monitor add deploy_ng     {n g}
        $rdb monitor add drivers       {driver_id}
        $rdb monitor add econ_n        {n}
        $rdb monitor add absits        {s}
        $rdb monitor add frcgroups     {g}
        $rdb monitor add groups        {g}
        $rdb monitor add hooks         {hook_id}
        $rdb monitor add hook_topics   {hook_id topic_id}
        $rdb monitor add hrel_fg       {f g}
        $rdb monitor add curse_injects {curse_id inject_num}
        $rdb monitor add ioms          {iom_id}
        $rdb monitor add mads          {mad_id}
        $rdb monitor add magic_attrit  {id}
        $rdb monitor add nbhoods       {n}
        $rdb monitor add nbrel_mn      {m n}
        $rdb monitor add orggroups     {g}
        $rdb monitor add payloads      {iom_id payload_num}
        $rdb monitor add plants_shares {n a}
        $rdb monitor add sat_gc        {g c}
        $rdb monitor add units         {u}
        $rdb monitor add vrel_ga       {g a}

        # NEXT, create the actual RDB file on the disk.
        set rdbfile [fileutil::tempfile rdb]
        $rdb open $rdbfile
        $rdb clear

        # NEXT, enable write-ahead logging on the RDB
        $rdb eval { PRAGMA journal_mode = WAL; }
    }

    # DefineTempSchema
    #
    # Adds the temporary schema definitions into the RDB

    method DefineTempSchema {} {
        # FIRST, define SQL functions
        # TBD: qsecurity should be added to scenariodb(n).
        # TBD: moneyfmt should be added to sqldocument(n).
        $rdb function locked               [myproc Locked]
        $rdb function m2ref                [myproc M2Ref]
        $rdb function qsecurity            ::projectlib::qsecurity
        $rdb function moneyfmt             ::marsutil::moneyfmt
        $rdb function mklinks              [list ::link html]
        $rdb function uram_gamma           [myproc UramGamma]
        $rdb function sigline              [myproc Sigline]
        $rdb function firing_narrative     [myproc FiringNarrative]
        $rdb function elink                [myproc EntityLink]
        $rdb function yesno                [myproc YesNo]
        $rdb function bsysname             ::bsys::bsysname
        $rdb function topicname            ::bsys::topicname
        $rdb function affinity             ::bsys::affinity
        $rdb function qposition            [myproc QPosition]
        $rdb function hook_narrative       ::hook::hook_narrative
        $rdb function service              [myproc Service]

        # NEXT, define the GUI Views
        $self RdbEvalFile gui_scenario.sql       ;# Scenario Entities
        $self RdbEvalFile gui_attitude.sql       ;# Attitude Area
        $self RdbEvalFile gui_econ.sql           ;# Economics Area
        $self RdbEvalFile gui_ground.sql         ;# Ground Area
        $self RdbEvalFile gui_info.sql           ;# Information Area
        $self RdbEvalFile gui_curses.sql         ;# User-defined CURSEs Area
        $self RdbEvalFile gui_politics.sql       ;# Politics Area
        $self RdbEvalFile gui_infrastructure.sql ;# Infrastructure Area
        $self RdbEvalFile gui_application.sql    ;# Application Views
    }

    # RdbEvalFile filename
    #
    # filename   - An SQL file
    #
    # Reads the file from the application library directory and
    # passes it to the RDB for evaluation.
    #
    # TODO:
    #   * Consider adding evalfile as an sqldocument command.

    method RdbEvalFile {filename} {
        $rdb eval [readfile [file join $::app_athena::library $filename]]
    }

    # destructor
    #
    # This command cleans up when an existing scenario is destroyed.
    #
    # NOTE: In the long run, this destructor might not be needed.
    # At present, it is resetting the Athena application objects that
    # are not yet owned by scenario.

    destructor {
        # FIRST, close and destroy the RDB.
        $rdb destroy

        # NEXT, reset other modules not yet owned by this object.
        bean reset
        catch {sim new}
    }

    #-------------------------------------------------------------------
    # Event Handlers


    # ExplainCmd query explanation
    #
    # query       - An sql query
    # explanation -  Result of calling EXPLAIN QUERY PLAN on the query.
    #
    # Logs the query and its explanation.
    #
    # TODO: Make -explaincmd an option on the scenario instance; the
    # application can create it as necessary.

    method ExplainCmd {query explanation} {
        log normal rdb "EXPLAIN QUERY PLAN {$query}\n---\n$explanation"
    }

    #-------------------------------------------------------------------
    # Saving the Scenario
        
    # save ?filename?
    #
    # filename - Name for the new save file
    #
    # Saves the scenario to the current or specified filename.
    # Throws "SCENARIO SAVE" if there's an error saving.

    method save {{filename ""}} {
        # FIRST, if filename is not specified, get the dbfile
        if {$filename eq ""} {
            if {$info(dbfile) eq ""} {
                # This is a coding error in the client; hence, no
                # special error code.
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

        # NEXT, save the saveables to the rdb.
        $self SaveSaveables -saved

        # NEXT, Save the scenario to disk.
        try {
            if {[file exists $dbfile]} {
                file rename -force $dbfile [file rootname $dbfile].bak
            }

            $rdb saveas $dbfile
        } on error {result} {
            throw {SCENARIO SAVE} $result
        }

        # NEXT, save the name
        set info(dbfile) $dbfile

        return
    }

    # unsaved
    #
    # Returns 1 if there are unsaved changes, and 0 otherwise.

    method unsaved {} {
        if {[$rdb unsaved]} {
            return 1
        }

        foreach saveable $meta(saveables) {
            if {[{*}$saveable changed]} {
                return 1
            }
        }

        return 0
    }



    # SaveSaveables ?-saved?
    #
    # Save all saveable data to the checkpoint table, optionally
    # clearing the "changed" flag for all of the saveables.

    method SaveSaveables {{option ""}} {
        foreach saveable $meta(saveables) {
            # Forget and skip saveables that no longer exist
            if {[llength [info commands [lindex $saveable 0]]] == 0} {
                ldelete meta(saveables) $saveable
                continue
            }

            set checkpoint [{*}$saveable checkpoint $option]

            $rdb eval {
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

    method RestoreSaveables {{option ""}} {
        $rdb eval {
            SELECT saveable,checkpoint FROM saveables
        } {
            if {[llength [info commands [lindex $saveable 0]]] != 0} {
                {*}$saveable restore $checkpoint $option
            } else {
                # TODO: can't call "log" here. -warningcmd?
                log warning scenario \
                    "Unknown saveable found in checkpoint: \"$saveable\""
            }
        }
    }

    #-------------------------------------------------------------------
    # Snapshot management

    # snapshot save
    #
    # Saves an on-lock snapshot of the scenario, so that we can 
    # return to it on-lock.  See nonSnapshotTables, above, for the
    # excluded tables.

    method {snapshot save} {} {
        # FIRST, save the saveables
        $self SaveSaveables

        # NEXT, get the snapshot text
        set snapshot [$self GrabAllBut $nonSnapshotTables]

        # NEXT, save it into the RDB
        $rdb eval {
            INSERT OR REPLACE INTO snapshots(tick,snapshot)
            VALUES(-1,$snapshot)
        }

        # TODO: move log to app, or add -logcmd.
        log normal scenario "snapshot saved: [string length $snapshot] bytes"
    }

    # GrabAllBut exclude
    #
    # exclude  - Names of tables to exclude from the snapshot.
    #
    # Grabs all but the named tables.

    method GrabAllBut {exclude} {
        # FIRST, Get the list of tables to include
        set tables [list]

        $rdb eval {
            SELECT name FROM sqlite_master WHERE type='table'
        } {
            if {$name ni $exclude} {
                lappend tables $name
            }
        }

        # NEXT, export each of the required tables.
        set snapshot [list]

        foreach name $tables {
            lassign [$rdb grab $name {}] grabbedName content

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

    method {snapshot load} {} {
        set snapshot [$rdb onecolumn {
            SELECT snapshot FROM snapshots
            WHERE tick = -1
        }]

        # NEXT, import it.
        # TODO: Do log in app, or add -logcmd.
        log normal scenario \
            "Loading on-lock snapshot: [string length $snapshot] bytes"

        $rdb transaction {
            # NEXT, clear the tables being loaded.
            foreach {tableSpec content} $snapshot {
                lassign $tableSpec table tag
                $rdb eval "DELETE FROM $table;"
            }

            # NEXT, import the tables
            $rdb ungrab $snapshot
        }

        # NEXT, restore the saveables
        $self RestoreSaveables
    }

    # snapshot purge
    #
    # Purges the on-lock snapshot and all history.

    method {snapshot purge} {} {
        $rdb eval {
            DELETE FROM snapshots;
            DELETE FROM ucurve_contribs_t;
            DELETE FROM rule_firings;
            DELETE FROM rule_inputs;
        }

        # TODO: This should be part of grand scenario object.
        hist purge -1
    }

    #-------------------------------------------------------------------
    # Rebase Scenario
    
    method rebase {} {
        # FIRST, allow all modules to rebase.
        rebase save
        
        # NEXT, purge history.  (Do this second, in case the modules
        # needed the history to do their work.)
        sdb snapshot purge
        sigevent purge 0

        # NEXT, update the clock
        simclock configure -tick0 [simclock now]

        # NEXT, reinitialize modules that depend on the time.
        aram clear

        # NEXT, purge simulation tables
        foreach table [$rdb tables] {
            if {$table ni $scenarioTables} {
                $rdb eval "DELETE FROM $table"
            } 
        }
        
        # NEXT, this is a new scenario; it has no name.
        set info(dbfile) ""
    }


    #-------------------------------------------------------------------
    # Scenario queries

    # dbfile
    #
    # Returns the name of the loaded .adb file, or "" if none.

    method dbfile {} {
        return $info(dbfile)
    } 
     
    
}

