#-----------------------------------------------------------------------
# TITLE:
#    sim.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Simulation Control
#
#    This module manages the overall simulation, as distinct from the 
#    the purely scenario-data oriented work done by scenario(sim).
#
# TBD: Global refs: simclock, sanity, app/messagebox, rebase
#
#-----------------------------------------------------------------------

snit::type ::athena::sim {
    #-------------------------------------------------------------------
    # Components

    component adb       ;# The athenadb(n) instance
    component ticker    ;# The timeout(n) instance that makes the
                         # simulation go when running in an event loop.

    #-------------------------------------------------------------------
    # Non-checkpointed Instancd Variables

    # constants -- scalar array
    #
    # startdata - The initial date of time 0
    # starttick - The initial simulation tick.
    # tickDelay - The delay between ticks
    
    variable constants -array {
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

    variable info -array {
        changed    0
        state      PREP
        stoptime   0
        reason     ""
    }

    # trans -- transient data array
    #
    #  buffer  - Buffer used to build up long strings.

    variable trans -array {
        buffer {}
    }

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        # FIRST, save athenadb(n) handle
        set adb $adb_

        # NEXT, set the simulation state
        set info(state)    PREP
        set info(changed)  0
        set info(stoptime) 0

        $adb flunky state $info(state)

        simclock configure \
            -week0 $constants(startdate) \
            -tick0 $constants(starttick)

        $adb notify "" <Time>

        # NEXT, create the ticker
        install ticker using timeout ${selfns}::ticker    \
            -interval   $constants(tickDelay)             \
            -repetition yes                               \
            -command    [list $adb profile sim Tick]

    }


    #-------------------------------------------------------------------
    # Public Methods

    # reset
    #
    # Reinitializes the module when a new scenario is created.

    method reset {} {
        # FIRST, configure the simclock.
        simclock reset
        simclock configure \
            -week0 $constants(startdate) \
            -tick0 $constants(starttick)

        # NEXT, set the simulation status
        set info(changed) 0
        set info(state)   PREP
    }
    
    #-------------------------------------------------------------------
    # Queries

    delegate method now using {::simclock %m}

    # state
    #
    # Returns the current simulation state

    method state {} {
        return $info(state)
    }

    # locked
    #
    # Returns 1 if the simulation is locked, and 0 otherwise.

    method locked {} {
        return [expr {$info(state) in {PAUSED RUNNING}}]
    }

    # stable
    #
    # Returns 1 if the simulation is "stable", with nothing in process.
    # I.e., the simulation is in either the PREP or PAUSED states.

    method stable {} {
        return [expr {$info(state) in {PREP PAUSED}}]
    }

    # stoptime
    #
    # Returns the current stop time in ticks

    method stoptime {} {
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
    
    method stopreason {} {
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

    method wizard {{flag ""}} {
        if {$flag ne ""} {
            assert {$info(state) in {PREP WIZARD}}

            if {$flag} {
                $self SetState WIZARD
            } else {
                $self SetState PREP
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


    # startdate startdate
    #
    # startdate   The date of t=0 as a week(n) string
    #
    # Sets the simclock's -week0 start date.

    method startdate {startdate} {
        set oldDate [simclock cget -week0]

        simclock configure -week0 $startdate

        # NEXT, saveable(i) data has changed
        set info(changed) 1

        # NEXT, notify the app
        $adb notify "" <Time>

        # NEXT, set the undo command
        return [mymethod startdate $oldDate]
    }

    # starttick starttick
    #
    # starttick   The integer tick as of SIM:LOCK
    #
    # Sets the simclock's -tick0 start tick

    method starttick {starttick} {
        set oldtick [simclock cget -tick0]

        simclock configure -tick0 $starttick

        # NEXT, saveable(i) data has changed
        set info(changed) 1

        # NEXT, notify the app
        $adb notify "" <Time>

        # NEXT, set the undo command
        return [mymethod starttick $oldtick]
    }

    # lock
    #
    # Causes the simulation to transition from PREP to PAUSED.

    method lock {} {
        assert {$info(state) eq "PREP"}

        # FIRST, Make sure that bsys has had a chance to compute
        # all of the affinities.
        $adb bsys start

        # NEXT, save an on-lock snapshot
        $adb snapshot save

        # NEXT, do initial analyses, and initialize modules that
        # begin to work at this time.
        $adb sigevent log 1 lock "Scenario locked; simulation begins"

        # NEXT, start the simulation
        $self StartModels

        # NEXT, mark the time: this supports time queries based on
        # symbolic time names.
        simclock mark set LOCK
        simclock mark set RUN

        # NEXT, set the state to PAUSED
        $self SetState PAUSED

        # NEXT, resync the GUI, since much has changed.
        $adb dbsync

        # NEXT, return "", as this can't be undone.
        return ""
    }

    # unlock
    #
    # Causes the simulation to transition from PAUSED
    # to PREP.

    method unlock {} {
        assert {$info(state) eq "PAUSED"}

        # FIRST, load the PREP snapshot
        $adb snapshot load
        $adb snapshot purge
        $adb sigevent purge 0

        # NEXT, set state
        $self SetState PREP

        # NEXT, log it.
        $adb notify "" <Unlock>
        $adb log normal sim "Unlocked Scenario Preparation"

        # NEXT, resync the app with the RDB
        $adb dbsync

        # NEXT, return "", as this can't be undone.
        return ""
    }

    # rebase
    #
    # Causes the simulation to transition from PAUSED
    # to PREP, retaining the current simulation state.

    method rebase {} {
        assert {$info(state) eq "PAUSED"}

        # FIRST, save the current simulation state to the
        # scenario tables
        $adb rebase save

        # NEXT, set state
        $self SetState PREP

        # NEXT, log it.
        $adb notify "" <Unlock>
        $adb log normal sim "Unlocked Scenario Preparation"

        # NEXT, resync the app with the RDB
        $adb dbsync

        # NEXT, return "", as this can't be undone.
        return ""
    }

    # run ?options...?
    #
    # -ticks ticks       Run until now + ticks
    # -until tick        Run until tick
    # -block flag        If true, block until run completed.
    #
    # Causes the simulation to run time forward until the specified
    # time, or until "pause" is called.
    #
    # Time proceeds by ticks.  Normally, each tick is run in the 
    # context of the Tcl event loop, as controlled by a timeout(n) 
    # object called "ticker".  The timeout interval is called the 
    # inter-tick delay; it determines how fast the simulation runs.
    # If -block is specified, then this routine runs time forward
    # until the stoptime, and then returns.  Thus, -block requires
    # -ticks or -until.

    method run {args} {
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
        $self SetState RUNNING

        # NEXT, mark the start of the run.
        simclock mark set RUN 1

        # NEXT, we have been paused, and the user might have made
        # changes.  Run necessary analysis before the first tick.
        $self RestartModels

        # NEXT, Either execute the first tick and schedule the next,
        # or run in blocking mode until the stop time.
        if {!$blocking} {
            # FIRST, run a tick immediately.
            $self Tick

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
        if {[catch {$self BlockingRun} result eopts]} {
            $self SetState PAUSED
            return {*}$eopts $result
        }

        # NEXT, return "", as this can't be undone.
        return ""
    }

    method BlockingRun {} {
        while {$info(state) eq "RUNNING"} {
            $self Tick
        }

        set info(stoptime) 0
    }

    # pause
    #
    # Pauses the simulation from running.

    method pause {} {
        # FIRST, cancel the ticker, so that the next tick doesn't occur.
        $ticker cancel

        # NEXT, if we're in tactic execution just set the stop time to now
        # and TickWork will do the rest.  Otherwise, this is coming from a
        # GUI event, outside TickWork; just set the state to paused.

        if {[$adb flunky state] eq "TACTIC"} {
            set info(stoptime) [simclock now]
        } elseif {$info(state) eq "RUNNING"} {
            set info(stoptime) 0
            $self SetState PAUSED
        }

        # NEXT, cannot be undone.
        return ""
    }

    #-------------------------------------------------------------------
    # Model Execution
    
    # StartModels
    #
    # Initializes the models on simulation start.

    method StartModels {} {
        # FIRST, Set up the attitudes model: initialize URAM and relate all
        # existing MADs to URAM drivers.
        $adb cprofile aram init -reload

        # NEXT, prepare for an immediate rebase (silly though that would be
        # to do).
        $adb rebase prepare

        # NEXT, initialize all modules, and do basic analysis, in preparation
        # for executing the on-lock tactics.

        $adb cprofile demog start          ;# Computes population statistics
        $adb cprofile personnel start      ;# Initial deployments and base units.
        $adb cprofile service start        ;# Populates service tables.

        # NEXT, security must go before coverage
        $adb cprofile security_model start ;# Computes initial security
        $adb cprofile coverage_model start ;# Computes initial coverage

        $adb cprofile security_model analyze 
        $adb cprofile coverage_model analyze 

        $adb cprofile control_model start  ;# Computes initial support and influence

        # NEXT, Advance time to tick0.  What we get here is a pseudo-tick,
        # in which we execute the on-lock strategy and provide transient
        # effects to URAM.

        set t0 [simclock now]

        $adb cprofile cash start           ;# Prepare cash for on-lock strategies
        $adb cprofile strategy start       ;# Execute on-lock strategies
        $adb cprofile econ start           ;# Initializes the econ model taking 
                                            # into account on-lock strategies
        $adb cprofile plant start          ;# Initializes the infrastructure model
                                            # which depends on the econ model
        $adb cprofile aam start            ;# Compute effective forces of 
                                            # deployed troops

        # NEXT, do analysis and assessment, of transient effects only.
        # There will be no attrition and no shifts in neighborhood control.

        $adb cprofile demog stats
        $adb cprofile absit assess

        # NEXT, security must go before coverage
        $adb cprofile security_model analyze
        $adb cprofile coverage_model analyze

        $adb cprofile control_model analyze
        $adb cprofile activity assess
        $adb cprofile service assess
        set econOK [$adb econ tock]

        # NEXT, if the econ tock is okay, we compute the demographics model
        # econ stats and then run another econ tock with updated unemployment
        # data
        if {$econOK} {
            $adb cprofile demog econstats
            $adb cprofile econ tock
        }

        $adb cprofile ruleset CONSUMP assess
        $adb cprofile ruleset UNEMP assess

        # NEXT, set natural attitude levels for those attitudes whose
        # natural level varies with time.
        $self SetNaturalLevels

        # NEXT, advance URAM to t0, applying the transient inputs
        # entered above.
        $adb cprofile aram advance $t0

        # NEXT,  Save time 0 history!
        $adb cprofile hist tick
        $adb cprofile hist econ
    }


    #-------------------------------------------------------------------
    # Tick

    # Tick
    #
    # This command invokes TickWork to do the tick work, wrapped in an
    # RDB transaction.

    method Tick {} {
        if {[$adb parm get sim.tickTransaction]} {
            $adb rdb transaction {
                $self TickWork
            }
        } else {
            $self TickWork
        }
    }

    # TickWork
    #
    # This command is executed at each time tick.

    method TickWork {} {
        # FIRST, tell the engine to do a tick.
        $self TickModels

        # NEXT, pause if it's the pause time, or checks failed.
        set stopping 0

        if {[$adb sanity ontick check] != "OK"} {
            # TBD: Need to handle this across library I/F.
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
            $adb log normal sim "Stop time reached"
            set info(reason) "OK"
            set stopping 1
        }

        if {$stopping} {
            $self pause
        }

        # NEXT, notify the application that the tick has occurred.
        $adb notify "" <Tick>
    }


    # TickModels
    #
    # This command is executed to update the models at each 
    # simulation time tick.

    method TickModels {} {
        # FIRST, advance time by one tick.
        simclock tick
        $adb notify "" <Time>
        $adb log normal sim "Tick [simclock now]"

        # NEXT, prepare for a rebase at the end of this tick.
        $adb rebase prepare

        # NEXT, allow the population to grow or shrink
        # according to its growth rate, and recompute 
        # demographic statistics.
        $adb cprofile demog growth
        $adb cprofile demog stats
        
        # NEXT, GOODS production infrastructure plants may degrade 
        $adb cprofile plant degrade

        # NEXT, execute strategies; this changes the situation
        # on the ground.  It may also schedule events to be executed
        # immediately.  Recompute demog stats immediately, as the
        # strategies might have moved population around.
        $adb cprofile strategy tock
        $adb cprofile demog stats

        # NEXT, do analysis and assessment
        $adb cprofile absit assess

        # NEXT, security must go before coverage
        $adb cprofile security_model analyze
        $adb cprofile coverage_model analyze

        $adb cprofile ruleset MOOD assess
        $adb cprofile control_model analyze
        $adb cprofile activity assess
        $adb cprofile service assess
        $adb cprofile abevent assess

        # NEXT, do attrition and recompute demog stats, since groups
        # might have lost personnel
        $adb cprofile aam assess
        $adb cprofile demog stats

        # NEXT, update the economics.
        if {[simclock now] % [$adb parm get econ.ticksPerTock] == 0} {
            set econOK [$adb cprofile econ tock]

            if {$econOK} {
                $adb cprofile demog econstats
            }
        }

        # NEXT, assess econ-dependent drivers.
        $adb cprofile ruleset CONSUMP assess
        $adb cprofile ruleset UNEMP assess
        $adb cprofile control_model assess

        # NEXT, advance URAM, first giving it the latest population data
        # and natural attitude levels.
        $adb aram update pop {*}[$adb eval {
            SELECT g,population 
            FROM demog_g
        }]

        $adb profile $self SetNaturalLevels
        $adb cprofile aram advance [simclock now]

        # NEXT, save the history for this tick.
        $adb cprofile hist tick

        if {[simclock now] % [$adb parm get econ.ticksPerTock] == 0} {
            if {$econOK} {
                $adb cprofile hist econ
            }
        }
    }

    # RestartModels
    #
    # Analysis to be done when restarting simulation, to update
    # data values used by strategy conditions.

    method RestartModels {} {
        $adb cprofile demog stats
        $adb cprofile security_model analyze
        $adb cprofile coverage_model analyze
        $adb cprofile control_model analyze
    }


    # SetNaturalLevels
    #
    # This routine sets the natural level for all attitude curves whose
    # natural level changes over time.
    
    method SetNaturalLevels {} {
        # Set the natural level for all SFT curves.
        set Z [$adb parm get attitude.SFT.Znatural]

        set values [list]

        $adb eval {
            SELECT g, security
            FROM civgroups
            JOIN force_ng USING (g,n)
        } {
            lappend values $g SFT [zcurve eval $Z $security]
        }

        $adb aram sat cset {*}$values
    }

    #-------------------------------------------------------------------
    # Utility Routines

    # SetState state
    #
    # state    The simulation state
    #
    # Sets the current simulation state, and reports it as <State>.

    method SetState {state} {
        # FIRST, transition to the new state.
        set info(state) $state
        $adb flunky state $state

        $adb log normal sim "Simulation state is $info(state)"

        $adb notify "" <State>
    }

    #-------------------------------------------------------------------
    # saveable(i) interface

    # checkpoint ?-saved?
    #
    # Returns a checkpoint of the non-RDB simulation data.

    method checkpoint {{option ""}} {
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
    # checkpoint     A string returned by the checkpoint method
    
    method restore {checkpoint {option ""}} {
        set info(changed) 1

        if {[dict size $checkpoint] > 0} {
            dict with checkpoint {
                simclock restore $clock
                set info(state) $state
            }
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
        my setundo [$adb sim startdate $parms(startdate)]
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
        my setundo [$adb sim starttick $parms(starttick)]
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
        set sev [$adb sanity onlock check]

        if {$sev in {"ERROR" "WARNING"}} {
            my reject * {
                The on-lock sanity check failed with one or more errors; 
                time cannot advance.  Fix the error, and try again.
                Please see the On-lock Sanity Check Report in the 
                Detail Browser for details.
            }

            my returnOnError
        }
    }

    method _execute {{flunky ""}} {
        my setundo [$adb sim lock]
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
        my setundo [$adb sim unlock]
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
        $adb sim rebase
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

            # TBD: The library needs to know whether the event loop is 
            # running or not.  If not, block automatically.
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
            lappend undo [$adb sim run]
        } else {
            lappend undo [$adb sim run -ticks $parms(weeks) -block $parms(block)]
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
        my setundo [$adb sim pause]
    }
}




