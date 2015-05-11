#-----------------------------------------------------------------------
# TITLE:
#    sanity.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Simulation Sanity Checks
#
#    This module defines the "onlock" sanity check, which determines
#    whether the scenario can be locked, and the "ontick" sanity 
#    check, which determines whether simulation execution can proceed.
#
#    Some checks are done by other modules, called from here.
#
#-----------------------------------------------------------------------

snit::type ::athena::sanity {
    #-------------------------------------------------------------------
    # Lookup Tables

    # failureKeys: dictlist record spec
    #
    # severity - error|warning
    # code     - A code identifying the specific check
    # entity   - An entity reference, e.g., "nbhood" or "group/BLUE"
    # message  - A human-readable error message.

    typevariable failureKeys {
        severity
        code 
        entity 
        message
    }

    #-------------------------------------------------------------------
    # Type Methods

    # flist
    #
    # Returns a dictlist(n) object in which to accumulate failures.
    
    typemethod flist {} {
        return [::projectlib::dictlist new $failureKeys]
    }

    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Instance variables

    # Transient data used while sanity check
    variable trans -array {
        failures {}
    }
    

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        set adb $adb_
    }

    #-------------------------------------------------------------------
    # On-lock Sanity check

    # onlock ?-warnings?
    #
    # Does a sanity check of the model and returns a list of failure
    # records.  If no problems are found, the returned list is empty.
    # Failures can have severity=warning or error.  By default, only
    # errors are returned; if -warnings is given, then warnings are 
    # included as well.

    method onlock {{opt ""}} {
        try {
            set f [sanity flist]

            $self OnLockChecker $f

            # $adb iom checker $f 
            # $adb curse checker $f
            $adb strategy checker $f 
            $adb econ checker $f

            if {$opt eq "-warnings"} {
                return [$f dicts]
            } else {
                return [$f find severity error]
            }
        } finally {
            $f destroy
        }
    }

    # FilterFailures f opt
    #
    # f     - a dictlist of failures
    # opt

    # OnLockChecker f
    #
    # f   - A dictlist for accumulating failure records.
    #
    # Does the sanity check, and returns a list of failure records.
    # (If the scenario is sane, the list will be empty.)

    method OnLockChecker {f} {
        # At least one neighborhood
        if {[llength [$adb nbhood names]] == 0} {
            $f add error nbhood.none nbhood "No neighborhoods are defined."
        }

        # Neighborhoods are properly stacked
        $adb eval {
            SELECT n, obscured_by FROM nbhoods
            WHERE obscured_by != ''
        } {
            $f add error nbhood.obscured nbhood/$n \
    "Neighborhood's reference point is obscured by another neighborhood."
        }

        # At least one force group
        if {[llength [$adb frcgroup names]] == 0} {
            $f add error frcgroup.none group "No force groups are defined."
        }

        # Each force group has an owning actor
        $adb eval {SELECT g FROM frcgroups_view WHERE a IS NULL} {
            $f add error frcgroup.notowned group/$g \
                "Force group has no owning actor."
        }

        # Each ORG group has an owning actor
        $adb eval {SELECT g FROM orggroups_view WHERE a IS NULL} {
            $f add error orggroup.notowned group/$g \
                "Organization group has no owning actor."
        }

        # Each CAP has an owning actor
        $adb eval {SELECT k FROM caps WHERE owner IS NULL} {
            $f add error cap.notowned cap/$k \
                "Communications Asset Package (CAP) has no owning actor."            
        }

        # At least one civ group
        if {[llength [$adb civgroup names]] == 0} {
            $f add error civgroup.none group "No civilian groups are defined."
        }

        # Population exceeds 0
        set basepop [$adb eval {
            SELECT total(basepop) FROM civgroups
        }]

        if {$basepop == 0} {
            $f add error civgroup.pop group \
                "No civilian group has a base population greater than 0."
        }

        # NEXT, collect data on groups and neighborhoods
        $adb eval {
            SELECT g,n FROM civgroups
        } {
            lappend gInN($n)  $g
        }

        # Every neighborhood must have at least one group.
        # TBD: Is this really required?  Can we insist, instead,
        # that at least one neighborhood must have a group?
        foreach n [$adb nbhood names] {
            if {![info exists gInN($n)]} {
                $f add error nbhood.empty nbhood/$n \
                    "Neighborhood has no civilian groups."
            }
        }


        # At least 1 local consumer; and hence, there
        # must be at least one local civ group with sa_flag=0.

        if {![$adb exists {
            SELECT sa_flag 
            FROM civgroups JOIN nbhoods USING (n)
            WHERE local AND NOT sa_flag
        }]} {
            $f add error econ.noconsumers group \
                [normalize {
                    No consumers in local economy.  At least one civilian
                    group must be in a "local" neighborhood, must have
                    base population greater than 0, and must not live by
                    subsistence agriculture.}] 
        }

        # All GOODS production infrastructure in local neighborhoods

        set localn [$adb nbhood local names]

        $adb eval {
            SELECT DISTINCT n FROM plants_shares
        } {
            if {$n ni $localn} {
                $f add error plants.nonlocal nbhood/$n \
           "GOODS Infrastructure (plants) present in non-local nbhood."
            }
        }

        return
    }



    # onlock_report ht
    # 
    # ht   - An htools buffer.
    #
    # OBSOLETE!
    # Computes the sanity check, and formats the results into the 
    # ht buffer for inclusion in an HTML page.  This command can
    # presume that the buffer is already initialized and ready to
    # receive the data.

    method onlock_report {ht} {
        # FIRST, do a check and find out what kind of problems we have.
        set severity [$self onlock check]

        # NEXT, put an appropriate message at the top of the page.  
        # If we are OK, there's no need to add anything else.

        if {$severity eq "OK"} {
            $ht putln "No problems were found."
            return
        } elseif {$severity eq "WARNING"} {
            $ht putln {
                <b>The on-lock sanity check has failed with one or more
                warnings</b>, as listed below.  Athena has marked the problem
                objects (e.g., tactics, IOM payloads, etc.) invalid;
                the scenario can be locked, but in a degraded state.
            }

            $ht para
        } else {
            $ht putln {
                <b>The on-lock sanity check has failed with one or more
                serious errors,</b> as listed below.  Therefore, the 
                scenario cannot be locked.  Fix the errors, and try again.
            }

            $ht para
        }

        # NEXT, redo the checks, recording all of the problems.
        $self DoOnLockCheck $ht
    }


    #-------------------------------------------------------------------
    # On-Tick Sanity Check

    # ontick check
    #
    # Does a sanity check of the model: can we advance time at this tick?
    # 
    # Returns an esanity value:
    #
    # OK      - Model is sane; go ahead and advance time.
    # WARNING - Problems were found and disabled; time can be advanced.
    # ERROR   - Serious problems were found; time cannot be advanced.

    method {ontick check} {} {
        set ht [htools %AUTO%]

        set flag [$self DoOnTickCheck $ht]

        $ht destroy

        return $flag
    }


    # ontick report ht
    # 
    # ht   - An htools buffer.
    #
    # Computes the sanity check, and formats the results into the 
    # ht buffer for inclusion in an HTML page.  This command can
    # presume that the buffer is already initialized and ready to
    # receive the data.

    method {ontick report} {ht} {
        # FIRST, do a check and find out what kind of problems we have.
        set severity [$self ontick check]

        # NEXT, put an appropriate message at the top of the page.  
        # If we are OK, there's no need to add anything else.

        if {$severity eq "OK"} {
            $ht putln "No problems were found."
            return
        } elseif {$severity eq "WARNING"} {
            $ht putln {
                <b>The on-tick sanity check has failed with one or more
                warnings</b>, as listed below.  Athena has marked the problem
                objects (e.g., tactics, IOM payloads, etc.) invalid;
                time can be advanced, but in a degraded state.
            }

            $ht para
        } else {
            $ht putln {
                <b>The on-tick sanity check has failed with one or more
                serious errors,</b> as listed below.  Therefore, 
                time cannot be advanced.
            }

            $ht para
        }

        # NEXT, redo the checks, recording all of the problems.
        
        $self DoOnTickCheck $ht
    }

    # ontick text
    #
    # Returns the ontick report text.

    method {ontick text} {} {
        set ht [htools %AUTO%]
        $self ontick report $ht
        set text [$ht get]
        $ht destroy

        return $text
    }

    # DoOnTickCheck ht
    #
    # ht   - An htools buffer
    #
    # Does the on-tick sanity check, and returns an esanity value
    # indicating the status.  Any warnings or errors are written into
    # the buffer.

    method DoOnTickCheck {ht} {
        # FIRST, presume that the model is sane.
        set sev OK

        # NEXT, call each of the on-lock checkers
        savemax sev [$self EconOnTickChecker $ht] 

        # NEXT, return the severity
        return $sev
    }

    # EconOnTickChecker ht
    #
    # ht   - An htools buffer
    #
    # Does the sanity check, and returns an esanity value, writing
    # the report into the buffer.  This routine detects only ERRORs.
    #
    # TBD: This routine should probably live in econ.tcl.

    method EconOnTickChecker {ht} {
        # FIRST, if the econ model is disabled, there are no errors to
        # find.
        if {[$adb econ state] eq "DISABLED"} {
            return OK
        }

        # NEXT, presume that the model is sane.
        set sev OK

        # NEXT, push a buffer onto the stack, for the problems.
        $ht push

        # NEXT, Some help for the reader
        $ht subtitle "Economic On-Tick Constraints</b>" 
        $ht putln {
            One or more of Athena's economic on-tick sanity checks has 
            failed; the entries below give complete details.  These checks
            involve the economic model; hence, disabling the 
            the Econ model on the <a href="gui:/tab/econ/control">Control</a>
            tab will allow the simulation to proceed at the cost of ignoring
            the economy.
        }
        
        $ht para

        $ht dl

        # NEXT, Check econ CGE convergence.
        if {![$adb econ ok]} {
            set sev ERROR

            $ht dlitem "<b>Error: Economy: Diverged</b>" {
                The economic model uses a system of equations called
                a CGE.  The system of equations could not be solved.
                This might be an error in the CGE; alternatively, the
                economy might really be in chaos.
            }
        }

        # NEXT, check a variety of econ result constraints.
        array set cells [$adb econ get]
        array set start [$adb econ getstart]

        if {$cells(Out::SUM.QS) == 0.0} {
            set sev ERROR

            $ht dlitem "<b>Error: Economy: Zero Production</b>" {
                The economy has converged to the zero point, i.e., there
                is no consumption or production, and hence no economy.
                Enter 
                <tt><a href="/help/command/dump/econ.html">dump econ In</a></tt>
                at the CLI to see the current 
                inputs to the economy; it's likely that there are no
                consumers.
            }
        }

        if {!$cells(Out::FLAG.QS.NONNEG)} {
            set sev ERROR

            $ht dlitem "<b>Error: Economy: Negative Quantity Supplied</b>" {
                One of the QS.i cells has a negative value; this implies
                an error in the CGE.  Enter 
                <tt><a href="/help/command/dump/econ.html">dump econ</a></tt>
                at the CLI to
                see the full list of CGE outputs.  Consider disabling
                the economic model on the
                <a href="my:/gui/tab/econ/control.html">Econ/Control tab</a> 
                since it is clearly malfunctioning.
            }
        }

        if {!$cells(Out::FLAG.P.POS)} {
            set sev ERROR

            $ht dlitem "<b>Error: Economy: Non-Positive Prices</b>" {
                One of the P.i price cells is negative or zero; this implies
                an error in the CGE.  Enter 
                <tt><a href="/help/command/dump/econ.html">dump econ</a></tt>
                at the CLI to
                see the full list of CGE outputs.  Consider disabling
                the economic model on the
                <a href="my:/gui/tab/econ/control.html">Econ/Control tab</a> 
                since it is clearly malfunctioning.
            }
        }

        set limit [$adb parm get econ.check.MinConsumerFrac]

        if {
            $cells(In::Consumers) < $limit * $start(In::Consumers)
        } {
            set sev ERROR

            $ht dlitem "<b>Error: Number of consumers has declined alarmingly</b>" "
                The current number of consumers in the local economy,
                $cells(In::Consumers),
                is less than 
                $limit
                of the starting number.  To change the limit, set the
                value of the 
                <a href=\"/help/parmdb/econ/check/minconsumerfrac.html\">econ.check.MinConsumerFrac</a>
                model parameter.
            "
        }

        set limit [$adb parm get econ.check.MinLaborFrac]

        if {
            $cells(In::LF) < $limit * $start(In::LF)
        } {
            set sev ERROR

            $ht dlitem "<b>Error: Number of workers has declined
            alarmingly</b>" "
                The current number of workers in the local labor force,
                $cells(In::LF), 
                is less than
                $limit
                of the starting number.  To change the limit, set the 
                value of the 
                <a href=\"/help/parmdb/econ/check/minlaborfrac.html\">econ.check.MinLaborFrac</a>
                model parameter.
            "
        }

        set limit [$adb parm get econ.check.MaxUR]

        if {$cells(Out::UR) > $limit} {
            set sev ERROR

            $ht dlitem "<b>Error: Unemployment skyrockets</b>" "
                The unemployment rate, 
                [format {%.1f%%,} $cells(Out::UR)]
                exceeds the limit of 
                [format {%.1f%%.} $limit]
                To change the limit, set the value of the 
                <a href=\"/help/parmdb/econ/check/maxur.html\">econ.check.MaxUR</a>
                model parameter.
            "
        }

        set limit [$adb parm get econ.check.MinDgdpFrac]

        if {
            $cells(Out::DGDP) < $limit * $start(Out::DGDP)
        } {
            set sev ERROR

            $ht dlitem "<b>Error: DGDP Plummets</b>" "
                The Deflated Gross Domestic Product (DGDP),
                \$[moneyfmt $cells(Out::DGDP)],
                is less than 
                $limit
                of its starting value.  To change the limit, set the
                value of the 
                <a href=\"/help/parmdb/econ/check/mindgdpfrac.html\">econ.check.MinDgdpFrac</a>
                model parameter.
            "
        }

        set min [$adb parm get econ.check.MinCPI]
        set max [$adb parm get econ.check.MaxCPI]

        if {$cells(Out::CPI) < $min || 
            $cells(Out::CPI) > $max
        } {
            set sev ERROR

            $ht dlitem "<b>Error: CPI beyond limits</b>" "
                The Consumer Price Index (CPI), 
                [format {%4.2f,} $cells(Out::CPI)]
                is outside the expected range of
                [format {(%4.2f, %4.2f).} $min $max]
                To change the bounds, set the values of the 
                <a href=\"/help/parmdb/econ/check/mincpi.html\">econ.check.MinCPI</a>
                and 
                <a href=\"/help/parmdb/econ/check/maxcpi.html\">econ.check.MaxCPI</a>
                model parameters.
            "
        }

        $ht /dl

        # NEXT, we only have content if there were errors.
        set html [$ht pop]

        if {$sev ne "OK"} {
            $ht put $html
        }
        

        # NEXT, return the result
        return $sev
    }

    #-------------------------------------------------------------------
    # Helper Routines

    # savemax varname errsym
    #
    # varname   - A variable containing an esanity value
    # errsym    - An esanity value
    #
    # Sets the variable to the more severe of the two esanity values.

    proc savemax {varname errsym} {
        upvar 1 $varname maxsym

        if {[esanity gt $errsym $maxsym]} {
            set maxsym $errsym
        }
    }

}



