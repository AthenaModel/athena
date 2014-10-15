#-----------------------------------------------------------------------
# TITLE:
#    appserver_iom.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: IOMs
#
#    my://app/ioms
#    my://app/iom/{iom_id}
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module IOM {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /ioms/ {ioms/?} \
            tcl/linkdict [myproc /ioms:linkdict] \
            text/html    [myproc /ioms:html] {
                Links to all of the currently defined IOMs. HTML
                content includes IOM attributes.
            }

        appserver register /iom/{iom_id} {iom/(\w+)/?} \
            text/html [myproc /iom:html]         \
            "Detail page for IOM {iom_id}."

    }

    #-------------------------------------------------------------------
    # /ioms: All defined IOMs
    #
    # No match parameters

    # /ioms:linkdict udict matchArray
    #
    # tcl/linkdict of all IOMs.
    
    proc /ioms:linkdict {udict matchArray} {
        return [objects:linkdict {
            label    "IOMs"
            listIcon ::projectgui::icon::message12
            table    gui_ioms
        }]
    }

    # /ioms:html udict matchArray
    #
    # Tabular display of CAP data.

    proc /ioms:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Begin the page
        ht page "IOMs"
        ht title "Information Operations Messages (IOMs)"

        ht put "The scenario currently includes the following "
        ht put "Information Operations Messages (IOMs):"
        ht para

        ht query {
            SELECT link          AS "Name",
                   longname      AS "Description",
                   hlink         AS "Semantic Hook"
            FROM gui_ioms
        } -default "None." -align LLL

        ht /page

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /iom/{iom_id}: A single iom {iom_id}
    #
    # Match Parameters:
    #
    # {iom_id} => $(1)    - The IOM's ID

    # /iom:html udict matchArray
    #
    # Detail page for a single IOM {iom_id}

    proc /iom:html {udict matchArray} {
        upvar 1 $matchArray ""
       
        # FIRST, get the IOM ID and data.
        set iom_id [string toupper $(1)]

        rdb eval {SELECT * FROM gui_ioms WHERE iom_id=$iom_id} data {}

        # NEXT, Begin the page
        ht page "IOM: $iom_id"
        ht title $data(fancy) "IOM" 

        ht linkbar {
            "#payloads"  "IOM Payloads"
            "#hook"      "Semantic Hook"
            "#sigevents" "Significant Events"
        }
 
        ht subtitle "IOM Payloads" payloads

        ht put "Payloads specify what effect the message should have on "
        ht put "the recipients of the message.  Changes in cooperation, "
        ht put "satisfaction or a change in relationship with a group or "
        ht put "an actor are the types of effects that appear in payloads. "
        ht put "The following table shows the payloads currently specified "
        ht put "for the IOM called $iom_id."

        ht query {
            SELECT payload_num   AS "Number", 
                   payload_type  AS "Type",
                   narrative     AS "Narrative"
            FROM gui_payloads 
            WHERE iom_id=$iom_id
        } -default "None." -align LLL

        ht para

        ht subtitle "Semantic Hook" hook

        rdb eval {
            SELECT longlink FROM gui_hooks WHERE hook_id=$data(hook_id)
        } hdata {}

        ht put "Along with its payloads, a semantic hook is part of an IOM.  "
        ht put "A semantic hook takes a position on one or more belief "
        ht put "system topics in an effort to appeal to the groups that "
        ht put "are meant to receive the IOM.  Semantic hook topics that "
        ht put "are disabled or invalid will not be used in the message.  "
        ht put "This IOM uses the $hdata(longlink) semantic hook which "
        ht put "contains these topics:"
        ht para

        ht push

        # NEXT, may need to customize the table for disabled or invalid
        # hook topics, so build it from scratch
        ht table {"Topic" "Position" "Symbolic Value" "State"} {
            rdb eval {
                SELECT fancy      AS fancy,
                       position   AS position,
                       state      AS state
                FROM gui_hook_topics WHERE hook_id=$data(hook_id)
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

        ht subtitle "Significant Events" sigevents

        if {[locked -disclaimer]} {
            appserver::SIGEVENTS recent $iom_id
        }

        ht /page

        return [ht get]
    }
}



