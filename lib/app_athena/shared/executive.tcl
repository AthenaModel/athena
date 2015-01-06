#-----------------------------------------------------------------------
# TITLE:
#    executive.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Executive Command Processor
#
#    The Executive is the program's command processor.  It's a singleton
#    that provides safe command interpretation for user input, separate
#    from the main interpreter.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# executive

snit::type executive {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Components

    typecomponent interp  ;# smartinterpreter(n) for processing commands.

    #-------------------------------------------------------------------
    # Instance Variables

    # Array of instance variables
    #
    #  userMode            normal | super
    #  stackTrace          Traceback for last error

    typevariable info -array {
        userMode     normal
        stackTrace   {}
    }
        

    #-------------------------------------------------------------------
    # Initialization
   
    # init
    #
    # Initializes the interpreter at start-up.
 
    typemethod init {} {
        log normal exec "init"

        $type InitializeInterp

        log normal exec "init complete"
    }


    # reset
    #
    # Resets the interpreter back to its original state.

    typemethod reset {} {
        assert {[info exists interp] && $interp ne ""}

        $interp destroy
        set interp ""

        log normal exec "reset starting"
        $type InitializeInterp

        set out ""

        set autoScripts [rdb eval {
            SELECT name FROM scripts
            WHERE auto=1
            ORDER BY seq
        }]

        foreach name $autoScripts {
            log normal exec "loading: $name"
            append out "Loading script: $name\n"
            if {[catch {$type script load $name} result]} {
                log normal exec "failed: $result"
                append out "   *** Failed: $result\n"
            }
        }

        log normal exec "reset complete"

        append out "Executive has been reset.\n"
        return $out
    }

    # check script
    #
    # Checks the script for obvious errors relative to the executive
    # interpreter.  Returns a flat list of line numbers and error
    # messages.

    typemethod check {script} {
        return [tclchecker check $interp $script]
    }

    # InitializeInterp
    #
    # Creates and initializes the executive interpreter.

    typemethod InitializeInterp {} {
        # FIRST, create the interpreter.  It's a safe interpreter but
        # most Tcl commands are retained, to allow scripting.  Allow
        # the "source" command.
        set interp [smartinterp ${type}::interp -cli yes]

        # NEXT, make all mathfuncs available in the global namespace
        $interp eval {
            namespace path ::tcl::mathfunc
        }

        # NEXT, add a few commands back that we need.
        $interp expose file
        $interp expose pwd
        $interp expose source

        # NEXT, add commands that need to be defined in the slave itself.
        $interp proc call {script args} {
            # FIRST, load the args into the executive.
            uplevel 1 [list set argv $args]

            # NEXT, if the script is an internal script, load it.
            if {[script exists $script]} {
                return [uplevel 1 [list script load $script]]
            }

            # NEXT, try to load it from disk.
            if {[extension $script] eq ""} {
                append script ".tcl"
            }

            uplevel 1 [list source [file join [pwd] $script]]
        }

        $interp proc select {args} {
            set query "SELECT $args"
            
            return [rdb query $query]
        }

        $interp proc csv {args} {
            set query "SELECT $args"
            
            return [rdb query $query -mode csv]
        }

        $interp proc selectfile {filename args} {
            return [tofile $filename .txt [select {*}$args]]
        }

        $interp proc csvfile {filename args} {
            return [tofile $filename .csv [csv {*}$args]]
        }

        # NEXT, install the executive functions
        $type DefineExecutiveFunctions

        # NEXT, install the executive commands

        # =
        $interp eval {
            interp alias {} = {} expr
        }
        $interp setsig = 1 1 {expression}

        # advance
        $interp smartalias advance 1 1 {days} \
            [myproc advance]

        # autogen
        $interp ensemble autogen

        # autogen scenario
        $interp smartalias {autogen scenario} 0 - \
            {?-nb n? ?-actors n? ?-frcg n? ?-civg n? ?-orgg n? ?-topics n?} \
            [list autogen scenario]

        # autogen actors
        $interp smartalias {autogen actors} 0 1 {?num?} \
            [list autogen actors]

        # autogen nbhoods
        $interp smartalias {autogen nbhoods} 0 1 {?num?} \
            [list autogen nbhoods]

        # autogen civgroups
        $interp smartalias {autogen civgroups} 0 1 {?num?} \
            [list autogen civgroups]

        # autogen orggroups
        $interp smartalias {autogen orggroups} 0 1 {?num?} \
            [list autogen orggroups]

        # autogen frcgroups
        $interp smartalias {autogen frcgroups} 0 1 {?num?} \
            [list autogen frcgroups]

        # autogen bsystem 
        $interp smartalias {autogen bsystem} 0 1 {?num?} \
            [list autogen bsystem]

        # autogen strategy
        $interp smartalias {autogen strategy} 0 - \
{?-tactics tlist? ?-actors alist? ?-frcg glist? ?-civg glist? ?-orgg glist?} \
            [list autogen strategy]

        # autogen assign
        $interp smartalias {autogen assign} 1 - \
            {owner ?-group g? ?-nbhood n? ?-activity act?} \
            [list autogen assign]

        # axdb 
        $interp ensemble axdb

        # axdb case
        $interp ensemble {axdb case}

        # axdb case add
        $interp smartalias {axdb case add} 0 - {parm value...} \
            [list axdb case add]

        # axdb case dump
        $interp smartalias {axdb case dump} 1 1 {id} \
            [list axdb case dump]

        # axdb case list
        $interp smartalias {axdb case list} 0 0 {} \
            [list axdb case list]

        # axdb clear
        $interp smartalias {axdb clear} 0 0 {} \
            [list axdb clear]

        # axdb close
        $interp smartalias {axdb close} 0 0 {} \
            [list axdb close]

        # axdb create
        $interp smartalias {axdb create} 1 1 {filename} \
            [list axdb create]

        # axdb csv
        $interp smartalias {axdb csv} 1 - {query...} \
            [myproc AxdbQuery csv ""]

        # axdb csvfile
        $interp smartalias {axdb csvfile} 1 - {filename query...} \
            [myproc AxdbQuery csv]

        # axdb open
        $interp smartalias {axdb open} 1 1 {filename} \
            [list axdb open]
            
        # axdb parm
        $interp ensemble {axdb parm}

        # axdb parm define
        $interp smartalias {axdb parm define} 3 3 {name docstring script} \
            [list axdb parm define]

        # axdb parm dump
        $interp smartalias {axdb parm dump} 0 1 {?name?} \
            [list axdb parm dump]

        # axdb parm list
        $interp smartalias {axdb parm list} 0 0 {} \
            [list axdb parm list]

        # axdb parm names
        $interp smartalias {axdb parm names} 0 0 {} \
            [list axdb parm names]

        # axdb prepare
        $interp smartalias {axdb prepare} 1 1 {case_id} \
            [list axdb prepare]

        # axdb run
        $interp smartalias {axdb run} 0 - {?option value...?} \
            [list axdb run]

        # axdb runcase
        $interp smartalias {axdb runcase} 1 - {case_id ?option value...?} \
            [list axdb runcase]

        # axdb select
        $interp smartalias {axdb select} 1 - {query...} \
            [myproc AxdbQuery mc ""]

        # axdb selectfile
        $interp smartalias {axdb selectfile} 1 - {filename query...} \
            [myproc AxdbQuery mc]

        # block
        $interp ensemble block

        # block add
        $interp smartalias {block add} 1 - {agent ?option value...?} \
            [mytypemethod block add]
            
        $interp smartalias {block cget} 1 2 {block_id ?option?} \
            [mytypemethod block cget]

        $interp smartalias {block configure} 1 - {block_id ?option value...?} \
            [mytypemethod block configure]

        $interp smartalias {block last} 0 0 {} \
            [myproc last_bean ::block]

        # condition
        $interp ensemble condition

        # condition add
        $interp smartalias {condition add} 1 - {block_id typename ?option value...?} \
            [mytypemethod condition add]
            
        $interp smartalias {condition cget} 1 2 {condition_id ?option?} \
            [mytypemethod condition cget]

        $interp smartalias {condition configure} 1 - {condition_id ?option value...?} \
            [mytypemethod condition configure]

        $interp smartalias {condition last} 0 0 {} \
            [myproc last_bean ::condition]


        # clear
        $interp smartalias clear 0 0 {} \
            [list .main cli clear]

        # debug
        $interp smartalias debug 0 0 {} \
            [list ::marsgui::debugger new]

        # dump
        $interp ensemble dump

        # dump econ
        $interp smartalias {dump econ} 0 1 {?page?} \
            [list ::econ dump]

        # absit
        $interp ensemble absit

        # absit id
        $interp smartalias {absit id} 2 2 {n stype} \
            [myproc absit_id]

        # absit last
        $interp smartalias {absit last} 0 0 {} \
            [myproc last_absit]

        # enterx
        $interp smartalias enterx 1 - {order ?parm value...?} \
            [myproc enterx]
        
        # errtrace
        $interp smartalias errtrace 0 0 {} \
            [mytypemethod errtrace]

        # export
        $interp smartalias export 1 2 {?-history? scriptFile} \
            [myproc export]

        # extension
        $interp smartalias extension 1 1 {name} \
            [list ::file extension]

        # gofer
        $interp smartalias gofer 1 - {typeOrGdict ?rulename? ?args...?} \
            [mytypemethod gofer]

        # help
        $interp smartalias help 0 - {?-info? ?command...?} \
            [mytypemethod help]

        # last
        $interp ensemble last

        # last block
        $interp smartalias {last block} 0 0 {} \
            [myproc last_bean ::block]

        # last condition
        $interp smartalias {last condition} 0 0 {} \
            [myproc last_bean ::condition]

        # last absit
        $interp smartalias {last absit} 0 0 {} \
            [myproc last_absit]

        # last mad
        $interp smartalias {last mad} 0 0 {} \
            [myproc last_mad]

        # last tactic
        $interp smartalias {last tactic} 0 0 {} \
            [myproc last_bean ::tactic]

        # last_mad
        $interp smartalias last_mad 0 0 {} \
            [myproc last_mad]

        # load
        $interp smartalias load 1 1 {filename} \
            [list scenario open]

        # lock
        $interp smartalias lock 0 0 {} \
            [myproc lock]

        # log
        $interp smartalias log 1 1 {message} \
            [myproc LogCmd]

        # nbfill
        $interp smartalias nbfill 1 1 {varname} \
            [list .main nbfill]

        # new
        $interp smartalias new 0 0 {} \
            [list scenario new]

        # parm
        $interp ensemble parm

        # parm export
        $interp smartalias {parm export} 1 1 {filename} \
            [list ::parm save]

        # parm get
        $interp smartalias {parm get} 1 1 {parm} \
            [list ::parm get]

        # parm import
        $interp smartalias {parm import} 1 1 {filename} \
            [myproc parmImport]

        # parm list
        $interp smartalias {parm list} 0 1 {?pattern?} \
            [myproc parmList]

        # parm names
        $interp smartalias {parm names} 0 1 {?pattern?} \
            [list ::parm names]

        # parm reset
        $interp smartalias {parm reset} 0 0 {} \
            [myproc parmReset]

        # parm set
        $interp smartalias {parm set} 2 2 {parm value} \
            [myproc parmSet]

        # prefs
        $interp ensemble prefs

        # prefs get
        $interp smartalias {prefs get} 1 1 {prefs} \
            [list prefs get]

        # prefs help
        $interp smartalias {prefs help} 1 1 {parm} \
            [list prefs help]

        # prefs list
        $interp smartalias {prefs list} 0 1 {?pattern?} \
            [list prefs list]

        # prefs names
        $interp smartalias {prefs names} 0 1 {?pattern?} \
            [list prefs names]

        # prefs reset
        $interp smartalias {prefs reset} 0 0 {} \
            [list prefs reset]

        # prefs set
        $interp smartalias {prefs set} 2 2 {prefs value} \
            [list prefs set]

        # rdb
        $interp ensemble rdb

        # rdb eval
        $interp smartalias {rdb eval}  1 1 {sql} \
            [list ::rdb safeeval]

        # rdb query
        $interp smartalias {rdb query} 1 - {sql ?option value...?} \
            [list ::rdb safequery]

        # rdb schema
        $interp smartalias {rdb schema} 0 1 {?table?} \
            [list ::rdb schema]

        # rdb tables
        $interp smartalias {rdb tables} 0 0 {} \
            [list ::rdb tables]

        # redo
        $interp smartalias redo 0 0 {} \
            [myproc redo]

        # reset
        $interp smartalias {reset} 0 0 {} \
            [mytypemethod reset]

        # save
        $interp smartalias save 1 1 {filename} \
            [myproc save]

        # script
        $interp ensemble script

        # script auto
        $interp smartalias {script auto} 1 2 {name ?flag?} \
            [mytypemethod script auto]

        # script delete
        $interp smartalias {script delete} 1 1 {name} \
            [mytypemethod script delete]

        # script exists
        $interp smartalias {script exists} 1 1 {name} \
            [mytypemethod script exists]

        # script get
        $interp smartalias {script get} 1 1 {name} \
            [mytypemethod script get]

        # script list
        $interp smartalias {script list} 0 0 {} \
            [mytypemethod script list]

        # script load
        $interp smartalias {script load} 1 1 {name} \
            [mytypemethod script load]

        # script names
        $interp smartalias {script names} 0 0 {} \
            [mytypemethod script names]

        # script save
        $interp smartalias {script save} 2 2 {name script} \
            [mytypemethod script save]

        # script sequence
        $interp smartalias {script sequence} 2 2 {name priority} \
            [mytypemethod script sequence]

        # send
        $interp smartalias send 1 - {order ?option value...?} \
            [myproc send]

        # sendx
        $interp smartalias sendx 1 - {order ?option value...?} \
            [myproc sendx]

        # show
        $interp smartalias show 1 1 {url} \
            [myproc show]

        # sigevent
        $interp smartalias sigevent 1 - {message ?tags...?} \
            [myproc SigEventLog]

        # super
        $interp smartalias super 1 - {arg ?arg...?} \
            [myproc super]

        # tactic
        $interp ensemble tactic

        # tactic add
        $interp smartalias {tactic add} 1 - {block_id typename ?option value...?} \
            [mytypemethod tactic add]
            
        $interp smartalias {tactic cget} 1 2 {tactic_id ?option?} \
            [mytypemethod tactic cget]

        $interp smartalias {tactic configure} 1 - {tactic_id ?option value...?} \
            [mytypemethod tactic configure]

        $interp smartalias {tactic last} 0 0 {} \
            [myproc last_bean ::tactic]

        # tofile
        $interp smartalias tofile 3 3 {filename extension text} \
            [myproc tofile]

        # undo
        $interp smartalias undo 0 0 {} \
            [myproc undo]

        # unlock
        $interp smartalias unlock 0 0 {} \
            [myproc unlock]

        # usermode
        $interp smartalias {usermode} 0 1 {?mode?} \
            [list ::executive usermode]

        # version
        $interp smartalias version 0 0 {} \
            [list version]
    }

    #-------------------------------------------------------------------
    # Function Definitions

    # DefineExecutiveFunctions
    #
    # Defines the executive functions.
    
    typemethod DefineExecutiveFunctions {} {
        $interp function affinity 2 2 {x y} \
            [myproc affinity]

        $interp function aplants 1 1 {a} \
            [myproc aplants]

        $interp function assigned 3 3 {g activity n} \
            [myproc assigned]

        $interp function consumers 1 - {g ?g...?} \
            [myproc consumers]

        $interp function controls 2 - {a n ?n...?} \
            [myproc controls]

        $interp function coop 2 2 {f g} \
            [myproc coop]

        $interp function coverage 3 3 {g activity n} \
            [myproc coverage]

        $interp function deployed 2 - {g n ?n...?} \
            [myproc deployed]

        $interp function gdp 0 0 {} \
            [myproc gdp]

        $interp function goodscap 1 1 {a} \
            [myproc goodscap]

        $interp function goodsidle 0 0 {} \
            [myproc goodsidle]

        $interp function hrel 2 2 {f g} \
            [myproc hrel]

        $interp function income 1 - {a ?a...?} \
            [myproc income]

        $interp function income_black 1 - {a ?a...?} \
            [myproc income_black]

        $interp function income_goods 1 - {a ?a...?} \
            [myproc income_goods]

        $interp function income_pop 1 - {a ?a...?} \
            [myproc income_pop]

        $interp function income_region 1 - {a ?a...?} \
            [myproc income_region]

        $interp function income_world 1 - {a ?a...?} \
            [myproc income_world]

        $interp function influence 2 2 {a n} \
            [myproc influence]

        $interp function local_consumers 0 0 {} \
            [myproc local_consumers]

        $interp function local_pop 0 0 {} \
            [myproc local_pop]

        $interp function local_unemp 0 0 {} \
            [myproc local_unemp]

        $interp function local_workers 0 0 {} \
            [myproc local_workers]

        $interp function mobilized 1 - {g ?g...?} \
            [myproc mobilized]

        $interp function mood 1 1 {g} \
            [myproc mood]

        $interp function nbconsumers 1 - {n ?n...?} \
            [myproc nbconsumers]

        $interp function nbcoop 2 2 {n g} \
            [myproc nbcoop]

        $interp function nbgoodscap 1 1 {n} \
            [myproc nbgoodscap]

        $interp function nbmood 1 1 {n} \
            [myproc nbmood]

        $interp function nbplants 1 1 {n} \
            [myproc nbplants]

        $interp function nbpop 1 - {n ?n...?} \
            [myproc nbpop]

        $interp function nbsupport 2 2 {a n} \
            [myproc nbsupport]

        $interp function nbunemp 1 - {n ?n...?} \
            [myproc nbunemp]

        $interp function nbworkers 1 - {n ?n...?} \
            [myproc nbworkers]

        $interp function now 0 0 {} \
            [list simclock now]

        $interp function onhand 1 1 {a} \
            [myproc onhand]

        $interp function parm 1 1 {parm} \
            [list ::parm get]

        $interp function pbconsumers 0 0 {} \
            [myproc pbconsumers]

        $interp function pbgoodscap 0 0 {} \
            [myproc pbgoodscap]

        $interp function pbplants 0 0 {} \
            [myproc pbplants]

        $interp function pbpop 0 0 {} \
            [myproc pbpop]

        $interp function pbunemp 0 0 {} \
            [myproc pbunemp]

        $interp function pbworkers 0 0 {} \
            [myproc pbworkers]

        $interp function pctcontrol 1 - {a ?a...?} \
            [myproc pctcontrol]

        $interp function plants 2 2 {a n} \
            [myproc plants]

        $interp function pop 1 - {g ?g...?} \
            [myproc pop]

        $interp function repair 2 2 {a n} \
            [myproc repair]

        $interp function reserve 1 1 {a} \
            [myproc reserve]

        $interp function sat 2 2 {g c} \
            [myproc sat]

        $interp function security 1 2 {g ?n?} \
            [myproc security]

        $interp function support 2 3 {a g ?n?} \
            [myproc support]

        $interp function supports 2 - {a b ?n...?} \
            [myproc supports]

        $interp function troops 1 - {g ?n...?} \
            [myproc troops]

        $interp function unemp 1 - {g ?g...?} \
            [myproc unemp]

        $interp function volatility 1 1 {n} \
            [myproc volatility]

        $interp function vrel 2 2 {g a} \
            [myproc vrel]

        $interp function workers 1 - {g ?g...?} \
            [myproc workers]
    }

    # affinity x y
    #
    # x - A belief system entity.
    # y - A belief system entity.
    #
    # At present x and y are any group or actor.
    # Returns the affinity of x for y.

    proc affinity {x y} {
        set gdict [gofer construct NUMBER AFFINITY $x $y] 
        return [gofer::NUMBER eval $gdict]
    }

    # aplants a
    #
    # a - An agent
    #
    # Returns the total number of plants owned by agent a.

    proc aplants {a} {
        set gdict [gofer construct NUMBER AGENT_PLANTS $a] 
        return [gofer::NUMBER eval $gdict]
    }

    # assigned g activity n
    #
    # g - A force group
    # activity - an activity
    # n - A neighborhood
    #
    # Returns the number of personnel in force or org group g
    # assigned to do the activity in nbhood n.

    proc assigned {g activity n} {
        set gdict [gofer construct NUMBER ASSIGNED $g $activity $n] 
        return [gofer::NUMBER eval $gdict]
    }

    # consumers g ?g...?
    #
    # g - A list of civilian groups or multiple civilian groups
    #
    # Returns the consumers belonging to the listed civilian group(s) g.

    proc consumers {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [gofer construct NUMBER GROUP_CONSUMERS $args] 
        return [gofer::NUMBER eval $gdict]
    }

    # controls a n ?n...?
    #
    # a      - An actor
    # n      - A neighborhood
    #
    # Returns 1 if a controls all of the listed neighborhoods, and 
    # 0 otherwise.

    proc controls {a args} {
        set a [actor validate [string toupper $a]]

        if {[llength $args] == 0} {
            error "No neighborhoods given"
        }

        set nlist [list]

        foreach n $args {
            lappend nlist [nbhood validate [string toupper $n]]
        }

        set inClause "('[join $nlist ',']')"

        rdb eval "
            SELECT count(n) AS count
            FROM control_n
            WHERE n IN $inClause
            AND controller=\$a
        " {
            return [expr {$count == [llength $nlist]}]
        }
    }

    # coop f g
    #
    # f - A civilian group
    # g - A force group
    #
    # Returns the cooperation of f with g.

    proc coop {f g} {
        set gdict [gofer construct NUMBER COOP $f $g] 
        return [gofer::NUMBER eval $gdict]
    }

    # coverage g activity n
    #
    # g - A force or org group
    # a - An activity
    # n - A neighborhood
    #
    # Returns the coverage for force/org group g assigned to 
    # activity a in neighborhood n.

    proc coverage {g activity n} {
        set gdict [gofer construct NUMBER COVERAGE $g $activity $n]
        return [gofer::NUMBER eval $gdict]
    }

    # deployed g n ?n...?
    #
    # g - A force or org group
    # n - A neighborhood (or multiple)
    #
    # Returns the deployed personnel of force/org group g
    # deployed in neighborhood(s) n.

    proc deployed {g args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [gofer construct NUMBER DEPLOYED $g $args] 
        return [gofer::NUMBER eval $gdict]
    }

    # gdp
    #
    # Returns the GDP in base-year dollars (i.e., Out::DGDP).
    # It's an error if the economic model is disabled.

    proc gdp {} {
        set gdict [gofer construct NUMBER GDP]
        return [gofer::NUMBER eval $gdict]
    }

    # goodscap a
    #
    # a - An agents
    #
    # Returns the total output capacity of all goods production 
    # plants owned by agent a.

    proc goodscap {a} {
        set gdict [gofer construct NUMBER GOODS_CAP $a] 
        return [gofer::NUMBER eval $gdict]
    }

    # goodsidle
    #
    # Returns the idle capacity for the playbox.

    proc goodsidle {} {
        set gdict [gofer construct NUMBER GOODS_IDLE] 
        return [gofer::NUMBER eval $gdict]
    }

    # hrel f g
    #
    # f - A group
    # g - A group
    #
    # Returns the horizontal relationship of f with g.

    proc hrel {f g} {
        set gdict [gofer construct NUMBER HREL $f $g] 
        return [gofer::NUMBER eval $gdict]
    }

    # income a ?a...?
    #
    # a - A list of actors multiple actors
    #
    # Returns the total income for actor(s) a.

    proc income {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [gofer construct NUMBER INCOME $args] 
        return [gofer::NUMBER eval $gdict]
    }

    # income_black a ?a...?
    #
    # a - A list of actors multiple actors
    #
    # Returns the total income from the black market sector for actor(s) a.

    proc income_black {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [gofer construct NUMBER INCOME_BLACK $args] 
        return [gofer::NUMBER eval $gdict]
    }

    # income_goods a ?a...?
    #
    # a - A list of actors multiple actors
    #
    # Returns the total income from the goods sector for actor(s) a.

    proc income_goods {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [gofer construct NUMBER INCOME_GOODS $args] 
        return [gofer::NUMBER eval $gdict]
    }

    # income_pop a ?a...?
    #
    # a - A list of actors multiple actors
    #
    # Returns the total income from the pop sector for actor(s) a.

    proc income_pop {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [gofer construct NUMBER INCOME_POP $args] 
        return [gofer::NUMBER eval $gdict]
    }

    # income_region a ?a...?
    #
    # a - A list of actors multiple actors
    #
    # Returns the total income from the region sector for actor(s) a.

    proc income_region {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [gofer construct NUMBER INCOME_REGION $args] 
        return [gofer::NUMBER eval $gdict]
    }

    # income_world a ?a...?
    #
    # a - A list of actors multiple actors
    #
    # Returns the total income from the world sector for actor(s) a.

    proc income_world {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [gofer construct NUMBER INCOME_WORLD $args] 
        return [gofer::NUMBER eval $gdict]
    }

    # influence a n
    #
    # a - An actor
    # n - A neighborhood
    #
    # Returns the influence of a in n.

    proc influence {a n} {
        set gdict [gofer construct NUMBER INFLUENCE $a $n] 
        return [gofer::NUMBER eval $gdict]
    }

    # local_consumers 
    #
    # Returns the consumers resident in local neighborhood(s) (all consumers).

    proc local_consumers {} {
        set gdict [gofer construct NUMBER LOCAL_CONSUMERS] 
        return [gofer::NUMBER eval $gdict]
    }

    # local_pop 
    #
    # Returns the population of civilian groups in local neighborhood(s).

    proc local_pop {} {
        set gdict [gofer construct NUMBER LOCAL_POPULATION] 
        return [gofer::NUMBER eval $gdict]
    }

    # local_unemp 
    #
    # Returns the unemployment rate in local neighborhood(s).

    proc local_unemp {} {
        set gdict [gofer construct NUMBER LOCAL_UNEMPLOYMENT_RATE] 
        return [gofer::NUMBER eval $gdict]
    }

    # local_workers 
    #
    # Returns the workers resident in local neighborhood(s).

    proc local_workers {} {
        set gdict [gofer construct NUMBER LOCAL_WORKERS] 
        return [gofer::NUMBER eval $gdict]
    }

    # mobilized g ?g...?
    #
    # g - A force or org group (or multiple)
    #
    # Returns the mobilized personnel of force/org group g
    # in the playbox.

    proc mobilized {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [gofer construct NUMBER MOBILIZED $args] 
        return [gofer::NUMBER eval $gdict]
    }

    # mood g
    #
    # g - A civilian group
    #
    # Returns the mood of group g.

    proc mood {g} {
        set gdict [gofer construct NUMBER MOOD $g] 
        return [gofer::NUMBER eval $gdict]
    }

    # nbconsumers n ?n...?
    #
    # n - A list of neighborhoods
    #
    # Returns the consumers resident in the listed neighborhood(s).

    proc nbconsumers {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [gofer construct NUMBER NBCONSUMERS $args] 
        return [gofer::NUMBER eval $gdict]
    }

    # nbcoop n g
    #
    # n - A neighborhood
    # g - A force group
    #
    # Returns the cooperation of n with g.

    proc nbcoop {n g} {
        set gdict [gofer construct NUMBER NBCOOP $n $g] 
        return [gofer::NUMBER eval $gdict]
    }

    # nbgoodscap n
    #
    # n - A neighborhood
    #
    # Returns the total output capacity of all goods production 
    # plants in a neighborhood n

    proc nbgoodscap {n} {
        set gdict [gofer construct NUMBER NB_GOODS_CAP $n] 
        return [gofer::NUMBER eval $gdict]
    }

    # nbmood n
    #
    # n - Neighborhood
    #
    # Returns the mood of neighborhood n.

    proc nbmood {n} {
        set gdict [gofer construct NUMBER NBMOOD $n] 
        return [gofer::NUMBER eval $gdict]
    }

    # nbplants n
    #
    # n - A neighborhood
    #
    # Returns the total number of plants in 
    # neighborhood n.

    proc nbplants {n} {
        set gdict [gofer construct NUMBER NB_PLANTS $n] 
        return [gofer::NUMBER eval $gdict]
    }

    # nbpop n ?n...?
    #
    # n - A list of neighborhoods
    #
    # Returns the civilian population resident in the listed neighborhood(s).

    proc nbpop {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [gofer construct NUMBER NBPOPULATION $args] 
        return [gofer::NUMBER eval $gdict]
    }

    # nbsupport a n
    #
    # a - An actor
    # n - A neighborhood
    #
    # Returns the support of a in n.

    proc nbsupport {a n} {
        set gdict [gofer construct NUMBER NBSUPPORT $a $n]

        return [gofer::NUMBER eval $gdict]
    }

    # nbunemp n ?n...?
    #
    # n - A list of neighborhoods
    #
    # Returns the unemployment rate for the listed neighborhood(s).

    proc nbunemp {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [gofer construct NUMBER NB_UNEMPLOYMENT_RATE $args] 
        return [gofer::NUMBER eval $gdict]
    }

    # nbworkers n ?n...?
    #
    # n - A list of neighborhoods
    #
    # Returns the workers resident in the listed neighborhood(s).

    proc nbworkers {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [gofer construct NUMBER NBWORKERS $args] 
        return [gofer::NUMBER eval $gdict]
    }

    # onhand a
    #
    # a - An actor
    #
    # Returns the cash on hand of actor a.

    proc onhand {a} {
        set gdict [gofer construct NUMBER CASH_ON_HAND $a] 
        return [gofer::NUMBER eval $gdict]
    }

    # pbconsumers 
    #
    # Returns the consumers resident in the playbox
    #  (same as local_consumers()).

    proc pbconsumers {} {
        set gdict [gofer construct NUMBER PLAYBOX_CONSUMERS] 
        return [gofer::NUMBER eval $gdict]
    }

    # pbgoodscap
    #
    # Returns the total output capacity of all goods production 
    # plants in the playbox.

    proc pbgoodscap {} {
        set gdict [gofer construct NUMBER PLAYBOX_GOODS_CAP] 
        return [gofer::NUMBER eval $gdict]
    }

    # pbplants
    #
    #
    # Returns the total number of plants in the playbox.

    proc pbplants {} {
        set gdict [gofer construct NUMBER PLAYBOX_PLANTS] 
        return [gofer::NUMBER eval $gdict]
    }

    # pbpop 
    #
    # Returns the population of civilian groups in the playbox

    proc pbpop {} {
        set gdict [gofer construct NUMBER PLAYBOX_POPULATION] 
        return [gofer::NUMBER eval $gdict]
    }

    # pbunemp 
    #
    # Returns the average unemployment rate in the playbox

    proc pbunemp {} {
        set gdict [gofer construct NUMBER PLAYBOX_UNEMPLOYMENT_RATE] 
        return [gofer::NUMBER eval $gdict]
    }

    # pbworkers 
    #
    # Returns the workers resident in the playbox
    #  (same as local_workers()).

    proc pbworkers {} {
        set gdict [gofer construct NUMBER PLAYBOX_WORKERS] 
        return [gofer::NUMBER eval $gdict]
    }

    # pctcontrol a ?a...?
    #
    # a - An actor
    #
    # Returns the percentage of neighborhoods controlled by the
    # listed actors.

    proc pctcontrol {args} {
        set gdict [gofer construct NUMBER PCTCONTROL $args] 
        return [gofer::NUMBER eval $gdict]
    }

    # plants a n
    #
    # a - An agent
    # n - A neighborhood
    #
    # Returns the total number of plants owned by agent a in 
    # neighborhood n.

    proc plants {a n} {
        set gdict [gofer construct NUMBER PLANTS $a $n]
        return [gofer::NUMBER eval $gdict]
    }

    # pop g ?g...?
    #
    # g - A list of civilian groups or multiple civilian groups
    #
    # Returns the population of the listed civilian group(s) g in the playbox.

    proc pop {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [gofer construct NUMBER GROUP_POPULATION $args] 
        return [gofer::NUMBER eval $gdict]
    }

    # repair a n
    #
    # a - An actor
    # n - A neighborhood
    #
    # Returns the current level of repair for plants owned by actor a in 
    # neighborhood n.

    proc repair {a n} {
        set gdict [gofer construct NUMBER REPAIR $a $n] 
        return [gofer::NUMBER eval $gdict]
    }

    # reserve a
    #
    # a - An actor
    #
    # Returns the cash reserve of actor a.

    proc reserve {a} {
        set gdict [gofer construct NUMBER CASH_RESERVE $a] 
        return [gofer::NUMBER eval $gdict]
    }

    # sat g c
    #
    # g - A civilian group
    # c - A concern
    #
    # Returns the satisfaction of g with c

    proc sat {g c} {
        set gdict [gofer construct NUMBER SAT $g $c] 
        return [gofer::NUMBER eval $gdict]
    }

    # security g ?n?
    #
    # g - A group
    # n - A neighborhood
    #
    # Returns g's security in n
    # If no n is specified, g is assumed to be a civilian group

   proc security {g {n ""}} {
        if {$n eq ""} {
            set gdict [gofer construct NUMBER SECURITY_CIV $g]
        } else {
            set gdict [gofer construct NUMBER SECURITY $g $n]
        }

        return [gofer::NUMBER eval $gdict]
    }

    # support a g ?n?
    #
    # a - An actor
    # g - A group
    # n - A neighborhood
    #
    # Returns the support for a by g in n. 
    # If n is not given, g is assumed to be a civilian group.

    proc support {a g {n ""}} {
        if {$n eq ""} {
            set gdict [gofer construct NUMBER SUPPORT_CIV $a $g]
        } else {
            set gdict [gofer construct NUMBER SUPPORT $a $g $n]
        }

        return [gofer::NUMBER eval $gdict]
    }

    # supports a b ?n...?
    #
    # a - An actor
    # b - Another actor, SELF, or NONE
    # n - A neighborhood
    #
    # Returns 1 if actor a usually supports actor b, and 0 otherwise.
    # If one or more neighborhoods are given, actor a must support b in 
    # all of them.

    proc supports {a b args} {
        # FIRST, handle the playbox case.
        set a [actor validate [string toupper $a]]
        set b [ptype a+self+none validate [string toupper $b]]

        if {$b eq $a} {
            set b SELF
        }

        if {[llength $args] == 0} {
            if {[rdb exists {
                SELECT supports FROM gui_actors
                WHERE a=$a AND supports=$b
            }]} {
                return 1
            }

            return 0
        }

        # NEXT, handle the multiple neighborhoods case
        set nlist [list]

        foreach n $args {
            lappend nlist [nbhood validate [string toupper $n]]
        }

        set inClause "('[join $nlist ',']')"

        set count [rdb onecolumn "
            SELECT count(*)
            FROM gui_supports
            WHERE a=\$a AND supports=\$b and n IN $inClause
        "]

        if {$count == [llength $nlist]} {
            return 1
        } else {
            return 0
        }
    }

    # troops g ?n...?
    #
    # g      - A force or organization group
    # n      - A neighborhood
    #
    # If no neighborhood is given, returns the number of troops g has in
    # the playbox.  If one or more neighborhoods are given, returns the
    # number of troops g has in those neighborhoods.

    proc troops {g args} {
        set g [ptype fog validate [string toupper $g]]

        # FIRST, handle the playbox case
        if {[llength $args] == 0} {
            rdb eval {
                SELECT total(personnel) AS personnel
                FROM personnel_g WHERE g=$g
            } {
                return [format %.0f $personnel]
            }
        }

        # NEXT, handle the multiple neighborhoods case

        set nlist [list]

        foreach n $args {
            lappend nlist [nbhood validate [string toupper $n]]
        }

        set inClause "('[join $nlist ',']')"

        rdb eval "
            SELECT total(personnel) AS personnel
            FROM deploy_ng
            WHERE n IN $inClause
            AND g=\$g
        " {
            return [format %.0f $personnel]
        }
    }

    # unemp g ?g...?
    #
    # g - A list of civilian groups or multiple civilian groups
    #
    # Returns the unemployment rate for the listed civilian group(s) g.

    proc unemp {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [gofer construct NUMBER GROUP_UNEMPLOYMENT_RATE $args] 
        return [gofer::NUMBER eval $gdict]
    }

    # volatility n
    #
    # n - A neighborhood
    #
    # Returns the volatility of neighborhood n

    proc volatility {n} {
        set n [nbhood validate [string toupper $n]]

        rdb eval {
            SELECT volatility FROM force_n WHERE n=$n
        } {
            return $volatility
        }

        error "volatility not yet computed"
    }

    # vrel g a
    #
    # g - A group
    # a - An actor
    #
    # Returns the vertical relationship of g with a.

    proc vrel {g a} {
        set gdict [gofer construct NUMBER VREL $g $a] 
        return [gofer::NUMBER eval $gdict]
    }

    # workers g ?g...?
    #
    # g - A list of civilian groups or multiple civilian groups
    #
    # Returns the workers belonging to the listed civilian group(s) g.

    proc workers {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [gofer construct NUMBER GROUP_WORKERS $args] 
        return [gofer::NUMBER eval $gdict]
    }

    #-------------------------------------------------------------------
    # Public typemethods

    delegate typemethod expr to interp

    # commands
    #
    # Returns a list of the commands defined in the Executive's 
    # interpreter

    typemethod commands {} {
        $interp eval {info commands}
    }

    # errtrace
    #
    # returns the stack trace from the most recent evaluation error.

    typemethod errtrace {} {
        if {$info(stackTrace) ne ""} {
            log normal exec "errtrace:\n$info(stackTrace)"
        } else {
            log normal exec "errtrace: None"
        }

        return $info(stackTrace)
    }
 
    # eval script
    #
    # Evaluate the script; throw an error or return the script's value.
    # Either way, log what happens. Ignore empty scripts.

    typemethod eval {script} {
        if {[string trim $script] eq ""} {
            return
        }

        log normal exec "Command: $script"

        # Make sure the command displays in the log before it
        # executes.
        update idletasks

        if {[catch {
            if {$info(userMode) eq "normal"} {
                $interp eval $script
            } else {
                uplevel \#0 $script
            }
        } result eopts]} {
            set info(stackTrace) $::errorInfo
            log warning exec "Command error: $result"
            return {*}$eopts $result
        }

        return $result
    }


    # gofer typeOrGdict ?rulename? ?args...?
    #
    # typeOrGdict   - either a type name or a gdict for evaluation.
    # rulename      - a rule name for the named type
    # args          - An arguments required by the rule
    #
    # Constructs gofer dictionary values; type and rule names can
    # be lower case and will be converted automatically.  If there
    # is only one argument, it is assumed to be a gdict, and will
    # be evaluated.

    typemethod gofer {typeOrGdict {rulename ""} args} {
        if {$rulename ne ""} {
            return [gofer construct $typeOrGdict $rulename {*}$args]
        } else {
            return [gofer eval [gofer validate $typeOrGdict]]
        }
    }

    # help ?-info? ?command...?
    #
    # Outputs the help for the command 

    typemethod help {args} {
        if {[llength $args] == 0} {
            app show my://help/command
        }

        if {[lindex $args 0] eq "-info"} {
            set args [lrange $args 1 end]

            set out [$interp help $args]

            append out "\n\n[$interp cmdinfo $args]"

            return $out
        } else {
            app help $args
        }
    }

    # usermode ?mode?
    #
    # mode     normal|super
    #
    # Queries/sets the CLI mode.  In normal mode, all commands are 
    # processed by the smartinterp, unless "super" is used.  In
    # super mode, all commands are processed by the main interpreter.

    typemethod usermode {{mode ""}} {
        # FIRST, handle queries
        if {$mode eq ""} {
            return $info(userMode)
        }

        # NEXT, check the mode
        require {$mode in {normal super}} \
            "Invalid mode, should be one of: normal, super"

        # NEXT, save it.
        set info(userMode) $mode

        # NEXT, this is usually a CLI command; it looks odd to
        # return the mode in this case, so don't.
        return
    }

    #-----------------------------------------------------------------------
    # Script API

    # script names
    #
    # Returns a list of the names of the defined executive scripts
    # in sequence order.

    typemethod {script names} {} {
        return [rdb eval {
            SELECT name FROM scripts ORDER BY seq;
        }]
    }

    # script list
    #
    # Returns a human-readable list of the names of the defined executive 
    # scripts, in sequence order, one per line.  The result is not a
    # proper Tcl list if the names contain whitespace.

    typemethod {script list} {} {
        set out ""
        rdb eval {
            SELECT name, auto 
            FROM scripts ORDER BY seq;
        } {
            if {$auto} {
                append out "$name (auto-execute)\n"
            } else {
                append out "$name"
            }
        }

        return $out
    }

    # script get name
    #
    # name    - The name of the script
    #
    # Retrieves the body of the script given its name.

    typemethod {script get} {name} {
        rdb eval {
            SELECT body FROM scripts WHERE name=$name
        } {
            return $body
        }

        error "No such script: $name"
    }

    # script exists name
    #
    # name    - The putative script name
    #
    # Determines whether there is a script with the given name or not.

    typemethod {script exists} {name} {
        return [rdb exists {SELECT body FROM scripts WHERE name=$name}]
    }

    # script delete name
    #
    # name  - The script name
    #
    # Deletes any script with the given name.

    typemethod {script delete} {name} {
        rdb eval {
            DELETE FROM scripts WHERE name=$name
        }

        notifier send ::executive <Scripts> delete $name
        return
    }

    # script load name
    #
    # name   - The script name
    #
    # Loads the script into the executive interpreter.  No error
    # handling is done; it's presumed that the caller will handle
    # any errors.

    typemethod {script load} {name} {
        set body [$type script get $name]

        return [$type eval $body]
    }

    # script save name ?body? ?-silent?
    #
    # name   - The script name
    # body   - The body of the script
    #
    # Saves the script to disk.  If it already exists, it will be
    # saved back to its own place.  If it does not exist, it will
    # be put at the end of the list.
    #
    # If the body is omitted or "", a comment with the script's
    # name will be used.
    #
    # if "-silent" is included, then no notification will be sent
    # to the application.

    typemethod {script save} {name {body ""} {opt ""}} {
        # FIRST, get the body.
        if {$body eq ""} {
            set body "# $name\n"
        } else {
            set body [outdent $body]
        }

        # NEXT, if it already exists, just save it.
        if {[$type script exists $name]} {
            rdb eval {
                UPDATE scripts SET body=$body WHERE name=$name
            }

            if {$opt ne "-silent"} {
                notifier send ::executive <Scripts> update $name
            }
            return
        }

        # NEXT, get the sequence number, and insert it.
        set seq [rdb onecolumn {
            SELECT coalesce(max(seq) + 1, 1) FROM scripts    
        }]

        rdb eval {
            INSERT INTO scripts(name, seq, body)
            VALUES($name, $seq, $body)
        }

        if {$opt ne "-silent"} {
            notifier send ::executive <Scripts> update $name
        }

        return
    }

    # script auto name ?flag?
    #
    # name   - A script name
    # flag   - A boolean flag
    #
    # Returns the value of the auto flag for the named script, first
    # setting the flag if a new value is given.

    typemethod {script auto} {name {flag ""}} {
        # FIRST, if the script doesn't exist, that's an error.
        require {[$type script exists $name]} \
            "No such script: $name"

        # NEXT, set the flag if given.
        if {$flag ne ""} {
            snit::boolean validate $flag

            if {$flag} {
                set auto 1
            } else {
                set auto 0
            }

            rdb eval {
                UPDATE scripts SET auto=$auto
                WHERE name=$name
            }

            notifier send ::executive <Scripts> update $name
        }

        return [rdb eval {SELECT auto FROM scripts WHERE name=$name}]
    }

    # script import filename
    #
    # filename  - The name of the script file to import
    #
    # If the file can be read, imports a script whose name is the
    # filename minus its extension.  If the name is duplicated, adds
    # a "-<index>" to the end.  Returns the name.

    typemethod {script import} {filename} {
        # FIRST, get the text; any error will be handled by the client.
        set text [readfile $filename]

        # NEXT, get the name
        set name [file rootname [file tail $filename]]

        if {[$type script exists $name]} {
            set name [$type GetUniqueScriptName $name]
        }

        $type script save $name $text

       notifier send ::executive <Scripts> update $name

        return $name
    }

    # GetUniqueScriptName name 
    #
    # name   - A script name
    #
    # Adds numeric indices to the end of the script name until a 
    # unique name is found.

    typemethod GetUniqueScriptName {name} {
        set base $name
        set count 0
        while {[$type script exists $name]} {
            set name "$base-[incr count]"
        }

        return $name
    }

    # script rename oldName newName
    #
    # oldName   - The old script name
    # newName   - The new script name
    #
    # Renames the script as desired.

    typemethod {script rename} {oldName newName} {
        # FIRST, if the script doesn't exist, that's an error.
        if {![$type script exists $oldName]} {
            error "No such script: $oldName"
        }

        rdb eval {
            UPDATE scripts SET name=$newName WHERE name=$oldName
        }

        notifier send ::executive <Scripts> update ""
    }

    # script sequence name priority
    #
    # name      - The script name
    # priority  - An ePrioUpdate value (top, raise, lower, bottom)
    #
    # Moves the script to the desired spot in the sequence.
    
    typemethod {script sequence} {name priority} {
        # FIRST, if the script doesn't exist, that's an error.
        if {![$type script exists $name]} {
            error "No such script: $name"
        } 

        # NEXT, get the old sequence
        set oldSequence [rdb eval {
            SELECT name, seq FROM scripts ORDER BY seq    
        }]

        # NEXT, reposition this script in the sequence.
        set sequence [lprio [dict keys $oldSequence] $name $priority]

        # NEXT, assign new sequence numbers
        set seq 1

        foreach name $sequence {
            rdb eval {
                UPDATE scripts
                SET seq=$seq
                WHERE name=$name
            }

            incr seq
        }

        notifier send ::executive <Scripts> update ""

        return
    }
    
    #-------------------------------------------------------------------
    # Executive Command Implementations

    # advance weeks
    #
    # weeks    - An integer number of weeks
    #
    # advances time by the specified number of weeks.  Locks the
    # scenario if necessary.

    proc advance {weeks} {
        if {[sim state] eq "PREP"} {
            lock
        }

        send SIM:RUN -weeks $weeks -block YES
    }

    # AxdbQuery mode filename query...
    #
    # mode      - query -mode
    # filename  - Name of file to save result in, or ""
    # query     - All of the select query, as arguments on the command line,
    #             except the "SELECT" keyword.
    #
    # Handles the four [axdb] query subcommands.

    proc AxdbQuery {mode filename args} {
        set query "SELECT $args"

        set result [axdb safequery $query -mode $mode]

        if {$filename ne ""} {
            if {$mode eq "csv"} {
                set extension ".csv"
            } else {
                set extension ".txt"
            }

            return [tofile $filename $extension $result]
        } else {
            return $result
        }
    }

    # block add agent ?option value...?
    #
    # agent   - Name of an agent.
    # options - Options for the new block.
    #
    # Adds a block to the given agent's strategy, and applies the
    # options to it.  The options are the BLOCK:UPDATE send options
    # plus -state.

    typemethod {block add} {agent args} {
        cif transaction "block add..." {
            set block_id [send STRATEGY:BLOCK:ADD -agent $agent]
            BlockConfigure $block_id $args
        }

        return $block_id
    }

    # block cget block_id ?option?
    #
    # block_id   - A valid block ID, or "-" for the newest block.
    #
    # Retrieves the value of a block option.  If no option is given,
    # returns a dictionary of options and values.
    #
    # TBD: It may be possible to add a BeanCget command, as the
    # shared implementation for block/condition/tactic cget.

    typemethod {block cget} {block_id {opt ""}} {
        # FIRST, get the block_id
        if {$block_id eq "-"} {
            set block_id [last_bean ::block]
        }

        pot valclass block $block_id

        # NEXT, get the block data
        set block [pot get $block_id]

        set dict [parmdict2optdict [$block view cget]]

        # NEXT, return what was asked for.
        if {$opt eq ""} {
            return $dict
        }

        if {[dict exists $dict $opt]} {
            return [dict get $dict $opt]
        } else {
            error "Unknown option: \"$opt\""
        }
    }

    # block configure block_id ?option value...?
    #
    # block_id      - A valid block ID, or "-" for the newest block.
    # option value  - BLOCK:UPDATE/BLOCK:STATE options
    #
    # Configures the block using orders.

    typemethod {block configure} {block_id args} {
        # FIRST, get the block_id
        if {$block_id eq "-"} {
            set block_id [last_bean ::block]
        }

        # NEXT, configure it
        cif transaction "block configure..." {
            BlockConfigure $block_id $args
        }
    }
    
    # BlockConfigure block_id opts
    #
    # block_id   - A block ID
    # opts       - A list of block options and values
    #
    # Applies the options to the block.  The options are the BLOCK:UPDATE 
    # send options plus -state.

    proc BlockConfigure {block_id opts} {
        set state [from opts -state ""]

        send BLOCK:UPDATE -block_id $block_id {*}$opts

        if {$state ne ""} {
            send BLOCK:STATE -block_id $block_id -state $state
        }
    }

    # condition add block_id typename ?option value...?
    #
    # block_id - A valid block_id, or "-" for the last block created.
    # typename - Type for the new condition
    # options  - Options for the new condition.
    #
    # Adds a condition to the given agent's strategy, and applies the
    # options to it.  The options are the CONDITION:UPDATE send options
    # plus -state.

    typemethod {condition add} {block_id typename args} {
        # FIRST, get the block_id
        if {$block_id eq "-"} {
            set block_id [last_bean ::block]
        }

        # NEXT, create the condition
        cif transaction "condition add..." {
            set condition_id [send BLOCK:CONDITION:ADD \
                                    -block_id $block_id \
                                    -typename $typename]
            ConditionConfigure $condition_id $args
        }

        return $condition_id
    }

    # condition cget condition_id ?option?
    #
    # condition_id   - A valid condition ID, or "-" for the newest condition.
    #
    # Retrieves the value of a condition option.  If no option is given,
    # returns a dictionary of options and values.

    typemethod {condition cget} {condition_id {opt ""}} {
        # FIRST, get the condition_id
        if {$condition_id eq "-"} {
            set condition_id [last_bean ::condition]
        }

        pot valclass condition $condition_id

        # NEXT, get the condition data
        set condition [pot get $condition_id]

        set dict [parmdict2optdict [$condition view cget]]

        # NEXT, return what was asked for.
        if {$opt eq ""} {
            return $dict
        }

        if {[dict exists $dict $opt]} {
            return [dict get $dict $opt]
        } else {
            error "Unknown option: \"$opt\""
        }
    }

    # condition configure condition_id ?option value...?
    #
    # condition_id  - A valid condition ID, or "-" for the newest condition.
    # option value  - CONDITION:UPDATE/CONDITION:STATE options
    #
    # Configures the condition using orders.

    typemethod {condition configure} {condition_id args} {
        # FIRST, get the condition_id
        if {$condition_id eq "-"} {
            set condition_id [last_bean ::condition]
        }

        pot valclass ::condition $condition_id

        # NEXT, configure it
        cif transaction "condition configure..." {
            ConditionConfigure $condition_id $args
        }
    }
    
    # ConditionConfigure condition_id opts
    #
    # condition_id   - A condition ID
    # opts           - A list of condition options and values
    #
    # Applies the options to the condition.  The options are the 
    # CONDITION:UPDATE send options plus -state.

    proc ConditionConfigure {condition_id opts} {
        set c [pot get $condition_id]

        set state [from opts -state ""]

        send CONDITION:[$c typename] -condition_id $condition_id {*}$opts

        if {$state ne ""} {
            send CONDITION:STATE -condition_id $condition_id -state $state
        }
    }


    # absit_id n stype
    #
    # n      - Neighborhood
    # stype  - Situation Type
    #
    # Returns the situation ID of the absit of the given type
    # in the given neighborhood.  Returns "" if none.

    proc absit_id {n stype} {
        set n [nbhood validate [string toupper $n]]
        set stype [eabsit validate $stype]

        return [rdb onecolumn {
            SELECT s FROM absits 
            WHERE n=$n AND stype=$stype
        }]
    }

    # absit_last
    #
    # Returns the situation ID of the most recently created absit.

    proc absit_last {} {
        return [rdb onecolumn {
            SELECT s FROM absits ORDER BY s DESC LIMIT 1;
        }]
    }



    # export ?-history? scriptFile
    #
    # -history    - Export the sequence of orders used to build the
    #               scenario up to this point.
    # scriptFile  - Name of a file relative to the current working
    #               directory.
    #
    # Creates a script of "send" commands that will rebuild the
    # scenario.  By default, a minimal set of orders is created;
    # this can only be done in PREP.
    #
    # If the -history option is given, exports the orders in the
    # CIF.  This can be done when time is advanced, and will run
    # the scenario to the same point.

    proc export {args} {
        # FIRST, get the options.
        array set opts {
            -history 0
        }

        set optargs [lrange $args 0 end-1]
        set filename [lindex $args end]

        if {[file extension $filename] ne ".tcl"} {
            append filename ".tcl"
        }

        set fullname [file join [pwd] $filename]

        while {[llength $optargs] > 0} {
            set opt [lshift optargs]

            switch -exact -- $opt {
                -history {
                    set opts(-history) 1
                }

                default {
                    error "unknown option "
                }
            }
        }

        # NEXT, if they want the -history export, that can be done
        # at any time.  Do it and return.
        if {$opts(-history)} {
            exporter fromcif $fullname

            app puts "Exported scenario from history as $fullname."
            return
        }

        # NEXT, the normal export can only be done during PREP.
        if {[sim locked]} {
            error "Cannot export while the scenario is locked."
        }

        exporter fromdata $fullname

        app puts "Exported scenario from current data as $fullname."

        return
    }

    # last_bean cls
    #
    # cls   - A bean class
    #
    # Returns the bean ID of the most recently created instance of
    # the given bean class, or "" if none.

    proc last_bean {cls} {
        set last [lindex [pot ids $cls] end]

        if {$last eq ""} {
            set kind [namespace tail $cls]
            error "last $kind: no ${kind}s have been created."
        }

        return $last
    }

    # last_absit
    #
    # Returns the situation ID of the most recently created absit.

    proc last_absit {} {
        rdb eval {
            SELECT s FROM absits ORDER BY s DESC LIMIT 1;
        } {
            return $s
        }

        error "last absit: no absits have been created."
    }

    # last_mad
    #
    # Returns the ID of the most recently created MAD.

    proc last_mad {} {
        rdb eval {
            SELECT mad_id FROM mads ORDER BY mad_id DESC LIMIT 1;
        } {
            return $mad_id
        }

        error "last mad: no MADs have been created."
    }

    # lock
    #
    # Locks the scenario.

    proc lock {} {
        send SIM:LOCK
    }

    # LogCmd message
    #
    # message - A text string
    #
    # Logs the message at normal level as "script".

    proc LogCmd {message} {
        log normal script $message
    }

    # parmImport filename
    #
    # filename   A .parmdb file
    #
    # Imports the .parmdb file

    proc parmImport {filename} {
        send PARM:IMPORT -filename $filename
    }


    # parmList ?pattern?
    #
    # pattern    A glob pattern
    #
    # Lists all parameters with their values, or those matching the
    # pattern.  If none are found, throws an error.

    proc parmList {{pattern *}} {
        set result [parm list $pattern]

        if {$result eq ""} {
            error "No matching parameters"
        }

        return $result
    }


    # parmReset 
    #
    # Resets all parameters to defaults.

    proc parmReset {} {
        send PARM:RESET
    }


    # parmSet parm value
    #
    # parm     A parameter name
    # value    A value
    #
    # Sets the parameter's value, using PARM:SET

    proc parmSet {parm value} {
        send PARM:SET -parm $parm -value $value
    }

    # save filename
    # 
    # filename   - Scenario file name
    #
    # Saves the scenario using the name.  Errors are handled by
    # [app error].

    proc save {filename} {
        scenario save $filename

        # Don't let [scenario save]'s return value pass through.
        return
    }
    
    # send order ?option value...?
    #
    # order     The name of an order(sim) order.
    # option    One of order's parameter names, prefixed with "-"
    # value     The parameter's value
    #
    # This routine provides a convenient way to enter orders from
    # the command line or a script.  The order name is converted
    # to upper case automatically.  The parameter names are validated,
    # and a parameter dictionary is created.  The order is sent.
    # Any error message is pretty-printed.
    #
    # Usually the order is sent using the "raw" interface; if the
    # order state is TACTIC, meaning that the order is sent by an
    # EXECUTIVE tactic script, the order is sent using the 
    # "tactic" interface.  That way the order state is checked but
    # the order is not CIF'd.

    proc send {order args} {
        # FIRST, build the parameter dictionary, validating the
        # parameter names as we go.
        set order [string toupper $order]

        order validate $order

        # NEXT, build the parameter dictionary, validating the
        # parameter names as we go.
        set parms [order parms $order]
        set pdict [dict create]

        while {[llength $args] > 0} {
            set opt [lshift args]

            set parm [string range $opt 1 end]

            if {![string match "-*" $opt] ||
                $parm ni $parms
            } {
                error "unknown option: $opt"
            }

            if {[llength $args] == 0} {
                error "missing value for option $opt"
            }

            dict set pdict $parm [lshift args]
        }

        # NEXT, fill in default values.
        set userParms [dict keys $pdict]

        # NEXT, determine the order interface.
        if {[order state] eq "TACTIC"} {
            set interface tactic
        } else {
            set interface raw
        }

        # NEXT, send the order, and handle errors.
        if {[catch {
            order send $interface $order $pdict
        } result eopts]} {
            if {[dict get $eopts -errorcode] ne "REJECT"} {
                # Rethrow
                return {*}$eopts $result
            }

            set wid [lmaxlen [dict keys $pdict]]

            set text "$order rejected:\n"

            # FIRST, add the parms in error.
            dict for {parm msg} $result {
                append text [format "-%-*s   %s\n" $wid $parm $msg]
            }

            # NEXT, add the defaulted parms
            set defaulted [list]
            dict for {parm value} $pdict {
                if {$parm ni $userParms &&
                    ![dict exists $result $parm]
                } {
                    lappend defaulted $parm
                }
            }

            if {[llength $defaulted] > 0} {
                append text "\nDefaulted Parameters:\n"
                dict for {parm value} $pdict {
                    if {$parm in $defaulted} {
                        append text [format "-%-*s   %s\n" $wid $parm $value]
                    }
                }
            }

            return -code error -errorcode REJECT $text
        }

        return $result
    }

    # sendx order ?option value...?
    #
    # order  - The name of an order.
    # option - One of the order's parameter names, prefixed with "-"
    # value  - The parameter's value
    #
    # This routine provides a convenient way to enter orders from
    # the command line or a script.  The order name is converted
    # to upper case automatically.  The parameter names are validated,
    # and a parameter dictionary is created.  The order is sent.
    # Any error message is pretty-printed.
    #
    # Usually the order is sent using the "normal" mode; if the
    # order state is TACTIC, meaning that the order is sent by an
    # EXECUTIVE tactic script, the order is sent using the 
    # "private" mode.  That way the order state is checked but
    # the order is not CIF'd.

    proc sendx {order args} {
        set order [string toupper $order]

        # NEXT, determine the order mode.
        if {[order state] eq "TACTIC"} {
            flunky send private $order {*}$args
        } else {
            flunky send normal $order {*}$args
        }
    }

    # enterx order ?parm value...?
    #
    # order   - The name of an order.
    # parm    - One of order's parameter names
    # value   - The parameter's value
    #
    # This routine pops up an order dialog from the command line.  It is
    # intended for debugging rather than end-user use.

    proc enterx {order args} {
        app enter $order $args
    }


    # show url
    #
    # Shows a URL in the detail browser.

    proc show {url} {
        .main tab view detail
        app show $url
    }

    # SigEventLog message ?tags...?
    #
    # message - A sig event narrative
    # tags    - Zero or more neighborhoods/actors/groups
    #
    # Writes a message to the significant event log.

    proc SigEventLog {message args} {
        sigevent log 1 script $message {*}$args
    }

    # super args
    #
    # Executes args as a command in the global namespace
    proc super {args} {
        namespace eval :: $args
    }


    # tactic add block_id typename ?option value...?
    #
    # block_id - A valid block_id, or "-" for the last block created.
    # typename - Type for the new tactic
    # options  - Options for the new tactic.
    #
    # Adds a tactic to the given agent's strategy, and applies the
    # options to it.  The options are the TACTIC:UPDATE send options
    # plus -state.

    typemethod {tactic add} {block_id typename args} {
        # FIRST, get the block_id
        if {$block_id eq "-"} {
            set block_id [last_bean ::block]
        }

        # NEXT, create the tactic
        cif transaction "tactic add..." {
            set tactic_id [send BLOCK:TACTIC:ADD \
                                    -block_id $block_id \
                                    -typename $typename]
            TacticConfigure $tactic_id $args
        }

        return $tactic_id
    }

    # tactic cget tactic_id ?option?
    #
    # tactic_id   - A valid tactic ID, or "-" for the newest tactic.
    #
    # Retrieves the value of a tactic option.  If no option is given,
    # returns a dictionary of options and values.

    typemethod {tactic cget} {tactic_id {opt ""}} {
        # FIRST, get the tactic_id
        if {$tactic_id eq "-"} {
            set tactic_id [last_bean ::tactic]
        }

        pot valclass tactic $tactic_id

        # NEXT, get the tactic data
        set tactic [pot get $tactic_id]

        set dict [parmdict2optdict [$tactic view cget]]

        # NEXT, return what was asked for.
        if {$opt eq ""} {
            return $dict
        }

        if {[dict exists $dict $opt]} {
            return [dict get $dict $opt]
        } else {
            error "Unknown option: \"$opt\""
        }
    }

    # tactic configure tactic_id ?option value...?
    #
    # tactic_id  - A valid tactic ID, or "-" for the newest tactic.
    # option value  - TACTIC:UPDATE/TACTIC:STATE options
    #
    # Configures the tactic using orders.

    typemethod {tactic configure} {tactic_id args} {
        # FIRST, get the tactic_id
        if {$tactic_id eq "-"} {
            set tactic_id [last_bean ::tactic]
        }

        pot valclass tactic $tactic_id

        # NEXT, configure it
        cif transaction "tactic configure..." {
            TacticConfigure $tactic_id $args
        }
    }
    
    # TacticConfigure tactic_id opts
    #
    # tactic_id   - A tactic ID
    # opts           - A list of tactic options and values
    #
    # Applies the options to the tactic.  The options are the 
    # TACTIC:UPDATE send options plus -state.

    proc TacticConfigure {tactic_id opts} {
        set c [pot get $tactic_id]

        set state [from opts -state ""]

        send TACTIC:[$c typename] -tactic_id $tactic_id {*}$opts

        if {$state ne ""} {
            send TACTIC:STATE -tactic_id $tactic_id -state $state
        }
    }

    # tofile filename text
    #
    # filename   - A filename
    # extension  - A default extension
    # text       - Text
    #
    # Writes the text to the filename

    proc tofile {filename extension text} {
        # FIRST, add the extension if there is none.
        if {[file extension $filename] eq ""} {
            append filename $extension
        }

        # NEXT, open the file.  On error, the executive will pass
        # the error message to the user.
        set f [open $filename w]

        # NEXT, try to write to it.
        try {
            puts $f $text
        } finally {
            close $f   
        }

        return "saved $filename"
    }

    # undo
    #
    # If possible, undoes the order on the top of the stack.

    proc undo {} {
        set title [cif canundo]

        if {$title eq ""} {
            return "Nothing to undo."
        }

        cif undo -test

        return "Undone: $title"
    }
 
    # redo
    #
    # If possible, redoes the last undone order.

    proc redo {} {
        set title [cif canredo]

        if {$title eq ""} {
            return "Nothing to redo."
        }

        cif redo

        return "Redone: $title"
    }

    # unlock
    #
    # Unlocks the scenario.

    proc unlock {} {
        send SIM:UNLOCK
    }

}

#-----------------------------------------------------------------------
# Commands defined in ::, for use when usermode is super

# usermode ?mode?
#
# Calls executive usermode

proc usermode {{mode ""}} {
    executive usermode $mode
}



