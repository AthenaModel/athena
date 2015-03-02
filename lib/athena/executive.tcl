#-----------------------------------------------------------------------
# TITLE:
#    executive.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Executive Command Processor
#
#    The Executive is the scenario's command methodessor.  It's a singleton
#    that provides safe command interpretation for user input, separate
#    from the main interpreter.
#
# TBD: Global refs: ptype, simclock, app puts
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# executive

snit::type ::athena::executive {
    #-------------------------------------------------------------------
    # Components

    component adb     ;# The athenadb(n) instance
    component interp  ;# smartinterpreter(n) for methodessing commands.

    #-------------------------------------------------------------------
    # Instance Variables

    # Array of instance variables
    #
    #  userMode            normal | super
    #  stackTrace          Traceback for last error

    variable info -array {
        userMode     normal
        stackTrace   {}
    }
        
    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        set adb $adb_
        $self InitializeInterp
    }

    # InitializeInterp
    #
    # Creates and initializes the executive interpreter.

    method InitializeInterp {} {
        # FIRST, create the interpreter.  It's a safe interpreter but
        # most Tcl commands are retained, to allow scripting.  Allow
        # the "source" command.
        set interp [smartinterp ${selfns}::interp -cli yes]

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

            try {
                monitor off
                uplevel 1 [list source [file join [pwd] $script]]
            } finally {
                monitor on
                dbsync
            }
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

        # NEXT, install the executive functions and commands
        $self DefineExecutiveFunctions
        $self DefineExecutiveCommands
    }



    #-------------------------------------------------------------------
    # Public Methods

    delegate method expr       to interp
    delegate method proc       to interp
    delegate method smartalias to interp

    # reset
    #
    # Resets the interpreter back to its original state.

    method reset {} {
        assert {[info exists interp] && $interp ne ""}

        $interp destroy
        set interp ""

        $adb log normal exec "reset starting"
        $self InitializeInterp

        set out ""

        set autoScripts [$adb eval {
            SELECT name FROM scripts
            WHERE auto=1
            ORDER BY seq
        }]

        foreach name $autoScripts {
            log normal exec "loading: $name"
            append out "Loading script: $name\n"
            if {[catch {$self script load $name} result]} {
                $adb log normal exec "failed: $result"
                append out "   *** Failed: $result\n"
            }
        }

        $adb log normal exec "reset complete"

        append out "Executive has been reset.\n"
        return $out
    }

    # check script
    #
    # Checks the script for obvious errors relative to the executive
    # interpreter.  Returns a flat list of line numbers and error
    # messages.

    method check {script} {
        return [tclchecker check $interp $script]
    }


    # commands
    #
    # Returns a list of the commands defined in the Executive's 
    # interpreter

    method commands {} {
        $interp eval {info commands}
    }

    # eval script
    #
    # Evaluate the script; throw an error or return the script's value.
    # Either way, log what happens. Ignore empty scripts.

    method eval {script} {
        if {[string trim $script] eq ""} {
            return
        }

        $adb log normal exec "Command: $script"

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
            $adb log warning exec "Command error: $result"
            return {*}$eopts $result
        }

        return $result
    }

    # errtrace
    #
    # returns the stack trace from the most recent evaluation error.

    method errtrace {} {
        if {$info(stackTrace) ne ""} {
            $adb log normal exec "errtrace:\n$info(stackTrace)"
        } else {
            $adb log normal exec "errtrace: None"
        }

        return $info(stackTrace)
    }
 


    #-----------------------------------------------------------------------
    # Script API

    # script names
    #
    # Returns a list of the names of the defined executive scripts
    # in sequence order.

    method {script names} {} {
        return [$adb eval {
            SELECT name FROM scripts ORDER BY seq;
        }]
    }

    # script list
    #
    # Returns a human-readable list of the names of the defined executive 
    # scripts, in sequence order, one per line.  The result is not a
    # proper Tcl list if the names contain whitespace.

    method {script list} {} {
        set out ""
        $adb eval {
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

    method {script get} {name} {
        $adb eval {
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

    method {script exists} {name} {
        return [$adb exists {SELECT body FROM scripts WHERE name=$name}]
    }

    # script delete name
    #
    # name  - The script name
    #
    # Deletes any script with the given name.

    method {script delete} {name} {
        $adb eval {
            DELETE FROM scripts WHERE name=$name
        }

        $adb notify executive <Scripts> delete $name
        return
    }

    # script load name
    #
    # name   - The script name
    #
    # Loads the script into the executive interpreter.  No error
    # handling is done; it's presumed that the caller will handle
    # any errors.

    method {script load} {name} {
        set body [$self script get $name]

        return [$self eval $body]
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

    method {script save} {name {body ""} {opt ""}} {
        # FIRST, get the body.
        if {$body eq ""} {
            set body "# $name\n"
        } else {
            set body [outdent $body]
        }

        # NEXT, if it already exists, just save it.
        if {[$self script exists $name]} {
            $adb eval {
                UPDATE scripts SET body=$body WHERE name=$name
            }

            if {$opt ne "-silent"} {
                $adb notify executive <Scripts> update $name
            }
            return
        }

        # NEXT, get the sequence number, and insert it.
        set seq [$adb onecolumn {
            SELECT coalesce(max(seq) + 1, 1) FROM scripts    
        }]

        $adb eval {
            INSERT INTO scripts(name, seq, body)
            VALUES($name, $seq, $body)
        }

        if {$opt ne "-silent"} {
            $adb notify executive <Scripts> update $name
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

    method {script auto} {name {flag ""}} {
        # FIRST, if the script doesn't exist, that's an error.
        require {[$self script exists $name]} \
            "No such script: $name"

        # NEXT, set the flag if given.
        if {$flag ne ""} {
            snit::boolean validate $flag

            if {$flag} {
                set auto 1
            } else {
                set auto 0
            }

            $adb eval {
                UPDATE scripts SET auto=$auto
                WHERE name=$name
            }

            $adb notify executive <Scripts> update $name
        }

        return [$adb eval {SELECT auto FROM scripts WHERE name=$name}]
    }

    # script import filename
    #
    # filename  - The name of the script file to import
    #
    # If the file can be read, imports a script whose name is the
    # filename minus its extension.  If the name is duplicated, adds
    # a "-<index>" to the end.  Returns the name.

    method {script import} {filename} {
        # FIRST, get the text; any error will be handled by the client.
        set text [readfile $filename]

        # NEXT, get the name
        set name [file rootname [file tail $filename]]

        if {[$self script exists $name]} {
            set name [$self GetUniqueScriptName $name]
        }

        $self script save $name $text

       $adb notify executive <Scripts> update $name

        return $name
    }

    # GetUniqueScriptName name 
    #
    # name   - A script name
    #
    # Adds numeric indices to the end of the script name until a 
    # unique name is found.

    method GetUniqueScriptName {name} {
        set base $name
        set count 0
        while {[$self script exists $name]} {
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

    method {script rename} {oldName newName} {
        # FIRST, if the script doesn't exist, that's an error.
        if {![$self script exists $oldName]} {
            error "No such script: $oldName"
        }

        $adb eval {
            UPDATE scripts SET name=$newName WHERE name=$oldName
        }

        $adb notify executive <Scripts> update ""
    }

    # script sequence name priority
    #
    # name      - The script name
    # priority  - An ePrioUpdate value (top, raise, lower, bottom)
    #
    # Moves the script to the desired spot in the sequence.
    
    method {script sequence} {name priority} {
        # FIRST, if the script doesn't exist, that's an error.
        if {![$self script exists $name]} {
            error "No such script: $name"
        } 

        # NEXT, get the old sequence
        set oldSequence [$adb eval {
            SELECT name, seq FROM scripts ORDER BY seq    
        }]

        # NEXT, reposition this script in the sequence.
        set sequence [lprio [dict keys $oldSequence] $name $priority]

        # NEXT, assign new sequence numbers
        set seq 1

        foreach name $sequence {
            $adb eval {
                UPDATE scripts
                SET seq=$seq
                WHERE name=$name
            }

            incr seq
        }

        $adb notify executive <Scripts> update ""

        return
    }

    #-------------------------------------------------------------------
    # Function Definitions

    # DefineExecutiveFunctions
    #
    # Defines the executive functions.
    
    method DefineExecutiveFunctions {} {
        $interp function affinity 2 2 {x y} \
            [mymethod Fn_affinity]

        $interp function aplants 1 1 {a} \
            [mymethod Fn_aplants]

        $interp function assigned 3 3 {g activity n} \
            [mymethod Fn_assigned]

        $interp function consumers 1 - {g ?g...?} \
            [mymethod Fn_consumers]

        $interp function controls 2 - {a n ?n...?} \
            [mymethod Fn_controls]

        $interp function coop 2 2 {f g} \
            [mymethod Fn_coop]

        $interp function coverage 3 3 {g activity n} \
            [mymethod Fn_coverage]

        $interp function deployed 2 - {g n ?n...?} \
            [mymethod Fn_deployed]

        $interp function gdp 0 0 {} \
            [mymethod Fn_gdp]

        $interp function goodscap 1 1 {a} \
            [mymethod Fn_goodscap]

        $interp function goodsidle 0 0 {} \
            [mymethod Fn_goodsidle]

        $interp function hrel 2 2 {f g} \
            [mymethod Fn_hrel]

        $interp function income 1 - {a ?a...?} \
            [mymethod Fn_income]

        $interp function income_black 1 - {a ?a...?} \
            [mymethod Fn_income_black]

        $interp function income_goods 1 - {a ?a...?} \
            [mymethod Fn_income_goods]

        $interp function income_pop 1 - {a ?a...?} \
            [mymethod Fn_income_pop]

        $interp function income_region 1 - {a ?a...?} \
            [mymethod Fn_income_region]

        $interp function income_world 1 - {a ?a...?} \
            [mymethod Fn_income_world]

        $interp function influence 2 2 {a n} \
            [mymethod Fn_influence]

        $interp function local_consumers 0 0 {} \
            [mymethod Fn_local_consumers]

        $interp function local_pop 0 0 {} \
            [mymethod Fn_local_pop]

        $interp function local_unemp 0 0 {} \
            [mymethod Fn_local_unemp]

        $interp function local_workers 0 0 {} \
            [mymethod Fn_local_workers]

        $interp function mobilized 1 - {g ?g...?} \
            [mymethod Fn_mobilized]

        $interp function mood 1 1 {g} \
            [mymethod Fn_mood]

        $interp function nbconsumers 1 - {n ?n...?} \
            [mymethod Fn_nbconsumers]

        $interp function nbcoop 2 2 {n g} \
            [mymethod Fn_nbcoop]

        $interp function nbgoodscap 1 1 {n} \
            [mymethod Fn_nbgoodscap]

        $interp function nbmood 1 1 {n} \
            [mymethod Fn_nbmood]

        $interp function nbplants 1 1 {n} \
            [mymethod Fn_nbplants]

        $interp function nbpop 1 - {n ?n...?} \
            [mymethod Fn_nbpop]

        $interp function nbsupport 2 2 {a n} \
            [mymethod Fn_nbsupport]

        $interp function nbunemp 1 - {n ?n...?} \
            [mymethod Fn_nbunemp]

        $interp function nbworkers 1 - {n ?n...?} \
            [mymethod Fn_nbworkers]

        $interp function now 0 0 {} \
            [list simclock now]

        $interp function onhand 1 1 {a} \
            [mymethod Fn_onhand]

        $interp function parm 1 1 {parm} \
            [list $adb parm get]

        $interp function pbconsumers 0 0 {} \
            [mymethod Fn_pbconsumers]

        $interp function pbgoodscap 0 0 {} \
            [mymethod Fn_pbgoodscap]

        $interp function pbplants 0 0 {} \
            [mymethod Fn_pbplants]

        $interp function pbpop 0 0 {} \
            [mymethod Fn_pbpop]

        $interp function pbunemp 0 0 {} \
            [mymethod Fn_pbunemp]

        $interp function pbworkers 0 0 {} \
            [mymethod Fn_pbworkers]

        $interp function pctcontrol 1 - {a ?a...?} \
            [mymethod Fn_pctcontrol]

        $interp function plants 2 2 {a n} \
            [mymethod Fn_plants]

        $interp function pop 1 - {g ?g...?} \
            [mymethod Fn_pop]

        $interp function repair 2 2 {a n} \
            [mymethod Fn_repair]

        $interp function reserve 1 1 {a} \
            [mymethod Fn_reserve]

        $interp function sat 2 2 {g c} \
            [mymethod Fn_sat]

        $interp function security 1 2 {g ?n?} \
            [mymethod Fn_security]

        $interp function support 2 3 {a g ?n?} \
            [mymethod Fn_support]

        $interp function supports 2 - {a b ?n...?} \
            [mymethod Fn_supports]

        $interp function troops 1 - {g ?n...?} \
            [mymethod Fn_troops]

        $interp function unemp 1 - {g ?g...?} \
            [mymethod Fn_unemp]

        $interp function volatility 1 1 {n} \
            [mymethod Fn_volatility]

        $interp function vrel 2 2 {g a} \
            [mymethod Fn_vrel]

        $interp function workers 1 - {g ?g...?} \
            [mymethod Fn_workers]
    }

    # Fn_affinity x y
    #
    # x - A belief system entity.
    # y - A belief system entity.
    #
    # At present x and y are any group or actor.
    # Returns the affinity of x for y.

    method Fn_affinity {x y} {
        set gdict [$adb gofer make NUMBER AFFINITY $x $y] 
        return [$adb gofer eval $gdict]
    }

    # Fn_aplants a
    #
    # a - An agent
    #
    # Returns the total number of plants owned by agent a.

    method Fn_aplants {a} {
        set gdict [$adb gofer make NUMBER AGENT_PLANTS $a] 
        return [$adb gofer eval $gdict]
    }

    # Fn_assigned g activity n
    #
    # g - A force group
    # activity - an activity
    # n - A neighborhood
    #
    # Returns the number of personnel in force or org group g
    # assigned to do the activity in nbhood n.

    method Fn_assigned {g activity n} {
        set gdict [$adb gofer make NUMBER ASSIGNED $g $activity $n] 
        return [$adb gofer eval $gdict]
    }

    # Fn_consumers g ?g...?
    #
    # g - A list of civilian groups or multiple civilian groups
    #
    # Returns the consumers belonging to the listed civilian group(s) g.

    method Fn_consumers {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [$adb gofer make NUMBER GROUP_CONSUMERS $args] 
        return [$adb gofer eval $gdict]
    }

    # Fn_controls a n ?n...?
    #
    # a      - An actor
    # n      - A neighborhood
    #
    # Returns 1 if a controls all of the listed neighborhoods, and 
    # 0 otherwise.

    method Fn_controls {a args} {
        set a [$adb actor validate [string toupper $a]]

        if {[llength $args] == 0} {
            error "No neighborhoods given"
        }

        set nlist [list]

        foreach n $args {
            lappend nlist [$adb nbhood validate [string toupper $n]]
        }

        set inClause "('[join $nlist ',']')"

        $adb eval "
            SELECT count(n) AS count
            FROM control_n
            WHERE n IN $inClause
            AND controller=\$a
        " {
            return [expr {$count == [llength $nlist]}]
        }
    }

    # Fn_coop f g
    #
    # f - A civilian group
    # g - A force group
    #
    # Returns the cooperation of f with g.

    method Fn_coop {f g} {
        set gdict [$adb gofer make NUMBER COOP $f $g] 
        return [$adb gofer eval $gdict]
    }

    # Fn_coverage g activity n
    #
    # g - A force or org group
    # a - An activity
    # n - A neighborhood
    #
    # Returns the coverage for force/org group g assigned to 
    # activity a in neighborhood n.

    method Fn_coverage {g activity n} {
        set gdict [$adb gofer make NUMBER COVERAGE $g $activity $n]
        return [$adb gofer eval $gdict]
    }

    # Fn_deployed g n ?n...?
    #
    # g - A force or org group
    # n - A neighborhood (or multiple)
    #
    # Returns the deployed personnel of force/org group g
    # deployed in neighborhood(s) n.

    method Fn_deployed {g args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [$adb gofer make NUMBER DEPLOYED $g $args] 
        return [$adb gofer eval $gdict]
    }

    # Fn_gdp
    #
    # Returns the GDP in base-year dollars (i.e., Out::DGDP).
    # It's an error if the economic model is disabled.

    method Fn_gdp {} {
        set gdict [$adb gofer make NUMBER GDP]
        return [$adb gofer eval $gdict]
    }

    # Fn_goodscap a
    #
    # a - An agents
    #
    # Returns the total output capacity of all goods production 
    # plants owned by agent a.

    method Fn_goodscap {a} {
        set gdict [$adb gofer make NUMBER GOODS_CAP $a] 
        return [$adb gofer eval $gdict]
    }

    # Fn_goodsidle
    #
    # Returns the idle capacity for the playbox.

    method Fn_goodsidle {} {
        set gdict [$adb gofer make NUMBER GOODS_IDLE] 
        return [$adb gofer eval $gdict]
    }

    # Fn_hrel f g
    #
    # f - A group
    # g - A group
    #
    # Returns the horizontal relationship of f with g.

    method Fn_hrel {f g} {
        set gdict [$adb gofer make NUMBER HREL $f $g] 
        return [$adb gofer eval $gdict]
    }

    # Fn_income a ?a...?
    #
    # a - A list of actors multiple actors
    #
    # Returns the total income for actor(s) a.

    method Fn_income {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [$adb gofer make NUMBER INCOME $args] 
        return [$adb gofer eval $gdict]
    }

    # Fn_income_black a ?a...?
    #
    # a - A list of actors multiple actors
    #
    # Returns the total income from the black market sector for actor(s) a.

    method Fn_income_black {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [$adb gofer make NUMBER INCOME_BLACK $args] 
        return [$adb gofer eval $gdict]
    }

    # Fn_income_goods a ?a...?
    #
    # a - A list of actors multiple actors
    #
    # Returns the total income from the goods sector for actor(s) a.

    method Fn_income_goods {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [$adb gofer make NUMBER INCOME_GOODS $args] 
        return [$adb gofer eval $gdict]
    }

    # Fn_income_pop a ?a...?
    #
    # a - A list of actors multiple actors
    #
    # Returns the total income from the pop sector for actor(s) a.

    method Fn_income_pop {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [$adb gofer make NUMBER INCOME_POP $args] 
        return [$adb gofer eval $gdict]
    }

    # Fn_income_region a ?a...?
    #
    # a - A list of actors multiple actors
    #
    # Returns the total income from the region sector for actor(s) a.

    method Fn_income_region {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [$adb gofer make NUMBER INCOME_REGION $args] 
        return [$adb gofer eval $gdict]
    }

    # Fn_income_world a ?a...?
    #
    # a - A list of actors multiple actors
    #
    # Returns the total income from the world sector for actor(s) a.

    method Fn_income_world {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [$adb gofer make NUMBER INCOME_WORLD $args] 
        return [$adb gofer eval $gdict]
    }

    # Fn_influence a n
    #
    # a - An actor
    # n - A neighborhood
    #
    # Returns the influence of a in n.

    method Fn_influence {a n} {
        set gdict [$adb gofer make NUMBER INFLUENCE $a $n] 
        return [$adb gofer eval $gdict]
    }

    # Fn_local_consumers 
    #
    # Returns the consumers resident in local neighborhood(s) (all consumers).

    method Fn_local_consumers {} {
        set gdict [$adb gofer make NUMBER LOCAL_CONSUMERS] 
        return [$adb gofer eval $gdict]
    }

    # Fn_local_pop 
    #
    # Returns the population of civilian groups in local neighborhood(s).

    method Fn_local_pop {} {
        set gdict [$adb gofer make NUMBER LOCAL_POPULATION] 
        return [$adb gofer eval $gdict]
    }

    # Fn_local_unemp 
    #
    # Returns the unemployment rate in local neighborhood(s).

    method Fn_local_unemp {} {
        set gdict [$adb gofer make NUMBER LOCAL_UNEMPLOYMENT_RATE] 
        return [$adb gofer eval $gdict]
    }

    # Fn_local_workers 
    #
    # Returns the workers resident in local neighborhood(s).

    method Fn_local_workers {} {
        set gdict [$adb gofer make NUMBER LOCAL_WORKERS] 
        return [$adb gofer eval $gdict]
    }

    # Fn_mobilized g ?g...?
    #
    # g - A force or org group (or multiple)
    #
    # Returns the mobilized personnel of force/org group g
    # in the playbox.

    method Fn_mobilized {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [$adb gofer make NUMBER MOBILIZED $args] 
        return [$adb gofer eval $gdict]
    }

    # Fn_mood g
    #
    # g - A civilian group
    #
    # Returns the mood of group g.

    method Fn_mood {g} {
        set gdict [$adb gofer make NUMBER MOOD $g] 
        return [$adb gofer eval $gdict]
    }

    # Fn_nbconsumers n ?n...?
    #
    # n - A list of neighborhoods
    #
    # Returns the consumers resident in the listed neighborhood(s).

    method Fn_nbconsumers {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [$adb gofer make NUMBER NBCONSUMERS $args] 
        return [$adb gofer eval $gdict]
    }

    # Fn_nbcoop n g
    #
    # n - A neighborhood
    # g - A force group
    #
    # Returns the cooperation of n with g.

    method Fn_nbcoop {n g} {
        set gdict [$adb gofer make NUMBER NBCOOP $n $g] 
        return [$adb gofer eval $gdict]
    }

    # Fn_nbgoodscap n
    #
    # n - A neighborhood
    #
    # Returns the total output capacity of all goods production 
    # plants in a neighborhood n

    method Fn_nbgoodscap {n} {
        set gdict [$adb gofer make NUMBER NB_GOODS_CAP $n] 
        return [$adb gofer eval $gdict]
    }

    # Fn_nbmood n
    #
    # n - Neighborhood
    #
    # Returns the mood of neighborhood n.

    method Fn_nbmood {n} {
        set gdict [$adb gofer make NUMBER NBMOOD $n] 
        return [$adb gofer eval $gdict]
    }

    # Fn_nbplants n
    #
    # n - A neighborhood
    #
    # Returns the total number of plants in 
    # neighborhood n.

    method Fn_nbplants {n} {
        set gdict [$adb gofer make NUMBER NB_PLANTS $n] 
        return [$adb gofer eval $gdict]
    }

    # Fn_nbpop n ?n...?
    #
    # n - A list of neighborhoods
    #
    # Returns the civilian population resident in the listed neighborhood(s).

    method Fn_nbpop {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [$adb gofer make NUMBER NBPOPULATION $args] 
        return [$adb gofer eval $gdict]
    }

    # Fn_nbsupport a n
    #
    # a - An actor
    # n - A neighborhood
    #
    # Returns the support of a in n.

    method Fn_nbsupport {a n} {
        set gdict [$adb gofer make NUMBER NBSUPPORT $a $n]

        return [$adb gofer eval $gdict]
    }

    # Fn_nbunemp n ?n...?
    #
    # n - A list of neighborhoods
    #
    # Returns the unemployment rate for the listed neighborhood(s).

    method Fn_nbunemp {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [$adb gofer make NUMBER NB_UNEMPLOYMENT_RATE $args] 
        return [$adb gofer eval $gdict]
    }

    # Fn_nbworkers n ?n...?
    #
    # n - A list of neighborhoods
    #
    # Returns the workers resident in the listed neighborhood(s).

    method Fn_nbworkers {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [$adb gofer make NUMBER NBWORKERS $args] 
        return [$adb gofer eval $gdict]
    }

    # Fn_onhand a
    #
    # a - An actor
    #
    # Returns the cash on hand of actor a.

    method Fn_onhand {a} {
        set gdict [$adb gofer make NUMBER CASH_ON_HAND $a] 
        return [$adb gofer eval $gdict]
    }

    # Fn_pbconsumers 
    #
    # Returns the consumers resident in the playbox
    #  (same as local_consumers()).

    method Fn_pbconsumers {} {
        set gdict [$adb gofer make NUMBER PLAYBOX_CONSUMERS] 
        return [$adb gofer eval $gdict]
    }

    # Fn_pbgoodscap
    #
    # Returns the total output capacity of all goods production 
    # plants in the playbox.

    method Fn_pbgoodscap {} {
        set gdict [$adb gofer make NUMBER PLAYBOX_GOODS_CAP] 
        return [$adb gofer eval $gdict]
    }

    # Fn_pbplants
    #
    #
    # Returns the total number of plants in the playbox.

    method Fn_pbplants {} {
        set gdict [$adb gofer make NUMBER PLAYBOX_PLANTS] 
        return [$adb gofer eval $gdict]
    }

    # Fn_pbpop 
    #
    # Returns the population of civilian groups in the playbox

    method Fn_pbpop {} {
        set gdict [$adb gofer make NUMBER PLAYBOX_POPULATION] 
        return [$adb gofer eval $gdict]
    }

    # Fn_pbunemp 
    #
    # Returns the average unemployment rate in the playbox

    method Fn_pbunemp {} {
        set gdict [$adb gofer make NUMBER PLAYBOX_UNEMPLOYMENT_RATE] 
        return [$adb gofer eval $gdict]
    }

    # Fn_pbworkers 
    #
    # Returns the workers resident in the playbox
    #  (same as local_workers()).

    method Fn_pbworkers {} {
        set gdict [$adb gofer make NUMBER PLAYBOX_WORKERS] 
        return [$adb gofer eval $gdict]
    }

    # Fn_pctcontrol a ?a...?
    #
    # a - An actor
    #
    # Returns the percentage of neighborhoods controlled by the
    # listed actors.

    method Fn_pctcontrol {args} {
        set gdict [$adb gofer make NUMBER PCTCONTROL $args] 
        return [$adb gofer eval $gdict]
    }

    # Fn_plants a n
    #
    # a - An agent
    # n - A neighborhood
    #
    # Returns the total number of plants owned by agent a in 
    # neighborhood n.

    method Fn_plants {a n} {
        set gdict [$adb gofer make NUMBER PLANTS $a $n]
        return [$adb gofer eval $gdict]
    }

    # Fn_pop g ?g...?
    #
    # g - A list of civilian groups or multiple civilian groups
    #
    # Returns the population of the listed civilian group(s) g in the playbox.

    method Fn_pop {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [$adb gofer make NUMBER GROUP_POPULATION $args] 
        return [$adb gofer eval $gdict]
    }

    # Fn_repair a n
    #
    # a - An actor
    # n - A neighborhood
    #
    # Returns the current level of repair for plants owned by actor a in 
    # neighborhood n.

    method Fn_repair {a n} {
        set gdict [$adb gofer make NUMBER REPAIR $a $n] 
        return [$adb gofer eval $gdict]
    }

    # Fn_reserve a
    #
    # a - An actor
    #
    # Returns the cash reserve of actor a.

    method Fn_reserve {a} {
        set gdict [$adb gofer make NUMBER CASH_RESERVE $a] 
        return [$adb gofer eval $gdict]
    }

    # Fn_sat g c
    #
    # g - A civilian group
    # c - A concern
    #
    # Returns the satisfaction of g with c

    method Fn_sat {g c} {
        set gdict [$adb gofer make NUMBER SAT $g $c] 
        return [$adb gofer eval $gdict]
    }

    # Fn_security g ?n?
    #
    # g - A group
    # n - A neighborhood
    #
    # Returns g's security in n
    # If no n is specified, g is assumed to be a civilian group

   method Fn_security {g {n ""}} {
        if {$n eq ""} {
            set gdict [$adb gofer make NUMBER SECURITY_CIV $g]
        } else {
            set gdict [$adb gofer make NUMBER SECURITY $g $n]
        }

        return [$adb gofer eval $gdict]
    }

    # Fn_support a g ?n?
    #
    # a - An actor
    # g - A group
    # n - A neighborhood
    #
    # Returns the support for a by g in n. 
    # If n is not given, g is assumed to be a civilian group.

    method Fn_support {a g {n ""}} {
        if {$n eq ""} {
            set gdict [$adb gofer make NUMBER SUPPORT_CIV $a $g]
        } else {
            set gdict [$adb gofer make NUMBER SUPPORT $a $g $n]
        }

        return [$adb gofer eval $gdict]
    }

    # Fn_supports a b ?n...?
    #
    # a - An actor
    # b - Another actor, SELF, or NONE
    # n - A neighborhood
    #
    # Returns 1 if actor a usually supports actor b, and 0 otherwise.
    # If one or more neighborhoods are given, actor a must support b in 
    # all of them.

    method Fn_supports {a b args} {
        # FIRST, handle the playbox case.
        set a [$adb actor validate [string toupper $a]]
        set b [ptype a+self+none validate [string toupper $b]]

        if {$b eq $a} {
            set b SELF
        }

        if {[llength $args] == 0} {
            if {[$adb exists {
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
            lappend nlist [$adb nbhood validate [string toupper $n]]
        }

        set inClause "('[join $nlist ',']')"

        set count [$adb onecolumn "
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

    # Fn_troops g ?n...?
    #
    # g      - A force or organization group
    # n      - A neighborhood
    #
    # If no neighborhood is given, returns the number of troops g has in
    # the playbox.  If one or more neighborhoods are given, returns the
    # number of troops g has in those neighborhoods.

    method Fn_troops {g args} {
        set g [ptype fog validate [string toupper $g]]

        # FIRST, handle the playbox case
        if {[llength $args] == 0} {
            $adb eval {
                SELECT total(personnel) AS personnel
                FROM personnel_g WHERE g=$g
            } {
                return [format %.0f $personnel]
            }
        }

        # NEXT, handle the multiple neighborhoods case

        set nlist [list]

        foreach n $args {
            lappend nlist [$adb nbhood validate [string toupper $n]]
        }

        set inClause "('[join $nlist ',']')"

        $adb eval "
            SELECT total(personnel) AS personnel
            FROM deploy_ng
            WHERE n IN $inClause
            AND g=\$g
        " {
            return [format %.0f $personnel]
        }
    }

    # Fn_unemp g ?g...?
    #
    # g - A list of civilian groups or multiple civilian groups
    #
    # Returns the unemployment rate for the listed civilian group(s) g.

    method Fn_unemp {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [$adb gofer make NUMBER GROUP_UNEMPLOYMENT_RATE $args] 
        return [$adb gofer eval $gdict]
    }

    # Fn_volatility n
    #
    # n - A neighborhood
    #
    # Returns the volatility of neighborhood n

    method Fn_volatility {n} {
        set n [$adb nbhood validate [string toupper $n]]

        $adb eval {
            SELECT volatility FROM force_n WHERE n=$n
        } {
            return $volatility
        }

        error "volatility not yet computed"
    }

    # Fn_vrel g a
    #
    # g - A group
    # a - An actor
    #
    # Returns the vertical relationship of g with a.

    method Fn_vrel {g a} {
        set gdict [$adb gofer make NUMBER VREL $g $a] 
        return [$adb gofer eval $gdict]
    }

    # Fn_workers g ?g...?
    #
    # g - A list of civilian groups or multiple civilian groups
    #
    # Returns the workers belonging to the listed civilian group(s) g.

    method Fn_workers {args} {
        if {[llength $args]==1} {
            set args [lindex $args 0]
        }
        set gdict [$adb gofer make NUMBER GROUP_WORKERS $args] 
        return [$adb gofer eval $gdict]
    }


    #-------------------------------------------------------------------
    # Executive Command Definitions
    
    # DefineExecutiveCommands
    #
    # Defines the remaining executive commands.

    method DefineExecutiveCommands {} {
        # =
        $interp eval {
            interp alias {} = {} expr
        }
        $interp setsig = 1 1 {expression}

        # absit
        $interp ensemble absit

        # absit id
        $interp smartalias {absit id} 2 2 {n stype} \
            [mymethod AbsitId]

        # absit last
        $interp smartalias {absit last} 0 0 {} \
            [mymethod AbsitLast]

        # advance
        $interp smartalias advance 1 1 {days} \
            [mymethod Advance]

        # autogen
        $interp ensemble autogen

        # autogen scenario
        $interp smartalias {autogen scenario} 0 - \
            {?-nb n? ?-actors n? ?-frcg n? ?-civg n? ?-orgg n? ?-topics n?} \
            [list $adb autogen scenario]

        # autogen actors
        $interp smartalias {autogen actors} 0 1 {?num?} \
            [list $adb autogen actors]

        # autogen nbhoods
        $interp smartalias {autogen nbhoods} 0 1 {?num?} \
            [list $adb autogen nbhoods]

        # autogen civgroups
        $interp smartalias {autogen civgroups} 0 1 {?num?} \
            [list $adb autogen civgroups]

        # autogen orggroups
        $interp smartalias {autogen orggroups} 0 1 {?num?} \
            [list $adb autogen orggroups]

        # autogen frcgroups
        $interp smartalias {autogen frcgroups} 0 1 {?num?} \
            [list $adb autogen frcgroups]

        # autogen bsystem 
        $interp smartalias {autogen bsystem} 0 1 {?num?} \
            [list $adb autogen bsystem]

        # autogen strategy
        $interp smartalias {autogen strategy} 0 - \
{?-tactics tlist? ?-actors alist? ?-frcg glist? ?-civg glist? ?-orgg glist?} \
            [list $adb autogen strategy]

        # autogen assign
        $interp smartalias {autogen assign} 1 - \
            {owner ?-group g? ?-nbhood n? ?-activity act?} \
            [list $adb autogen assign]

        # block
        $interp ensemble block

        # block add
        $interp smartalias {block add} 1 - {agent ?option value...?} \
            [mymethod BlockAdd]
            
        $interp smartalias {block cget} 1 2 {block_id ?option?} \
            [mymethod BlockCget]

        $interp smartalias {block configure} 1 - {block_id ?option value...?} \
            [mymethod BlockConfigure]

        $interp smartalias {block last} 0 0 {} \
            [mymethod LastBean ::athena::block]

        # condition
        $interp ensemble condition

        # condition add
        $interp smartalias {condition add} 1 - {block_id typename ?option value...?} \
            [mymethod ConditionAdd]
            
        $interp smartalias {condition cget} 1 2 {condition_id ?option?} \
            [mymethod ConditionCget]

        $interp smartalias {condition configure} 1 - {condition_id ?option value...?} \
            [mymethod ConditionConfigure]

        $interp smartalias {condition last} 0 0 {} \
            [mymethod LastBean ::athena::condition]

        # dbsync
        $interp smartalias dbsync 0 0 {} \
            [mymethod Dbsync]

        # dump
        $interp ensemble dump

        # dump econ
        $interp smartalias {dump econ} 0 1 {?page?} \
            [list $adb econ dump]

        # errtrace
        $interp smartalias errtrace 0 0 {} \
            [mymethod errtrace]

        # export
        $interp smartalias export 1 3 {?-history? ?-map? scriptFile} \
            [mymethod Export]

        # extension
        $interp smartalias extension 1 1 {name} \
            [list ::file extension]

        # gofer
        $interp smartalias gofer 1 - {typeOrGdict ?rulename? ?args...?} \
            [mymethod Gofer]

        # help
        $interp smartalias help 0 - {?-info? ?command...?} \
            [mymethod Help]

        # last
        $interp ensemble last

        # last absit
        $interp smartalias {last absit} 0 0 {} \
            [mymethod AbsitLast]

        # last block
        $interp smartalias {last block} 0 0 {} \
            [mymethod LastBean ::athena::block]

        # last condition
        $interp smartalias {last condition} 0 0 {} \
            [mymethod LastBean ::athena::condition]

        # last tactic
        $interp smartalias {last tactic} 0 0 {} \
            [mymethod LastBean ::athena::tactic]

        # lock
        $interp smartalias lock 0 0 {} \
            [mymethod Lock]

        # log
        $interp smartalias log 1 1 {message} \
            [mymethod Log]

        # monitor
        $interp smartalias monitor 0 1 {?flag?} \
            [list $adb order monitor]

        # parm
        $interp ensemble parm

        # parm export
        $interp smartalias {parm export} 1 1 {filename} \
            [list $adb parm save]

        # parm get
        $interp smartalias {parm get} 1 1 {parm} \
            [list $adb parm get]

        # parm import
        $interp smartalias {parm import} 1 1 {filename} \
            [mymethod ParmImport]

        # parm list
        $interp smartalias {parm list} 0 1 {?pattern?} \
            [mymethod ParmList]

        # parm names
        $interp smartalias {parm names} 0 1 {?pattern?} \
            [list $adb parm names]

        # parm reset
        $interp smartalias {parm reset} 0 0 {} \
            [mymethod ParmReset]

        # parm set
        $interp smartalias {parm set} 2 2 {parm value} \
            [mymethod ParmSet]

        # rdb
        $interp ensemble rdb

        # rdb eval
        $interp smartalias {rdb eval}  1 1 {sql} \
            [list $adb safeeval]

        # rdb query
        $interp smartalias {rdb query} 1 - {sql ?option value...?} \
            [list $adb safequery]

        # rdb schema
        $interp smartalias {rdb schema} 0 1 {?table?} \
            [list $adb schema]

        # rdb tables
        $interp smartalias {rdb tables} 0 0 {} \
            [list $adb tables]

        # redo
        $interp smartalias redo 0 0 {} \
            [mymethod Redo]

        # reset
        $interp smartalias {reset} 0 0 {} \
            [mymethod reset]

        # save
        # TBD: Application/library hybrid
        $interp smartalias save 1 1 {filename} \
            [mymethod Save]

        # script
        $interp ensemble script

        # script auto
        $interp smartalias {script auto} 1 2 {name ?flag?} \
            [mymethod script auto]

        # script delete
        $interp smartalias {script delete} 1 1 {name} \
            [mymethod script delete]

        # script exists
        $interp smartalias {script exists} 1 1 {name} \
            [mymethod script exists]

        # script get
        $interp smartalias {script get} 1 1 {name} \
            [mymethod script get]

        # script list
        $interp smartalias {script list} 0 0 {} \
            [mymethod script list]

        # script load
        $interp smartalias {script load} 1 1 {name} \
            [mymethod script load]

        # script names
        $interp smartalias {script names} 0 0 {} \
            [mymethod script names]

        # script save
        $interp smartalias {script save} 2 2 {name script} \
            [mymethod script save]

        # script sequence
        $interp smartalias {script sequence} 2 2 {name priority} \
            [mymethod script sequence]

        # send
        $interp smartalias send 1 - {order ?option value...?} \
            [mymethod Send]

        # sigevent
        $interp smartalias sigevent 1 - {message ?tags...?} \
            [mymethod Sigevent]

        # tactic
        $interp ensemble tactic

        # tactic add
        $interp smartalias {tactic add} 1 - {block_id typename ?option value...?} \
            [mymethod TacticAdd]
            
        $interp smartalias {tactic cget} 1 2 {tactic_id ?option?} \
            [mymethod TacticCget]

        $interp smartalias {tactic configure} 1 - {tactic_id ?option value...?} \
            [mymethod TacticConfigure]

        $interp smartalias {tactic last} 0 0 {} \
            [mymethod LastBean ::athena::tactic]

        # tofile
        $interp smartalias tofile 3 3 {filename extension text} \
            [mymethod Tofile]

        # undo
        $interp smartalias undo 0 0 {} \
            [mymethod Undo]

        # unlock
        $interp smartalias unlock 0 0 {} \
            [mymethod Unlock]

        # version
        $interp smartalias version 0 0 {} \
            [list $adb version]


        #---------------------------------------------------------------
        # Application Commands
        #
        # These will need to be moved to the application.


        # clear
        $interp smartalias clear 0 0 {} \
            [list .main cli clear]

        # debug
        $interp smartalias debug 0 0 {} \
            [list ::marsgui::debugger new]

        # enter
        $interp smartalias enter 1 - {order ?parm value...?} \
            [mymethod Enter]

        # load
        $interp smartalias load 1 1 {filename} \
            [list app open]

        # nbfill
        # TBD: Application executive command
        $interp smartalias nbfill 1 1 {varname} \
            [list .main nbfill]

        # new
        $interp smartalias new 0 0 {} \
            [list app new]

        # prefs
        # TBD: This whole ensemble is application-specific.
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

        # show
        # TBD: Application-specific commands
        $interp smartalias show 1 1 {url} \
            [mymethod Show]

        # super
        $interp smartalias super 1 - {arg ?arg...?} \
            [mymethod Super]

        # usermode
        $interp smartalias {usermode} 0 1 {?mode?} \
            [mymethod usermode]
    }

    
    #-------------------------------------------------------------------
    # Executive Command Implementations

    # absit id n stype
    #
    # n      - Neighborhood
    # stype  - Situation Type
    #
    # Returns the situation ID of the absit of the given type
    # in the given neighborhood.  Returns "" if none.

    method AbsitId {n stype} {
        set n [$adb nbhood validate [string toupper $n]]
        set stype [eabsit validate $stype]

        return [$adb onecolumn {
            SELECT s FROM absits 
            WHERE n=$n AND stype=$stype
        }]
    }

    # absit last, last absit
    #
    # Returns the situation ID of the most recently created absit.

    method AbsitLast {} {
        $adb eval {
            SELECT s FROM absits ORDER BY s DESC LIMIT 1;
        } {
            return $s
        }

        error "last absit: no absits have been created."
    }

    # advance weeks
    #
    # weeks    - An integer number of weeks
    #
    # advances time by the specified number of weeks.  Locks the
    # scenario if necessary.

    method Advance {weeks} {
        if {[$adb state] eq "PREP"} {
            $self Lock
        }

        $self Send SIM:RUN -weeks $weeks -block YES
    }

    # block add agent ?option value...?
    #
    # agent   - Name of an agent.
    # options - Options for the new block.
    #
    # Adds a block to the given agent's strategy, and applies the
    # options to it.  The options are the BLOCK:UPDATE send options
    # plus -state.

    method BlockAdd {agent args} {
        $adb order transaction "block add..." {
            set block_id [$self Send STRATEGY:BLOCK:ADD -agent $agent]
            $self BlockUpdate $block_id $args
        }

        return $block_id
    }

    # block cget block_id ?option?
    #
    # block_id   - A valid block ID, or "-" for the newest block.
    #
    # Retrieves the value of a block option.  If no option is given,
    # returns a dictionary of options and values.

    method BlockCget {block_id {opt ""}} {
        # FIRST, get the block_id
        if {$block_id eq "-"} {
            set block_id [$self LastBean ::athena::block]
        }

        $adb bean valclass ::athena::block $block_id

        # NEXT, get the block data
        set block [$adb bean get $block_id]

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

    method BlockConfigure {block_id args} {
        # FIRST, get the block_id
        if {$block_id eq "-"} {
            set block_id [$self LastBean ::athena::block]
        }

        # NEXT, configure it
        $adb order transaction "block configure..." {
            $self BlockUpdate $block_id $args
        }
    }
    
    # BlockUpdate block_id opts
    #
    # block_id   - A block ID
    # opts       - A list of block options and values
    #
    # Applies the options to the block.  The options are the BLOCK:UPDATE 
    # send options plus -state.

    method BlockUpdate {block_id opts} {
        set state [from opts -state ""]

        $self Send BLOCK:UPDATE -block_id $block_id {*}$opts

        if {$state ne ""} {
            $self Send BLOCK:STATE -block_id $block_id -state $state
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

    method ConditionAdd {block_id typename args} {
        # FIRST, get the block_id
        if {$block_id eq "-"} {
            set block_id [$self LastBean ::athena::block]
        }

        # NEXT, create the condition
        $adb order transaction "condition add..." {
            set condition_id [$self Send BLOCK:CONDITION:ADD \
                                    -block_id $block_id \
                                    -typename $typename]
            $self ConditionUpdate $condition_id $args
        }

        return $condition_id
    }

    # condition cget condition_id ?option?
    #
    # condition_id   - A valid condition ID, or "-" for the newest condition.
    #
    # Retrieves the value of a condition option.  If no option is given,
    # returns a dictionary of options and values.

    method ConditionCget {condition_id {opt ""}} {
        # FIRST, get the condition_id
        if {$condition_id eq "-"} {
            set condition_id [$self LastBean ::athena::condition]
        }

        $adb bean valclass ::athena::condition $condition_id

        # NEXT, get the condition data
        set condition [$adb bean get $condition_id]

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

    method ConditionConfigure {condition_id args} {
        # FIRST, get the condition_id
        if {$condition_id eq "-"} {
            set condition_id [$self LastBean ::athena::condition]
        }

        $adb bean valclass ::athena::condition $condition_id

        # NEXT, configure it
        $adb order transaction "condition configure..." {
            $self ConditionUpdate $condition_id $args
        }
    }
    
    # ConditionUpdate condition_id opts
    #
    # condition_id   - A condition ID
    # opts           - A list of condition options and values
    #
    # Applies the options to the condition.  The options are the 
    # CONDITION:UPDATE send options plus -state.

    method ConditionUpdate {condition_id opts} {
        set c [$adb bean get $condition_id]

        set state [from opts -state ""]

        $self Send CONDITION:[$c typename] -condition_id $condition_id {*}$opts

        if {$state ne ""} {
            $self Send CONDITION:STATE -condition_id $condition_id -state $state
        }
    }

    # dbsync
    #
    # Syncs the UI with the scenario.

    method Dbsync {} {
        $adb dbsync
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

    method Export {args} {
        # FIRST, get the options.
        array set opts {
            -history 0
            -map     0
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

                -map {
                    set opts(-map) 1
                } 

                default {
                    error "unknown option "
                }
            }
        }

        # NEXT, if they want the -history export, that can be done
        # at any time.  Do it and return.
        if {$opts(-history)} {
            $adb export fromcif $fullname $opts(-map)

            app puts "Exported scenario from history as $fullname."
            return
        }

        # NEXT, the normal export can only be done during PREP.
        if {[$adb locked]} {
            error "Cannot export while the scenario is locked."
        }

        $adb export fromdata $fullname $opts(-map)

        app puts "Exported scenario from current data as $fullname."

        return
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

    method Gofer {typeOrGdict {rulename ""} args} {
        if {$rulename ne ""} {
            return [$adb gofer make $typeOrGdict $rulename {*}$args]
        } else {
            return [$adb gofer eval [$adb gofer validate $typeOrGdict]]
        }
    }

    # help ?-info? ?command...?
    #
    # Outputs the help for the command 
    #
    # TBD: Hybrid command, half application half library

    method Help {args} {
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

    # LastBean cls
    #
    # cls   - A bean class
    #
    # Returns the bean ID of the most recently created instance of
    # the given bean class, or "" if none.

    method LastBean {cls} {
        set last [lindex [$adb bean ids $cls] end]

        if {$last eq ""} {
            set kind [namespace tail $cls]
            error "last $kind: no ${kind}s have been created."
        }

        return $last
    }

    # lock
    #
    # Locks the scenario.

    method Lock {} {
        $self Send SIM:LOCK
    }

    # log message
    #
    # message - A text string
    #
    # Logs the message at normal level as "script".

    method Log {message} {
        $adb log normal script $message
    }

    # parm import filename
    #
    # filename   A .parmdb file
    #
    # Imports the .parmdb file

    method ParmImport {filename} {
        $self Send PARM:IMPORT -filename $filename
    }


    # parm list ?pattern?
    #
    # pattern  - A glob pattern
    #
    # Lists all parameters with their values, or those matching the
    # pattern.  If none are found, throws an error.

    method ParmList {{pattern *}} {
        set result [$adb parm list $pattern]

        if {$result eq ""} {
            error "No matching parameters"
        }

        return $result
    }


    # parm reset 
    #
    # Resets all parameters to defaults.

    method ParmReset {} {
        $self Send PARM:RESET
    }


    # parm set parm value
    #
    # parm     A parameter name
    # value    A value
    #
    # Sets the parameter's value, using PARM:SET

    method ParmSet {parm value} {
        $self Send PARM:SET -parm $parm -value $value
    }

    # redo
    #
    # If possible, redoes the last undone order.

    method Redo {} {
        if {![$adb order canredo]} {
            return "Nothing to redo."
        }

        set title [$adb order redotext]
        $adb order redo

        return "Redone: $title"
    }

    # save filename
    # 
    # filename   - Scenario file name
    #
    # Saves the scenario using the name.  Errors are handled by
    # [app error].
    #
    # TBD: hybrid

    method Save {filename} {
        app save $filename
        return
    }
    

    # send order ?option value...?
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

    method Send {order args} {
        set order [string toupper $order]

        # NEXT, determine the order mode.
        if {[$adb state] eq "TACTIC"} {
            $adb order send private $order {*}$args
        } else {
            $adb order send normal $order {*}$args
        }
    }

    # sigevent message ?tags...?
    #
    # message - A sig event narrative
    # tags    - Zero or more neighborhoods/actors/groups
    #
    # Writes a message to the significant event log.

    method Sigevent {message args} {
        $adb sigevent log 1 script $message {*}$args
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

    method TacticAdd {block_id typename args} {
        # FIRST, get the block_id
        if {$block_id eq "-"} {
            set block_id [$self LastBean ::athena::block]
        }

        # NEXT, create the tactic
        $adb order transaction "tactic add..." {
            set tactic_id [$self Send BLOCK:TACTIC:ADD \
                                    -block_id $block_id \
                                    -typename $typename]
            $self TacticUpdate $tactic_id $args
        }

        return $tactic_id
    }

    # tactic cget tactic_id ?option?
    #
    # tactic_id   - A valid tactic ID, or "-" for the newest tactic.
    #
    # Retrieves the value of a tactic option.  If no option is given,
    # returns a dictionary of options and values.

    method TacticCget {tactic_id {opt ""}} {
        # FIRST, get the tactic_id
        if {$tactic_id eq "-"} {
            set tactic_id [$self LastBean ::athena::tactic]
        }

        $adb bean valclass ::athena::tactic $tactic_id

        # NEXT, get the tactic data
        set tactic [$adb bean get $tactic_id]

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

    method TacticConfigure {tactic_id args} {
        # FIRST, get the tactic_id
        if {$tactic_id eq "-"} {
            set tactic_id [$self LastBean ::athena::tactic]
        }

        $adb bean valclass ::athena::tactic $tactic_id

        # NEXT, configure it
        $adb order transaction "tactic configure..." {
            $self TacticUpdate $tactic_id $args
        }
    }
    
    # TacticUpdate tactic_id opts
    #
    # tactic_id   - A tactic ID
    # opts           - A list of tactic options and values
    #
    # Applies the options to the tactic.  The options are the 
    # TACTIC:UPDATE send options plus -state.

    method TacticUpdate {tactic_id opts} {
        set c [$adb bean get $tactic_id]

        set state [from opts -state ""]

        $self Send TACTIC:[$c typename] -tactic_id $tactic_id {*}$opts

        if {$state ne ""} {
            $self Send TACTIC:STATE -tactic_id $tactic_id -state $state
        }
    }

    # tofile filename text
    #
    # filename   - A filename
    # extension  - A default extension
    # text       - Text
    #
    # Writes the text to the filename

    method Tofile {filename extension text} {
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

    method Undo {} {
        if {![$adb order canundo]} {
            return "Nothing to undo."
        }

        set title [$adb order undotext]
        $adb order undo

        return "Undone: $title"
    }
 
    # unlock
    #
    # Unlocks the scenario.

    method Unlock {} {
        $self Send SIM:UNLOCK
    }


    #-------------------------------------------------------------------
    # Application Executive Commands
    #
    # TBD: These need to move to app

    # enter order ?parm value...?
    #
    # order   - The name of an order.
    # parm    - One of order's parameter names
    # value   - The parameter's value
    #
    # This routine pops up an order dialog from the command line.  It is
    # intended for debugging rather than end-user use.

    method Enter {order args} {
        app enter $order $args
    }

    # show url
    #
    # Shows a URL in the detail browser.

    method Show {url} {
        .main tab view detail
        app show $url
    }

    # super args
    #
    # Executes args as a command in the global namespace
    method Super {args} {
        namespace eval :: $args
    }

    # usermode ?mode?
    #
    # mode     normal|super
    #
    # Queries/sets the CLI mode.  In normal mode, all commands are 
    # methodessed by the smartinterp, unless "super" is used.  In
    # super mode, all commands are methodessed by the main interpreter.

    method usermode {{mode ""}} {
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

    
}



#-----------------------------------------------------------------------
# Commands defined in ::, for use when usermode is super

# usermode ?mode?
#
# Calls executive usermode
# TBD: As written this should be in the application.

proc usermode {{mode ""}} {
    ::adb executive usermode $mode
}



