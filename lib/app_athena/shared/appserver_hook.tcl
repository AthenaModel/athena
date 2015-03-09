#-----------------------------------------------------------------------
# TITLE:
#    appserver_hook.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Semantic Hooks
#
#    my://app/hooks
#    my://app/hook/{hook_id}
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module HOOK {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /hooks/ {hooks/?} \
            tcl/linkdict [myproc /hooks:linkdict] \
            text/html    [myproc /hooks:html] {
                Links to all of the currently defined semantic hookss. 
                HTML content includes semantic hook attributes.
            }

        appserver register /hook/{hook_id} {hook/(\w+)/?} \
            text/html [myproc /hook:html]         \
            "Detail page for semantic hook {hook_id}."

    }

    #-------------------------------------------------------------------
    # /hooks: All defined semantic hooks
    #
    # No match parameters

    # /hooks:linkdict udict matchArray
    #
    # tcl/linkdict of all semantic hooks.
    
    proc /hooks:linkdict {udict matchArray} {
        return [objects:linkdict {
            label    "Semantic Hooks"
            listIcon ::projectgui::icon::hook12
            table    gui_hooks
        }]
    }

    # /hooks:html udict matchArray
    #
    # Tabular display of CAP data.

    proc /hooks:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Begin the page
        ht page "Semantic Hooks"
        ht title "Semantic Hooks"

        ht put "The scenario currently includes the following "
        ht put "Semantic Hooks:"
        ht para

        ht query {
            SELECT link          AS "Name",
                   narrative     AS "Narrative"
            FROM gui_hooks
        } -default "None." -align LL

        ht /page

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /hook/{hook_id}: A single semantic hook {hook_id}
    #
    # Match Parameters:
    #
    # {hook_id} => $(1)    - The Semantic Hook's ID

    # /hook:html udict matchArray
    #
    # Detail page for a single semantic hook {hook_id}

    proc /hook:html {udict matchArray} {
        upvar 1 $matchArray ""
       
        # FIRST, get the hook ID and data.
        set hook_id [string toupper $(1)]

        adb eval {SELECT * FROM gui_hooks WHERE hook_id=$hook_id} data {}

        # NEXT, Begin the page
        ht page "Semantic Hook: $hook_id"
        ht title $data(fancy) "Semantic Hook" 

        ht linkbar {
            "#topics"    "Semantic Hook Topics"
            "#ioms"      "IOMs"
            "#sigevents" "Significant Events"
        }
 
        ht subtitle "Semantic Hook Topics" topics

        ht putln {
            Semantic hooks must take one or more positions on belief 
            system topics in order to have an effect on the groups 
            receiving an Information Operations Message (IOM).
        }
        ht para

        ht putln {
            <b>Note:</b> Disabled or invalid semantic hook topics will 
            not be used in Information Operations Messages.
        }

        ht para

        ht putln {
            The following topics and positions are defined for 
            this semantic hook:
        }

        ht para

        ht push

        ht table {"Topic" "Position" "Symbolic Value" "State"} {
            adb eval {
                SELECT fancy      AS fancy,
                       position   AS position,
                       state      AS state
                FROM gui_hook_topics WHERE hook_id=$hook_id
            } {
                ht tr {
                    ht td left {
                        ht put "<span class=$state>$fancy</span>"
                    }

                    ht td right {
                        ht put $position
                    }

                    ht td left {
                        ht put [qposition longname $position]
                    }

                    ht td left {
                        ht put $state
                    }
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

        ht subtitle "IOMs" ioms

        ht putln "
            The following Information Operations Messages (IOMs) currently
            use this semantic hook:
        "

        ht para

        ht query {
            SELECT longlink AS "IOM",
                   longname AS "Narrative"
            FROM gui_ioms
            WHERE hook_id=$hook_id
        } -default "None." -align LL 

        ht para

        ht subtitle "Significant Events" sigevents

        if {[locked -disclaimer]} {
            appserver::SIGEVENTS recent $hook_id
        }

        ht /page

        return [ht get]
    }
}



