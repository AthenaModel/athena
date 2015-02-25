#-----------------------------------------------------------------------
# TITLE:
#    sim.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n) Simulation Ensemble
#
#    This module manages the overall simulation, as distinct from the 
#    the purely scenario-data oriented work done by scenario(sim).
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# sim ensemble

snit::type sim {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Components

    typecomponent ticker    ;# The timeout(n) instance that makes the
                             # simulation go.

    #-------------------------------------------------------------------
    # Non-checkpointed Type Variables

    # constants -- scalar array
    #
    # startdata - The initial date of time 0
    # starttick - The initial simulation tick.
    # tickDelay - The delay between ticks
    
    typevariable constants -array {
        startdate 2012W01
        starttick 0
        tickDelay 50
    }

    # info -- scalar info array
    #
    # changed   - 1 if saveable(i) data has changed, and 0 
    #             otherwise.
    # state     - The current simulation state, a simstate value
    # stoptime  - The time tick at which the simulation should 
    #             pause, or 0 if there's no limit.
    # reason    - A code indicating why the run stopped:
    # 
    #             OK        - Normal termination
    #             FAILURE   - On-tick sanity check failure
    #             ""        - Abnormal


    typevariable info -array {
        changed    0
        state      PREP
        stoptime   0
        reason     ""
    }

    # trans -- transient data array
    #
    #  buffer  - Buffer used to build up long strings.

    typevariable trans -array {
        buffer {}
    }

    #-------------------------------------------------------------------
    # Singleton Initializer

    # init
    #
    # Initializes the simulation proper, to the extent that this can
    # be done at application initialization.  True initialization
    # happens when scenario preparation is locked, when 
    # the simulation state moves from PREP to PAUSED.

    typemethod init {} {
        log normal sim "init"

        # FIRST, register with scenario(sim) as a saveable
        athena register $type

        # NEXT, set the simulation state
        set info(state)    PREP
        set info(changed)  0
        set info(stoptime) 0

        flunky state $info(state)

        simclock configure \
            -week0 $constants(startdate) \
            -tick0 $constants(starttick)

        notifier send ::sim <Time>

        # NEXT, create the ticker
        set ticker [timeout ${type}::ticker                \
                        -interval   $constants(tickDelay) \
                        -repetition yes                    \
                        -command    {profile sim Tick}]

        # NEXT, initialize the model engine.
        $type engine init

        log normal sim "init complete"
    }


    # new
    #
    # Reinitializes the module when a new scenario is created.
    #
    # TODO: move to scenario destructor.

    typemethod new {} {
        # FIRST, configure the simclock.
        simclock reset
        simclock configure \
            -week0 $constants(startdate) \
            -tick0 $constants(starttick)

        # NEXT, reset the map to default.
        map init

        # NEXT, set the simulation status
        set info(changed) 0
        set info(state)   PREP
    }

    # restart
    #
    # Reloads on-lock snapshot.

    typemethod restart {} {
        sim mutate unlock
    }
    
    #-------------------------------------------------------------------
    # RDB Synchronization

    # dbsync
    #
    # Database synchronization occurs when the RDB changes out from under
    # the application, i.e., brand new scenario is created or
    # loaded.  All application modules must re-initialize themselves
    # at this time.
    #
    # * Non-GUI modules subscribe to the <DbSyncA> event.
    # * GUI modules subscribe to the <DbSyncB> event.
    #
    # This guarantees that the "model" is in a consistent state
    # before the "view" is updated.

    typemethod dbsync {} {
        # FIRST, Sync the simulation
        notifier send $type <DbSyncA>

        # NEXT, Sync the GUI
        notifier send $type <DbSyncB>
        notifier send $type <Time>
        notifier send $type <State>
    }

    #-------------------------------------------------------------------
    # Queries

    delegate typemethod now using {::simclock %m}

    # state
    #
    # Returns the current simulation state

    typemethod state {} {
        return $info(state)
    }

    # locked
    #
    # Returns 1 if the simulation is locked, and 0 otherwise.

    typemethod locked {} {
        return [expr {$info(state) in {PAUSED RUNNING}}]
    }

    # stable
    #
    # Returns 1 if the simulation is "stable", with nothing in process.
    # I.e., the simulation is in either the PREP or PAUSED states.

    typemethod stable {} {
        return [expr {$info(state) in {PREP PAUSED}}]
    }

    # stoptime
    #
    # Returns the current stop time in ticks

    typemethod stoptime {} {
        return $info(stoptime)
    }

    # stopreason
    #
    # returns the reason why the sim returned from RUNNING to PAUSED:
    #
    # OK       - Normal termination
    # FAILURE  - on-tick sanity check failure
    # ""       - No reason assigned, hence an unexpected error.
    #            Use [catch] to get these.
    
    typemethod stopreason {} {
        return $info(reason)
    }

    #-------------------------------------------------------------------
    # Wizard Control

    # wizard ?flag?
    #
    # flag   - on | off
    #
    # By default, returns true if the sim state is WIZARD.  If the
    # flag is given, sets the sim state to WIZARD or to PREP, accordingly.

    typemethod wizard {{flag ""}} {
        if {$flag ne ""} {
            assert {$info(state) in {PREP WIZARD}}

            if {$flag} {
                $type SetState WIZARD
            } else {
                $type SetState PREP
            }
        }

        return [expr {$info(state) eq "WIZARD"}]
    }
    

    #-------------------------------------------------------------------
    # Mutators
    #
    # Mutators are used to implement orders that change the simulation in
    # some way.  Mutators assume that their inputs are valid, and returns
    # a script of one or more commands that will undo the change.  When
    # the change cannot be undone, the mutator returns the empty string.


    # mutate startdate startdate
    #
    # startdate   The date of t=0 as a week(n) string
    #
    # Sets the simclock's -week0 start date

    typemethod {mutate startdate} {startdate} {
        set oldDate [simclock cget -week0]

        simclock configure -week0 $startdate

        # NEXT, saveable(i) data has changed
        set info(changed) 1

        # NEXT, notify the app
        notifier send $type <Time>

        # NEXT, set the undo command
        return [mytypemethod mutate startdate $oldDate]
    }

    # mutate starttick starttick
    #
    # starttick   The integer tick as of SIM:LOCK
    #
    # Sets the simclock's -tick0 start tick

    typemethod {mutate starttick} {starttick} {
        set oldtick [simclock cget -tick0]

        simclock configure -tick0 $starttick

        # NEXT, saveable(i) data has changed
        set info(changed) 1

        # NEXT, notify the app
        notifier send $type <Time>

        # NEXT, set the undo command
        return [mytypemethod mutate starttick $oldtick]
    }

    # mutate lock
    #
    # Causes the simulation to transition from PREP to PAUSED.

    typemethod {mutate lock} {} {
        assert {$info(state) eq "PREP"}

        # FIRST, Make sure that bsys has had a chance to compute
        # all of the affinities.
        bsys start

        # NEXT, save an on-lock snapshot
        adb snapshot save

        # NEXT, do initial analyses, and initialize modules that
        # begin to work at this time.
        sigevent log 1 lock "Scenario locked; simulation begins"

        # NEXT, start the engine
        $type engine start

        # NEXT, mark the time
        simclock mark set LOCK
        simclock mark set RUN

        # NEXT, set the state to PAUSED
        $type SetState PAUSED

        # NEXT, resync the GUI, since much has changed.
        notifier send $type <DbSyncB>

        # NEXT, return "", as this can't be undone.
        return ""
    }

    # mutate unlock
    #
    # Causes the simulation to transition from PAUSED
    # to PREP.

    typemethod {mutate unlock} {} {
        assert {$info(state) eq "PAUSED"}

        # FIRST, load the PREP snapshot
        adb snapshot load
        adb snapshot purge
        sigevent purge 0

        # NEXT, set state
        $type SetState PREP

        # NEXT, log it.
        log newlog prep
        log normal sim "Unlocked Scenario Preparation"

        # NEXT, resync the sim with the RDB
        $type dbsync

        # NEXT, return "", as this can't be undone.
        return ""
    }

    # mutate rebase
    #
    # Causes the simulation to transition from PAUSED
    # to PREP, retaining the current simulation state.

    typemethod {mutate rebase} {} {
        assert {$info(state) eq "PAUSED"}

        # FIRST, save the current simulation state to the
        # scenario tables
        adb rebase

        # NEXT, set state
        $type SetState PREP

        # NEXT, log it.
        log newlog prep
        log normal sim "Unlocked Scenario Preparation"

        # NEXT, resync the sim with the RDB
        $type dbsync

        # NEXT, return "", as this can't be undone.
        return ""
    }

    # mutate run ?options...?
    #
    # -ticks ticks       Run until now + ticks
    # -until tick        Run until tick
    # -block flag        If true, block until run completed.
    #
    # Causes the simulation to run time forward until the specified
    # time, or until "mutate pause" is called.
    #
    # Time proceeds by ticks.  Normally, each tick is run in the 
    # context of the Tcl event loop, as controlled by a timeout(n) 
    # object called "ticker".  The timeout interval is called the 
    # inter-tick delay; it determines how fast the simulation runs.
    # If -block is specified, then this routine runs time forward
    # until the stoptime, and then returns.  Thus, -block requires
    # -ticks or -until.

    typemethod {mutate run} {args} {
        assert {$info(state) eq "PAUSED"}

        # FIRST, clear the stop reason.
        set info(reason) ""

        # NEXT, get the pause time
        set info(stoptime) 0
        set blocking 0

        while {[llength $args] > 0} {
            set opt [lshift args]
            
            switch -exact -- $opt {
                -ticks {
                    set val [lshift args]

                    set info(stoptime) [expr {[simclock now] + $val}]
                }

                -until {
                    set info(stoptime) [lshift args]
                }

                -block {
                    set blocking [lshift args]
                }

                default {
                    error "Unknown option: \"$opt\""
                }
            }
        }

        # The SIM:RUN order should have guaranteed this, but let's
        # check it to make sure.
        assert {$info(stoptime) == 0 || $info(stoptime) > [simclock now]}
        assert {!$blocking || $info(stoptime) != 0}

        # NEXT, set the state to running.  This will initialize the
        # models, if need be.
        $type SetState RUNNING

        # NEXT, mark the start of the run.
        simclock mark set RUN 1

        # NEXT, we have been paused, and the user might have made
        # changes.  Run necessary analysis before the first tick.
        $type engine analysis

        # NEXT, Either execute the first tick and schedule the next,
        # or run in blocking mode until the stop time.
        if {!$blocking} {
            # FIRST, run a tick immediately.
            $type Tick

            # NEXT, if we didn't pause as a result of the first
            # tick, schedule the next one.
            if {$info(state) eq "RUNNING"} {
                $ticker schedule
            }

            # NEXT, return "", as this can't be undone.
            return ""
        }

        # NEXT, handle a blocking run.  On error, set state to PAUSED
        # since it didn't get done automatically.
        if {[catch {$type BlockingRun} result eopts]} {
            $type SetState PAUSED
            return {*}$eopts $result
        }

        # NEXT, return "", as this can't be undone.
        return ""
    }

    typemethod BlockingRun {} {
        while {$info(state) eq "RUNNING"} {
            $type Tick
        }

        set info(stoptime) 0
    }

    # mutate pause
    #
    # Pauses the simulation from running.

    typemethod {mutate pause} {} {
        # FIRST, cancel the ticker, so that the next tick doesn't occur.
        $ticker cancel

        # NEXT, if we're in tactic execution just set the stop time to now
        # and TickWork will do the rest.  Otherwise, this is coming from a
        # GUI event, outside TickWork; just set the state to paused.

        if {[flunky state] eq "TACTIC"} {
            set info(stoptime) [simclock now]
        } elseif {$info(state) eq "RUNNING"} {
            set info(stoptime) 0
            $type SetState PAUSED
        }

        # NEXT, cannot be undone.
        return ""
    }

    #-------------------------------------------------------------------
    # Tick

    # Tick
    #
    # This command invokes TickWork to do the tick work, wrapped in an
    # RDB transaction.

    typemethod Tick {} {
        if {[parm get sim.tickTransaction]} {
            rdb transaction {
                $type TickWork
            }
        } else {
            $type TickWork
        }
    }

    # TickWork
    #
    # This command is executed at each time tick.

    typemethod TickWork {} {
        # FIRST, tell the engine to do a tick.  Disable aram's undo
        # capability so that we aren't saving undo info unnecessarily.
        try {
            aram configure -undo off
            $type engine tick
        } finally {
            aram configure -undo on
        }

        # NEXT, pause if it's the pause time, or checks failed.
        set stopping 0

        if {[sanity ontick check] != "OK"} {
            # NEXT, direct the user to the appropriate appserver page
            # if we are in GUI mode
            if {[app tkloaded]} {
                app show my://app/sanity/ontick

                if {[winfo exists .main]} {
                    messagebox popup \
                        -parent  [app topwin]         \
                        -icon    error                \
                        -title   "Simulation Stopped" \
                        -message [normalize {
                On-tick sanity check failed; simulation stopped.
                Please see the On-Tick Sanity Check report for details.
                        }]
                }
            }

            set info(reason) FAILURE
            set stopping 1
        }

        if {$info(stoptime) != 0 &&
            [simclock now] >= $info(stoptime)
        } {
            log normal sim "Stop time reached"
            set info(reason) "OK"
            set stopping 1
        }

        if {$stopping} {
            $type mutate pause
        }

        # NEXT, notify the application that the tick has occurred.
        notifier send $type <Tick>
    }

    #-------------------------------------------------------------------
    # Engine Routines
    
    # engine init
    #
    # Initializes the engine and its submodules, to the extent that
    # this can be done at application initialization.  True initialization
    # happens when scenario preparation is locked, when 
    # the simulation state moves from PREP to PAUSED.

    typemethod {engine init} {} {
        log normal sim "engine init"

        # FIRST, create an instance of URAM and register it as a saveable
        # TBD: wart needed.  Register only in main thread.
        profile uram ::aram \
            -rdb          ::rdb                   \
            -loadcmd      [mytypemethod LoadAram] \
            -undo         on                      \
            -logger       ::log                   \
            -logcomponent "aram"


        athena register [list ::aram saveable]

        log normal engine "init complete"
    }


    # engine start
    #
    # Engine activities on simulation start.

    typemethod {engine start} {} {
        # FIRST, Set up the attitudes model: initialize URAM and relate all
        # existing MADs to URAM drivers.
        profile aram init -reload

        # NEXT, prepare for an immediate rebase (silly though that would be
        # to do).
        rebase prepare

        # NEXT, initialize all modules, and do basic analysis, in preparation
        # for executing the on-lock tactics.

        profile demog start          ;# Computes population statistics
        profile personnel start      ;# Initial deployments and base units.
        profile service start        ;# Populates service tables.

        # NEXT, security must go before coverage
        profile security_model start ;# Computes initial security
        profile coverage_model start ;# Computes initial coverage

        profile security_model analyze 
        profile coverage_model analyze 

        profile control_model start  ;# Computes initial support and influence

        # NEXT, Advance time to tick0.  What we get here is a pseudo-tick,
        # in which we execute the on-lock strategy and provide transient
        # effects to URAM.

        set t0 [simclock now]

        profile cash start           ;# Prepare cash for on-lock strategies
        profile strategy start       ;# Execute on-lock strategies
        profile econ start           ;# Initializes the econ model taking 
                                      # into account on-lock strategies
        profile plant start          ;# Initializes the infrastructure model
                                     ;# which depends on the econ model

        # NEXT, do analysis and assessment, of transient effects only.
        # There will be no attrition and no shifts in neighborhood control.

        profile demog stats
        profile absit assess

        # NEXT, security must go before coverage
        profile security_model analyze
        profile coverage_model analyze

        profile control_model analyze
        profile activity assess
        profile service assess
        set econOK [econ tock]

        # NEXT, if the econ tock is okay, we compute the demographics model
        # econ stats and then run another econ tock with updated unemployment
        # data
        if {$econOK} {
            profile demog econstats
            profile econ tock
        }

        profile ruleset CONSUMP assess
        profile ruleset UNEMP assess

        # NEXT, set natural attitude levels for those attitudes whose
        # natural level varies with time.
        $type SetNaturalLevels

        # NEXT, advance URAM to t0, applying the transient inputs
        # entered above.
        profile aram advance $t0

        # NEXT,  Save time 0 history!
        profile hist tick
        profile hist econ
    }


    # engine tick
    #
    # This command is executed at each simulation time tick.
    # A tick is one week long.

    typemethod {engine tick} {} {
        # FIRST, advance time by one tick.
        simclock tick
        notifier send ::sim <Time>
        log normal engine "Tick [simclock now]"

        # NEXT, prepare for a rebase at the end of this tick.
        rebase prepare

        # NEXT, allow the population to grow or shrink
        # according to its growth rate, and recompute 
        # demographic statistics.
        profile demog growth
        profile demog stats
        
        # NEXT, GOODS production infrastructure plants may degrade 
        profile plant degrade

        # NEXT, execute strategies; this changes the situation
        # on the ground.  It may also schedule events to be executed
        # immediately.  Recompute demog stats immediately, as the
        # strategies might have moved population around.
        profile strategy tock
        profile demog stats

        # NEXT, do analysis and assessment
        profile absit assess

        # NEXT, security must go before coverage
        profile security_model analyze
        profile coverage_model analyze

        profile ruleset MOOD assess
        profile control_model analyze
        profile activity assess
        profile service assess
        profile abevent assess

        # NEXT, do attrition and recompute demog stats, since groups
        # might have lost personnel
        profile aam assess
        profile demog stats

        # NEXT, update the economics.
        if {[simclock now] % [parm get econ.ticksPerTock] == 0} {
            set econOK [profile econ tock]

            if {$econOK} {
                profile demog econstats
            }
        }

        # NEXT, assess econ-dependent drivers.
        profile ruleset CONSUMP assess
        profile ruleset UNEMP assess
        profile control_model assess

        # NEXT, advance URAM, first giving it the latest population data
        # and natural attitude levels.
        aram update pop {*}[rdb eval {
            SELECT g,population 
            FROM demog_g
        }]

        profile $type SetNaturalLevels
        profile aram advance [simclock now]

        # NEXT, save the history for this tick.
        profile hist tick

        if {[simclock now] % [parm get econ.ticksPerTock] == 0} {
            if {$econOK} {
                profile hist econ
            }
        }
    }

    # engine analysis
    #
    # Analysis to be done when restarting simulation, to update
    # data values used by strategy conditions.

    typemethod {engine analysis} {} {
        profile demog stats
        profile security_model analyze
        profile coverage_model analyze
        profile control_model analyze
    }

    #-------------------------------------------------------------------
    # URAM-related routines.
    
    # LoadAram uram
    #
    # Loads scenario data into URAM when it's initialized.

    typemethod LoadAram {uram} {
        $uram load causes {*}[ecause names]

        $uram load actors {*}[rdb eval {
            SELECT a FROM actors
            ORDER BY a
        }]

        $uram load nbhoods {*}[rdb eval {
            SELECT n FROM nbhoods
            ORDER BY n
        }]

        # TBD: See about saving proximity in nbrel_mn in numeric form.
        set data [list]
        rdb eval {
            SELECT m, n, proximity FROM nbrel_mn
            ORDER BY m,n
        } {
            lappend data $m $n [eproximity index $proximity]
        }
        $uram load prox {*}$data

        $uram load civg {*}[rdb eval {
            SELECT g,n,basepop FROM civgroups_view
            ORDER BY g
        }]

        $uram load otherg {*}[rdb eval {
            SELECT g,gtype FROM groups
            WHERE gtype != 'CIV'
            ORDER BY g
        }]

        $uram load hrel {*}[rdb eval {
            SELECT f, g, current, base, nat FROM gui_hrel_base_view
            ORDER BY f, g
        }]

        $uram load vrel {*}[rdb eval {
            SELECT g, a, current, base, nat FROM gui_vrel_base_view
            ORDER BY g, a
        }]

        # Note: only SFT has a natural level, and it can't be computed
        # until later.
        $uram load sat {*}[rdb eval {
            SELECT g, c, current, base, 0.0, saliency
            FROM sat_gc
            ORDER BY g, c
        }]

        # Note: COOP natural levels are not being computed yet.
        $uram load coop {*}[rdb eval {
            SELECT f, 
                   g,
                   base, 
                   base, 
                   CASE WHEN regress_to='BASELINE' THEN base ELSE natural END
            FROM coop_fg
            ORDER BY f, g
        }]
    }

    # SetNaturalLevels
    #
    # This routine sets the natural level for all attitude curves whose
    # natural level changes over time.
    
    typemethod SetNaturalLevels {} {
        # Set the natural level for all SFT curves.
        set Z [parm get attitude.SFT.Znatural]

        set values [list]

        rdb eval {
            SELECT g, security
            FROM civgroups
            JOIN force_ng USING (g,n)
        } {
            lappend values $g SFT [zcurve eval $Z $security]
        }

        aram sat cset {*}$values
    }

    #-------------------------------------------------------------------
    # Utility Routines

    # SetState state
    #
    # state    The simulation state
    #
    # Sets the current simulation state, and reports it as <State>.

    typemethod SetState {state} {
        # FIRST, transition to the new state.
        set info(state) $state
        log normal sim "Simulation state is $info(state)"

        notifier send $type <State>
    }

    #-------------------------------------------------------------------
    # saveable(i) interface

    # checkpoint ?-saved?
    #
    # Returns a checkpoint of the non-RDB simulation data.

    typemethod checkpoint {{option ""}} {
        assert {$info(state) in {PREP PAUSED}}

        if {$option eq "-saved"} {
            set info(changed) 0
        }

        set checkpoint [dict create]
        
        dict set checkpoint state $info(state)
        dict set checkpoint clock [simclock checkpoint]

        return $checkpoint
    }

    # restore checkpoint ?-saved?
    #
    # checkpoint     A string returned by the checkpoint typemethod
    
    typemethod restore {checkpoint {option ""}} {
        # FIRST, restore the checkpoint data
        dict with checkpoint {
            simclock restore $clock
            set info(state) $state
        }

        if {$option eq "-saved"} {
            set info(changed) 0
        }
    }

    # changed
    #
    # Returns 1 if saveable(i) data has changed, and 0 otherwise.

    typemethod changed {} {
        return $info(changed)
    }
}

