#-----------------------------------------------------------------------
# TITLE:
#    appserver_agent.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Agent Strategies
#
#    my://app/agents
#    my://app/agent/{agent}
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module AGENT {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /agents {agents/?}         \
            tcl/linkdict [myproc /agents:linkdict]    \
            tcl/enumlist [asproc enum:enumlist {adb agent}] \
            text/html    [myproc /agents:html] {
                Links to all of the currently 
                defined agents.  HTML content 
                includes agent attributes.
            }

        # TBD: We'll put this back in the /sanity tree eventually
        appserver register /agents/sanity {agents/sanity/?} \
            text/html [myproc /agents/sanity:html]            \
            "Sanity check report for agent strategies."

        appserver register /agent/{agent} {agent/(\w+)/?} \
            text/html [myproc /agent:html]            \
            "Index page for agent {agent}'s strategy."

        appserver register /agent/{agent}/full {agent/(\w+)/full/?} \
            text/html [myproc /agent/full:html]            \
            "Full detail page for agent {agent}'s strategy."
    }



    #-------------------------------------------------------------------
    # /agents: All defined agents
    #
    # No match parameters

    # /agents:linkdict udict matchArray
    #
    # tcl/linkdict of all agents.
    
    proc /agents:linkdict {udict matchArray} {
        return [objects:linkdict {
            label    "Agents"
            listIcon ::projectgui::icon::actor12
            table    gui_agents
        }]
    }

    # /agents:html udict matchArray
    #
    # Tabular display of agent data; content depends on 
    # simulation state.

    proc /agents:html {udict matchArray} {
        upvar 1 $matchArray ""

        # FIRST, Begin the page
        ht page "Agents"
        ht title "Agents"

        ht putln {
            An agent is a simulation entity that has a strategy, and can
            make decisions that affect the course of the simulation.
            Agent types include 
        }

        ht link my://app/actors "Actors"

        ht putln {
            and the SYSTEM agent, which serves as a general purpose
            scheduling mechanism.
        }
        ht para

        ht putln "The scenario currently includes the following agents:"
        ht para

        # NEXT, output the table of data.

        ht table {
            "Agent" "Type" "# Blocks" "# Conditions" "# Tactics"
        } {
            foreach a [adb agent names] {
                array set stats [adb agent stats $a]

                ht tr {
                    ht td left  { ht link my://app/agent/$a $a }
                    ht td left  { ht put [adb agent type $a]       }
                    ht td right { ht put $stats(blocks)        }
                    ht td right { ht put $stats(conditions)    }
                    ht td right { ht put $stats(tactics)       } 
                }
            }
        }

        ht /page

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /agent/{agent}: A single {agent}'s strategy
    #
    # Match Parameters:
    #
    # {agent} => $(1)    - The agent's short name

    # /agent:html udict matchArray
    #
    # Index page for a single agent's strategy

    proc /agent:html {udict matchArray} {
        upvar 1 $matchArray ""

        # FIRST, Accumulate data
        set a [string toupper $(1)]

        if {![adb agent exists $a]} {
            return -code error -errorcode NOTFOUND \
                "Unknown entity: [dict get $udict url]."
        }

        set s [adb strategy getname $a]

        # NEXT, Begin the page
        adb eval {SELECT * FROM gui_agents WHERE agent_id=$a} data {}

        ht page "Agent: $a ($data(agent_type))"
        ht title "Agent: $a ($data(agent_type))" 

        if {$data(agent_type) eq "actor"} {
            ht putln "Agent $a is an actor; click "
            ht link [adb onecolumn {
                SELECT url FROM gui_actors
                WHERE a=$a
            }] here
            ht put " for the actor's data."
            ht para
        }

        ht linkbar [list \
            "my://app/agent/$a/full" "Full Strategy" \
            "gui:/tab/strategy"      "Editor"]

        # NEXT, List the blocks
        BlockList $a index

        # NEXT, complete the page

        ht /page

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /agent/{agent}/full: A single {agent}'s full strategy
    #
    # Match Parameters:
    #
    # {agent} => $(1)    - The agent's short name

    # /agent/full:html udict matchArray
    #
    # Detail page for a single agent's strategy

    proc /agent/full:html {udict matchArray} {
        upvar 1 $matchArray ""

        # FIRST, Accumulate data
        set a [string toupper $(1)]

        if {![adb agent exists $a]} {
            return -code error -errorcode NOTFOUND \
                "Unknown entity: [dict get $udict url]."
        }

        set s [adb strategy getname $a]

        # NEXT, Begin the page
        adb eval {SELECT * FROM gui_agents WHERE agent_id=$a} data {}

        ht page "Agent: $a ($data(agent_type))"
        ht title "Agent: $a ($data(agent_type))" 

        if {$data(agent_type) eq "actor"} {
            ht putln "Agent $a is an actor; click "
            ht link [adb onecolumn {
                SELECT url FROM gui_actors
                WHERE a=$a
            }] here
            ht put " for the actor's data."
            ht para
        }

        ht linkbar [list \
            "my://app/agent/$a"  "Overview" \
            "gui:/tab/strategy"  "Editor"]

        # NEXT, List the blocks in a table
        BlockList $a full

        # NEXT, list the blocks in detail

        set nblocks [llength [$s blocks]]

        if {$nblocks > 0} {
            ht putln "Details follow for each block in the strategy."

            ht para

            foreach block [$s blocks] {
                ht hr
                $block html ::appserver::ht
            }
        }

        # NEXT, complete the page

        ht /page

        return [ht get]
    }

    #-------------------------------------------------------------------
    # Helpers

    # BlockList a mode
    #
    # a     - An agent
    # mode  - index | full
    #
    # Produces a table of strategy blocks for the agent.  If mode is
    # index, the entries link to the individual block pages.
    # If mode is full, the entries link to the blocks in the body of
    # of the page.

    proc BlockList {a mode} {
        set s [adb strategy getname $a]

        if {$mode eq "full"} {
            set root my://app/agent/$a/full#block
        } else {
            set root my://app/bean/
        }

        # FIRST, List the blocks
        ht putln "Agent $a's strategy contains the following blocks:"
        ht para

        ht push

        ht table {
            "ID" "Exec" "State" "Intent" "On-Lock" "Once" "Time Constraints"
            "#C" "#T" "Last"
        } {
            foreach block [$s blocks] {
                array set b [$block view html]
                set numconds [llength [$block conditions]]
                set numtacs  [llength [$block tactics]]


                ht tr {
                    ht td right  { ht link ${root}$b(id) $b(id) }
                    ht td center { ht image $b(statusicon) }
                    ht td left   { ht put $b(state) }
                    ht td left   { 
                        ht put "<span class=$b(state)>"
                        ht link ${root}$b(id) $b(intent)
                        ht put "</span>"
                    }
                    ht td left   { ht put $b(pretty_onlock)  }
                    ht td left   { ht put $b(pretty_once)    }
                    ht td left   { ht put $b(timestring)     }
                    ht td right  { ht put $numconds          }
                    ht td right  { ht put $numtacs           }
                    ht td right  { ht put $b(pretty_exectime)}
                }
            }
        }

        set text [ht pop]

        if {[ht rowcount] > 0} {
            ht putln $text
        } else {
            ht putln "None."
        }

        ht para
    }
    

    #-------------------------------------------------------------------
    # /agents/sanity:  Strategy Sanity Check reports
    #
    # No match parameters

    # /agents/sanity:html udict matchArray
    #
    # Formats the strategy sanity check report for
    # /agents/sanity.  Note that sanity is checked by the
    # "strategy checker" command; this command simply reports on the
    # results.

    proc /agents/sanity:html {udict matchArray} {
        ht page "Sanity Check: Agents' Strategies" {
            ht title "Agents' Strategies" "Sanity Check"
            
            if {[adb strategy checker ::appserver::ht] eq "OK"} {
                ht putln "No problems were found."
                ht para
            }
        }

        return [ht get]
    }
}
