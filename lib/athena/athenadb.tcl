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
    component rdb            -public rdb            ;# writable sqldatabase handle
    component autogen        -public autogen        ;# Scenario auto-generator
    component background     -public background     ;# master for bg thread
    component executive      -public executive      ;# executive command processor
    component exporter       -public export         ;# exporter
    component flunky         -public order          ;# athena_flunky(n)
    component gofer          -public gofer          ;# gofer
    component hist           -public hist           ;# results history
    component logger         -public log            ;# logger(n)
    component parmdb         -public parm           ;# model parameter DB
    component paster         -public paste          ;# paste manager
    component pot            -public bean           ;# beanpot(n)
    component ptype          -public ptype          ;# parm type validators
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

    # -subject name
    #
    # The name of the object for use in log messages and as a 
    # notifier(n) subject.  Defaults to the tail of the object's command.

    option -subject \
        -readonly yes

    # -adbfile filename
    #
    # Pseudo-option, read-only after creation.  Used to open an .adb 
    # file.  After that, tracks names established by "save".

    option -adbfile      \
        -default     ""  \
        -readonly    yes \
        -cgetmethod  CgetAdbFile

    method CgetAdbFile {opt} {
        return [$self adbfile]
    }

    # -logdir dir
    #
    # The name of the root log directory for this scenario object.
    # The scenario will create a subdirectory based on its -subject.

    option -logdir


    # -scratch dirname
    #
    # The name of a directory in which athena(n) can write files.
    # Defaults to the current working directory.

    option -scratch \
        -default ""

    # -executivecmd cmd
    #
    # The name of a command to call to define additional executive
    # commands in the context of the scenario.  The cmd is a command
    # prefix, to which will be added the name of the athena(n) object.
    
    option -executivecmd \
        -readonly yes

    #-------------------------------------------------------------------
    # Instance Variables

    # Scenario working info.
    #
    # adbfile   - The name of the related .adb file, or "" if none.
    # changed   - 1 if cpinfo changed, 0 otherwise.
    # saveables - Dictionary of saveable(i) objects by symbolic name.
    #             The symbolic name is used in the RDB saveables table.
    # 
    # datalock  - 1 if scenario is locked, 0 if it is not.
    # busytext  - The busy text
    # pausecmd  - Command to use to pause the scenario when busy.
    # progress  - Busy progress indicator, "user", "wait", or fraction.
    # state     - State as of last state change.  Used to detect changes.

    variable info -array {
        adbfile   ""
        changed   0
        saveables {}
        busytext  ""
        pausecmd  {}
        progress  user
        state     ""
    }

    # cpinfo - Checkpointed Data Array
    #
    # locked   - The scenario lock flag.  If 1, scenario is locked;
    #            if 0, scenario is unlocked.

    variable cpinfo -array {
        locked 0
    }

    #-------------------------------------------------------------------
    # Constructor/Destructor

    # constructor ?options...?
    #
    # Creates a new scenario object.  If a valid -adbfile is given,
    # the .adb file will be loaded; otherwise, the new scenario will
    # be empty.  

    constructor {args} {
        # FIRST, initialize the workdir if it hasn't been.
        workdir init

        # NEXT, set the -subject's default value.  Then, get the option
        # values.
        set options(-subject) $self

        $self configurelist $args

        # NEXT, create the simulation clock
        install simclock using ::projectlib::weekclock ${selfns}::simclock

        # NEXT, initialize the log.
        if {$options(-logdir) eq ""} {
            set options(-logdir) [workdir join log]
        }

        install logger using logger ${selfns}::logger \
            -simclock  $simclock                      \
            -logdir    $options(-logdir)              \
            -newlogcmd [mymethod OnNewLog]

        $self log normal athenadb "Initializing athena: $options(-subject)"

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
        $flunky state [$self state]

        # NEXT, create the gofer for retrieving data.
        install gofer using ::athena::goferx create ${selfns}::gofer $self

        # NEXT, support pasting of objects.
        install paster using ::athena::paster create ${selfns}::paster $self

        # NEXT, create the executive.
        install executive using ::athena::executive ${selfns}::executive \
            $self \
            -executivecmd $options(-executivecmd)

        # NEXT, create the parmdb.
        install parmdb using ::athena::parmdb ${selfns}::parmdb $self

        # NEXT, add aram.
        install aram using uram ${selfns}::aram \
            -parmset      $parmdb               \
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
            background                  \
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
        $self RegisterSaveable aram     [list $aram saveable]
        $self RegisterSaveable athenadb $self
        $self RegisterSaveable bsys     $bsys
        $self RegisterSaveable econ     $econ
        $self RegisterSaveable parm     $parmdb
        $self RegisterSaveable pot      $pot
        $self RegisterSaveable sim      $sim


        # NEXT, either load the named file or create an empty database.
        if {$options(-adbfile) ne ""} {
            $self load $options(-adbfile)
        } else {
            set info(adbfile) ""
            $self FinishOpeningScenario
        }

        # NEXT, make the scenario saved.
        $self marksaved
    } 

    # OnNewLog filename
    #
    # This is called when we open a new log directory.

    method OnNewLog {filename} {
        $self notify "" <NewLog> $filename
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
        $self RdbEvalFile gui_combat.sql         ;# Combat 
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
        catch {
            $rdb close
            $rdb destroy
        }
    }

    #-------------------------------------------------------------------
    # Delegated commands

    # RDB
    delegate method eval              to rdb
    delegate method delete            to rdb
    delegate method exists            to rdb
    delegate method grab              to rdb
    delegate method last_insert_rowid to rdb
    delegate method monitor           to rdb
    delegate method onecolumn         to rdb
    delegate method query             to rdb
    delegate method schema            to rdb
    delegate method tables            to rdb
    delegate method ungrab            to rdb

    # FLUNKY
    delegate method send              to flunky

    #-------------------------------------------------------------------
    # Scenario Control

    # reset
    #
    # Resets the scenario to its empty state, i.e., turns it into a 
    # "new" scenario.

    method reset {} {
        require {[$self idle]} "A new scenario cannot be created in this state."

        # FIRST, unlock the scenario if it is locked; this
        # will reinitialize modules like URAM.
        if {[$self locked]} {
            $self unlock
        }

        # NEXT, open a new log directory.
        $self log newlog reset

        # NEXT, close the RDB if it's open
        if {[$rdb isopen]} {
            $rdb close
        }

        # NEXT, Reset the scenario, restoring saveable from an empty RDB.
        $self InitializeRDB
        $self RestoreSaveables
        $strategy reset
        $nbhood   dbsync

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
        $flunky reset

        $self FinishOpeningScenario
        $rdb marksaved
    }

    # InitializeRDB
    #
    # Initializes the RDB, opening a new RDB file on disk.

    method InitializeRDB {} {
        # FIRST, create the actual RDB file on the disk.
        $rdb open [fileutil::tempfile rdb]
        $rdb clear

        # NEXT, enable write-ahead logging on the RDB
        $rdb eval { PRAGMA journal_mode = WAL; }
    }

    # FinishOpeningScenario 
    #
    # Defines the temp schema and notifies
    # the application.

    method FinishOpeningScenario {} {
        $self DefineTempSchema
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
        require {[$self idle]} "A new scenario cannot be opened in this state."

        # NEXT, open a new log directory.
        $self log newlog load
        $self log normal athenadb "load $filename"

        try {
            $rdb load $filename
        } on error {result eopts} {
            throw {SCENARIO OPEN} $result
        }

        # NEXT, restore the saveables
        $self RestoreSaveables -saved
        $rdb marksaved

        $executive reset
        $flunky reset


        # NEXT, Finish Up
        $self FinishOpeningScenario

        $strategy dbsync
        $nbhood dbsync

        # NEXT, save the name.
        set info(adbfile) $filename

        return
    }

    # loadtemp filename
    #
    # filename  - An .adb file
    #
    # Loads the scenario data from the temporary file into the object, 
    # replacing what went before.  The result is unsaved.  This is
    # for loading the results from a background process or thread.

    method loadtemp {filename} {
        $self log normal athenadb "loadtemp $filename"
        try {
            $rdb load $filename
        } on error {result eopts} {
            throw {SCENARIO OPEN} $result
        }

        # NEXT, restore the saveables without marking them saved.
        $self RestoreSaveables
        $executive reset
        $flunky reset

        $self FinishOpeningScenario

        $strategy dbsync
        $nbhood dbsync

        return
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
        $self log normal athenadb "save $filename"
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

    # savetemp filename
    #
    # filename - Name for the temp save file
    #
    # Saves the scenario to the specified temporary file; the 
    # scenario is not marked saved.  Throws "SCENARIO SAVE" if there's 
    # an error saving.

    method savetemp {filename} {
        $self log normal athenadb "savetemp $filename"

        # FIRST, save the saveables to the rdb.
        $self SaveSaveables

        # NEXT, Save the scenario to disk.
        try {
            file delete -force $filename
            $rdb saveas $filename
        } on error {result} {
            throw {SCENARIO SAVE} $result
        }

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

    # marksaved
    #
    # Marks everything saved, whether it is or not.

    method marksaved {} {
        dict for {name command} $info(saveables) {
            {*}$command checkpoint -saved
        }
        $rdb marksaved
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
    # Scenario State Machine
    #
    # The scenario may be unlocked or locked; and it may be idle or 
    # busy.  The state names are as follows:
    #
    # PREP     - idle, unlocked
    # PAUSED   - idle, locked
    # BUSY     - busy, not interruptible
    # RUNNING  - busy, interruptible
    #
    # The scenario may be locked or unlocked only when it is idle.


    # canlock
    #
    # Returns 1 if the scenario is sane and can be locked, and 0 otherwise.

    method canlock {} {
        set sev [$sanity onlock check]

        expr {$sev ni {"ERROR" "WARNING"}}
    }

    # lock
    #
    # Locks the scenario, initializing the simulation models.  Saves
    # a snapshot of the state just prior to lock, so that it can be
    # restored on unlock.

    method lock {} {
        require {[$self idle] && [$self unlocked]} "Scenario is busy or locked"

        # FIRST, do the on-lock sanity check.
        if {![$self canlock]} {
            throw {SCENARIO LOCK} "Sanity check failed; cannot lock."
        }

        # NEXT, log it.
        $self log newlog lock
        $self log normal athenadb "lock"
        $self sigevent log 1 lock "Locking Scenario; simulation begins"

        # FIRST, Make sure that bsys has had a chance to compute
        # all of the affinities.
        $bsys start

        # NEXT, save an on-lock snapshot
        $self SnapshotSave

        # NEXT, do initial analyses, and initialize modules that
        # begin to work at this time.
        $sim start

        # NEXT, mark the time: this supports time queries based on
        # symbolic time names.
        $simclock mark set LOCK
        $simclock mark set RUN

        # NEXT, lock the scenario
        $self SetLock 1

        # NEXT, resync the GUI, since much has changed.
        $self dbsync

        $self log normal athenadb "Scenario is locked; simulation begins."

        return
    }

    # unlock ?-rebase?
    #
    # Unlocks the scenario.  By default, it restores the on-lock snap-shot,
    # returning the scenario to its state before the scneario was locked.
    # If -rebase is given, the current state of the simulation is saved
    # as the new scenario inputs. 

    method unlock {{opt ""}} {
        require {[$self idle] && [$self locked]} "Scenario is busy or unlocked"

        $self log newlog onlock
        $self log normal athenadb "unlock $opt"

        $self log normal athenadb "Unlocking scenario."

        # FIRST, rebase or load the on-lock snapshot
        if {$opt eq "-rebase"} {
            $self RebaseSave
        } else {
            $self SnapshotLoad
            $self SnapshotPurge
            $sigevent purge 0
        }

        # NEXT, set unlock the scenario
        $self SetLock 0

        # NEXT, log it.
        $self notify "" <Unlock>

        # NEXT, resync the app with the RDB
        $self dbsync
        $self log normal athenadb "Unlocked scenario; Preparation resumes."
        return
    }


    # SetLock flag
    #
    # flag   - 1 if the scenario is locked, and 0 otherwise.
    #
    # Sets the scenario lock flag.

    method SetLock {flag} {
        set cpinfo(locked) $flag
        set info(changed) 1

        $self StateChange
    }

    # busy set busytext ?pausecmd?
    #
    # busytext  - A busy message, e.g., "Running until 2014W32"
    # pausecmd - A command to interrupt the activity.
    #
    # The scenario is running a long running process in the context
    # of the event loop, in either the foreground or the background.
    # The busytext indicates what it is.  If pausecmd is given, it is
    # interruptible; otherwise not.
    #
    # This is usually used with 'progress' to give progress information
    # to the user.
    #
    # busy set can be called multiple times while busy to change the
    # busytext or the pausecmd.

    method {busy set} {busytext {pausecmd ""}} {
        set info(busytext) $busytext
        set info(pausecmd) $pausecmd

        $self StateChange
    }

    # busy clear
    #
    # The long running process has ended. Clears the busytext and
    # pausecmd; the scenario is now idle.

    method {busy clear} {} {
        require {[$self isbusy]} "Scenario is already idle"
        set info(busytext) ""
        set info(pausecmd) ""

        $self progress user
        $self StateChange
    }

    # StateChange
    #
    # Notifies the rest of the scenario code, and the client, that
    # the state has changed.

    method StateChange {} {
        if {[$self state] ne $info(state)} {
            $flunky state [$self state]

            # Clear undo stack on state change; can't undo after
            # going from PREP to PAUSED.
            # TBD: Might not be best approach.  There are no undoable
            # orders in any state but PREP.  Just need to make 
            # canundo/undotext handle the state properly.  Then you
            # can lock, unlock, and have your undo stack back.
            $flunky reset
        }
        $self notify "" <State>
    }

    # progress ?value?
    #
    # value   - A new progress value
    #
    # Gets/sets the progress value.  The progress value may be:
    #
    # user        - The program is under user control.  (Default)
    # wait        - An indefinitely long process is on-going.
    # 0.0 to 1.0  - We are this fraction of the way through the process.
    #
    # When the scenario becomes idle, the progress is set back to "user".
    # It is up to the busy activity to set progress to "wait" or a
    # fraction.
    #
    # Sends <Progress> on change.

    method progress {{value ""}} {
        if {$value ne ""} {
            set info(progress) $value
            $self notify "" <Progress>
        }

        return $info(progress)
    }

    # interrupt
    #
    # Interrupts the busy process.  This is an error if the busy process
    # is not interruptible.

    method interrupt {} {
        require {[$self interruptible]} "No interruptible process is running"
        $self log normal athenadb "Interrupting busy process"
        {*}$info(pausecmd)
        return
    }

    #-------------------------------------------------------------------
    # State Machine Queries
    
    # state
    #
    # Computes and returns the scenario state.

    method state {} {
        if {$info(busytext) ne ""} {
            if {$info(pausecmd) eq ""} {
                return "BUSY"
            } else {
                return "RUNNING"
            }
        } else {
            if {$cpinfo(locked)} {
                return "PAUSED"
            } else {
                return "PREP"
            }
        }
    }

    # statetext
    #
    # Returns a human-readable equivalent of the state, using the
    # busytext if available.

    method statetext {} {
        if {$info(busytext) ne ""} {
            return $info(busytext)
        } else {
            return [esimstate longname [$self state]]
        }
    }

    #-------------------------------------------------------------------
    # Predicates
    #
    # TBD: Eventually, all predicates will be grouped under "is".
    
    # is advanced
    #
    # Returns 1 if time has been advanced, and 0 otherwise.

    method {is advanced} {} {
        expr {[$simclock delta] > 0}
    }


    # locked
    #
    # Returns 1 if the scenario is locked, and 0 otherwise.

    method locked {} {
        if {$cpinfo(locked)} {
            return 1
        } else {
            return 0
        }
    }

    # unlocked
    #
    # Returns 1 if the scenario is unlocked, and 0 otherwise.

    method unlocked {} {
        if {!$cpinfo(locked)} {
            return 1
        } else {
            return 0
        }
    }

    # idle
    #
    # Returns 1 if the scenario is idle, with nothing in process,
    # and 0 otherwise.

    method idle {} {
        expr {$info(busytext) eq ""}
    }
    
    # isbusy
    #
    # Returns 1 if the scenario is busy, and 0 otherwise.

    method isbusy {} {
        expr {$info(busytext) ne ""}
    }

    # interruptible
    #
    # Returns 1 if the scenario is busy and the process is interruptible,
    # and 0 otherwise.

    method interruptible {} {
        expr {[$self isbusy] && $info(pausecmd) ne ""}
    }

    #-------------------------------------------------------------------
    # Advance time (run)

    # advance ?options...?
    #
    # -ticks ticks   - Run until now + ticks
    # -until tick    - Run until tick
    # -mode mode     - blocking|foreground|background (blocking is default)
    # -tickcmd cmd   - Command is called each tick; see sim.tcl.  
    #
    # Causes the simulation to run time forward until the specified
    # time, or until "interrupt" is called.  This routine processes
    # the inputs and delegates the actual work to either sim.tcl or
    # background.tcl.

    method advance {args} {
        require {[$self idle] && [$self locked]} "Scenario is busy or unlocked"

        # FIRST, process the arguments.
        set ticks   1
        set mode    blocking
        set tickcmd {}

        foroption opt args -all {
            -ticks {
                set ticks [lshift args]
            }
            -until {
                let ticks {[lshift args] - [$simclock now]}
            }
            -mode {
                set mode [lshift args]
            }
            -tickcmd {
                set tickcmd [lshift args]
            }
        }

        assert {$ticks > 0}

        if {$mode eq "background"} {
            $background advance $ticks $tickcmd
        } elseif {$mode in {"blocking" "foreground"}} {
            $sim advance $mode $ticks $tickcmd
        } else {
            error "Invalid -mode: \"$mode\""
        }
    }    


    #-------------------------------------------------------------------
    # Snapshot management

    # SnapshotSave
    #
    # Saves an on-lock snapshot of the scenario, so that we can 
    # return to it on-lock.  See nonSnapshotTables, above, for the
    # excluded tables.

    method SnapshotSave {} {
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
        $self log normal athenadb "snapshot saved: [string length $snapshot] bytes"
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

    # SnapshotLoad
    #
    # Loads the on-lock snapshot.  The caller should
    # dbsync the sim.

    method SnapshotLoad {} {
        set snapshot [$rdb onecolumn {
            SELECT snapshot FROM snapshots
            WHERE tick = -1
        }]

        # NEXT, import it.
        $self log normal athenadb \
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

    # SnapshotPurge
    #
    # Purges the on-lock snapshot and all history.

    method SnapshotPurge {} {
        $rdb eval {
            DELETE FROM snapshots;
            DELETE FROM ucurve_contribs_t;
            DELETE FROM rule_firings;
            DELETE FROM rule_inputs;
        }

        $hist purge -1
    }

    #-------------------------------------------------------------------
    # Rebase Scenario

    delegate method {rebase prepare} to rebase as prepare
    
    method RebaseSave {} {

        # FIRST, allow all modules to rebase.
        $rebase save
        
        # NEXT, purge history.  (Do this second, in case the modules
        # needed the history to do their work.)
        $self SnapshotPurge
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

    # rdbfile
    #
    # Returns the name of the working RDB file.  Note that this will
    # change on "load" or "reset".

    method rdbfile {} {
        return [$rdb dbfile]
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

    # profile ?depth? command ?args...?
    #
    # Calls the command once using [time], in the caller's context,
    # and logs the outcome, returning the command's return value.
    # In other words, you can stick "$self profile" before any command name
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

        $self log detail "" "${prefix}profile [list $args] $msec"

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

    # scratch args
    #
    # Returns a path to a file in the scratch directory, joining the
    # arguments together like [file join].

    method scratch {args} {
        if {$options(-scratch) ne ""} {
            set base $options(-scratch)
        } else {
            set base [pwd]
        }

        return [file join $base {*}$args]
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

    #-------------------------------------------------------------------
    # saveable(i) interface

    # checkpoint ?-saved?
    #
    # Returns a checkpoint of the non-RDB simulation data.

    method checkpoint {{option ""}} {
        assert {[$self idle]}

        if {$option eq "-saved"} {
            set info(changed) 0
        }

        set checkpoint [dict create]
        
        return [array get cpinfo]
    }

    # restore checkpoint ?-saved?
    #
    # checkpoint     A string returned by the checkpoint method
    
    method restore {checkpoint {option ""}} {
        set info(changed) 1

        if {[dict size $checkpoint] > 0} {
            array unset cpinfo
            array set cpinfo $checkpoint
        }

        if {$option eq "-saved"} {
            set info(changed) 0
        }
    }

    # changed
    #
    # Returns 1 if saveable(i) data has changed, and 0 otherwise.

    method changed {} {
        return $info(changed)
    }

    #===================================================================
    # RDB Utilities

    # safe subcommand args
    #
    # subcommand  - A subcommand on this same object
    # args        - Arguments to the subcommand
    #
    # Installs an SQLite3 authorizer that prevents writing to the,
    # executes the subcommand in the caller's context, and removes
    # the authorizer.  Errors bubble up normally.

    method safe {subcommand args} {
        $rdb authorizer [myproc SafeRdbAuthorizer]

        try {
            uplevel 1 [list $self $subcommand {*}$args]
        } on error {result eopts} {
            return {*}$eopts "safe $subcommand error: $result"
        } finally {
            $rdb authorizer ""
        }
    }

    # SafeRdbAuthorizer op args
    #
    # op     - The SQLite operation
    # args   - Related arguments; ignored.
    #
    # Allows SELECT, READ, and FUNCTION operations, which are needed to
    # query the database.  All other operations are denied.

    proc SafeRdbAuthorizer {op args} {
        if {$op in {"SQLITE_SELECT" "SQLITE_READ" "SQLITE_FUNCTION"}} {
            return SQLITE_OK
        } else {
            return SQLITE_DENY
        }
    }

    
    #===================================================================
    # SQL Functions

    # Locked
    #
    # Returns 1 if the scenario is locked, and 0 otherwise.

    method Locked {} {
        $self locked
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
        return [expr [lindex [$parmdb get uram.factors.$ctype] 1]]
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
        return [$parmdb get service.$svc.$which.$urb]
    }


}

