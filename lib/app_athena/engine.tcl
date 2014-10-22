#-----------------------------------------------------------------------
# TITLE:
#    engine.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_engine(n) Engine Ensemble
#
#    This module is responsible for initializing and invoking the
#    model-oriented code at scenario start and at time advances.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# engine ensemble

snit::type engine {
    pragma -hastypedestroy 0 -hasinstances 0


    #-------------------------------------------------------------------
    # Public Type Methods

    # init
    #
    # Initializes the engine and its submodules, to the extent that
    # this can be done at application initialization.  True initialization
    # happens when scenario preparation is locked, when 
    # the simulation state moves from PREP to PAUSED.

    typemethod init {} {
        log normal engine "init"

        # FIRST, create an instance of URAM and register it as a saveable
        # TBD: wart needed.  Register only in main thread.
        profile uram ::aram \
            -rdb          ::rdb                   \
            -loadcmd      [mytypemethod LoadAram] \
            -undo         on                      \
            -logger       ::log                   \
            -logcomponent "aram"


        scenario register [list ::aram saveable]

        # NEXT, initialize the simulation modules
        econ init ;# TBD: Proxy needed, but not a simple forwarding proxy.
        driver::IOM init

        log normal engine "init complete"
    }


    # start
    #
    # Engine activities on simulation start.

    typemethod start {} {
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
        profile nbstat start         ;# Computes initial security and coverage
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
        profile nbstat analyze
        profile control_model analyze
        profile driver::actsit assess
        profile service_eni assess
        profile service_ais assess
        set econOK [econ tock]

        # NEXT, if the econ tock is okay, we compute the demographics model
        # econ stats and then run another econ tock with updated unemployment
        # data
        if {$econOK} {
            profile demog econstats
            profile econ tock
        }

        profile driver::CONSUMP assess
        profile driver::UNEMP assess

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


    # tick
    #
    # This command is executed at each simulation time tick.
    # A tick is one week long.

    typemethod tick {} {
        # FIRST, advance time by one tick.
        simclock tick
        notifier send $type <Time>
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
        profile nbstat analyze
        profile driver::MOOD assess
        profile control_model analyze
        profile driver::actsit assess
        profile service_eni assess
        profile service_ais assess
        profile driver::abevent assess

        # NEXT, do attrition and recompute demog stats, since groups
        # might have lost personnel
        profile aam assess
        profile demog stats

        # NEXT, update the economics.
        if {[simclock now] % [parmdb get econ.ticksPerTock] == 0} {
            set econOK [profile econ tock]

            if {$econOK} {
                profile demog econstats
            }
        }

        # NEXT, assess econ-dependent drivers.
        profile driver::CONSUMP assess
        profile driver::UNEMP assess
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

        if {[simclock now] % [parmdb get econ.ticksPerTock] == 0} {
            if {$econOK} {
                profile hist econ
            }
        }
    }

    # analysis
    #
    # Analysis to be done when restarting simulation, to update
    # data values used by strategy conditions.

    typemethod analysis {} {
        profile demog stats
        profile nbstat analyze
        profile control_model analyze
    }

    #-------------------------------------------------------------------
    # URAM-related routines.
    #
    # TBD: Consider defining an ::aram module that wraps an instance
    # of ::uram.  These calls would naturally belong there.
    
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
}





