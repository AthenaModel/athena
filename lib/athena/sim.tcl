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
#-----------------------------------------------------------------------

snit::type ::athena::sim {
    #-------------------------------------------------------------------
    # Components

    component adb       ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Options

    # -tickcmd cmd
    #
    # Callback called at the end of each time tick while advancing time. 
    option -tickcmd
    
    #-------------------------------------------------------------------
    # Non-checkpointed Instance Variables

    # constants -- scalar array
    #
    # startdata - The initial date of time 0
    # starttick - The initial simulation tick.
    # tickDelay - The delay between ticks
    
    variable constants -array {
        startdate 2012W01
        starttick 0
    }

    # info -- scalar info array
    #
    # changed   - 1 if saveable(i) data has changed, and 0 
    #             otherwise.
    # state     - The current simulation state, a simstate value
    # stoptime  - The time tick at which the simulation should 
    #             pause, or 0 if there's no limit.
    # basetime  - The time at which a run started.
    # reason    - A code indicating why the run stopped:
    # 
    #             OK        - Normal termination
    #             FAILURE   - On-tick sanity check failure
    #             ""        - Abnormal

    variable info -array {
        changed    0
        state      PREP
        stoptime   0
        basetime   0
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

    constructor {adb_ args} {
        # FIRST, save athenadb(n) handle and options.
        set adb $adb_
        $self configurelist $args

        # NEXT, set the simulation state
        set info(state)    PREP
        set info(changed)  0
        set info(stoptime) 0

        $adb order state $info(state)

        $adb clock configure \
            -week0 $constants(startdate) \
            -tick0 $constants(starttick)

        $adb notify "" <Time>
    }


    #-------------------------------------------------------------------
    # Public Methods

    # reset
    #
    # Reinitializes the module when a new scenario is created.

    method reset {} {
        # FIRST, configure the $adb clock.
        $adb clock reset
        $adb clock configure \
            -week0 $constants(startdate) \
            -tick0 $constants(starttick)

        # NEXT, set the simulation status
        set info(changed) 0
        set info(state)   PREP
    }
    
    #-------------------------------------------------------------------
    # Queries

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

    # wizlock ?flag?
    #
    # flag   - on | off
    #
    # By default, returns true if the sim state is WIZARD.  If the
    # flag is given, sets the sim state to WIZARD or to PREP, accordingly.

    method wizlock {{flag ""}} {
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
        set oldDate [$adb clock cget -week0]

        $adb clock configure -week0 $startdate

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
        set oldtick [$adb clock cget -tick0]

        $adb clock configure -tick0 $starttick

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
        $adb clock mark set LOCK
        $adb clock mark set RUN

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
    #
    # Causes the simulation to run time forward until the specified
    # time, or until "pause" is called.
    #
    # Time advances by ticks until the stoptime is reached or
    # 'sim pause' is called during the -tickcmd.

    method run {args} {
        assert {$info(state) eq "PAUSED"}

        # FIRST, clear the stop reason.
        set info(reason) ""

        # NEXT, get the stop time.  By default, run for one week.
        let info(stoptime) {[$adb clock now] + 1}

        while {[llength $args] > 0} {
            set opt [lshift args]
            
            switch -exact -- $opt {
                -ticks {
                    set val [lshift args]

                    set info(stoptime) [expr {[$adb clock now] + $val}]
                }

                -until {
                    set info(stoptime) [lshift args]
                }

                default {
                    error "Unknown option: \"$opt\""
                }
            }
        }

        # The SIM:RUN order should have guaranteed this, but let's
        # check it to make sure.
        assert {$info(stoptime) > [$adb clock now]}

        # NEXT, set the state to running.  This will initialize the
        # models, if need be.
        $self SetState RUNNING

        # NEXT, mark the start of the run.
        set info(basetime) [$adb clock now]
        $adb clock mark set RUN 1

        # NEXT, we have been paused, and the user might have made
        # changes.  Run necessary analysis before the first tick.
        $self RestartModels

        # NEXT, handle a blocking run.  On error, set state to PAUSED
        # since it didn't get done automatically.
        set withTrans [$adb parm get sim.tickTransaction]

        try {
            while {$info(state) eq "RUNNING"} {
                if {$withTrans} {
                    $adb rdb transaction {
                        $self Tick
                    }
                } else {
                    $self Tick
                }
            }
        } on error {result eopts} {
            $self SetState PAUSED
            return {*}$eopts $result
        }

        # NEXT, return "", as this can't be undone.
        return ""
    }



    # pause
    #
    # Pauses the simulation from running.

    method pause {} {
        # FIRST, set the stoptime to now.
        set info(stoptime) [$adb clock now]

        # NEXT, cannot be undone.
        return ""
    }

    # halt
    #
    # If running, pauses the simulation; never throws an error.
    # This allows the application to halt the sim cleanly on error.

    method halt {} {
        if {[$self state] eq "RUNNING"} {
            $self pause
        }

        return
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

        set t0 [$adb clock now]

        $adb cprofile cash start           ;# Prepare cash for on-lock strategies
        $adb cprofile strategy start       ;# Execute on-lock strategies
        $adb cprofile econ start           ;# Initializes the econ model taking 
                                                # into account on-lock strategies
        $adb cprofile plant start          ;# Initializes the infrastructure model
                                               ;# which depends on the econ model

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
    # This command is executed at each time tick.

    method Tick {} {
        # FIRST, tell the engine to do a tick.
        $self TickModels

        # NEXT, notify the client about progress
        let i {[$adb clock now] - $info(basetime)}
        let n {$info(stoptime) - $info(basetime)}
        callwith $options(-tickcmd) $info(state) $i $n 

        # NEXT, pause if checks failed or the stop time is met.
        set stopping 0

        if {[$adb sanity ontick check] != "OK"} {
            set info(reason) FAILURE
            set stopping 1

            $adb notify "" <InsaneOnTick>
        }

        if {[$adb clock now] >= $info(stoptime)} {
            $adb log normal sim "Stop time reached"
            set info(reason) "OK"
            set stopping 1
        }

        $adb notify "" <Tick>

        if {$stopping} {
            $self SetState PAUSED
            callwith $options(-tickcmd) PAUSED $i $n
        }
    }


    # TickModels
    #
    # This command is executed to update the models at each 
    # simulation time tick.

    method TickModels {} {
        # FIRST, advance time by one tick.
        $adb clock tick
        $adb notify "" <Time>
        $adb log normal sim "Begin Tick [$adb clock now]"

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
        if {[$adb clock now] % [$adb parm get econ.ticksPerTock] == 0} {
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
        $adb cprofile aram advance [$adb clock now]

        # NEXT, save the history for this tick.
        $adb cprofile hist tick

        if {[$adb clock now] % [$adb parm get econ.ticksPerTock] == 0} {
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
        $adb order state $state

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
        dict set checkpoint clock [$adb clock checkpoint]

        return $checkpoint
    }

    # restore checkpoint ?-saved?
    #
    # checkpoint     A string returned by the checkpoint method
    
    method restore {checkpoint {option ""}} {
        $self reset
        set info(changed) 1

        if {[dict size $checkpoint] > 0} {
            dict with checkpoint {
                $adb clock restore $clock
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
    meta parmlist   {
        {weeks 1} 
        {block 1}
    }

    meta form {
        rcc "Weeks to Run:" -for weeks
        text weeks -defvalue 1

        rcc "Block?" -for block
        enumlong block -dict {1 Yes 0 No} -defvalue 1
    }


    method _validate {} {
        my prepare weeks -toupper -type ipositive

        my returnOnError
    }

    method _execute {{flunky ""}} {
        # NEXT, start the simulation and return the undo script. 
        lappend undo [$adb sim run -ticks $parms(weeks)]

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