# SIM:STARTDATE
#
# Sets the calendar week corresponding to t=0.

::athena::orders define SIM:STARTDATE {
    meta title      "Set Start Date"
    meta sendstates PREP
    meta parmlist   {startdate}

    meta form {
        rcc "Start Date:" -for startdate
        text startdate
    }

    method _validate {} {
        my prepare startdate -toupper -required -type week
    }

    method _execute {{flunky ""}} {
        my setundo [sim mutate startdate $parms(startdate)]
    }
}

# SIM:STARTTICK
#
# Sets the integer time tick at which the simulation will be locked.

::athena::orders define SIM:STARTTICK {
    meta title      "Set Start Tick"
    meta sendstates PREP
    meta parmlist   {starttick}

    meta form {
        rcc "Start Tick:" -for starttick
        text starttick
    }


    method _validate {} {
        my prepare starttick -toupper -required -type iquantity
    }

    method _execute {{flunky ""}} {
        my setundo [sim mutate starttick $parms(starttick)]
    }
}

# SIM:LOCK
#
# Locks scenario preparation and transitions from PREP to PAUSED.

::athena::orders define SIM:LOCK {
    meta title      "Lock Scenario Preparation"
    meta sendstates PREP
    meta monitor    off
    meta parmlist   {}

    method _validate {} {
        # FIRST, do the on-lock sanity check.
        set sev [sanity onlock check]

        if {$sev eq "ERROR"} {
            app show my://app/sanity/onlock

            my reject * {
                The on-lock sanity check failed with one or more errors; 
                time cannot advance.  Fix the error, and try again.
                Please see the On-lock Sanity Check Report in the 
                Detail Browser for details.
            }

            my returnOnError
        }

        if {$sev eq "WARNING"} {
            app show my://app/sanity/onlock

            if {[my mode] eq "gui"} {
                set answer \
                    [messagebox popup \
                         -title         "On-lock Sanity Check Failed"    \
                         -icon          warning                          \
                         -buttons       {ok "Continue" cancel "Cancel"}  \
                         -default       my cancel                           \
                         -ignoretag     onlock_check_failed              \
                         -ignoredefault ok                               \
                         -parent        [app topwin]                     \
                         -message       [normalize {
                         The on-lock sanity check failed with warnings; 
                         one or more simulation objects are invalid.  See the 
                         Detail Browser for details.  Press "Cancel" and
                         fix the problems, or press "Continue" to 
                         go ahead and lock the scenario, in which 
                         case the invalid simulation objects will be 
                         ignored as the simulation runs.
                     }]]

                if {$answer eq "cancel"} {
                    # Don't do anything.
                    return
                }
            } else {
                my reject * {
                    The on-lock sanity check failed with one or more errors; 
                    time cannot advance.  Fix the error, and try again.
                    Please use the Athena GUI to lock the scenario and see 
                    the On-lock Sanity Check Report in the Detail Browser 
                    for details.
                }
            }
        }
    }

    method _execute {{flunky ""}} {
        my setundo [sim mutate lock]
    }
}


