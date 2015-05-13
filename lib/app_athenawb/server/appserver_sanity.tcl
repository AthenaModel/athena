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
            
            lassign [adb sanity onlock] severity flist

            switch -- $severity {
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
                        be ultimately be fixed.
                    }

                    FormatFailureList $flist
                }
                ERROR {
                    ht putln "<b>The scenario cannot be locked.</b>"
                    ht putln {
                        Entries marked "Error" in the following list must
                        be fixed before the scenario can be locked.  Entries
                        marked "Warning" will not affect the run, but 
                        should be resolved in the long run. 
                    }

                    FormatFailureList $flist
                }
                default { error "Unknown severity: \"$severity\""}
            }

            ht para
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
        ht page "Sanity Check: On-Tick"
        ht title "On-Tick" "Sanity Check"

        ht putln {
            Athena checks the scenario's sanity before
            advancing time at each time tick.
        }

        ht para

        if {[adb state] eq "PREP"} {
            ht putln {
                This check cannot be performed until after the scenario
                is locked.
            }

            ht para
            return [ht /page]
        }


        lassign [adb sanity ontick] severity flist

        switch -- $severity {
            OK {
                ht putln {
                    No problems were found; the scenario may be
                    locked and time may continue to advance.
                }
                ht para
            }
            ERROR {
                ht putln "<b>Time cannot be advanced.</b>"
                ht putln {
                    The following problems prevent time from
                    advancing.
                }
                ht para

                FormatFailureList $flist
            }
            default { error "Unknown severity: \"$severity\""}
        }


        return [ht /page]
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

            lassign [adb iom check] severity flist

            switch -- $severity {
                OK {
                    ht putln "No problems were found."
                    ht para
                }
                WARNING {
                    ht putln {
                        <b>One or more IOMs failed their sanity checks
                        and have been marked invalid.  Please fix or 
                        delete them.<p>

                        The specific problems are as follows:<p>
                    }

                    FormatFailureList $flist
                }
                default { error "Unknown severity: \"$severity\""}
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

            lassign [adb curse chec] severity flist

            switch -- $severity {
                OK {
                    ht putln "No problems were found."
                    ht para
                }
                WARNING {
                    ht putln {
                        <b>One or more CURSEs failed their sanity checks
                        and have been marked invalid.  Please fix or 
                        delete them.<p>

                        The specific problems are as follows:<p>
                    }

                    FormatFailureList $flist
                }
                default { error "Unknown severity: \"$severity\""}
            }
        }

        return [ht get]
    }

    #-------------------------------------------------------------------
    # Helpers

    # FormatFailureList flist
    #
    # flist  - A list of sanity failure dictionaries.
    #
    # Formats the failure list as a table.

    proc FormatFailureList {flist} {
        ht table {"Severity" "Code" "Entity" "Message"} {
            foreach dict $flist {
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



