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

    # onlock
    #
    # Does a sanity check of the model.  Returns a list of two items
    # {OK|WARNING|ERROR flist}, where the flist is a 
    # list of failure dictionaries as accumulated in a 
    # failurelist object.

    method onlock {} {
        set f [failurelist new]

        try {
            $self OnLockChecker $f
            $adb iom checker $f
            $adb curse checker $f
            $adb strategy checker $f
            $adb econ checker $f

            return [list [$f severity] [$f dicts]]
        } finally {
            $f destroy
        }
    }

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
            $f add error frcgroup.none group/frc "No force groups are defined."
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
            $f add error civgroup.none group/civ "No civilian groups are defined."
        }

        # Population exceeds 0
        set basepop [$adb eval {
            SELECT total(basepop) FROM civgroups
        }]

        if {$basepop == 0} {
            $f add error civgroup.pop group/civ \
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
            $f add error econ.noconsumers group/civ \
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

    #-------------------------------------------------------------------
    # On-Tick Sanity Check

    # ontick
    #
    # Does a sanity check of the model.  Returns a list of two items
    # {OK|WARNING|ERROR flist}, where the flist is a 
    # list of failure dictionaries as accumulated in a 
    # failurelist object.

    method ontick {} {
        set f [failurelist new]

        try {
            $self OnTickChecker $f

            return [list [$f severity] [$f dicts]]
        } finally {
            $f destroy
        }
    }

    # OnTickChecker f
    #
    # f    - A failurelist object
    #
    # Does the sanity check, adding failures to the list.
    # TBD: This routine should probably live in econ.tcl.

    method OnTickChecker {f} {
        # FIRST, if the econ model is disabled, there are no errors to
        # find.
        if {[$adb econ state] eq "DISABLED"} {
            return OK
        }

        # NEXT, do checks
        if {![$adb econ ok]} {
            $f add error econ.diverged econ {
                Economy: diverged. The economic model uses a system of 
                equations called a CGE.  The system of equations could 
                not be solved. This might be an error in the CGE; 
                alternatively, the economy might really be in chaos.
            }
        }

        # NEXT, check a variety of econ result constraints.
        array set cells [$adb econ get]
        array set start [$adb econ getstart]

        if {$cells(Out::SUM.QS) == 0.0} {
            $f add error econ.zeroprod econ {
                Economy: Zero production. The economy has converged to the zero 
                point, i.e., there is no consumption or production, and 
                hence no economy. Enter 
                <tt><a href="/help/command/dump/econ.html">dump econ In</a></tt>
                at the CLI to see the current 
                inputs to the economy; it's likely that there are no
                consumers.
            }
        }

        if {!$cells(Out::FLAG.QS.NONNEG)} {
            $f add error econ.negsupp econ {
                Economy: Negative quantity supplied.
                One of the QS.i cells has a negative value; this implies
                an error in the CGE.  Enter 
                <tt><a href="/help/command/dump/econ.html">dump econ</a></tt>
                at the CLI to
                see the full list of CGE outputs.  Consider disabling
                the economic model since it is clearly malfunctioning.
            }
        }

        if {!$cells(Out::FLAG.P.POS)} {
            $f add error econ.negprice econ {
                Economy: non-positive prices.
                One of the P.i price cells is negative or zero; this implies
                an error in the CGE.  Enter 
                <tt><a href="/help/command/dump/econ.html">dump econ</a></tt>
                at the CLI to
                see the full list of CGE outputs.  Consider disabling
                the economic model since it is clearly malfunctioning.
            }
        }

        set limit [$adb parm get econ.check.MinConsumerFrac]

        if {$cells(In::Consumers) < $limit * $start(In::Consumers)} {
            $f add error econ.popdrop econ "
                Economy: Number of consumers has declined alarmingly.
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

        if {$cells(In::LF) < $limit * $start(In::LF)} {
            $f add error econ.workerdrop econ "
                Error: Number of workers has declined alarmingly
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
            $f add error econ.urup econ "
                Error: Unemployment skyrockets.
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

        if {$cells(Out::DGDP) < $limit * $start(Out::DGDP)} {
            $f add error econ.dgdpdrop econ "
                Error: DGDP Plummets.
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

        if {$cells(Out::CPI) < $min || $cells(Out::CPI) > $max} {
            $f add error econ.cpi econ "
                Error: CPI beyond limits</b>
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
    }
}



