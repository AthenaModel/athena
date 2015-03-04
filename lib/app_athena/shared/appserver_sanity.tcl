#-----------------------------------------------------------------------
# TITLE:
#    appserver_sanity.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Sanity Check Reports
#
#    my://app/sanity/...
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module SANITY {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /sanity/onlock {sanity/onlock/?} \
            text/html [myproc /sanity/onlock:html]          \
            "Scenario On-Lock sanity check report."

        appserver register /sanity/ontick {sanity/ontick/?} \
            text/html [myproc /sanity/ontick:html]          \
            "Simulation On-Tick sanity check report."

        appserver register /sanity/hook {sanity/hook/?} \
            text/html [myproc /sanity/hook:html]        \
            "Sanity check report for Semantic Hooks."

        appserver register /sanity/iom {sanity/iom/?} \
            text/html [myproc /sanity/iom:html]       \
            "Sanity check report for IOMs and their payloads."

        appserver register /sanity/strategy {sanity/strategy/?} \
            text/html [myproc /sanity/strategy:html]            \
            "Sanity check report for actor strategies."

        appserver register /sanity/curse {sanity/curse/?} \
            text/html [myproc /sanity/curse:html]            \
            "Sanity check report for CURSEs and their injects."
    }

    #-------------------------------------------------------------------
    # /sanity/onlock:       On-Lock sanity check report.
    #
    # No match parameters

    # /sanity/onlock:html udict matchArray
    #
    # Formats the on-lock sanity check report for
    # /sanity/onlock.  Note that sanity is checked by the
    # "sanity onlock report" command; this command simply reports on the
    # results.

    proc /sanity/onlock:html {udict matchArray} {
        ht page "Sanity Check: On-Lock" {
            ht title "On-Lock" "Sanity Check"

            ht putln {
                Athena checks the scenario's sanity before
                allowing the user to lock the scenario and begin
                simulation.
            }

            ht para
            
            adb sanity onlock report ::appserver::ht
        }

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /sanity/ontick:   On Tick sanity check report
    #
    # No match parameters

    # /sanity/ontick:html udict matchArray
    #
    # Formats the on-tick sanity check report for
    # /sanity/ontick.  Note that sanity is checked by the
    # "sanity ontick report" command; this command simply reports on the
    # results.

    proc /sanity/ontick:html {udict matchArray} {
        ht page "Sanity Check: On-Tick" {
            ht title "On-Tick" "Sanity Check"

            ht putln {
                Athena checks the scenario's sanity before
                advancing time at each time tick.
            }

            ht para

            if {[sim state] ne "PREP"} {
                adb sanity ontick report ::appserver::ht
            } else {
                ht putln {
                    This check cannot be performed until after the scenario
                    is locked.
                }

                ht para
            }
        }

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /sanity/hook:   Hook sanity checks
    #
    # No match parameters

    # /sanity/hook:html udict matchArray
    #
    # Formats the semantic hook sanity check report for
    # /sanity/hook.  Note that sanity is checked by the 
    # "hook sanity report" command; this command simply reports on the
    # results.

    proc /sanity/hook:html {udict matchArray} {
        ht page "Sanity Check: Semantic Hook Topics" {
            ht title "Semantic Hooks" "Sanity Check"

            if {[adb hook checker ::appserver::ht] eq "OK"} {
                ht putln "No problems were found."
                ht para
            }
        }

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /sanity/iom: IOM sanity check reports
    #
    # No match parameters

    # /sanity/iom:html udict matchArray
    #
    # Formats the iom sanity check report for
    # /sanity/iom.  Note that sanity is checked by the
    # "iom sanity report" command; this command simply reports on the
    # results.

    proc /sanity/iom:html {udict matchArray} {
        ht page "Sanity Check: IOMs" {
            ht title "IOMs" "Sanity Check"
            
            if {[adb iom checker ::appserver::ht] eq "OK"} {
                ht putln "No problems were found."
                ht para
            }
        }

        return [ht get]
    }


    #-------------------------------------------------------------------
    # /sanity/strategy:  Strategy Sanity Check reports
    #
    # No match parameters

    # /sanity/strategy:html udict matchArray
    #
    # Formats the strategy sanity check report for
    # /sanity/strategy.  Note that sanity is checked by the
    # "strategy sanity report" command; this command simply reports on the
    # results.

    proc /sanity/strategy:html {udict matchArray} {
        ht page "Sanity Check: Actors' Strategies" {
            ht title "Actors' Strategies" "Sanity Check"
            
            if {[adb strategy checker ::appserver::ht] eq "OK"} {
                ht putln "No problems were found."
                ht para
            }
        }

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /sanity/curse: CURSE sanity check reports
    #
    # No match parameters

    # /sanity/curse:html udict matchArray
    #
    # Formats the curse sanity check report for
    # /sanity/curse.  Note that sanity is checked by the
    # "curse sanity report" command; this command simply reports on the
    # results.

    proc /sanity/curse:html {udict matchArray} {
        ht page "Sanity Check: CURSEs" {
            ht title "CURSEs" "Sanity Check"
            
            if {[adb curse checker ::appserver::ht] eq "OK"} {
                ht putln "No problems were found."
                ht para
            }
        }

        return [ht get]
    }

}



