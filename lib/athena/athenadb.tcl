#-----------------------------------------------------------------------
# TITLE:
#   athena.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#   athena(n) Package: Private Scenario Object
#
#   This type is the main *private* entry point into the athena(n) library.
#   Instances of athenadb(n) define entire scenarios, and can be saved
#   to and loaded from .adb files.
#
#   Not only does athenadb(n) represent the entire scenario, it is also
#   the main utility object for the entire library.  When athenadb(n)
#   is created, it creates the other scenario objects; and it passes itself
#   to them so that they can access the library's other services through 
#   it.
#
#   Thus, athenadb(n) becomes a facade for the rest of the library.
#
# RELATIONSHIP BETWEEN athena(n) AND athenadb(n):
#
#   athena(n) is the main *public* entry point into the library.  It is
#   a simple wrapper wround athenadb(n), providing only those calls needed
#   by clients.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# athena type

snit::type ::athena::athenadb {
    #-------------------------------------------------------------------
    # Lookup tables

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

    #-------------------------------------------------------------------
    # Type Variables
    

    # Info Array: most scalars are stored here
    #
    # saveable            List of saveables.

    typevariable meta -array {
        saveables {}
    }


    #-------------------------------------------------------------------
    # Registration of saveable objects

    # register saveable
    #
    # saveable     A saveable(i) command or command prefix
    #
    # Registers the saveable(i); its data will be included in
    # the scenario and restored as appropriate.
    #
    # TODO: Ultimately, all registration will be done internally,
    # and this can become a private helper method.

    typemethod register {saveable} {
        if {$saveable ni $meta(saveables)} {
            lappend meta(saveables) $saveable
        }
    }

    #===================================================================
    # Instance Code

    #-------------------------------------------------------------------
    # Components
    
    # Resources
    component rdb                        ;# writable sqldatabase handle
    component pot      -public pot       ;# beanpot(n)
    component flunky   -public flunky    ;# athena_flunky(n)

    # Editable Entities
    component absit    -public absit     ;# absit manager
    component actor    -public actor     ;# actor manager
    component agent    -public agent     ;# agent manager
    component civgroup -public civgroup  ;# civgroup manager
    component frcgroup -public frcgroup  ;# frcgroup manager
    component nbhood   -public nbhood    ;# nbhood manager
    component orggroup -public orggroup  ;# orggroup manager

    #-------------------------------------------------------------------
    # Options

    # -logcmd cmd
    #
    # The name of a logger(n) object (or equivalent) to use to log the 
    # scenario's activities.  This object will use the -subject as its
    # logger(n) "component" name.

    option -logcmd

    # -subject name
    #
    # The name of the object for use in log messages and as a 
    # notifier(n) subject.  Defaults to the tail of the object's command.

    option -subject \
        -readonly yes
    

    #-------------------------------------------------------------------
    # Instance Variables

    # Scenario working info.
    #
    # adbfile - The name of the related .adb file, or "" if none.

    variable info -array {
        adbfile ""
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

    constructor {filename args} {
        # FIRST, set the -subject's default value.  Then, get the option
        # values.
        set options(-subject) $self

        $self configurelist $args

        # NEXT, create the RDB and other components.
        $self CreateRDB
        install pot      using beanpot ${selfns}::pot -rdb $rdb
        install flunky   using ::athena::athena_flunky create ${selfns}::flunky $self

        $self MakeComponents \
            absit            \
            actor            \
            agent            \
            civgroup         \
            frcgroup         \
            nbhood           \
            orggroup

        # NEXT, Make these components globally available.
        # TBD: These will go away once the transition to library code
        # is complete.
        interp alias {} ::rdb      {} $rdb
        interp alias {} ::pot      {} $pot
        interp alias {} ::flunky   {} $flunky

        # NEXT, either load the named file or create an empty database.
        if {$filename ne ""} {
            try {
                $rdb load $filename
            } on error {result eopts} {
                throw {SCENARIO OPEN} $result
            }

            # NEXT, restore the saveables
            $self RestoreSaveables -saved

            # NEXT, save the name.
            set info(adbfile) $filename
        } else {
            set info(adbfile) ""

            # Initialize external packages
            strategy init
            bsys clear
            parm reset
            parm checkpoint -saved
        }

        # NEXT, finish up
        $self DefineTempSchema
        executive reset

        $rdb marksaved
    } 

    # MakeComponents component...
    #
    # component...  - A list of component names.
    #
    # Creates instances for a list of components, all of which take one
    # constructor argument, the athenadb(n) instance.  For now, also
    # defines global entry points.

    method MakeComponents {args} {
        foreach name $args {
            install $name using ::athena::${name} ${selfns}::$name $self

            # TBD: The alias will go away once the conversion is complete.
            interp alias {} ::${name} {} [set $name]
        }
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
            -subject    $options(-subject)

        # NEXT, register SQL sections
        $rdb register ::service

        # NEXT, monitor tables.
        $rdb monitor add actors        {a}
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
        $rdb function locked               [mymethod Locked]
        $rdb function m2ref                [mymethod M2Ref]
        $rdb function qsecurity            ::projectlib::qsecurity
        $rdb function moneyfmt             ::marsutil::moneyfmt
        $rdb function mklinks              [list ::link html]
        $rdb function uram_gamma           [mymethod UramGamma]
        $rdb function sigline              [mymethod Sigline]
        $rdb function firing_narrative     [mymethod FiringNarrative]
        $rdb function elink                [myproc EntityLink]
        $rdb function yesno                [myproc YesNo]
        $rdb function bsysname             ::bsys::bsysname
        $rdb function topicname            ::bsys::topicname
        $rdb function affinity             ::bsys::affinity
        $rdb function qposition            [myproc QPosition]
        $rdb function hook_narrative       ::hook::hook_narrative
        $rdb function service              [mymethod Service]

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
        $rdb eval [readfile [file join $::athena::library $filename]]
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
        $rdb close
        $rdb destroy

        # NEXT, reset other modules not yet owned by this object.
        catch {sim new}
    }

    #-------------------------------------------------------------------
    # Delegated commands

    # RDB

    delegate method eval              to rdb as eval
    delegate method delete            to rdb as delete
    delegate method exists            to rdb as exists
    delegate method grab              to rdb as grab
    delegate method last_insert_rowid to rdb as last_insert_rowid
    delegate method monitor           to rdb as monitor
    delegate method onecolumn         to rdb as onecolumn
    delegate method query             to rdb as query
    delegate method ungrab            to rdb as ungrab
    

    #-------------------------------------------------------------------
    # Event Handlers


    # ExplainCmd query explanation
    #
    # query       - An sql query
    # explanation -  Result of calling EXPLAIN QUERY PLAN on the query.
    #
    # Logs the query and its explanation.

    method ExplainCmd {query explanation} {
        $self log normal "EXPLAIN QUERY PLAN {$query}\n---\n$explanation"
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
            if {$info(adbfile) eq ""} {
                # This is a coding error in the client; hence, no
                # special error code.
                error "Cannot save: no file name"
            }

            set dbfile $info(adbfile)
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
        set info(adbfile) $dbfile

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
                $self log warning "" \
                    "Unknown saveable found in checkpoint: \"$saveable\""
            }
        }
    }

    #-------------------------------------------------------------------
    # Snapshot management
    #
    # TBD: This code is essential, but private.  Once the sim module
    # has been incorporated into athena(n), these should be renamed.

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

        # NEXT, log the size.
        $self log normal "" "snapshot saved: [string length $snapshot] bytes"
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
        $self log normal "" \
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
        $self snapshot purge
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
        set info(adbfile) ""
    }


    #-------------------------------------------------------------------
    # Scenario queries

    # adbfile
    #
    # Returns the name of the loaded .adb file, or "" if none.

    method adbfile {} {
        return $info(adbfile)
    } 

    # rdb component
    #
    # Returns the name of the RDB component, for use by athena(n).

    method {rdb component} {} {
        return $rdb
    }


    #===================================================================
    # Helper API
    #
    # These methods are defined for use by components.

    # log level component message
    #
    # level       - The log level
    # component   - The athenadb(n) component name, e.g., "flunky"
    # message     - The log message
    #
    # Writes the message to the scrolling log, prefixing the component
    # with "$subject.".

    method log {level component message} {
        set name [namespace tail $options(-subject)]

        if {$component ne ""} {
            append name ".$component"
        }

        callwith $options(-logcmd) $level $name $message
    }

    # notify component event args...
    #
    # component   - The athenadb(n) component name, e.g., "flunky"
    # event       - The notifier(n) event name.
    # args        - Event arguments
    #
    # Sends the event, using subject "$options(-subject).$component"
    
    method notify {component event args} {
        notifier send $options(-subject).$component $event {*}$args
    }

    

    #===================================================================
    # SQL Functions
    #
    # TODO: Some should be application specific.
    

    # Locked
    #
    # Returns 1 if the scenario is locked, and 0 otherwise.

    method Locked {} {
        expr {[sim state] ne "PREP"}
    }

    # M2Ref args
    #
    # args    map coordinates of one or more points as a flat list
    #
    # Returns a list of one or more map reference strings corrresponding
    # to the coords

    method M2Ref {args} {
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

    method UramGamma {ctype} {
        # The [expr] converts it to a number.
        return [expr [lindex [parm get uram.factors.$ctype] 1]]
    }

    # Sigline dtype signature
    #
    # dtype     - A driver type
    # signature - The driver's signature
    #
    # Returns the driver's signature line.

    method Sigline {dtype signature} {
        driver::$dtype sigline $signature
    }

    # FiringNarrative fdict
    #
    # fdict   - A rule firing dictionary
    #
    # Returns the rule firing's narrative string.

    method FiringNarrative {fdict} {
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

    # Service  service which urb
    #
    # service    - an eabservice(n) value
    # which      - either 'ACTUAL' or 'REQUIRED'
    # urb        - an eurbanization(n) value
    #
    # Returns the proper parmdb parameter value for an abstract
    # infrastructure service based on urbanization and type of LOS

    method Service {service which urb} {
        return [parm get service.$service.$which.$urb]
    }


}