# SIM:UNLOCK
#
# Unlocks the scenario, returning to the PREP state as it was before any
# simulation was done.

::athena::orders define SIM:UNLOCK {
    meta title      "Unlock Scenario Preparation"
    meta sendstates PAUSED
    meta monitor    off
    meta parmlist   {}

    method _validate {} {
        # Nothing to validate
    }

    method _execute {{flunky ""}} {
        my setundo [sim mutate unlock]
    }
}

# SIM:REBASE
#
# Unlocks the scenario and returns to the PREP state, first saving the
# current simulation state as a new base scenario.

::athena::orders define SIM:REBASE {
    meta title      "Rebase Simulation"
    meta sendstates PAUSED
    meta monitor    off
    meta parmlist   {}

    method _validate {} {
        # Nothing to validate
    }

    method _execute {{flunky ""}} {
        # NEXT, make sure the user knows what he is getting into.
        if {[my mode] eq "gui"} {
            set answer [messagebox popup \
                            -title         "Are you sure?"                  \
                            -icon          warning                          \
                            -buttons       {ok "Rebase" cancel "Cancel"}    \
                            -default       my cancel                           \
                            -ignoretag     SIM:REBASE                   \
                            -ignoredefault ok                               \
                            -parent        [app topwin]                     \
                            -message       [normalize {
                                By pressing "Rebase" you will be creating a
                                new scenario based on the current simulation
                                state.  This action cannot be undone, so be
                                sure to save the old scenario before you do
                                this.
                            }]]

            if {$answer eq "cancel"} {
                my cancel
            }
        }

        # NEXT, rebase the scenario; this is not undoable.
        sim mutate rebase
    }
}


