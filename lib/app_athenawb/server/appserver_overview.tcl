#-----------------------------------------------------------------------
# TITLE:
#    appserver_overview.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Overview Pages
#
#    my://app/overview/...
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module OVERVIEW {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /overview {overview/?}    \
            tcl/linkdict [myproc /overview:linkdict] \
            text/html    [myproc /overview:html]     \
            "Overview"

        appserver register /overview/deployment {overview/deployment/?} \
            text/html [myproc /overview/deployment:html] {
                Deployment of force and organization group personnel
                to neighborhoods.
            }

    }

    #-------------------------------------------------------------------
    # /overview:     Overview of simulation data
    #
    # No match parameters

    # /overview:linkdict udict matchArray
    #
    # Returns a tcl/linkdict of overview pages

    proc /overview:linkdict {udict matchArray} {
        return {
            /sigevents?start=RUN { 
                label "Sig. Events: Recent" 
                listIcon ::projectgui::icon::eye12
            }
            /sigevents { 
                label "Sig. Events: All" 
                listIcon ::projectgui::icon::eye12
            }
            /overview/deployment { 
                label "Personnel Deployment" 
                listIcon ::projectgui::icon::eye12
            }
            /nbhoods/prox { 
                label "Neighborhood Proximities" 
                listIcon ::projectgui::icon::eye12
            }
        }
    }

    # /overview:html udict matchArray
    #
    # Formats and displays the overview.ehtml page.

    proc /overview:html {udict matchArray} {
        if {[catch {
            set text [readfile [file join $::app_athenawb::library overview.ehtml]]
        } result]} {
            return -code error -errorcode NOTFOUND \
                "The Overview page could not be loaded from disk: $result"
        }

        return [tsubst $text]
    }



    #-------------------------------------------------------------------
    # /overview/deployment:  FRC/ORG group deployments
    #
    # No Match Parameters

    # /overview/deployment:html udict matchArray
    #
    # Returns a text/html of FRC/ORG group deployment.

    proc /overview/deployment:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Begin the page
        ht page "Personnel Deployment"
        ht title "Personnel Deployment"

        if {![locked -disclaimer]} {
            ht /page
            return [ht get]
        }

        ht putln {
            Force and organization group personnel
            are deployed to neighborhoods as follows:
        }
        ht para

        if {![locked -disclaimer]} {
            ht /page
            return [ht get]
        }

        ht query {
            SELECT G.longlink     AS "Group",
                   G.gtype        AS "Type",
                   N.longlink     AS "Neighborhood",
                   D.personnel    AS "Personnel"
            FROM deploy_ng AS D
            JOIN gui_agroups AS G USING (g)
            JOIN gui_nbhoods AS N ON (D.n = N.n)
            WHERE D.personnel > 0
            ORDER BY G.longlink, N.longlink
        } -default "No personnel are deployed." -align LLLR

        ht /page
        
        return [ht get]
    }
}



