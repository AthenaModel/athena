#-----------------------------------------------------------------------
# TITLE:
#    parm.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1) model parameters
#
#    The module delegates most of its function to parmdb(n).
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# parm

snit::type parm {
    # Make it a singleton
    pragma -hasinstances 0

    #-------------------------------------------------------------------
    # Typecomponents

    typecomponent ps ;# parmdb(n), really

    #-------------------------------------------------------------------
    # Public typemethods

    delegate typemethod * to ps

    # init mode
    #
    # mode   - master or slave
    #
    # Initializes the module as a master (in the App thread) or as
    # a slave (in the Engine thread).

    typemethod init {mode} {
        # Don't initialize twice.
        if {$ps ne ""} {
            return
        }

        log detail parm "init $mode"

        # FIRST, initialize parmdb(n), and delegate to it.
        parmdb init

        set ps ::projectlib::parmdb

        # NEXT, if master get connected with the other App thread
        # entities.

        if {$mode eq "master"} {
            # Register to receive simulation state updates.
            notifier bind ::sim <State> $type [mytypemethod SimState]

            # Register this type as a saveable
            athena register ::parm
        } else {
            # Slave
            $type LockParms
        }

        log detail parm "init complete"
    }

    #-------------------------------------------------------------------
    # Event Handlers

    # SimState
    #
    # This is called when the simulation state changes, e.g., from
    # PREP to RUNNING.  It locks and unlocks significant parameters.

    typemethod SimState {} {
        if {[sim state] eq "PREP"} {
            parmdb unlock *
        } else {
            $type LockParms
        }
    }

    # LockParms
    #
    # Locks parameters that shouldn't be changed once the simulation is
    # running.

    typemethod LockParms {} {
        parmdb lock econ.ticksPerTock
    }


    #-------------------------------------------------------------------
    # Queries

    # validate parm
    #
    # parm     - A parameter name
    #
    # Validates parm as a parameter name.  Returns the name.

    typemethod validate {parm} {
        set canonical [$type names $parm]

        if {$canonical ni [$type names]} {
            return -code error -errorcode INVALID \
                "Unknown model parameter: \"$parm\""
        }

        # Return it in canonical form
        return $canonical
    }

    # nondefaults ?pattern?
    #
    # Returns a list of the parameters with non-default values.

    typemethod nondefaults {{pattern ""}} {
        if {$pattern eq ""} {
            set parms [parm names]
        } else {
            set parms [parm names $pattern]
        }

        set result [list]

        foreach parm $parms {
            if {[parm get $parm] ne [parm getdefault $parm]} {
                lappend result $parm
            }
        }

        return $result
    }

    #-------------------------------------------------------------------
    # Mutators
    #
    # Mutators are used to implement orders that change the scenario in
    # some way.  Mutators assume that their inputs are valid, and returns
    # a script of one or more commands that will undo the change.  When
    # change cannot be undone, the mutator returns the empty string.

    # mutate import filename
    #
    # filename     A parameter file
    #
    # Attempts to import the parameter into the RDB.  This command is
    # undoable.

    typemethod {mutate import} {filename} {
        # FIRST, get the undo information
        set undo [mytypemethod restore [$ps checkpoint]]

        # NEXT, try to load the parameters
        $ps load $filename

        # NEXT, log it.
        log normal parm "Imported Parameters: $filename"
        
        app puts "Imported Parameters: $filename"

        notifier send $type <Update>

        # NEXT, Return the undo script
        return $undo
    }


    # mutate reset
    #
    # Resets the values to the current defaults, reading them from the
    # disk as necessary.

    typemethod {mutate reset} {} {
        # FIRST, get the undo information
        set undo [mytypemethod restore [$ps checkpoint]]

        # NEXT, get the names and values of any locked parameters
        set locked [$ps locked]

        foreach parm $locked {
            set saved($parm) [$ps get $parm]
        }

        $ps unlock *

        # NEXT, reset values to defaults.
        $type reset

        # NEXT, put the locked parameters back
        set unreset [list]

        foreach parm $locked {
            if {$saved($parm) ne [$ps get $parm]} {
                $ps set $parm $saved($parm)
                lappend unreset $parm
            }
            $ps lock $parm
        }

        # NEXT, log it.
        if {[llength $unreset] == 0} {
            log normal parm "Reset Parameters"
            app puts        "Reset Parameters"
        } else {
            log normal warning \
                "Reset Parameters, except for the following locked parameters\n[join $unreset \n]"

            app puts "Reset Parameters (except for locked parameters, see log)"
        }

        notifier send $type <Update>

        # NEXT, Return the undo script
        return $undo
    }


    # mutate set parm value
    #
    # parm    A parameter name
    # value   A parameter value
    #
    # Sets the value of the parameter, and returns an undo script

    typemethod {mutate set} {parm value} {
        # FIRST, get the undo information
        set undo [mytypemethod mutate set $parm [$ps get $parm]]

        # NEXT, try to set the parameter
        $ps set $parm $value

        notifier send $type <Update>

        # NEXT, return the undo script
        return $undo
    }

    #-------------------------------------------------------------------
    # Order helpers

    # LoadValue idict parm
    #
    # idict - "parm" item definition dictionary
    # parm  - Chosen parameter name
    #
    # Returns the value for the parameter.

    proc LoadValue {idict parm} {
        if {$parm ne ""} {
            dict create value [parm get $parm]
        }
    }
}

#-----------------------------------------------------------------------
# Orders: PARM:*

# PARM:IMPORT
#
# Imports the contents of a parmdb file into the scenario.

order define PARM:IMPORT {
    title "Import Parameter File"

    options -sendstates {PREP PAUSED}

    # NOTE: Dialog is not usually used.  Could define a "filepicker"
    # -editcmd or field type, though.
    form {
        rcc "Parameter File:" -for filename
        text filename
    }
} {
    # FIRST, prepare the parameters
    prepare filename -required 

    returnOnError -final

    # NEXT, validate the parameters
    if {[catch {
        # In this case, simply try it.
        setundo [parm mutate import $parms(filename)]
    } result]} {
        reject filename $result
    }

    returnOnError
}


# PARM:RESET
#
# Imports the contents of a parmdb file into the scenario.

order define PARM:RESET {
    title "Reset Parameters to Defaults"

    options -sendstates {PREP PAUSED}
} {
    returnOnError -final

    # FIRST, try to do it.
    if {[catch {
        # In this case, simply try it.
        setundo [parm mutate reset]
    } result]} {
        reject * $result
    }

    returnOnError
}


# PARM:SET
#
# Sets the value of a parameter.

order define PARM:SET {
    title "Set Parameter Value"

    options -sendstates {PREP PAUSED}

    form {
        rcc "Parameter:" -for parm
        enum parm -listcmd {parm names} \
            -loadcmd {parm::LoadValue}

        rcc "Value:" -for value
        text value -width 40
    }
} {
    # FIRST, prepare the parameters
    prepare parm  -required  -type parm
    prepare value

    returnOnError

    # NEXT, validate the value
    set vtype [parm type $parms(parm)]

    if {[catch {$vtype validate $parms(value)} result]} {
        reject value $result
    }

    returnOnError -final

    # NEXT, set the value
    setundo [parm mutate set $parms(parm) $parms(value)]
}
