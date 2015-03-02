#-----------------------------------------------------------------------
# TITLE:
#   athena.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#   athena(n) Package: athena scenario object.
#
#   This type is the main public entry point into the athena(n) library.
#   Instances of athena(n) define entire scenarios, and can be saved
#   to and loaded from .adb files.
#
#   However, the athena(n) type is just a wrapper around the 
#   athenadb(n), which does all of the work.  The athenadb(n) object 
#   creates all other objects in the scenario, passing itself to them
#   to serve as the main *private* entry point. 
#
#-----------------------------------------------------------------------

namespace eval ::athena:: {
    namespace export \
        athena
}

#-----------------------------------------------------------------------
# athena type

snit::type ::athena::athena {
    #-------------------------------------------------------------------
    # Type Components and Methods

    typecomponent athenadb

    delegate typemethod register to athenadb

    typeconstructor {
        set athenadb ::athena::athenadb
    }
    
    #-------------------------------------------------------------------
    # Components
    #
    # The primary component is the adb (athenadb) component; for 
    # efficiency, some of its components are exposed to athena(n) for
    # direct delegation.

    component adb ;# The scenario's athenadb component

    
    component rdb ;# Read-only RDB handle

    #-------------------------------------------------------------------
    # Options

    delegate option -logcmd  to adb
    delegate option -subject to adb

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

    #-------------------------------------------------------------------
    # Constructor

    # constructor ?options...?
    #
    # Creates a new athena(n), loading an .adb if -filename is given.

    constructor {args} {
        # FIRST, handle options explicitly.
        set filename [from args -adbfile ""]
        set subject  [from args -subject $self]

        # NEXT, create and configure the athenadb instance.
        install adb using athenadb ${selfns}::adb $filename \
            -subject $subject

        # NEXT, handle any additional options.
        $self configurelist $args

        # NEXT, get subcomponents from athenadb(n).
        set rdb [$adb rdb component]
    } 

    destructor {
        catch {$adb destroy}
    }

    #-------------------------------------------------------------------
    # Delegated commands

    # TBD: Review commands which are ensembles; and verify which 
    # subcommands we really want to expose.

    # ADB
    delegate method adbfile              to adb
    delegate method autogen              to adb
    delegate method dbsync               to adb
    delegate method enter                to adb
    delegate method executive            to adb
    delegate method export               to adb
    delegate method gofer                to adb
    delegate method load                 to adb
    delegate method locked               to adb
    delegate method paste                to adb
    delegate method reset                to adb
    delegate method sanity               to adb
    delegate method save                 to adb
    delegate method {order available}    to adb as {order available}
    delegate method {order canundo}      to adb as {order canundo}
    delegate method {order canredo}      to adb as {order canredo}
    delegate method {order class}        to adb as {order class}
    delegate method {order make}         to adb as {order make}
    delegate method {order monitor}      to adb as {order monitor}
    delegate method {order redo}         to adb as {order redo}
    delegate method {order redotext}     to adb as {order redotext}
    delegate method {order reset}        to adb as {order reset}
    delegate method {order send}         to adb as {order send}
    delegate method {order senddict}     to adb as {order senddict}
    delegate method {order transaction}  to adb as {order transaction}
    delegate method {order transactions} to adb as {order transactions}
    delegate method {order undo}         to adb as {order undo}
    delegate method {order undotext}     to adb as {order undotext}
    delegate method stable               to adb
    delegate method state                to adb
    delegate method unsaved              to adb
    delegate method version              to adb
    delegate method contribs             to adb as {aram contribs}
    delegate method {bean get}           to adb as {bean get}
    delegate method {bean has}           to adb as {bean has}
    delegate method {bean ids}           to adb as {bean ids}

    # RDB
    #
    # At present, these are delegated to the real RDB.  Ultimately
    # we will want to create a read-only RDB handle and delegate to
    # that.
    delegate method eval            to rdb as eval
    delegate method exists          to rdb as exists
    delegate method onecolumn       to rdb as onecolumn
    delegate method query           to rdb as query
    delegate method safequery       to rdb as safequery
    delegate method safeeval        to rdb as safeeval

    #-------------------------------------------------------------------
    # Public Methods

    # athenadb
    #
    # Returns the athenadb(n) handle.

    method athenadb {} {
        return $adb
    }
    
    # lock
    # 
    # Locks the scenario by sending SIM:LOCK.

    method lock {} {
        $adb send normal SIM:LOCK
    }

    # unlock
    # 
    # Unlocks the scenario by sending SIM:UNLOCK.

    method unlock {} {
        $adb send normal SIM:UNLOCK
    }

    # rebase
    # 
    # Rebases the scenario by sending SIM:REBASE.

    method rebase {} {
        $adb send normal SIM:REBASE
    }

}

