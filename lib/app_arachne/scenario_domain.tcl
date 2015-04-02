#-----------------------------------------------------------------------
# TITLE:
#   scenario_domain.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# PACKAGE:
#   app_arachne(n): Arachne Implementation Package
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   scenario_domain: The smartdomain(n) for scenario data.
#
#-----------------------------------------------------------------------

oo::class create scenario_domain {
    superclass ::projectlib::smartdomain

    #-------------------------------------------------------------------
    # Constructor

    constructor {} {
        next /scenario

        # FIRST, define helpers
        htools ht \
            -cssfile   "/athena.css"         \
            -headercmd [mymethod htmlHeader] \
            -footercmd [mymethod htmlFooter]

        # NEXT, define content
        my url /index.html [mymethod index.html] {List of open scenarios}
        my url /index.json [mymethod index.json] {List of open scenarios}

    }            

    #-------------------------------------------------------------------
    # Header and Footer

    method htmlHeader {title} {
        # TBD
    }

    method htmlFooter {} {
        # TBD
    }

    

    #-------------------------------------------------------------------
    # General Content

    method index.html {datavar qdict} {
        ht page "Scenarios"
        ht title "Scenarios"

        ht putln "The following scenarios are loaded:"
        ht para

        ht table {"ID" "State" "Tick" "Week"} {
            foreach case [app case names] {
                ht tr {
                    ht td left { 
                        ht putln <b>
                        ht link /scenario/$case $case
                        ht put </b>
                    }
                    ht td left { ht putln [app sdb $case state]          }
                    ht td left { ht putln [app sdb $case clock now]      }
                    ht td left { ht putln [app sdb $case clock asString] }
                }
            }
        }

        ht para
        ht putln (
        ht link /scenario/index.json json
        ht put )

        return [ht /page]
    }

    method index.json {datavar qdict} {
        set hud [huddle list]

        foreach case [app case names] {
            dict set dict id $case
            dict set dict url   "/scenario/$case/index.json"
            dict set dict state [app sdb $case state]
            dict set dict tick  [app sdb $case clock now]
            dict set dict week  [app sdb $case clock asString]

            huddle append hud [huddle create {*}$dict]
        }

        return [huddle jsondump $hud]
    }
    
}

