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
#    NOTE: The strategy sanity check is performed by strategy.tcl.
#
#-----------------------------------------------------------------------

snit::type ::athena::sanity {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

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

    # onlock check
    #
    # Does a sanity check of the model: can we lock the scenario?
    #
    # Returns an esanity value:
    #
    # OK      - Model is sane; go ahead and lock.
    # WARNING - Problems were found and disabled; scenario can be locked.
    # ERROR   - Problems were found and must be fixed.

    method {onlock check} {} {
        set ht [htools %AUTO%]

        set sev [$self DoOnLockCheck $ht]

        $ht destroy

        return $sev
    }

    # onlock report ht
    # 
    # ht   - An htools buffer.
    #
    # Computes the sanity check, and formats the results into the 
    # ht buffer for inclusion in an HTML page.  This command can
    # presume that the buffer is already initialized and ready to
    # receive the data.

    method {onlock report} {ht} {
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

    # onlock text
    #
    # Returns the onlock report text.

    method {onlock text} {} {
        set ht [htools %AUTO%]
        $self onlock report $ht
        set text [$ht get]
        $ht destroy

        return $text
    }

    # DoOnLockCheck ht
    #
    # ht   - An htools buffer
    #
    # Does the on-lock sanity check, and returns an esanity value
    # indicating the status.  Any warnings or errors are written into
    # the buffer.

    method DoOnLockCheck {ht} {
        # FIRST, presume that the model is sane.
        set sev OK

        # NEXT, call each of the on-lock checkers
        savemax sev [$self ScenarioOnLockChecker $ht] 
        savemax sev [$adb iom checker $ht] 
        savemax sev [$adb curse checker $ht]
        savemax sev [$adb strategy checker $ht] 
        savemax sev [$adb econ checker $ht]

        # NEXT, return the severity
        return $sev
    }


    # ScenarioOnLockChecker ht
    #
    # ht   - An htools buffer
    #
    # Does the sanity check, and returns an esanity value, writing
    # any errors into the buffer.
    #
    # This routine detects only ERRORs, not WARNINGs.

    method ScenarioOnLockChecker {ht} {
        # FIRST, presume that the model is sane.
        set sev OK

        # NEXT, push a buffer onto the stack, for the problems.
        $ht push

        $ht subtitle "Scenario Constraints"

        $ht putln "The following problems were found:"
        $ht para

        $ht dl

        # NEXT, Require at least one neighborhood:
        if {[llength [$adb nbhood names]] == 0} {
            set sev ERROR

            $ht dlitem "<b>Error: No neighborhoods are defined.</b>" {
                At least one neighborhood is required.
                Create neighborhoods on the 
                <a href="gui:/tab/viewer">Map</a> tab.
            }
        }

        # NEXT, verify that neighborhoods are properly stacked
        $adb eval {
            SELECT n, obscured_by FROM nbhoods
            WHERE obscured_by != ''
        } {
            set sev ERROR

            $ht dlitem "<b>Error: Neighborhood Stacking Error.</b>" "
                Neighborhood $n is obscured by neighborhood $obscured_by.
                Fix the stacking order on the 
                <a href=\"gui:/tab/nbhoods\">Neighborhoods/Neighborhoods</a>
                tab.
            "
        }

        # NEXT, Require at least one force group
        if {[llength [$adb frcgroup names]] == 0} {
            set sev ERROR

            $ht dlitem "<b>Error: No force groups are defined.</b>" {
                At least one force group is required.  Create force
                groups on the 
                <a href="gui:/tab/frcgroups">Groups/FrcGroups</a> tab.
            }
        }

        # NEXT, Require that each force group has an actor
        set names [$adb eval {SELECT g FROM frcgroups_view WHERE a IS NULL}]

        if {[llength $names] > 0} {
            set sev ERROR

            $ht dlitem "<b>Error: Some force groups have no owner.</b>" "
                The following force groups have no owning actor:
                [join $names {, }].  Assign owning actors to force
                groups on the 
                <a href=\"gui:/tab/frcgroups\">Groups/FrcGroups</a>
                tab.
            "
        }

        # NEXT, Require that each ORG group has an actor
        set names [$adb eval {SELECT g FROM orggroups_view WHERE a IS NULL}]

        if {[llength $names] > 0} {
            set sev ERROR

            $ht dlitem "<b>Error: Some organization groups have no owner.</b>" "
                The following organization groups have no owning actor:
                [join $names {, }].  Assign owning actors to
                organization groups on the 
                <a href=\"gui:/tab/orggroups\">Groups/OrgGroups</a>
                tab.
            "
        }

        # NEXT, Require that each CAP has an actor
        set names [$adb eval {SELECT k FROM caps WHERE owner IS NULL}]

        if {[llength $names] > 0} {
            set sev ERROR

            $ht dlitem \
                "<b>Error: Some Communication Asset Packages (CAPs) have no
            owner.</b>" "
                The following CAPs have no owning actor:
                [join $names {, }].  Assign owning actors to CAPs on the
                <a href=\"gui:/tab/caps\">Info/CAPs</a> tab.
            "
        }
                
        # NEXT, Require at least one civ group
        if {[llength [$adb civgroup names]] == 0} {
            set sev ERROR

            $ht dlitem "<b>Error: No civilian groups are defined.</b>" {
                At least one civilian group is required.  Create civilian
                groups on the 
                <a href="gui:/tab/civgroups">Groups/CivGroups</a>
                tab.
            }
        }

        # NEXT, require that there are people in the civ groups
        set basepop [$adb eval {
            SELECT total(basepop) FROM civgroups
        }]

        if {$basepop == 0} {
            set sev ERROR

            $ht dlitem "<b>Error: No civilian population.</b>" {
                No civilian group has a base population greater
                than 0.
            }
        }

        # NEXT, collect data on groups and neighborhoods
        $adb eval {
            SELECT g,n FROM civgroups
        } {
            lappend gInN($n)  $g
        }

        # NEXT, Every neighborhood must have at least one group
        # TBD: Is this really required?  Can we insist, instead,
        # that at least one neighborhood must have a group?
        foreach n [$adb nbhood names] {
            if {![info exists gInN($n)]} {
                set sev ERROR

                $ht dlitem "<b>Error: Neighborhood has no residents</b>" "
                    Neighborhood $n contains no civilian groups;
                    at least one is required.  Create civilian
                    groups and assign them to neighborhoods
                    on the 
                    <a href=\"gui:/tab/civgroups\">Groups/CivGroups</a>
                    tab.
                "
            }
        }


        # NEXT, there must be at least 1 local consumer; and hence, there
        # must be at least one local civ group with sa_flag=0.

        if {![$adb exists {
            SELECT sa_flag 
            FROM civgroups JOIN nbhoods USING (n)
            WHERE local AND NOT sa_flag
        }]} {
            set sev ERROR

            $ht dlitem "<b>Error: No consumers in local economy</b>" {
                There are no consumers in the local economy.  At least
                one civilian group in some "local" neighborhood
                needs to have non-subsistence
                population.  Add or edit civilian groups on the
                <a href="gui:/tab/civgroups">Groups/CivGroups</a>
                tab.
            }
        }

        # NEXT, there cannot be any GOODS production infrastructure allocated
        # to non-local neighborhoods

        set localn [$adb nbhood local names]

        $adb eval {
            SELECT n, a FROM plants_shares
        } {

            if {$n ni $localn} {
                set sev ERROR

                $ht dlitem \
                    "<b>Error: GOODS Infrastructure in non-local nbhood</b>" "
                    There is GOODS production infrastructure allocated to $n, 
                    which is a non-local neighborhood.  Only local 
                    neighborhoods can contain GOODS production infrastructure.
                    Delete or edit infrastructure allocation on the
                    <a href=\"gui:/tab/plants\">Infrastructure/GOODS Plants</a>
                    tab.
                "
            }
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



