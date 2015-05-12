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
#    /app/sanity/...
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

        appserver register /sanity/iom {sanity/iom/?} \
            text/html [myproc /sanity/iom:html]       \
            "Sanity check report for IOMs and their payloads."

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
            
            set f   [athena::sanity flist]
            set sev [adb sanity onlock $f]

            switch -- $sev {
                OK {
                    ht putln {
                        No problems were found; the scenario may be
                        locked and time may be advanced.
                    }
                }
                WARNING {
                    ht putln {
                        The scenario may be locked and time may be advanced,
                        but the following problems were found and should
                        be fixed.
                    }

                    FormatFailureList $f
                }
                ERROR {
                    ht putln "<b>The scenario cannot be locked.</b>"
                    ht putln {
                        Entries marked "error" in the following list must
                        be fixed before the scenario can be locked.
                    }

                    FormatFailureList $f
                }
            }

            ht para
        }

        $f destroy

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

            if {[adb state] ne "PREP"} {
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

    #-------------------------------------------------------------------
    # Helpers

    # FormatFailureList f
    #
    # f   - A [sanity flist] object
    #
    # formats the failure list as a table.

    proc FormatFailureList {f} {
        ht table {"Severity" "Code" "Entity" "Message"} {
            foreach dict [$f dicts] {
                dict with dict {}

                ht tr {
                    ht td left { 
                        if {$severity eq "error"} {
                            set cls error
                        } else {
                            set cls ""
                        }

                        ht span $cls {
                            ht put [esanity longname $severity] 
                        }
                    }
                    ht td left { ht put $code                        }
                    ht td left { ht link /app/$entity $entity        }
                    ht td left { ht put $message                     }
                }
            }
        }
    }

}