# SIM:RUN
#
# Starts the simulation going.

::athena::orders define SIM:RUN {
    meta title      "Run Simulation"
    meta sendstates PAUSED
    meta monitor    off
    meta parmlist   {weeks block}

    meta form {
        rcc "Weeks to Run:" -for weeks
        text weeks

        rcc "Block?" -for block
        enumlong block -dict {1 Yes 0 No} -defvalue 0
    }


    method _validate {} {
        my prepare weeks -toupper -type iticks
        my prepare block -toupper -type boolean

        my returnOnError

        my checkon block {
            if {$parms(block) && ($parms(weeks) eq "" || $parms(weeks) == 0)} {
                my reject block "Cannot block without specifying the weeks to run"
            }

            if {![app tkloaded] && !$parms(block)} {
                my reject block "Must be YES when Athena is in non-GUI mode"
            }
        }
    }

    method _execute {{flunky ""}} {
        if {$parms(block) eq ""} {
            set parms(block) 0
        }

        # NEXT, start the simulation and return the undo script. 
        # There is an assumption that a tick is exactly one week.
        if {$parms(weeks) eq "" || $parms(weeks) == 0} {
            lappend undo [sim mutate run]
        } else {
            lappend undo [sim mutate run -ticks $parms(weeks) -block $parms(block)]
        }

        my setundo [join $undo \n]
    }
}


# SIM:PAUSE
#
# Pauses the simulation.  It's an error if the simulation is not
# running.

::athena::orders define SIM:PAUSE {
    meta title      "Pause Simulation"
    meta sendstates {RUNNING TACTIC}
    meta parmlist   {}


    method _validate {} {
        # Nothing to validate
    }

    method _execute {{flunky ""}} {
        my setundo [sim mutate pause]
    }
}




