#-----------------------------------------------------------------------
# TITLE:
#    agent.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Agent Manager
#
#    This module is responsible for managing agents and operations
#    upon them.  An agent is an entity that can own and execute a
#    strategy, i.e., can have goals, tactics, and conditions.
#
#-----------------------------------------------------------------------

snit::type agent {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.


    # names
    #
    # Returns the list of agent names

    typemethod names {} {
        set names [rdb eval {
            SELECT agent_id FROM agents
        }]
    }


    # validate agent_id
    #
    # agent_id - Possibly, an agent short name.
    #
    # Validates an agent ID

    typemethod validate {agent_id} {
        set names [$type names]

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

    typemethod {system names} {} {
        set names [rdb eval {
            SELECT agent_id FROM agents WHERE agent_type = 'system'
        }]
    }


    # system validate agent_id
    #
    # agent_id - Possibly, a system agent short name.
    #
    # Validates a system agent ID

    typemethod {system validate} {agent_id} {
        set names [$type system names]

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

    typemethod type {agent_id} {
        rdb eval {SELECT agent_type FROM agents WHERE agent_id=$agent_id}
    }

    # stats agent_id
    #
    # Returns a dictionary of agent strategy statistics: the number
    # of blocks, conditions, and tactics in the agent's strategy.

    typemethod stats {agent_id} {
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

    typemethod tactictypes {agent_id} {
        # FIRST, get the tactic types that are valid for the agent type.
        set result [list]
        set atype [agent type $agent_id]

        foreach name [tactic typenames $atype] {
            # FIRST, skip special cases.
            if {$name  eq "MAINTAIN"                && 
                $atype eq "actor"                   &&
                [actor get $agent_id auto_maintain]
            } {
                continue
            }

            # NEXT, the name is valid.
            lappend result $name
        } 

        return $result
    }
}


