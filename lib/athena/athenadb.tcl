#-----------------------------------------------------------------------
# TITLE:
#   athenadb.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#   athenadb(n) Package: Private Scenario Object
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
    # Components
    
    # Resources
    component rdb                                   ;# writable sqldatabase handle
    component autogen        -public autogen        ;# Scenario auto-generator
    component executive      -public executive      ;# executive command processor
    component exporter       -public export         ;# exporter
    component flunky         -public order          ;# athena_flunky(n)
    component gofer          -public gofer          ;# gofer
    component hist           -public hist           ;# results history
    component parm           -public parm           ;# model parameter DB
    component paster         -public paste          ;# paste manager
    component pot            -public bean           ;# beanpot(n)
    component ptype          -public ptype          ;# app level type validators
    component ruleset        -public ruleset        ;# rule set manager
    component sanity         -public sanity         ;# sanity checker
    component sim            -public sim            ;# Simulation Control
    component simclock       -public clock          ;# Simulation Clock
    
    # Editable Entities
    component absit          -public absit          ;# absit manager
    component actor          -public actor          ;# actor manager
    component agent          -public agent          ;# agent manager
    component bsys           -public bsys           ;# belief system manager
    component cap            -public cap            ;# cap manager
    component civgroup       -public civgroup       ;# civgroup manager
    component coop           -public coop           ;# cooperation manager
    component curse          -public curse          ;# curse manager
    component econ           -public econ           ;# econ manager
    component frcgroup       -public frcgroup       ;# frcgroup manager
    component hook           -public hook           ;# semantic hook manager
    component hrel           -public hrel           ;# horiz. rel. manager
    component iom            -public iom            ;# iom manager
    component inject         -public inject         ;# curse inject manager
    component map            -public map            ;# map data manager
    component nbhood         -public nbhood         ;# nbhood manager
    component nbrel          -public nbrel          ;# nbhood rel. manager
    component orggroup       -public orggroup       ;# orggroup manager
    component payload        -public payload        ;# payload manager
    component plant          -public plant          ;# goods plant manager
    component sat            -public sat            ;# satisfaction manager
    component sigevent       -public sigevent       ;# Sig. Events manager
    component strategy       -public strategy       ;# strategy manager
    component unit           -public unit           ;# unit manager
    component vrel           -public vrel           ;# vert. rel. manager

    # Other Entities
    component activity       -public activity       ;# activity manager
    component agent          -public agent          ;# agent manager
    component group          -public group          ;# group manager

    # Tactic APIs
    component abevent        -public abevent        ;# Abstract event API
    component broadcast      -public broadcast      ;# IOM broadcast API
    component cash           -public cash           ;# cash/spending API
    component control        -public control        ;# nbhood control API
    component personnel      -public personnel      ;# personnel laydown API
    component stance         -public stance         ;# stance API

    # Models
    component aam            -public aam            ;# Athena attrition model 
    component aram           -public aram           ;# Athena URAM 
    component control_model  -public control_model  ;# actor control model 
    component coverage_model -public coverage_model ;# activity coverage model 
    component demog          -public demog          ;# demographics model
    component security_model -public security_model ;# security model 
    component service        -public service        ;# services model

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
    # adbfile   - The name of the related .adb file, or "" if none.
    # saveables - Dictionary of saveable(i) objects by symbolic name.
    #             The symbolic name is used in the RDB saveables table.

    variable info -array {
        adbfile   ""
        saveables {}
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

        # NEXT, create the simulation clock
        install simclock using ::projectlib::weekclock ${selfns}::simclock

        # NEXT, create the RDB and configure it for use.
        $self CreateRDB

        # NEXT, create the beanpot for creating and managing the Athena's
        # bean objects.  The beanpot will receive the athenadb(n) handle,
        # and use it to access the RDB; and it will be available to 
        # individual beans as needed via the beanpot's "db" method.
        install pot using beanpot ${selfns}::pot -rdb $self

        # NEXT, create the order flunky for processing order input and
        # handling undo/redo.
        install flunky using ::athena::athena_flunky create ${selfns}::flunky $self

        # NEXT, create the gofer for retrieving data.
        install gofer using ::athena::goferx create ${selfns}::gofer $self

        # NEXT, support pasting of objects.
        install paster using ::athena::paster create ${selfns}::paster $self

        # NEXT, add aram.
        install aram using uram ${selfns}::aram \
            -rdb          $rdb                  \
            -loadcmd      [mymethod LoadAram]   \
            -undo         on                    \
            -logger       [mymethod log]        \
            -logcomponent "aram"
        $aram configure -undo off

        # NEXT, make standard components.  These are modules that were
        # singletons when Athena was a monolithic app.  They are now
        # types/classes with instances; each instance takes one argument,
        # the athenadb(n) handle.

        $self MakeComponents            \
            aam                         \
            abevent                     \
            absit                       \
            activity                    \
            actor                       \
            agent                       \
            autogen                     \
            broadcast                   \
            bsys                        \
            cap                         \
            cash                        \
            civgroup                    \
            coop                        \
            control                     \
            control_model               \
            coverage_model              \
            curse                       \
            demog                       \
            econ                        \
            executive                   \
            exporter                    \
            frcgroup                    \
            group                       \
            hist                        \
            hook                        \
            hrel                        \
            inject                      \
            iom                         \
            map                         \
            nbhood                      \
            nbrel                       \
            orggroup                    \
            parm                        \
            payload                     \
            personnel                   \
            plant                       \
            ptype                       \
            rebase                      \
            {ruleset  ruleset_manager}  \
            sanity                      \
            sat                         \
            security_model              \
            service                     \
            sigevent                    \
            sim                         \
            stance                      \
            {strategy strategy_manager} \
            unit                        \
            vrel


        # NEXT, register the ones that are saveables.  This will change
        # when the transition to library code is complete.
        $self RegisterSaveable aram [list $aram saveable]
        $self RegisterSaveable bsys $bsys
        $self RegisterSaveable econ $econ
        $self RegisterSaveable parm $parm
        $self RegisterSaveable pot  $pot
        $self RegisterSaveable sim  $sim

        # NEXT, either load the named file or create an empty database.
        if {$filename ne ""} {
            $self load $filename
        } else {
            set info(adbfile) ""
            $self FinishOpeningScenario
        }
    } 

    # MakeComponents component...
    #
    # component...  - A list of component names.
    #
    # Creates instances for a list of components, all of which take one
    # constructor argument, the athenadb(n) instance.

    method MakeComponents {args} {
        foreach pair $args {
            lassign $pair comp module

            if {$module eq ""} {
                set module $comp
            }


            install $comp using ::athena::${module} ${selfns}::$comp $self
        }
    }

    # CreateRDB
    #
    # Creates the RDB Component.
    #
    # TODO:
    #   * Merge scenariodb(n) into this object?
    #     * Merge "marksaved" code in scenariodb(n) into sqldocument(n).
    #   * Consider where SQL sections should be registered.
    #   * Consider how to clean up sqldocument so that the temp schema
    #     can be defined in an sqlsection.
    #   

    method CreateRDB {} {
        # FIRST, create a clean working RDB.
        set rdb ${selfns}::rdb

        scenariodb $rdb \
            -clock      $simclock             \
            -explaincmd [mymethod ExplainCmd] \
            -subject    $options(-subject)

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
        $rdb monitor add nbhoods       {n}
        $rdb monitor add nbrel_mn      {m n}
        $rdb monitor add orggroups     {g}
        $rdb monitor add payloads      {iom_id payload_num}
        $rdb monitor add plants_shares {n a}
        $rdb monitor add sat_gc        {g c}
        $rdb monitor add units         {u}
        $rdb monitor add vrel_ga       {g a}

        # NEXT, create the actual RDB file on the disk.
        $self InitializeRDB
    }

    # DefineTempSchema
    #
    # Adds the temporary schema definitions into the RDB

    method DefineTempSchema {} {
        # FIRST, define SQL functions
        # TBD: qsecurity should be added to scenariodb(n).
        # TBD: moneyfmt should be added to sqldocument(n).
        $rdb function locked               [mymethod Locked]
        $rdb function mgrs                 [mymethod Mgrs]
        $rdb function qsecurity            ::projectlib::qsecurity
        $rdb function moneyfmt             ::marsutil::moneyfmt
        $rdb function mklinks              [list ::link html]
        $rdb function uram_gamma           [mymethod UramGamma]
        $rdb function sigline              [mymethod Sigline]
        $rdb function firing_narrative     [mymethod FiringNarrative]
        $rdb function elink                [myproc EntityLink]
        $rdb function yesno                [myproc YesNo]
        $rdb function bsysname             [list $bsys bsysname]
        $rdb function topicname            [list $bsys topicname]
        $rdb function affinity             [list $bsys affinity]
        $rdb function qposition            [myproc QPosition]
        $rdb function hook_narrative       [list $hook hook_narrative]
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
    # filename   - An SQL file in the sql/ subdirectory
    #
    # Reads the file from the library's sql directory and
    # passes it to the RDB for evaluation.

    method RdbEvalFile {filename} {
        $rdb eval [readfile [file join $::athena::library sql $filename]]
    }

    # destructor
    #
    # This command cleans up when an existing scenario is destroyed.
    #
    # NOTE: In the long run, this destructor might not be needed.
    # At present, it is resetting the Athena application objects that
    # are not yet owned by scenario.

    destructor {
        $self notify "" <Destroy>

        # FIRST, close and destroy the RDB.
        $rdb close
        $rdb destroy
    }

    #-------------------------------------------------------------------
    # Delegated commands

    # RDB
    delegate method {rdb *}           to rdb
    delegate method eval              to rdb
    delegate method delete            to rdb
    delegate method exists            to rdb
    delegate method grab              to rdb
    delegate method last_insert_rowid to rdb
    delegate method monitor           to rdb
    delegate method onecolumn         to rdb
    delegate method query             to rdb
    delegate method safeeval          to rdb
    delegate method safequery         to rdb
    delegate method schema            to rdb
    delegate method tables            to rdb
    delegate method ungrab            to rdb

    # SIM
    delegate method locked            to sim
    delegate method state             to sim
    delegate method stable            to sim
    delegate method stoptime          to sim
    delegate method wizlock           to sim
    
    # FLUNKY
    delegate method send              to flunky

    #-------------------------------------------------------------------
    # Scenario Control

    # reset
    #
    # Resets the scenario to its empty state, i.e., turns it into a 
    # "new" scenario.

    method reset {} {
        require {[$sim stable]} "A new scenario cannot be created in this state."

        # FIRST, unlock the scenario if it is locked; this
        # will reinitialize modules like URAM.
        if {[$sim state] ne "PREP"} {
            $sim unlock
        }

        # NEXT, close the RDB if it's open
        if {[$rdb isopen]} {
            $rdb close
        }

        # NEXT, Reset the scenario, restoring saveable from an empty RDB.
        $self InitializeRDB
        $self RestoreSaveables
        $strategy reset

        set info(adbfile) ""

        # NEXT, reset the executive, getting rid of any script
        # definitions from the previous scenario.
        # Note that any script in progress will complete normally,
        # but any changes to its interp state will be lost.  (This
        # is OK.)
        $executive reset

        # NEXT, clear any old transient data out of modules.
        $aram    clear
        $aam     reset
        $abevent reset

        $self FinishOpeningScenario
    }

    # InitializeRDB
    #
    # Initializes the RDB, opening a new RDB file on disk.

    method InitializeRDB {} {
        # FIRST, create the actual RDB file on the disk.
        set rdbfile [fileutil::tempfile rdb]
        $rdb open $rdbfile
        $rdb clear

        # NEXT, enable write-ahead logging on the RDB
        $rdb eval { PRAGMA journal_mode = WAL; }
    }

    # FinishOpeningScenario
    #
    # Defines the temp schema, marks everything saved, and notifies
    # the application.

    method FinishOpeningScenario {} {
        $self DefineTempSchema
        $rdb marksaved
        $flunky state [$self state]
        $self notify "" <Create>
    }
    
    # load filename
    #
    # filename  - An .adb file
    #
    # Loads the scenario data into the object, replacing what went
    # before.

    method load {filename} {
        require {[$sim stable]} "A new scenario cannot be opened in this state."

        try {
            $rdb load $filename
        } on error {result eopts} {
            throw {SCENARIO OPEN} $result
        }

        # NEXT, restore the saveables
        $self RestoreSaveables -saved
        $executive reset

        # NEXT, save the name.
        set info(adbfile) $filename

        # NEXT, Finish Up
        $self FinishOpeningScenario
    }
    
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

        dict for {name command} $info(saveables) {
            if {[{*}$command changed]} {
                return 1
            }
        }

        return 0
    }

    # RegisterSaveable name command
    #
    # name    - A symbolic name for the saveable, to be used in the .adb
    #           file.
    # command - The component command.

    method RegisterSaveable {name command} {
        dict set info(saveables) $name $command
    }

    # SaveSaveables ?-saved?
    #
    # Save all saveable data to the checkpoint table, optionally
    # clearing the "changed" flag for all of the saveables.

    method SaveSaveables {{option ""}} {
        dict for {name command} $info(saveables) {
            set checkpoint [{*}$command checkpoint $option]

            $rdb eval {
                INSERT OR REPLACE
                INTO saveables(saveable,checkpoint)
                VALUES($name,$checkpoint)
            }
        }
    }

    # RestoreSaveables ?-saved?
    #
    # Restore all saveable data from the checkpoint table, optionally
    # clearing the "changed" flag for all of the saveables.
    #
    # Note: This is different than the pattern prior to Athena 6.3:
    # every registered saveable is restored whether there is data in
    # the RDB or not.  Saveables must be able to reset themselves
    # when there is no data.

    method RestoreSaveables {{option ""}} {
        dict for {name command} $info(saveables) {
            set checkpoint [$rdb onecolumn {
                SELECT checkpoint FROM saveables
                WHERE saveable = $name
            }]

            {*}$command restore $checkpoint $option
        }
    }

    # dbsync
    #
    # Notify that application that everything has changed.
    # Database synchronization occurs when the RDB changes out from under
    # the application, i.e., brand new scenario is created or
    # loaded.  All application modules must re-initialize themselves
    # at this time.


    method dbsync {} {
        # Sync relevant models
        $nbhood dbsync
        $strategy dbsync

        $self notify "" <PreSync>
        $self notify "" <Sync>
        $self notify "" <Time>
        $self notify "" <State>

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
        $hist purge -1
    }

    #-------------------------------------------------------------------
    # Rebase Scenario

    delegate method {rebase prepare} to rebase as prepare
    
    method {rebase save} {} {

        # FIRST, allow all modules to rebase.
        $rebase save
        
        # NEXT, purge history.  (Do this second, in case the modules
        # needed the history to do their work.)
        $self snapshot purge
        $sigevent purge 0

        # NEXT, update the clock
        $simclock configure -tick0 [$simclock now]

        # NEXT, reinitialize modules that depend on the time.
        $aram clear

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

    # component rdb
    #
    # Returns the name of the RDB component, for use by athena(n).

    method {component rdb} {} {
        return $rdb
    }

    # component clock
    #
    # Returns the name of the clock component, for use by athena(n).

    method {component clock} {} {
        return $simclock
    }

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

    # profile ?depth? command ?args...?
    #
    # Calls the command once using [time], in the caller's context,
    # and logs the outcome, returning the command's return value.
    # In other words, you can stick "$adb profile" before any command name
    # and profile that call without changing code or adding new routines.
    #
    # If the depth is given, it must be an integer; that many "*" characters
    # are added to the beginning of the log message.

    method profile {args} {
        if {[string is integer -strict [lindex $args 0]]} {
            set prefix "[string repeat * [lshift args]] "
        } else {
            set prefix ""
        }

        set msec [lindex [time {
            set result [uplevel 1 $args]
        } 1] 0]

        $self log detail app "${prefix}profile [list $args] $msec"

        return $result
    }

    # cprofile ?depth? component ?args...?
    #
    # Profiles the command, which is a call to one of ADB's own 
    # components.  Provided for convenience.

    method cprofile {args} {
        if {[string is integer -strict [lindex $args 0]]} {
            set depth [list [lshift args]]
        } else {
            set depth ""
        }

        $self profile {*}$depth $self {*}$args
    }


    # notify component event args...
    #
    # component   - The athenadb(n) component name, e.g., "flunky"
    # event       - The notifier(n) event name.
    # args        - Event arguments
    #
    # Sends the event, using subject "$options(-subject).$component"
    
    method notify {component event args} {
        set subject $options(-subject)

        if {$component ne ""} {
            append subject ".$component"
        }

        notifier send $subject $event {*}$args
    }

    # tkloaded
    #
    # Returns 1 if Tk is loaded, and 0 otherwise.

    method tkloaded {} {
        return [expr {[info command "tk"] ne ""}]
    }

    # version
    #
    # Returns the package version.

    method version {} {
        return [package present athena]
    }

    #-------------------------------------------------------------------
    # Order Dialog Entry

    # enter options...
    #
    # -order        - Order name, e.g., MY:ORDER
    # -parmdict     - Dictionary of initial parameter values
    # -master       - Master window
    # -appname      - Application name for dialog title
    # -helpcmd      - Help command
    #
    # If tk is loaded, pops up an order dialog.

    method enter {args} {
        require {[$self tkloaded]} \
            "Command unavailable; this is not a Tk app."

        array set opts {
            -order    ""
            -parmdict {}
            -master   ""
            -appname  ""
            -helpcmd  ""
        }

        foroption opt args -all {
            -order    -
            -parmdict -
            -master   -
            -appname  -
            -helpcmd {
                set opts($opt) [lshift args]
            }
        }

        order_dialog enter \
            -resources [dict create adb_ $self db_ $self] \
            -flunky    $flunky                            \
            -refreshon {
                ::adb.flunky <Sync>
                ::adb        <Tick>
                ::adb        <Sync>
            } {*}[array get opts]
    }
    

    #-------------------------------------------------------------------
    # URAM-related routines.
    
    # LoadAram uram
    #
    # Loads scenario data into URAM when it's initialized.

    method LoadAram {uram} {
        $uram load causes {*}[ecause names]

        $uram load actors {*}[$rdb eval {
            SELECT a FROM actors
            ORDER BY a
        }]

        $uram load nbhoods {*}[$rdb eval {
            SELECT n FROM nbhoods
            ORDER BY n
        }]

        # TBD: See about saving proximity in nbrel_mn in numeric form.
        set data [list]
        $rdb eval {
            SELECT m, n, proximity FROM nbrel_mn
            ORDER BY m,n
        } {
            lappend data $m $n [eproximity index $proximity]
        }
        $uram load prox {*}$data

        $uram load civg {*}[$rdb eval {
            SELECT g,n,basepop FROM civgroups_view
            ORDER BY g
        }]

        $uram load otherg {*}[$rdb eval {
            SELECT g,gtype FROM groups
            WHERE gtype != 'CIV'
            ORDER BY g
        }]

        $uram load hrel {*}[$rdb eval {
            SELECT f, g, current, base, nat FROM gui_hrel_base_view
            ORDER BY f, g
        }]

        $uram load vrel {*}[$rdb eval {
            SELECT g, a, current, base, nat FROM gui_vrel_base_view
            ORDER BY g, a
        }]

        # Note: only SFT has a natural level, and it can't be computed
        # until later.
        $uram load sat {*}[$rdb eval {
            SELECT g, c, current, base, 0.0, saliency
            FROM sat_gc
            ORDER BY g, c
        }]

        # Note: COOP natural levels are not being computed yet.
        $uram load coop {*}[$rdb eval {
            SELECT f, 
                   g,
                   base, 
                   base, 
                   CASE WHEN regress_to='BASELINE' THEN base ELSE natural END
            FROM coop_fg
            ORDER BY f, g
        }]
    }

    #===================================================================
    # SQL Functions

    # Locked
    #
    # Returns 1 if the scenario is locked, and 0 otherwise.

    method Locked {} {
        expr {[$sim state] ne "PREP"}
    }

    # Mgrs args
    #
    # args    map coordinates of one or more points as a flat list
    #
    # Returns a list of one or more map reference strings corrresponding
    # to the coords

    method Mgrs {args} {
        set result [list]

        if {[llength $args] == 1} {
            set args [lindex $args 0]
        }

        foreach {lat lon} $args {
            lappend result [latlong tomgrs [list $lat $lon]]
        }

        return $result
    }

    # UramGamma ctype
    #
    # ctype - A URAM curve type: HREL, VREL, COOP, AUT, CUL, QOL.
    #
    # Returns the "gamma" parameter for curves of that type from
    # parmdb(5).

    method UramGamma {ctype} {
        # The [expr] converts it to a number.
        return [expr [lindex [$parm get uram.factors.$ctype] 1]]
    }

    # Sigline dtype signature
    #
    # dtype     - A driver type
    # signature - The driver's signature
    #
    # Returns the driver's signature line.

    method Sigline {dtype signature} {
        $ruleset $dtype sigline $signature
    }

    # FiringNarrative fdict
    #
    # fdict   - A rule firing dictionary
    #
    # Returns the rule firing's narrative string.

    method FiringNarrative {fdict} {
        set dtype [dict get $fdict dtype]
        $ruleset $dtype narrative $fdict
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
    # svc        - an eabservice(n) value
    # which      - either 'ACTUAL' or 'REQUIRED'
    # urb        - an eurbanization(n) value
    #
    # Returns the proper parmdb parameter value for an abstract
    # infrastructure service based on urbanization and type of LOS

    method Service {svc which urb} {
        return [$adb parm get service.$svc.$which.$urb]
    }


}

