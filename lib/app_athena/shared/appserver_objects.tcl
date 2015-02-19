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
#    my://app/objects/...
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
        /topics {
            label    "Topics of Belief"
            listIcon ::projectgui::icon::topic12
        }

        /bsystems {
            label    "Belief Systems"
            listIcon ::projectgui::icon::bsystem12
        }

        /actors {
            label    "Actors"
            listIcon ::projectgui::icon::actor12
        }

        /agents {
            label    "Agents"
            listIcon ::projectgui::icon::actor12
        }

        /caps   {
            label    "CAPs"
            listIcon ::projectgui::icon::cap12
        }

        /econ   {
            label    "Econ"
            listIcon ::projectgui::icon::dollar12
        }

        /ioms   {
            label    "IOMs"
            listIcon ::projectgui::icon::message12
        }

        /hooks {
            label    "Semantic Hooks"
            listIcon ::projectgui::icon::hook12
        }

        /groups {
            label    "Groups"
            listIcon ::projectgui::icon::group12
        }

        /groups/civ {
            label    "Civ. Groups"
            listIcon ::projectgui::icon::civgroup12
        }

        /groups/frc {
            label    "Force Groups"
            listIcon ::projectgui::icon::frcgroup12
        }

        /groups/org {
            label    "Org. Groups"
            listIcon ::projectgui::icon::orggroup12
        }

        /nbhoods {
            label    "Neighborhoods"
            listIcon ::projectgui::icon::nbhood12
        }

        /plants {
            label   "Infrastructure"
            listIcon ::projectgui::icon::plant12
        }

        /overview {
            label "Overview"
            listIcon ::projectgui::icon::eye12
        }

        /parmdb {
            label "Model Parameters"
            listIcon ::marsgui::icon::pencil12
        }

        /curses {
            label    "CURSEs"
            listIcon ::projectgui::icon::blueheart12
        }

        /drivers {
            label    "Drivers"
            listIcon ::projectgui::icon::blackheart12
        }

        /firings {
            label    "Rule Firings"
            listIcon ::projectgui::icon::orangeheart12
        }

        /contribs {
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
            /overview
            /bsystems
            /topics
            /actors 
            /agents
            /nbhoods 
            /groups/civ 
            /groups/frc 
            /groups/org
            /plants
            /curses
            /drivers
            /firings
            /contribs
            /econ
            /caps
            /hooks
            /ioms
            /parmdb
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



