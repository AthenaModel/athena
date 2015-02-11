#-----------------------------------------------------------------------
# TITLE:
#    agent.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Agent Manager
#
#    This module is responsible for managing agents and operations
#    upon them.  An agent is an entity that can own and execute a
#    strategy, i.e., can have goals, tactics, and conditions.
#
# TBD: Global refs: strategy, tactic
#
#-----------------------------------------------------------------------

snit::type ::athena::agent {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        set adb $adb_
    }

    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.


    # names
    #
    # Returns the list of agent names

    method names {} {
        set names [$adb eval {
            SELECT agent_id FROM agents
        }]
    }


    # validate agent_id
    #
    # agent_id - Possibly, an agent short name.
    #
    # Validates an agent ID

    method validate {agent_id} {
        set names [$self names]

        if {$agent_id ni $names} {
            set nameString [join $names ", "]

            if {$nameString ne ""} {
                set msg "should be one of: $nameString"
            } else {
                set msg "none are defined"
            }

            return -code error -errorcode INVALID \
                "Invalid agent, $msg"
        }

        return $agent_id
    }

    # system names
    #
    # Returns the list of system agent names

    method {system names} {} {
        set names [$adb eval {
            SELECT agent_id FROM agents WHERE agent_type = 'system'
        }]
    }


    # system validate agent_id
    #
    # agent_id - Possibly, a system agent short name.
    #
    # Validates a system agent ID

    method {system validate} {agent_id} {
        set names [$self system names]

        if {$agent_id ni $names} {
            set nameString [join $names ", "]

            if {$nameString ne ""} {
                set msg "should be one of: $nameString"
            } else {
                set msg "none are defined"
            }

            return -code error -errorcode INVALID \
                "Invalid system agent, $msg"
        }

        return $agent_id
    }

    # type agent_id
    #
    # agent_id - An agent short name
    #
    # Retrieves the type of the agent, or ""

    method type {agent_id} {
        $adb eval {SELECT agent_type FROM agents WHERE agent_id=$agent_id}
    }

    # stats agent_id
    #
    # Returns a dictionary of agent strategy statistics: the number
    # of blocks, conditions, and tactics in the agent's strategy.

    method stats {agent_id} {
        set result [dict create blocks 0 conditions 0 tactics 0]
        set s [strategy getname $agent_id]

        dict set result blocks [llength [$s blocks]]

        set nc 0
        set nt 0

        foreach block [$s blocks] {
            incr nc [llength [$block conditions]]
            incr nt [llength [$block tactics]]
        }

        dict set result conditions $nc
        dict set result tactics    $nt

        return $result
    }

    # tactictypes agent_id
    #
    # Returns a list of the names of the tactic types that are valid for this 
    # agent.

    method tactictypes {agent_id} {
        # FIRST, get the tactic types that are valid for the agent type.
        set result [list]
        set atype [$self type $agent_id]

        foreach name [::athena::tactic typenames $atype] {
            # FIRST, skip special cases.
            if {$name  eq "MAINTAIN"                && 
                $atype eq "actor"                   &&
                [$adb actor get $agent_id auto_maintain]
            } {
                continue
            }

            # NEXT, the name is valid.
            lappend result $name
        } 

        return $result
    }
}


