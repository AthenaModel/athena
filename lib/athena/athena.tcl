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

    delegate typemethod compdb using {::athena::compdb}
    delegate typemethod diff   using {::athena::differencer diff}

    typeconstructor {
        set athenadb ::athena::athenadb
    }

    # new ?options...?
    #
    # Creates and returns a new instance of athena(n).

    typemethod new {args} {
        return [$type create %AUTO% {*}$args]
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

    delegate option -subject      to adb
    delegate option -adbfile      to adb
    delegate option -scratch      to adb
    delegate option -logdir       to adb
    delegate option -executivecmd to adb
    delegate option -tempsqlfiles to adb

    #-------------------------------------------------------------------
    # Constructor

    # constructor ?options...?
    #
    # Creates a new athena(n), loading an .adb if -filename is given.

    constructor {args} {
        # FIRST, create and configure the athenadb instance.
        install adb using athenadb ${selfns}::adb      \
            -subject      [from args -subject $self]   \
            -adbfile      [from args -adbfile ""]      \
            -executivecmd [from args -executivecmd ""] \
            -logdir       [from args -logdir ""]       \
            -tempsqlfiles [from args -tempsqlfiles ""]

        # NEXT, handle any additional options.
        $self configurelist $args

        # NEXT, get subcomponents from athenadb(n).
        set rdb [$adb component rdb]
    } 

    destructor {
        catch {$adb destroy}
    }

    #-------------------------------------------------------------------
    # Delegated commands

    # ADB
    delegate method adbfile                 to adb
    delegate method advance                 to adb
    delegate method autogen                 to adb
    delegate method busy                    to adb
    delegate method canlock                 to adb
    delegate method clock                   to adb
    delegate method contribs                to adb as {aram contribs}
    delegate method dbsync                  to adb
    delegate method enter                   to adb
    delegate method eval                    to adb as {safe eval}
    delegate method executive               to adb
    delegate method exists                  to adb as {safe exists}
    delegate method export                  to adb
    delegate method getclock                to adb as {component clock}
    delegate method gofer                   to adb
    delegate method halt                    to adb as {sim halt} ;# TBD
    delegate method interrupt               to adb
    delegate method is                      to adb
    delegate method load                    to adb
    delegate method loadtemp                to adb
    delegate method lock                    to adb
    delegate method log                     to adb
    delegate method onecolumn               to adb as {safe onecolumn}
    delegate method paste                   to adb
    delegate method progress                to adb
    delegate method ptype                   to adb
    delegate method query                   to adb as {safe query}
    delegate method rdb                     to adb
    delegate method rdbfile                 to adb as {rdb dbfile}
    delegate method reset                   to adb
    delegate method sanity                  to adb
    delegate method save                    to adb
    delegate method savetemp                to adb
    delegate method state                   to adb
    delegate method statetext               to adb
    delegate method unlock                  to adb
    delegate method version                 to adb

    delegate method {absit exists}          to adb as {absit exists}
    delegate method {absit get}             to adb as {absit get}
    delegate method {absit isinitial}       to adb as {absit isinitial}
    delegate method {absit islive}          to adb as {absit islive}
    delegate method {absit names}           to adb as {absit names}
    delegate method {absit validate}        to adb as {absit validate}
    delegate method {absit view}            to adb as {absit view}

    delegate method {actor exists}          to adb as {actor exists}
    delegate method {actor get}             to adb as {actor get}
    delegate method {actor namedict}        to adb as {actor namedict}
    delegate method {actor names}           to adb as {actor names}
    delegate method {actor validate}        to adb as {actor validate}
    delegate method {actor view}            to adb as {actor view}
    
    delegate method {activity names}        to adb as {activity names}
    delegate method {activity frc names}    to adb as {activity frc names}
    delegate method {activity org names}    to adb as {activity org names}
    
    delegate method {agent exists}          to adb as {agent exists}
    delegate method {agent names}           to adb as {agent names}
    delegate method {agent stats}           to adb as {agent stats}
    delegate method {agent tactictypes}     to adb as {agent tactictypes}
    delegate method {agent type}            to adb as {agent type}
    delegate method {agent validate}        to adb as {agent validate}
    
    delegate method {bean get}              to adb as {bean get}
    delegate method {bean has}              to adb as {bean has}
    delegate method {bean ids}              to adb as {bean ids}
    delegate method {bean view}             to adb as {bean view}

    delegate method {bsys affinity}         to adb as {bsys affinity}
    delegate method {bsys belief view}      to adb as {bsys belief view}
    delegate method {bsys belief validate}  to adb as {bsys belief validate}
    delegate method {bsys belief isdefault} to adb as {bsys belief isdefault}
    delegate method {bsys playbox cget}     to adb as {bsys playbox cget}
    delegate method {bsys playbox view}     to adb as {bsys playbox view}
    delegate method {bsys system cget}      to adb as {bsys system cget}
    delegate method {bsys system exists}    to adb as {bsys system exists}
    delegate method {bsys system ids}       to adb as {bsys system ids}
    delegate method {bsys system namedict}  to adb as {bsys system namedict}
    delegate method {bsys system inuse}     to adb as {bsys system inuse}
    delegate method {bsys system validate}  to adb as {bsys system validate}
    delegate method {bsys system view}      to adb as {bsys system view}
    delegate method {bsys topic cget}       to adb as {bsys topic cget}
    delegate method {bsys topic exists}     to adb as {bsys topic exists}
    delegate method {bsys topic ids}        to adb as {bsys topic ids}
    delegate method {bsys topic inuse}      to adb as {bsys topic inuse}
    delegate method {bsys topic validate}   to adb as {bsys topic validate}
    delegate method {bsys topic view}       to adb as {bsys topic view}

    delegate method {civgroup exists}       to adb as {civgroup exists}
    delegate method {civgroup get}          to adb as {civgroup get}
    delegate method {civgroup local}        to adb as {civgroup local}
    delegate method {civgroup namedict}     to adb as {civgroup namedict}
    delegate method {civgroup names}        to adb as {civgroup names}
    delegate method {civgroup validate}     to adb as {civgroup validate}
    delegate method {civgroup view}         to adb as {civgroup view}

    delegate method {curse check}           to adb as {curse check}
    delegate method {curse exists}          to adb as {curse exists}
    delegate method {curse get}             to adb as {curse get}
    delegate method {curse namedict}        to adb as {curse namedict}
    delegate method {curse names}           to adb as {curse names}
    delegate method {curse normal}          to adb as {curse normal}
    delegate method {curse validate}        to adb as {curse validate}

    delegate method {econ state}            to adb as {econ state}
    delegate method {econ report}           to adb as {econ report}
    delegate method {econ hist}             to adb as {econ hist}
    delegate method {econ getcge}           to adb as {econ getcge}
    delegate method {econ getsam}           to adb as {econ getsam}
    delegate method {econ enable}           to adb as {econ enable}
    delegate method {econ disable}          to adb as {econ disable}

    delegate method {frcgroup exists}       to adb as {frcgroup exists}
    delegate method {frcgroup get}          to adb as {frcgroup get}
    delegate method {frcgroup namedict}     to adb as {frcgroup namedict}
    delegate method {frcgroup names}        to adb as {frcgroup names}
    delegate method {frcgroup validate}     to adb as {frcgroup validate}
    delegate method {frcgroup view}         to adb as {frcgroup view}

    delegate method {group exists}          to adb as {group exists}
    delegate method {group gtype}           to adb as {group gtype}
    delegate method {group namedict}        to adb as {group namedict}
    delegate method {group names}           to adb as {group names}
    delegate method {group validate}        to adb as {group validate}

    delegate method {hook get}              to adb as {hook get}
    delegate method {hook namedict}         to adb as {hook namedict}
    delegate method {hook names}            to adb as {hook names}
    delegate method {hook topic exists}     to adb as {hook topic exists}
    delegate method {hook topic get}        to adb as {hook topic get}
    delegate method {hook topic validate}   to adb as {hook topic validate}
    delegate method {hook validate}         to adb as {hook validate}

    delegate method {hist vars}             to adb as {hist vars}

    delegate method {inject exists}         to adb as {inject exists}
    delegate method {inject get}            to adb as {inject get}
    delegate method {inject typenames}      to adb as {inject typenames}
    delegate method {inject validate}       to adb as {inject validate}

    delegate method {iom check}             to adb as {iom check}
    delegate method {iom exists}            to adb as {iom exists}
    delegate method {iom get}               to adb as {iom get}
    delegate method {iom namedict}          to adb as {iom namedict}
    delegate method {iom names}             to adb as {iom names}
    delegate method {iom normal}            to adb as {iom normal}
    delegate method {iom validate}          to adb as {iom validate}

    delegate method {nbhood bbox}           to adb as {nbhood bbox}
    delegate method {nbhood exists}         to adb as {nbhood exists}
    delegate method {nbhood find}           to adb as {nbhood find}
    delegate method {nbhood get}            to adb as {nbhood get}
    delegate method {nbhood namedict}       to adb as {nbhood namedict}
    delegate method {nbhood names}          to adb as {nbhood names}
    delegate method {nbhood validate}       to adb as {nbhood validate}
    delegate method {nbhood view}           to adb as {nbhood view}

    delegate method {order available}       to adb as {order available}
    delegate method {order canredo}         to adb as {order canredo}
    delegate method {order canundo}         to adb as {order canundo}
    delegate method {order check}           to adb as {order check}
    delegate method {order class}           to adb as {order class}
    delegate method {order make}            to adb as {order make}
    delegate method {order monitor}         to adb as {order monitor}
    delegate method {order names}           to adb as {order names}
    delegate method {order redotext}        to adb as {order redotext}
    delegate method {order redo}            to adb as {order redo}
    delegate method {order reset}           to adb as {order reset}
    delegate method {order senddict}        to adb as {order senddict}
    delegate method {order send}            to adb as {order send}
    delegate method {order transactions}    to adb as {order transactions}
    delegate method {order transaction}     to adb as {order transaction}
    delegate method {order undotext}        to adb as {order undotext}
    delegate method {order undo}            to adb as {order undo}
    delegate method {order validate}        to adb as {order validate}

    delegate method {orggroup exists}       to adb as {orggroup exists}
    delegate method {orggroup get}          to adb as {orggroup get}
    delegate method {orggroup namedict}     to adb as {orggroup namedict}
    delegate method {orggroup names}        to adb as {orggroup names}
    delegate method {orggroup validate}     to adb as {orggroup validate}
    delegate method {orggroup view}         to adb as {orggroup view}

    delegate method {parm docstring}        to adb as {parm docstring}
    delegate method {parm get}              to adb as {parm get}
    delegate method {parm getdefault}       to adb as {parm getdefault}
    delegate method {parm islocked}         to adb as {parm islocked}
    delegate method {parm list}             to adb as {parm list}
    delegate method {parm names}            to adb as {parm names}
    delegate method {parm nondefaults}      to adb as {parm nondefaults}
    delegate method {parm save}             to adb as {parm save}

    delegate method {payload exists}        to adb as {payload exists}
    delegate method {payload get}           to adb as {payload get}
    delegate method {payload typenames}     to adb as {payload typenames}
    delegate method {payload validate}      to adb as {payload validate}

    delegate method {plant capacity}        to adb as {plant capacity}

    delegate method {ruleset detail}        to adb as {ruleset detail}
    delegate method {ruleset get}           to adb as {ruleset get}
    delegate method {ruleset narrative}     to adb as {ruleset narrative}
    delegate method {ruleset rulename}      to adb as {ruleset rulename}

    delegate method {service levels}        to adb as {service levels}

    delegate method {strategy getname}      to adb as {strategy getname}
    delegate method {strategy check}        to adb as {strategy check}

    delegate method {stats moodbybsys}      to adb as {stats moodbybsys}
    delegate method {stats moodbygroups}    to adb as {stats moodbygroups}
    delegate method {stats satbybsys}       to adb as {stats satbybsys}
    delegate method {stats satbygroups}     to adb as {stats satbygroups}
    delegate method {stats satbynb}         to adb as {stats satbynb}
    delegate method {stats pbsat}           to adb as {stats pbsat}
    delegate method {stats pbmood}          to adb as {stats pbmood}

    delegate method {unit get}              to adb as {unit get}
    delegate method {unit names}            to adb as {unit names}
    delegate method {unit validate}         to adb as {unit validate}

    #-------------------------------------------------------------------
    # Public Methods

    # athenadb
    #
    # Returns the athenadb(n) handle.

    method athenadb {} {
        return $adb
    }
    
}

