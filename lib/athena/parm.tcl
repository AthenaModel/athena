#-----------------------------------------------------------------------
# TITLE:
#    parm.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Model Parameters
#
# TBD: Global refs: athena register, 
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# parm

snit::type ::athena::parm {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Components

    component ps ;# parmdb(n), really

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        set adb $adb_

        # FIRST, initialize parmdb(n), and delegate to it.
        # TBD: parmdb will be moved into this module.
        set ps ::projectlib::parmdb
        $ps init

        # Register to receive simulation state updates.
        # We need a better way to do this.
        notifier bind [$adb cget -subject] <State> $self [mymethod SimState]
    }

    destructor {
        notifier forget $self
    }

    #-------------------------------------------------------------------
    # Public methods

    delegate method * to ps

    #-------------------------------------------------------------------
    # Event Handlers

    # SimState
    #
    # This is called when the simulation state changes, e.g., from
    # PREP to RUNNING.  It locks and unlocks significant parameters.

    method SimState {} {
        if {[$adb state] eq "PREP"} {
            $ps unlock *
        } else {
            $self LockParms
        }
    }

    # LockParms
    #
    # Locks parameters that shouldn't be changed once the simulation is
    # running.

    method LockParms {} {
        $ps lock econ.ticksPerTock
    }


    #-------------------------------------------------------------------
    # Queries

    # validate parm
    #
    # parm     - A parameter name
    #
    # Validates parm as a parameter name.  Returns the name.

    method validate {parm} {
        set canonical [$self names $parm]

        if {$canonical ni [$self names]} {
            return -code error -errorcode INVALID \
                "Unknown model parameter: \"$parm\""
        }

        # Return it in canonical form
        return $canonical
    }

    # nondefaults ?pattern?
    #
    # Returns a list of the parameters with non-default values.

    method nondefaults {{pattern ""}} {
        if {$pattern eq ""} {
            set parms [$self names]
        } else {
            set parms [$self names $pattern]
        }

        set result [list]

        foreach parm $parms {
            if {[$self get $parm] ne [$self getdefault $parm]} {
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

    method {mutate import} {filename} {
        # FIRST, get the undo information
        set undo [mymethod restore [$ps checkpoint]]

        # NEXT, try to load the parameters
        $ps load $filename

        # NEXT, log it.
        $adb log normal parm "Imported Parameters: $filename"
        
        $adb notify parm <Update>

        # NEXT, Return the undo script
        return $undo
    }


    # mutate reset
    #
    # Resets the values to the current defaults, reading them from the
    # disk as necessary.

    method {mutate reset} {} {
        # FIRST, get the undo information
        set undo [mymethod restore [$ps checkpoint]]

        # NEXT, get the names and values of any locked parameters
        set locked [$ps locked]

        foreach parm $locked {
            set saved($parm) [$ps get $parm]
        }

        $ps unlock *

        # NEXT, reset values to defaults.
        $self reset

        # NEXT, put the locked parameters back
        set unreset [list]

        foreach parm $locked {
            if {$saved($parm) ne [$ps get $parm]} {
                $ps set $parm $saved($parm)
                lappend unreset $parm
            }
            $ps lock $parm
        }

        $adb notify $self <Update>

        # NEXT, Return the undo script
        return $undo
    }


    # mutate set parm value
    #
    # parm    A parameter name
    # value   A parameter value
    #
    # Sets the value of the parameter, and returns an undo script

    method {mutate set} {parm value} {
        # FIRST, get the undo information
        set undo [mymethod mutate set $parm [$ps get $parm]]

        # NEXT, try to set the parameter
        $ps set $parm $value

        $adb notify parm <Update>

        # NEXT, return the undo script
        return $undo
    }
}

#-----------------------------------------------------------------------
# Orders: PARM:*

# PARM:IMPORT
#
# Imports the contents of a parmdb file into the scenario.

::athena::orders define PARM:IMPORT {
    meta title      "Import Parameter File"
    meta sendstates {PREP PAUSED}
    meta parmlist   {filename}

    method _validate {} {
        my prepare filename -required 

        my checkon filename {
            if {![file exists $parms(filename)]} {
                my reject filename "Error, file not found: \"$parms(filename)\""
            }

        }

        my returnOnError
    }

    method _execute {{flunky ""}} {
        if {[catch {
            # In this case, simply try it.
            my setundo [$adb parm mutate import $parms(filename)]
        } result]} {
            # TBD: what do we do here? bgerror for now
            error $result
        }
    }
}


# PARM:RESET
#
# Imports the contents of a parmdb file into the scenario.

::athena::orders define PARM:RESET {
    meta title      "Reset Parameters to Defaults"
    meta sendstates {PREP PAUSED}
    meta parmlist   {}

    method _validate {} {}

    method _execute {{flunky ""}} {
        if {[catch {
            # In this case, simply try it.
            my setundo [$adb parm mutate reset]
        } result]} {
            my reject * $result
        }

        my returnOnError
    }
}


# PARM:SET
#
# Sets the value of a parameter.

::athena::orders define PARM:SET {
    meta title      "Set Parameter Value"
    meta sendstates {PREP PAUSED}
    meta parmlist   {parm value}

    meta form {
        rcc "Parameter:" -for parm
        enum parm -listcmd {parm names} \
            -loadcmd {$order_ loadValue}

        rcc "Value:" -for value
        text value -width 40
    }

    # loadValue idict parm
    #
    # idict - "parm" item definition dictionary
    # parm  - Chosen parameter name
    #
    # Returns the value for the parameter.

    method loadValue {idict parm} {
        if {$parm ne ""} {
            dict create value [$adb parm get $parm]
        }
    }


    method _validate {} {
        my prepare parm  -required  -type [list $adb parm]
        my prepare value

        my returnOnError

        # NEXT, validate the value
        set vtype [$adb parm type $parms(parm)]

        if {[catch {$vtype validate $parms(value)} result]} {
            my reject value $result
        }
    }

    method _execute {{flunky ""}} {
        my setundo [$adb parm mutate set $parms(parm) $parms(value)]
    }
}
