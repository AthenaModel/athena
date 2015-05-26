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
    component ticker    ;# A worker(n) object for advancing time in the
                         # foreground.
    
    #-------------------------------------------------------------------
    # Non-checkpointed Instance Variables

    # constants -- scalar array
    #
    # startdate - The initial date of time 0
    # starttick - The initial simulation tick.
    
    variable constants -array {
        startdate 2012W01
        starttick 0
    }

    # info -- scalar info array
    #
    # changed   - 1 if saveable(i) data has changed, and 0 
    #             otherwise.
    # stoptime  - The time tick at which the simulation should 
    #             pause, or 0 if there's no limit.
    # basetime  - The time at which a run started.
    # reason    - A code indicating why the run stopped:
    # 
    #             COMPLETE  - Normal termination
    #             FAILURE   - On-tick sanity check failure
    #             ""        - Abnormal

    variable info -array {
        changed    0
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

    constructor {adb_} {
        # FIRST, save athenadb(n) handle and options.
        set adb $adb_

        # NEXT, set the simulation state
        set info(changed)  0
        set info(stoptime) 0

        $adb clock configure \
            -week0 $constants(startdate) \
            -tick0 $constants(starttick)

        $adb notify "" <Time>

        # NEXT, create the ticker, should we need it. 
        install ticker using worker ${selfns}::ticker
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
    }
    
    #-------------------------------------------------------------------
    # Queries


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
    # COMPLETE - Normal termination
    # FAILURE  - on-tick sanity check failure
    # ""       - No reason assigned, hence an unexpected error.
    #            Use [catch] to get these.
    
    method stopreason {} {
        return $info(reason)
    }

    #-------------------------------------------------------------------
    # Simulation Control

    # start
    #
    # Initializes the models on simulation start.

    method start {} {
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
                                            # which depends on the econ model
        $adb cprofile aam start            ;# Initializes attrition model

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


    # advance mode ticks ?tickcmd?
    #
    # mode     - blocking|foreground
    # ticks    - Number of ticks to advance time.
    # tickcmd  - Command to call on each tick and at end.
    #
    # Time advances by ticks until the stoptime is reached or
    # "pause' is called during the -tickcmd.  The process is 
    # interruptible if the mode is foreground; and sim pause
    # will pause even when blocking if called in the tickcmd.

    method advance {mode ticks {tickcmd ""}} {
        assert {[$adb is idle] && [$adb is locked]}

        # FIRST, clear the stop reason.
        set info(reason) ""

        # NEXT, get the stop time.  By default, run for one week.
        let info(stoptime) {[$adb clock now] + $ticks}

        # NEXT, are we interruptible?
        if {$mode eq "foreground"} {
            set pauseCmd [mymethod pause]
        } else {
            set pauseCmd ""
        }

        # NEXT, we are busy.
        $adb busy set \
            "Running until [$adb clock toString $info(stoptime)]" \
            $pauseCmd

        # NEXT, mark the start of the run.
        set info(basetime) [$adb clock now]
        $adb clock mark set RUN 1

        # NEXT, we have been paused, and the user might have made
        # changes.  Run necessary analysis before the first tick.
        $self RestartModels

        # NEXT, handle a blocking run.  On error, set state to PAUSED
        # since it didn't get done automatically.
        set withTrans [$adb parm get sim.tickTransaction]

        if {$mode eq "blocking"} {
            set allDone 0
            while {!$allDone} {
                set allDone [$self DoTick $withTrans $tickcmd]
            }            
        } elseif {$mode eq "foreground"} {
            $ticker configure \
                -command [list $self DoTick $withTrans $tickcmd]
            $ticker start
        } else {
            error "Invalid mode: \"$mode\""
        }

        return
    }

    # DoTick withTrans tickcmd
    #
    # withTrans  - If true, run in RDB transaction
    # tickcmd    - Callback to pass to Tick.
    #
    # Runs one tick, in an RDB transaction or not.

    method DoTick {withTrans tickcmd} {
        try {
            if {$withTrans} {
                $adb rdb transaction {
                    return [$self Tick $tickcmd]
                }
            } else {
                return [$self Tick $tickcmd]
            }
        } on error {result eopts} {
            # We halted; return to idle and rethrow
            if {[$adb is busy]} {
                $adb busy clear
            }
            return {*}$eopts $result
        }
    }

    # pause
    #
    # Asks the simulation to pause.  This must be called from the 
    # -tickcmd.  Pauses the simulation from running.

    method pause {} {
        # FIRST, set the stoptime to now.
        set info(stoptime) [$adb clock now]
    }

    # halt
    #
    # If running, pauses the simulation; never throws an error.
    # This allows the application to halt the sim cleanly on error.

    method halt {} {
        if {[$adb state] eq "RUNNING"} {
            $self pause
        }

        return
    }

    # Tick tickcmd
    #
    # tickcmd - A command to call after each tick, or ""
    #
    # This command is executed at each time tick.  If returns
    # 1 if it is done, and 0 otherwise.

    method Tick {tickcmd} {
        # FIRST, tell the engine to do a tick.
        $self TickModels

        # NEXT, notify the client about progress
        let i {[$adb clock now] - $info(basetime)}
        let n {$info(stoptime) - $info(basetime)}

        set progflag ""
        if {$tickcmd ne ""} {
            set progflag [{*}$tickcmd [$adb state] $i $n]
        }

        if {$progflag eq ""} {
            $adb progress [expr {double($i)/double($n)}] 
        }

        # NEXT, pause if checks failed or the stop time is met.
        set stopping 0
        lassign [$adb sanity ontick] sev
        if {$sev != "OK"} {
            set info(reason) FAILURE
            set stopping 1
            $adb log warning sim "On-tick sanity check failed"

            $adb notify "" <InsaneOnTick>
        }

        if {[$adb clock now] >= $info(stoptime)} {
            $adb log normal sim "Stop time reached"
            set info(reason) "COMPLETE"
            set stopping 1
        }

        $adb notify "" <Tick>

        if {$stopping} {
            $adb busy clear
            if {$tickcmd ne ""} {
                {*}$tickcmd COMPLETE $i $n
            }
        }

        return $stopping
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
    # saveable(i) interface

    # checkpoint ?-saved?
    #
    # Returns a checkpoint of the non-RDB simulation data.

    method checkpoint {{option ""}} {
        assert {[$adb is idle]}

        if {$option eq "-saved"} {
            set info(changed) 0
        }

        set checkpoint [dict create]
        
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

    #-------------------------------------------------------------------
    # Mutators
    #
    # Mutators are used to implement orders that change the simulation in
    # some way.  Mutators assume that their inputs are valid, and returns
    # a script of one or more commands that will undo the change.  When
    # the change cannot be undone, the mutator returns the empty string.
    #
    # TBD: There is no current reason for these mutators and the associated
    # orders to remain in this module; a "clock" module would make more
    # sense.  However, there is also no pressing reason to move them,
    # as that would require a change in the order names.

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
    # starttick   The integer tick on lock.
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



