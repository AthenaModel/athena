#-----------------------------------------------------------------------
# TITLE:
#    appserver_objects.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Object Types
#
#    /app/objects/...
#
#    The purpose of these URLs is to provide the top-level set of links
#    to navigate the tree of simulation objects in Athena (e.g., to 
#    populate the tree widgets in the detail browser).  At the
#    top-level are the object types, and subsets of these types.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module OBJECTS {
    #-------------------------------------------------------------------
    # Type Variables

    # objectInfo: Nested dictionary of object data.
    #
    # key: object collection resource
    #
    # value: Dictionary of data about each object/object type
    #
    #   label     - A human readable label for this kind of object.
    #   listIcon  - A Tk icon to use in lists and trees next to the
    #               label

    typevariable objectInfo {
        /app/topics {
            label    "Topics of Belief"
            listIcon ::projectgui::icon::topic12
        }

        /app/bsystems {
            label    "Belief Systems"
            listIcon ::projectgui::icon::bsystem12
        }

        /app/actors {
            label    "Actors"
            listIcon ::projectgui::icon::actor12
        }

        /app/agents {
            label    "Agents"
            listIcon ::projectgui::icon::actor12
        }

        /app/caps   {
            label    "CAPs"
            listIcon ::projectgui::icon::cap12
        }

        /app/econ   {
            label    "Econ"
            listIcon ::projectgui::icon::dollar12
        }

        /app/ioms   {
            label    "IOMs"
            listIcon ::projectgui::icon::message12
        }

        /app/hooks {
            label    "Semantic Hooks"
            listIcon ::projectgui::icon::hook12
        }

        /app/groups {
            label    "Groups"
            listIcon ::projectgui::icon::group12
        }

        /app/groups/civ {
            label    "Civ. Groups"
            listIcon ::projectgui::icon::civgroup12
        }

        /app/groups/frc {
            label    "Force Groups"
            listIcon ::projectgui::icon::frcgroup12
        }

        /app/groups/org {
            label    "Org. Groups"
            listIcon ::projectgui::icon::orggroup12
        }

        /app/nbhoods {
            label    "Neighborhoods"
            listIcon ::projectgui::icon::nbhood12
        }

        /app/plants {
            label   "Infrastructure"
            listIcon ::projectgui::icon::plant12
        }

        /app/overview {
            label "Overview"
            listIcon ::projectgui::icon::eye12
        }

        /app/parmdb {
            label "Model Parameters"
            listIcon ::marsgui::icon::pencil12
        }

        /app/combats {
            label "Combat"
            listIcon ::projectgui::icon::cannon12
        }

        /app/curses {
            label    "CURSEs"
            listIcon ::projectgui::icon::blueheart12
        }

        /app/drivers {
            label    "Drivers"
            listIcon ::projectgui::icon::blackheart12
        }

        /app/firings {
            label    "Rule Firings"
            listIcon ::projectgui::icon::orangeheart12
        }

        /app/contribs {
            label    "Contributions"
            listIcon ::projectgui::icon::heart12
        }
    }

    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /objects {objects/?}           \
            tcl/linkdict [myproc /objects:linkdict]       \
            text/html    [myproc /objects:html "Objects"] \
            "Links to the main Athena simulation objects."
    }

    #-------------------------------------------------------------------
    # /objects                 - All object types
    #
    # Match Parameters:
    # 
    # None.

    # /objects:linkdict udict matchArray
    #
    # Returns an objects[/*] resource as a tcl/linkdict 
    # where $(1) is the objects subset.

    proc /objects:linkdict {udict matchArray} {
        upvar 1 $matchArray ""

        # FIRST, handle subsets
        set subset {
            /app/overview
            /app/bsystems
            /app/topics
            /app/actors 
            /app/agents
            /app/nbhoods 
            /app/groups/civ 
            /app/groups/frc 
            /app/groups/org
            /app/combats
            /app/plants
            /app/curses
            /app/drivers
            /app/firings
            /app/contribs
            /app/econ
            /app/caps
            /app/hooks
            /app/ioms
            /app/parmdb
        }

        foreach otype $subset {
            dict with objectInfo $otype {
                dict set result $otype label $label
                dict set result $otype listIcon $listIcon
            }
        }

        return $result
    }

    # /objects:html title udict matchArray
    #
    # title      - The page title
    #
    # Returns an object/* resource as a text/html
    # where $(1) is the objects subset.

    proc /objects:html {title udict matchArray} {
        upvar 1 $matchArray ""

        set url [dict get $udict url]

        set types [/objects:linkdict $url ""]

        ht page $title
        ht h1 $title
        ht ul {
            foreach link [dict keys $types] {
                ht li { ht link $link [dict get $types $link label] }
            }
        }
        ht /page

        return [ht get]
    }
}



