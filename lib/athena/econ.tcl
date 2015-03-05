#-----------------------------------------------------------------------
# FILE: econ.tcl
#
#   Athena Economics Model
#
# PACKAGE:
#   athena(n) -- Economics Model Manager
#
#   This module is responsible for computing the economics of the
#   region for this scenario.  The three primary entry points are:
#   <init>, to be called at start-up; <calibrate>, which calibrates the 
#   model when the simulation leaves the PREP state and enters time 0, 
#   and <advance>, to be called when time is advanced for the economic model.
#
# CREATION/DELETION:
#    econ_n records are created explicitly by the neighborhood manager as 
#    neighborhoods are created, and are deleted by cascading delete.
#
# PROJECT:
#   Athena S&RO Simulation
#
# AUTHOR:
#    Will Duquette
#    Dave Hanks
#
# TBD:
#    Global entities: app
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Module: econ
#

snit::type ::athena::econ {

    #-------------------------------------------------------------------
    # Components

    component adb  ;# athenadb(n) instance
    component cge  ;# cellmodel(n) instance containing the CGE model
    component sam  ;# cellmodel(n) instance containing the SAM model

    #-------------------------------------------------------------------
    # Non-Checkpointed Variables

    # Miscellaneous non-checkpointed scalar values

    variable info -array {
        changed   0
        status    ok
        state     DISABLED
        cellModel {}
        page      {}
    }

    #-------------------------------------------------------------------
    # Checkpointed Type Variables

    variable startdict {}  ;# dict of CGE cell values, as of "econ start"

    # Historical data that must be used in case of start from a
    # rebase
    variable histdata -array {
        hist_flag       0
        rem             0
        rem_rate        0
        base_consumers  0
        base_ur         0
        base_gdp        0
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {adb_} {
        set adb $adb_

        # FIRST, default state is DISABLED
        set info(state) "DISABLED"

        # NEXT, create the SAM
        set sam [cellmodel sam \
                     -epsilon 0.000001 \
                     -maxiters 1       \
                     -failcmd  [mymethod CellModelFailure] \
                     -tracecmd [mymethod TraceSAM]]

        $sam load \
            [readfile [file join $::athena::library sam6x6.cm]]

        log detail econ "Read SAM from [file join $::app_athena_shared::library sam6x6.cm]"

        require {[$sam sane]} "The econ model's SAM is not sane."

        set result [$sam solve]

        # NEXT, handle failures.
        if {$result ne "ok"} {
            error "Failed to solve SAM model."
        }

        # NEXT, create the CGE.
        set cge [cellmodel cge \
                     -epsilon  0.000001 \
                     -maxiters 1000     \
                     -failcmd  [mymethod CellModelFailure] \
                     -tracecmd [mymethod TraceCGE]]
        $cge load [readfile [file join $::athena::library cge6x6.cm]]

        log detail econ "Read CGE from [file join $::app_athena_shared::library cge6x6.cm]"
        
        require {[$cge sane]} "The econ model's CGE (cge6x6.cm) is not sane."
    }

    # destructor
    #
    # When the econ object is destroyed the SAM and CGE components need
    # to be destroyed.

    destructor {
        $sam destroy
        $cge destroy
    }

    #-------------------------------------------------------------------
    # Sanity Check

    # checker ?ht?
    #
    # ht - An htools buffer
    #
    # Computes the sanity check, and formats the results into the buffer
    # for inclusion indo an HTML page. Returns an esanity value, either
    # OK or WARNING.

    method checker {{ht ""}} {
        # FIRST, if econ is disabled, always return OK
        if {$info(state) eq "DISABLED"} {
            return OK
        }

        # NEXT, perform the checks and return status
        set edict [$self DoSanityCheck]

        if {[dict size $edict] == 0} {
            return OK
        }

        if {$ht ne ""} {
            $self DoSanityReport $ht $edict
        }

        return ERROR
    }

    # DoSanityCheck
    #
    # Performs a sanity check on the various parts of the econ module. 
    # This primarily checks key cells in the SAM to see if there is data
    # that just doesn't make sense. Problems are reported back in a
    # dict, if there are any.

    method DoSanityCheck {} {
        set edict [dict create]


        array set cells [$sam get]

        let URfrac {$cells(BaseUR) / 100.0}

        set turFrac [$adb parm get demog.turFrac]

        # FIRST, turbulence cannot be greater than the unemployment rate
        if {$URfrac < $turFrac} {
            set pct [format "%.1f%%" [expr {$turFrac * 100.0}]]
            dict append edict BaseUR \
                "The unemployment rate, $cells(BaseUR)%, must be greater than or equal to $pct (demog.turFrac)."
        }

        # NEXT, per capita demand for goods must be reasonable
        if {$cells(BA.goods.pop) < 1.0} {
            dict append edict BA.goods.pop \
                "Annual per capita demand for goods is less than 1 goods basket."
        }

        # NEXT, base consumers must not be too low.
        if {$cells(BaseConsumers) < 100} {
            dict append edict BaseConsumers \
                "Base number of consumers must not be less than 100."
        }

        # NEXT, no base prices can be zero.
        if {$cells(BP.goods) == 0.0} {
            dict append edict BP.goods \
                "Base price of goods must not be zero."
        }

        if {$cells(BP.black) == 0.0} {
            dict append edict BP.black \
                "Base price in black market must not be zero."
        }

        if {$cells(BP.pop) == 0.0} {
            dict append edict BP.pop \
                "Base price in the pop sector must not be zero."
        }

        # The goods sector and pop sectors must have revenue and expenditures,
        # otherwise what's the point
        if {$cells(BREV.goods) == 0.0} {
            dict append edict BREV.goods \
                "There must be revenue in the goods sector."
        }

        if {$cells(BREV.pop) == 0.0} {
            dict append edict BREV.pop \
                "There must be revenue in the pop sector."
        }

        if {$cells(BEXP.goods) == 0.0} {
            dict append edict BEXP.goods \
                "There must be expenditures in the goods sector."
        }

        if {$cells(BEXP.pop) == 0.0} {
            dict append edict BEXP.pop \
                "There must be expenditures in the pop sector."
        }

        if {$cells(XT.pop.goods) == 0.0} {
            dict append edict BX.pop.goods \
                "There must be a money flow from the goods sector to the pop sector."
        }

        # NEXT, Cobb-Douglas coefficients in the goods sector must add up 
        # to 1.0 within a reasonable epsilon and cannot be greater than 1.0. 
        # The black sector is assumed to never have money flow into it from
        # the goods sector, thus f.black.goods == 0.0
        let f_goods {$cells(f.goods.goods) + $cells(f.pop.goods)}

        if {![Within $f_goods 1.0 0.001]} {
            dict append edict f.goods \
                "The Cobb-Douglas coefficients in the goods column do not sum to 1.0"
        }

        # NEXT, Cobb-Douglas coefficients in the pop sector must add up to 1.0
        # within a reasonable epsilon
        let f_pop {
            $cells(f.goods.pop) + $cells(f.black.pop) + $cells(f.pop.pop)
        }

        if {![Within $f_pop 1.0 0.001]} {
            dict append edict f.pop \
                "The Cobb-Douglas coefficients in the pop column do not sum to 1.0"
        }

        let f_region {
            $cells(f.goods.region) + $cells(f.black.region) + 
            $cells(f.pop.region)   + $cells(f.actors.region) +
            $cells(f.region.region) + $cells(f.world.region)
        }

        if {$f_region > 1.0} {
            dict append edict f.region \
                "The Cobb-Douglas coefficients in the region column sum to a number > 1.0"
        }

        if {$cells(BNR.black) < 0.0} {
            dict append edict NR.black \
                "Net Rev. in the black sector is negative. Either the feedstock price is too high or the unit price is too low."
        }

        $adb notify econ <Check>

        return $edict
    }

    # DoSanityReport ht edict
    #
    # ht    - an htools(n) buffer
    # edict - a dictionary of errors to be formatted for HTML output
    #
    # This method takes any errors from the sanity check and formats
    # them for output to the htools buffer.

    method DoSanityReport {ht edict} {
        $ht subtitle "Econ Model Warnings/Errors"

        $ht putln "Certain cells in the SAM have problems. This is likely "
        $ht putln "due to incorrect data being entered in the SAM. Details "
        $ht putln "are below."

        $ht para

        dict for {cell errmsg} $edict {
            $ht br
            $ht putln "$cell ==> $errmsg"
        }

        return
    }

    # disable
    #
    # This method sets the state of the econ model to "DISABLED" if the
    # simulation state is in PREP

    method disable {} {
        assert {[$adb state] eq "PREP"}
        set info(state) "DISABLED"
        set info(changed) 1
    }

    # enable 
    #
    # This method sets the state of the econ model to "ENABLED" if the
    # simulation state is in PREP

    method enable {} {
        assert {[$adb state] eq "PREP"}
        set info(state) "ENABLED"
        set info(changed) 1
    }

    #-----------------------------------------------------------------------
    # Interface to SAM and CGE

    method getsam {{copy 0}} {
        # FIRST, create a copy of the SAM
        if {$copy} {
            set samcopy [cellmodel %AUTO%  \
                         -epsilon 0.000001 \
                         -maxiters 1]

            $samcopy load \
                [readfile \
                    [file join $::athena::library sam6x6.cm]]

            return $samcopy
        }

        return $sam    
    }

    method setsam {args} {
        $sam set {*}$args
    }

    method getcge {} {
        return $cge
    }

    method setcge {args} {
        $cge set {*}$args
    }

    # setstate
    #
    # Thie method sets the state of the econ model to the supplied
    # state, first verifying that a state change can take place and then
    # sending a notifier event for the UI to update. This method is
    # used when the CGE or SAM fail to converge for some reason.

    method setstate {state} {
        if {[$adb state] ne "PREP" && $state eq "ENABLED"} {
            error "Cannot enable econ model, must be in scenario prep."
        }
        set info(state) [eeconstate validate $state]
        $adb notify econ <State> 
    }

    # state
    #
    # Returns the current state of the econ model, one of "ENABLED" or
    # "DISABLED"

    method state {} {
        return $info(state)
    }

    # report ht
    #
    # ht   - an htools object used to build the report
    #
    # This method creates an HTML report that reports on the status of
    # the econ model providing some insight if there has been a failure
    # for some reason.

    method report {ht} {
        # FIRST, if everything is fine, not much to report
        if {$info(status) eq "ok"} {
            if {$info(state) eq "ENABLED"} {
                $ht putln "The econ model is enabled and is operating without "
                $ht putln "error."
            } else {
                $ht putln "The econ model has been disabled."
            }
        } else {
            # NEXT, a cell model has either diverged or has errors, generate
            # the appropriate report 

            if {$info(status) eq "diverge"} {
                $ht putln "The econ model was not able to converge on the "
                $ht put   "$info(page) page.  "
            } elseif {$info(status) eq "errors"} {
                $ht putln "The econ model has encountered one or more errors. "
                $ht putln "The list of cells and their problems are: "
                
                $ht para
                
                # NEXT, create a table of cells and their errors
                $ht table {
                    "Cell Name" "Error"
                } {
                    foreach {cell} [$info(cellModel) cells error] {
                        set err [$info(cellModel) cellinfo error $cell]
                        $ht tr {
                            $ht td left {$ht put $cell}
                            $ht td left {$ht put $err}
                        }
                    }
                }

                set solutions {}

                # TBD ----------------------------------------------------
                # NEXT, look for some possible problems usually it is the
                # actor's sector that causes problems.
                if {[llength $solutions] > 0} {

                    $ht para
                    $ht putln "Troubleshooting suggestions:"
                    $ht para
                    $ht put "<ul>"

                    foreach solution $solutions {
                        $ht put "<li> $solution"
                    }

                    $ht put "</ul>"
                    $ht para
                }
            }

            $ht para

            $ht putln "Because of this the econ model has been disabled "
            $ht put   "automatically. "

            $ht para

            $ht put   "A file called econdebug.cmsnap that contains the set "
            $ht put   "of initial conditions that led to this problem "
            $ht put   "is located in [file normalize [workdir join ..]] "
            $ht put   "and can be used for debugging this problem."

            $ht para

            $ht putln "You can continue to run Athena with the model "
            $ht put   "disabled or you can return to PREP and try to "
            $ht put   "fix the problem."
        }
    }

    # TraceCGE
    #
    # The cellmodel(n) -tracecmd for the cell model components.  It simply
    # logs arguments.

    method TraceCGE {args} {
        if {[lindex $args 0] eq "converge"} {
            log detail econ "cge solve trace: $args"
        } else {
            log debug econ "cge solve trace: $args"
        }
    }

    # TraceSAM
    #
    # The cellmodel(n) -tracecmd for the cell model components.  It simply
    # logs arguments.

    method TraceSAM {args} {
        if {[lindex $args 0] eq "converge"} {
            log detail econ "sam solve trace: $args"
        } else {
            log debug econ "sam solve trace: $args"
        }
    }

    # CellModelFailure msg page
    #
    # msg    - the type of error: diverge or errors
    # page   - the page in the CGE that the failure occurred
    #
    # This is called by the CGE cellmodel(n) if there is a failure
    # when trying to solve. It will prompt the user to output an 
    # initialization file that can be used with mars_cmtool(1) to 
    # further analyze any problems.

    method CellModelFailure {cm msg page} {
        # FIRST, log the warning
        log warning econ "Cell model ailed to solve: $msg $page"
        
        # NEXT, open a debug file for use in analyzing the problem
        set filename [workdir join .. econdebug.cmsnap]
        set f [open $filename w]

        # NEXT, dump the CGE initial state
        set vdict [$cm initial]
        dict for {cell value} $vdict {
            puts $f "$cell $value"
        }
        close $f
    }

    # reset
    #
    # Resets the econ model to the initial state for both the SAM
    # and the CGE and notifies the GUI

    method reset {} {
        $sam reset
        set result [$sam solve]

        if {$result ne "ok"} {
            log warning econ "Failed to reset SAM"
            error "Failed to reset SAM model"
        }

        $cge reset

        # NEXT, no longer using any historical values
        set histdata(hist_flag) 0

        $adb notify econ <SyncSheet> 
    }

    # PrepareSAM
    #
    # This method prepares the SAM for initialization with computed
    # actor data.  It also sets pertinent historical data in the SAM
    # if need be (ie. starting from a rebase).

    method PrepareSAM {} {
        # FIRST, check and convert the parm that controls whether
        # remittances are taxable.  The SAM requires the flag to
        # be in canonical form.
        #
        # TBD: should cellmodel(n) be changed to handle symbolic 
        # "yes" and "no"?
        sam set [list Flag.REMisTaxed \
            [::projectlib::boolean validate [$adb parm get econ.REMisTaxed]]]

        # NEXT, if we have historical data to deal with, set that in 
        # the SAM. For now, just unemployment rate and the annual remittance
        # change rate
        if {$histdata(hist_flag)} {
            sam set [list \
                        BaseUR            $histdata(base_ur)    \
                        REMChangeRate     $histdata(rem_rate)]
        }
    }

    # SAMActorsSector
    #
    # The flow of money to and from the actors in Athena is mediated by the
    # definition of the actors themselves. This method grabs the income
    # amounts from the individual actors and aggregates that income into
    # money flows from all other sectors. Using those income
    # values, it recomputes the revenue in the actor sector.
    # Finally, it sums the total amount of graft for each actor and computes
    # a graft fraction based upon the amount of Foreign Aid for the Region,
    # the FAR cell (which is the same as the BX.region.world cell).

    method SAMActorsSector {} {
        # FIRST, get the cells from the SAM
        array set sdata [$sam get]

        # NEXT, determine the ratio of actual consumers to the BaseConsumers
        # specified in the SAM, we will scale the income to this factor
        array set data [$adb demog getlocal]
        let scalef {$data(consumers)/$sdata(BaseConsumers)}

        # NEXT, override scale factor if the hist flag is set, this is to
        # get actors sectors shape parameters in line with the historical
        # data.
        if {$histdata(hist_flag)} {
            let scalef {$histdata(base_consumers)/$sdata(BaseConsumers)}
        } 

        set Xag 0.0
        set Xap 0.0
        set Xab 0.0
        set Xar 0.0
        set Xaw 0.0

        # NEXT, get the totals of actor income by sector, scaled by the actual
        # number of consumers, income from black market net revenues is 
        # handled differently. Revenue from the region is the graft that
        # is received. Income is multiplied by 52 weeks since the user 
        # specifies income in weeks, but the SAM and CGE have it in years
        $adb eval {
            SELECT total(income_goods)     AS ig,
                   total(income_pop)       AS ip,
                   total(income_black_tax) AS ibt,
                   total(income_world)     AS iw,
                   total(income_graft)     AS igr
            FROM actors_view 
        } {
            let Xag {$ig  * $scalef * 52.0}
            let Xap {$ip  * $scalef * 52.0}
            let Xab {$ibt * $scalef * 52.0}
            let Xaw {$iw  * $scalef * 52.0}
            let Xar {$igr * $scalef * 52.0}
        }

        # NEXT, the expenditures made by budget actors are accounted for as
        # revenue from the world since budget actors have no income
        set budgetXaw [$adb onecolumn {
            SELECT total(goods + black  + pop +
                         actor + region + world)
            FROM expenditures AS E
            JOIN actors AS A ON (E.a = A.a)
            WHERE A.atype = 'BUDGET'
        }]

        let Xaw {$Xaw + ($budgetXaw * 52.0)}

        # NEXT, deal with black market net revenue
        let BNRb {max(0.0, $sdata(BNR.black))}

        # NEXT, the total number of black market net revenue shares owned
        # by actors. If this is zero, then no actor is getting any income
        # from the black market net revenues
        set totalBNRShares \
            [$adb onecolumn {SELECT total(shares_black_nr) FROM actors_view;}]

        # NEXT, get the baseline expenditures from the cash module
        array set exp [$adb cash allocations]

        let Xwa {$exp(world)  * 52.0}
        let Xra {$exp(region) * 52.0}
        let Xga {$exp(goods)  * 52.0}
        let Xba {$exp(black)  * 52.0}
        let Xpa {$exp(pop)    * 52.0}


        # NEXT, extract the pertinent data from the SAM in preparation for
        # the computation of shape parameters.
        set BPg   $sdata(BP.goods)
        set BQDg  $sdata(BQD.goods)
        set BPb   $sdata(BP.black)
        set BQDb  $sdata(BQD.black)
        set BPp   $sdata(BP.pop)
        set BQDp  $sdata(BQD.pop)
        set BREVw $sdata(BREV.world)
        set FAR   $sdata(BFAR)
 
        # NEXT compute the rates based on the base case data and
        # fill in the income_a table rates and set each actors
        # initial income. NOTE: mulitiplication by 52 because amounts in
        # the SAM are in years and actors in Athena get income in
        # weeks.
        $adb eval {
            SELECT * FROM actors
            WHERE atype = 'INCOME'
        } data {
            let t_goods      {$data(income_goods) * 52.0 / ($BPg * $BQDg)}
            let t_pop        {$data(income_pop)   * 52.0 / ($BPp * $BQDp)}

            if {$BREVw > 0.0} {
                let t_world  {$data(income_world) * 52.0 / $BREVw}
            } else {
                set t_world 0.0
                set data(income_world) 0.0
            }

            if {$FAR > 0.0} {
                let graft_region {$data(income_graft) * 52.0 / $FAR}
            } else {
                set graft_region 0.0
            }

            # NEXT, the black market may not have any product
            if {$BQDb > 0.0} {
                let t_black {$data(income_black_tax) * 52.0 / ($BPb * $BQDb)}
            } else {
                set t_black 0.0
                set data(income_black_tax) 0.0
            }

            # NEXT, distribute black market net revenue shares. If there
            # aren't any, then no actor is getting a cut.
            if {$totalBNRShares > 0} {
                let cut_black {$data(shares_black_nr)  / $totalBNRShares}
            } else {
                set cut_black 0.0
            }

            # NEXT, total income from the black sector is the tax rate
            # income plus the cut of the black market profit (aka net
            # revenue). NOTE: since net revenue is in years in the SAM we
            # divide by 52 to get actor income in weeks.
            let income_tot_black {
                $data(income_black_tax) + max(0.0, ($cut_black * $BNRb / 52.0))
            }

            # NEXT, total income for this actor
            let total_income {
                $data(income_goods) + $income_tot_black   + 
                $data(income_pop)   + $data(income_world) +
                $data(income_graft) 
            }

            # NEXT, set this actors rates and initial income
            $adb eval {
                UPDATE income_a 
                SET t_goods      = $t_goods,
                    t_black      = $t_black,
                    t_pop        = $t_pop,
                    t_world      = $t_world,
                    graft_region = $graft_region,
                    cut_black    = $cut_black,
                    income       = $total_income
                WHERE a=$data(a)
            }
        }

        # NEXT, Set the SAM values from the actor data and solve
        $sam set [list BX.goods.actors  $Xga]
        $sam set [list BX.pop.actors    $Xpa]
        $sam set [list BX.black.actors  $Xba]
        $sam set [list BX.region.actors $Xra]
        $sam set [list BX.world.actors  $Xwa]

        $sam set [list BX.actors.goods  $Xag]
        $sam set [list BX.actors.pop    $Xap]
        $sam set [list BX.actors.black  $Xab]
        $sam set [list BX.actors.region $Xar]
        $sam set [list BX.actors.world  $Xaw]

        # NEXT, set flags in the SAM and CGE indicating whether actors
        # are getting black market profits
        if {$totalBNRShares == 0} {
            cge set [list Flag.ActorsGetBNR 0]
            sam set [list Flag.ActorsGetBNR 0]
        } else {
            cge set [list Flag.ActorsGetBNR 1]
            sam set [list Flag.ActorsGetBNR 1]
        }

        # NEXT, compute the composite graft fraction
        set graft_frac \
            [$adb onecolumn {SELECT total(graft_region) FROM income_a;}]

        $sam set [list graft $graft_frac]

        set result [$sam solve]

        set info(status) [lindex $result 0]

        # NEXT, deal with possible errors in the SAM
        if {$info(status) ne "ok"} {
            set info(cellModel) $sam
            set info(page) [lindex $result 1]
        } else {
            set info(cellModel) ""
            set info(page) ""
        }

        # NEXT, handle failures.
        if {$info(status) ne "ok"} {
            log warning econ "Failed to initialize SAM"
            $self SamError "SAM Error"
            return 0
        }

        # NEXT, notify the GUI to sync to the latest data
        $adb notify econ <SyncSheet> 

        return 1
    }

    # InitCGEFromSAM
    #
    # Updates the actors sector in the SAM and then initializes the CGE
    # from the SAM

    method InitCGEFromSAM {} {

        # NEXT, get sectors and data from the SAM
        set sectors  [$sam index i]
        array set samdata [$sam get]

        # NEXT, base prices from the SAM
        foreach i $sectors {
            cge set [list BP.$i $samdata(BP.$i)]
        }

        # NEXT, base expenditures/revenues as a starting point for 
        # CGE BX.i.j's
        foreach i $sectors {
            foreach j $sectors {
                cge set [list BX.$i.$j $samdata(XT.$i.$j)]
            }
        }

        # NEXT, base quantities demanded as a starting point for 
        # CGE BQD.i.j's
        foreach i {black} {
            foreach j $sectors {
                cge set [list BQD.$i.$j $samdata(BQD.$i.$j)]
            }
        }

        # NEXT, the base GDP
        cge set [list BaseGDP $samdata(BaseGDP)]

        # NEXT, if we are loading from history, we need the historical
        # GDP
        if {$histdata(hist_flag)} {
            cge set [list BaseGDP $histdata(base_gdp)]
        }

        # NEXT, shape parameters for the economy
        
        #-------------------------------------------------------------
        # The goods sector
        foreach i {goods black pop} {
            cge set [list f.$i.goods $samdata(f.$i.goods)]
        }
       
        foreach i {actors region world} {
            cge set [list t.$i.goods $samdata(t.$i.goods)]
        }

        cge set [list k.goods $samdata(k.goods)]

        #-------------------------------------------------------------
        # The black sector
        foreach i {goods black pop} {
            cge set [list A.$i.black $samdata(A.$i.black)]
        }

        foreach i {actors region world} {
            cge set [list t.$i.black $samdata(t.$i.black)]
        }

        #-------------------------------------------------------------
        # The pop sector
        cge set [list k.pop $samdata(k.pop)]

        foreach i {goods black pop} {
            cge set [list f.$i.pop $samdata(f.$i.pop)]
        }

        foreach i {actors region world} {
            cge set [list t.$i.pop $samdata(t.$i.pop)]
        }

        #-------------------------------------------------------------
        # The actors and region sectors
        foreach i $sectors {
            cge set [list f.$i.actors $samdata(f.$i.actors)]
            cge set [list f.$i.region $samdata(f.$i.region)]
        }

        #-------------------------------------------------------------
        # The world sector
        cge set [list BFAA $samdata(BFAA)]
        cge set [list BFAR $samdata(BFAR)]

        #-------------------------------------------------------------
        # Base values for Exports
        foreach i {goods black pop} {
            cge set [list BEXPORTS.$i $samdata(BEXPORTS.$i)]
        }

        #-------------------------------------------------------------
        # A.goods.pop, the unconstrained base demand for goods in 
        # goods basket per year per capita.
        cge set [list BA.goods.pop $samdata(BA.goods.pop)]

        #-------------------------------------------------------------
        # graft, the percentage skimmed off FAR by all actors
        $cge set [list graft $samdata(graft)]

        #-------------------------------------------------------------
        # remittances to the populace
        $cge set [list BREM $samdata(BREM)]

        # NEXT, if this is from history then we use the historical
        # REM. This happens if we are initializing from a rebase.
        if {$histdata(hist_flag)} {
            cge set [list BREM $histdata(rem)]
        }

        #-------------------------------------------------------------
        # subsistence agriculture wages, at or near poverty level
        $cge set [list BaseSubWage $samdata(BaseSubWage)]
    }

    #-------------------------------------------------------------------
    # Assessment Routines

    # ok
    #
    # Returns 1 if the economy is "ok" and 0 otherwise.

    method ok {} {
        return [expr {$info(status) eq "ok"}]
    }

    # start
    #
    # Calibrates the CGE.  This is done when the simulation leaves
    # the PREP state and enters time 0.

    method start {} {
        log normal econ "start"

        # FIRST, clear out and initialize actor income tables.
        $adb eval {DELETE FROM income_a;}

        $adb eval {
            SELECT a FROM actors
            WHERE atype='INCOME'
        } {
            $adb eval {
                INSERT INTO income_a(a, income)
                VALUES($a, 0.0);
            }
        }

        if {$info(state) eq "ENABLED"} {
            # FIRST, reset the CGE
            cge reset

            # NEXT, prepare the SAM with actor data
            $self PrepareSAM

            # NEXT, compute the actors sector in the SAM, return if 
            # there is a problem
            if {![$self SAMActorsSector]} {
                return
            }

            # NEXT, initialize the CGE from the SAM
            $self InitCGEFromSAM

            # NEXT, calibrate the CGE
            $self analyze -calibrate

            set startdict [$cge get]

            log normal econ "start complete"
        } else {
            log warning econ "disabled"
        }

    }

    # tock
    #
    # Updates the CGE at each econ tock.  Returns 1 if the CGE
    # converged, and 0 otherwise.

    method tock {} {
        log normal econ "tock"

        if {$info(state) eq "ENABLED"} {
            $self analyze

            log normal econ "tock complete"
        } else {
            log warning econ "disabled"
            return 1
        }

        if {$info(status) ne "ok"} {
            return 0
        }

        return 1
    }

    #-------------------------------------------------------------------
    # Analysis


    # analyze
    #
    # Solves the CGE to convergence.  If the -calibrate flag is given,
    # then the CGE is first calibrated; this is normally only done during
    # PREP, or during the transition from PREP to PAUSED at time 0.
    #
    # Returns 1 on success, and 0 otherwise.
    #

    method analyze {{opt ""}} {
        log detail econ "analyze $opt"

        # FIRST, get labor and consumer security factors
        set LSF [$self ComputeLaborSecurityFactor]
        set CSF [$self ComputeConsumerSecurityFactor]

        # NEXT, SAM data
        array set samdata [$sam get]

        # NEXT, calibrate if requested.
        if {$opt eq "-calibrate"} {
            # FIRST, demographics
            array set demdata [$adb demog getlocal]

            # NEXT, some globals. These only need to get set during
            # calibration
            cge set [list Global::REMChangeRate $samdata(REMChangeRate)]

            # NEXT some calibration tuning parameters
            cge set [list GDPExponent     [$adb parm get econ.gdpExp]]
            cge set [list EmpExponent     [$adb parm get econ.empExp]]
            cge set [list TurFrac         [$adb parm get demog.turFrac]]
            cge set [list Flag.REMisTaxed \
                [::projectlib::boolean validate [$adb parm get econ.REMisTaxed]]]

            # NEXT, the base unemployed
            let baseUnemp {$demdata(labor_force) * $samdata(BaseUR) / 100.0}

            # NEXT, demographic data
            cge set [list \
                         BaseConsumers $demdata(consumers)     \
                         BaseUnemp     $baseUnemp              \
                         BaseLF        $demdata(labor_force)   \
                         Cal::BPp      $samdata(BP.pop)        \
                         In::Consumers $demdata(consumers)     \
                         In::LF        $demdata(labor_force)   \
                         In::LSF       $LSF                    \
                         In::CSF       $CSF]

            # NEXT, subsistence wage, the poverty level
            cge set [list In::SubWage $samdata(BaseSubWage)]

            # NEXT, foreign aid to the region
            cge set [list In::FAR $samdata(BFAR)]

            # NEXT, foreign aid to actors
            cge set [list In::FAA $samdata(BFAA)]

            # NEXT, remittances
            cge set [list In::REM $samdata(BREM)]

            # NEXT, override remittances with historical data if necessary
            if {$histdata(hist_flag)} {
                cge set [list In::REM $histdata(rem)]
            }

            # NEXT, exports
            foreach i {goods black pop} {
                cge set [list In::EXPORTS.$i $samdata(BEXPORTS.$i)]
            }

            # NEXT, black market capacity
            cge set [list In::CAP.black  $samdata(BaseCAP.black)]

            # NEXT, number engaged in subsistence agriculture
            let subsisters {$demdata(population) - $demdata(consumers)}
            cge set [list BaseSubsisters $subsisters]
            cge set [list In::Subsisters $subsisters]

            # NEXT, actors expenditures. Multiplication by 52 because the
            # CGE has money flows in years.
            array set exp [$adb cash allocations]

            let Xwa {$exp(world)  * 52.0}
            let Xra {$exp(region) * 52.0}
            let Xga {$exp(goods)  * 52.0}
            let Xba {$exp(black)  * 52.0}
            let Xpa {$exp(pop)    * 52.0}

            cge set [list \
                         In::X.world.actors  $Xwa \
                         In::X.region.actors $Xra \
                         In::X.goods.actors  $Xga \
                         In::X.black.actors  $Xba \
                         In::X.pop.actors    $Xpa]       

            # NEXT, actors revenue
            cge set [list \
                         In::X.actors.goods  $samdata(XT.actors.goods)  \
                         In::X.actors.black  $samdata(XT.actors.black)  \
                         In::X.actors.pop    $samdata(XT.actors.pop)    \
                         In::X.actors.region $samdata(XT.actors.region) \
                         In::X.actors.world  $samdata(XT.actors.world)]

            # NEXT, black market feedstocks
            cge set [list \
                        AF.world.black  $samdata(AF.world.black) \
                        MF.world.black  $samdata(MF.world.black) \
                        BPF.world.black $samdata(PF.world.black)]

            # NOTE: if income from graft is ever allowed to change
            # over time, then In::graft should be computed and set
            # here

            # NEXT, calibrate the CGE.
            set status [cge solve]

            set info(status) [lindex $status 0]

            if {$info(status) ne "ok"} {
                set info(cellModel) $cge
                set info(page) [lindex $status 1]
            } else {
                set info(cellModel) ""
                set info(page) ""
            }

            # NEXT, the data has changed.
            set info(changed) 1

            # NEXT, handle failures.
            if {$info(status) ne "ok"} {
                log warning econ "Failed to calibrate: $info(page)"
                $self CgeError "CGE Calibration Error"
                return 0
            }

            # NEXT, retrieve the initial CAP.goods.
            array set out [cge get Out -bare]
            set CAPgoods $out(BQS.goods)

            foreach n [$adb nbhood names] {
                set cap0 [$adb plant capacity n $n]
                let jobs0 {$out(BQS.pop) * $cap0 / $CAPgoods}
                
                $adb eval {
                    UPDATE econ_n
                    SET cap0  = $cap0,
                        cap   = $cap0,
                        jobs0 = $jobs0,
                        jobs  = $jobs0
                    WHERE n = $n
                }
            }
        }

        # NEXT, Recompute In through Out

        # Set the input parameters
        array set demdata [$adb demog getlocal]
        array set exp  [$adb cash allocations]

        # NEXT, multiply expenditures by 52 since the CGE money flows are
        # in years, but actors expenses are weekly
        let Xwa {$exp(world)  * 52.0}
        let Xra {$exp(region) * 52.0}
        let Xga {$exp(goods)  * 52.0}
        let Xba {$exp(black)  * 52.0}
        let Xpa {$exp(pop)    * 52.0}

        # NEXT, if we are not calibrating, goods sector capacity comes
        # from the infrastructure model
        if {$opt ne "-calibrate"} {
            set CAPgoods [$adb plant capacity total]
        }

        # NEXT, get geo-unemployment from the demographics model 
        set GU [$adb demog geounemp]

        # NEXT, subsisters are members of the population that are not
        # consumers
        let subsisters {$demdata(population) - $demdata(consumers)}

        # NEXT, compute an updated value for REM
        set REM [$self ComputeREM]

        cge set [list \
                     In::Consumers  $demdata(consumers)     \
                     In::Subsisters $subsisters             \
                     In::LF         $demdata(labor_force)   \
                     In::GU         $GU                     \
                     In::CAP.goods  $CAPgoods               \
                     In::CAP.black  $samdata(BaseCAP.black) \
                     In::LSF        $LSF                    \
                     In::CSF        $CSF                    \
                     In::REM        $REM]


        # NOTE: if income from graft is ever allowed to change
        # over time, then In::graft should be computed and set
        # here

        # NEXT, actors expenditures
        cge set [list \
                     In::X.world.actors  $Xwa \
                     In::X.region.actors $Xra \
                     In::X.goods.actors  $Xga \
                     In::X.black.actors  $Xba \
                     In::X.pop.actors    $Xpa]        


        # Solve the CGE.
        set status [cge solve In Out]
        set info(status) [lindex $status 0]

        if {$info(status) ne "ok"} {
            set info(cellModel) $cge
            set info(page) [lindex $status 1]
        } else {
            set info(cellModel) ""
            set info(page) ""
        }

        # The data has changed.
        set info(changed) 1

        # NEXT, handle failures
        if {$info(status) ne "ok"} {
            log warning econ "Economic analysis failed"
            $self CgeError "CGE Solution Error"
            return 0
        }

        # NEXT, if we are not calibrating set the number of jobs
        # based on GOODS production infrastructure capacity and
        # the number of jobs in the CGE
        if {$opt ne "-calibrate"} {

            # Jobs comes from the capacity constrained M page
            array set data [cge get M -bare]

            foreach n [$adb nbhood local names] {
                set cap [$adb plant capacity n $n]
                let jobs {floor($data(QS.pop) * $cap / $CAPgoods)}
                
                $adb eval {
                    UPDATE econ_n
                    SET cap  = $cap,
                        jobs = $jobs
                    WHERE n = $n
                }
            }
        }

        # NEXT, use sector revenues to determine actor
        # income sector by sector. NOTE: division by 52 since
        # CGE money flows are in years, but actors get incomes
        # based on a week.
        array set out [$cge get Out -bare]
        
        foreach {actor tg tb tp tw gr cut} [$adb eval {                   
                SELECT a, t_goods, t_black, t_pop,
                       t_world, graft_region, cut_black 
                FROM income_a
        }] {
            let inc_goods    {$out(REV.goods) * $tg  / 52.0}
            let inc_black_t  {$out(REV.black) * $tb  / 52.0}
            let inc_black_nr {$out(NR.black)  * $cut / 52.0}
            let inc_pop      {$out(REV.pop)   * $tp  / 52.0}
            let inc_region   {$out(FAR)       * $gr  / 52.0}
            let inc_world    {$out(REV.world) * $tw  / 52.0}

            # NEXT, protect against negative net revenue in the
            # black sector
            let inc_black_nr {max(0.0, $inc_black_nr)}

            let inc_total {
                $inc_goods + $inc_black_t + $inc_black_nr +
                $inc_pop   + $inc_region  + $inc_world
            }

            # NEXT, update the actor incomes
            $adb eval {
                UPDATE income_a
                SET income       = $inc_total,
                    inc_goods    = $inc_goods,
                    inc_black_t  = $inc_black_t,
                    inc_black_nr = $inc_black_nr,
                    inc_pop      = $inc_pop,
                    inc_region   = $inc_region,
                    inc_world    = $inc_world
                WHERE a = $actor
            }
        }

        # NEXT, actors sector revenues from potentially new income
        # rates, these will be used in the next time step
        $adb eval {
            SELECT total(inc_goods)    * 52.0 AS Xag,
                   total(inc_black_t + 
                         inc_black_nr) * 52.0 AS Xab,
                   total(inc_pop)      * 52.0 AS Xap,
                   total(inc_region)   * 52.0 AS Xar,
                   total(inc_world)    * 52.0 AS Xaw
            FROM income_a
        } {}

        # NEXT, the expenditures made by budget actors are accounted for as
        # revenue from the world since budget actors have no income
        set budgetXaw [$adb onecolumn {
            SELECT total(goods + black  + pop +
                         actor + region + world)
            FROM expenditures AS E
            JOIN actors AS A ON (E.a = A.a)
            WHERE A.atype = 'BUDGET'
        }]

        let Xaw {$Xaw + ($budgetXaw * 52.0)}

        cge set [list \
                    In::X.actors.goods  $Xag \
                    In::X.actors.black  $Xab \
                    In::X.actors.pop    $Xap \
                    In::X.actors.region $Xar \
                    In::X.actors.world  $Xaw] 

        log detail econ "analysis complete"
        
        return 1
    }

    # ComputeLaborSecurityFactor
    #
    # Computes the labor security factor given the security of
    # each local neighborhood group.

    method ComputeLaborSecurityFactor {} {
        # FIRST, get the total number of workers
        set totalLabor [$adb onecolumn {
            SELECT labor_force FROM demog_local
        }]

        if {$totalLabor == 0} {
            return 1.0
        }

        # NEXT, get the number of workers who are working given the
        # security levels.

        set numerator 0.0

        $adb eval {
            SELECT labor_force,
                   security
            FROM demog_g
            JOIN civgroups using (g)
            JOIN force_ng using (g)
            JOIN nbhoods using (n)
            WHERE force_ng.n = civgroups.n
            AND   nbhoods.local
        } {
            set security [qsecurity name $security]
            set factor [$adb parm get econ.secFactor.labor.$security]
            let numerator {$numerator + $factor*$labor_force}
        }

        # NEXT, compute the LSF
        let LSF {$numerator/$totalLabor}

        return $LSF
    }

    # ComputeConsumerSecurityFactor
    #
    # Computes the consumer security factor given the security of
    # each local neighborhood group.

    method ComputeConsumerSecurityFactor {} {
        # FIRST get the total number of consumers
        set totalCons [$adb onecolumn {
            SELECT consumers FROM demog_local
        }]

        if {$totalCons == 0} {
            return 1.0
        }


        # NEXT, get the number of consumers who are buying things
        # given the security levels.

        set numerator 0.0

        $adb eval {
            SELECT consumers, 
                   security
            FROM demog_g
            JOIN civgroups using (g)
            JOIN force_ng  using (g)
            JOIN nbhoods   using (n)
            WHERE force_ng.n = civgroups.n
            AND   nbhoods.local
        } {
            set security [qsecurity name $security]
            set factor   [$adb parm get econ.secFactor.consumption.$security]
            let numerator {$numerator + $factor*$consumers}
        }

        # NEXT, compute the CSF
        let CSF {$numerator/$totalCons}

        return $CSF
    }


    # ComputeREM 
    #
    # Given the global remittance change rate in the CGE
    # compute a new value for remittances and return it.

    method ComputeREM {} {
        array set cgeGlobals [$cge get Global -bare]
        array set cgeInputs  [$cge get In -bare]

        set changeRate $cgeGlobals(REMChangeRate)
        set currRem    $cgeInputs(REM)

        # NEXT, no change rate or first tick
        # TBD: is this really necessary?
        if {$changeRate == 0.0 || [$adb clock delta] == 0} {
            return $currRem
        }

        # NEXT, return new REM, protect against going negative
        # and convert to a weekly fraction from an annual percentage.
        return [expr {
            max(0.0, $currRem + $currRem * ($changeRate/100.0/52.0))
        }]
    }

    # CgeError title
    #
    # This method pops up a dialog to inform the user that because the CGE
    # has failed to solve the econ model is disabled.

    method CgeError {title} {
        append msg "Failure in the econ model caused it to be disabled."
        append msg "\nSee the detail browser for more information."

        # FIRST, disable the econ model.
        $self setstate DISABLED

        # NEXT, if the app in in GUI mode, inform the user about
        # the failure. The on-tick sanity check will also fail
        # which will stop the run if it's in batch mode
        if {[app tkloaded]} {
            set answer [messagebox popup              \
                            -icon warning             \
                            -message $msg             \
                            -parent [app topwin]      \
                            -title  $title            \
                            -buttons {ok "Ok" browser "Go To Detail Browser"}]

           if {$answer eq "browser"} {
               app show my://app/econ
           }
       }

    }

    # SamError title
    #
    # This method pops up a dialog to inform the user that because the CGE
    # has failed to solve the econ model is disabled.

    method SamError {title} {
        append msg "Failure in the econ model caused it to be disabled."
        append msg "\nSee the detail browser for more information."

        # FIRST, disable the econ model
        $self setstate DISABLED

        # NEXT, if the app in in GUI mode, inform the user about the
        # failure. The on-lock sanity check will also fail.
        if {[app tkloaded]} {
            set answer [messagebox popup              \
                            -icon warning             \
                            -message $msg             \
                            -parent [app topwin]      \
                            -title  $title            \
                            -buttons {ok "Ok" browser "Go To Detail Browser"}]

           if {$answer eq "browser"} {
               app show my://app/econ
           }
       }
    }


    #-------------------------------------------------------------------
    # Queries

    # Type Methods: Delegated
    #
    # Methods delegated to the <cge> component
    #
    # - get
    # - value

    delegate method get   to cge
    delegate method value to cge
    delegate method eval  to cge

    # samcells
    #
    # Returns the names of all cells found in the SAM

    method samcells {} {
        return [$sam cells]
    }

    # cgecells
    #
    # Returns the names of all the cells found in the CGE

    method cgecells {} {
        return [$cge cells]
    }

    # dump
    #
    # Dumps the cell values and formulas for one or all pages.  If 
    # no _page_ is specified, only the *out* page is included.

    method dump {{page Out}} {
        set pages [linsert [cge pages] 0 all]

        if {$page ni $pages} {
            set pages [join $pages ", "]
            return -code error -errorcode invalid \
                "Invalid page name \"$page\", should be one of: $pages"
        }

        cge dump $page
    }

    # getstart
    #
    # Returns a dictionary of the starting values for the CGE cells.

    method getstart {} {
        return $startdict
    }

    #-------------------------------------------------------------------
    # Mutators
    #
    # Mutators are used to implement orders that change the scenario in
    # some way.  Mutators assume that their inputs are valid, and returns
    # a script of one or more commands that will undo the change.  When
    # change cannot be undone, the mutator returns the empty string.

    # samcell parmdict
    #
    # parmdict   A dictionary of order parms
    #
    #   id       Cell ID in cellmodel(n) format (ie. BX.actors.actors)
    #   val      The new value for the cellmodel to assume at that cell ID
    #
    # Updates the SAM cell model given the parms, which are presumed to be 
    # valid

    method samcell {parmdict} {
        dict with parmdict {
            # FIRST, get the old value, this is for undo
            set oldval [dict get [sam get] $id]

            # NEXT, update the cell model, solve it and notify that the 
            # cell has been updated
            sam set [list $id $val]
            sam solve
            $adb notify econ <SamUpdate> $id $val

            # NEXT, return the undo command
            return [list $self samcell [list id $id val $oldval]]
        }
    }

    # cgecell parmdict
    #
    # parmdict   A dictionary of order parms
    #
    #   id       Cell ID in cellmodel(n) format (ie. BX.actors.actors)
    #   val      The new value for the cellmodel to assume at that cell ID
    #
    # Updates the CGE cell model given the parms, which are presumed to be 
    # valid

    method cgecell {parmdict} {
        dict with parmdict {
            # FIRST, get the old value, this is for undo
            set oldval [dict get [cge get] $id]

            # NEXT, update the cell model, solve it and notify that the 
            # cell has been updated
            cge set [list $id $val]
            cge solve In Out

            $adb notify econ <CgeUpdate>

            # NEXT, return the undo command
            return [list $self cgecell [list id $id val $oldval]]
        }
    }

    # hist parmdict
    #
    # parmdict   A dictionary of order parms
    #
    #    hist_flag       0 or 1; whether to use historical data
    #    rem             The amount of remittances
    #    rem_rate        The change rate of remittances; 
    #                    can be positive or negative
    #    base_consumers  The number of consumers to use in the base case
    #    base_ur         The base case unemployment rate
    #    base_gdp        The base case GDP
    #
    # Updates the histdata array given the parms, which are presumed to
    # be valid. Returns a command to restore to the previous state of 
    # the history data.

    method hist {parmdict} {
        # FIRST, get undo dict
        set udict [dict create {*}[array get histdata]]

        # NEXT, load new data
        dict with parmdict {
            set histdata(hist_flag)      $hist_flag 
            set histdata(rem)            $rem 
            set histdata(rem_rate)       $rem_rate 
            set histdata(base_consumers) $base_consumers 
            set histdata(base_ur)        $base_ur 
            set histdata(base_gdp)       $base_gdp 
        }

        # NEXT, return undo information
        return [list $self hist $udict]
    }

    # gethist 
    #
    # Returns a dictionary of the historical data 

    method gethist {} {
        return [dict create {*}[array get histdata]]
    }

    # rebase
    #
    # This method loads key values from the current state of the
    # economy into the history array.  This data will be used to
    # set up a calibration of the CGE on start to match the state
    # of the CGE from a rebased scenario. 

    method rebase {} {
        # FIRST, set the history flag
        set histdata(hist_flag) 1

        # NEXT, zero the actors sector, it'll get recomputed at the
        # proper time from rebased actor data
        set sectors [sam index i]

        foreach i $sectors {
            sam set [list BX.actors.$i 0.0]
            sam set [list BX.$i.actors 0.0]
        }

        # NEXT, store pertinent history
        array set cgedata [cge get]

        set histdata(rem)        $cgedata(In::REM)
        set histdata(rem_rate)   $cgedata(Global::REMChangeRate)
        set histdata(base_ur)    $cgedata(M::UR)
        set histdata(base_gdp)   $cgedata(M::GDP)
        set histdata(base_consumers)  \
            [$adb onecolumn {
                SELECT sum(basepop) FROM civgroups WHERE sa_flag=0;
            }]
    }

    # samparms
    #
    # Returns a dictionary of SAM inputs that have non-default values.

    method samparms {} {
        set result [dict create]

        foreach cell [$sam cells] {
            # Constants only.
            if {[$sam cellinfo ctype $cell] ne "constant"} {
                continue
            }

            set value [$sam value $cell]
            set ivalue [$sam cellinfo ivalue $cell]

            if {$value ne $ivalue} {
                dict set result $cell $value
            }
        }

        return $result
    }

    #-------------------------------------------------------------------
    # saveable(i) interface

    # checkpoint
    #
    # Returns a checkpoint of the non-RDB simulation data.  If 
    # -saved is specified, the data is marked unchanged.
    #

    method checkpoint {{option ""}} {
        if {$option eq "-saved"} {
            set info(changed) 0
        }

        return [list sam [sam get] \
                     cge [cge get] \
                     startdict $startdict \
                     histdata [array get histdata] \
                     info [array get info]]
    }

    # restore
    #
    # Restores the non-RDB state of the module to that contained
    # in the _checkpoint_.  If -saved is specified, the data is marked
    # unchanged.
    #
    # Syntax:
    #   restore _checkpoint_ ?-saved?
    #
    #   checkpoint - A string returned by the checkpoint method
    
    method restore {checkpoint {option ""}} {
        $self reset 

        if {[dict size $checkpoint] > 0} {
            # FIRST, restore the checkpoint data
            sam set [dict get $checkpoint sam]
            cge set [dict get $checkpoint cge]

            # NEXT, solve the SAM we need to have all computed values
            # updated
            sam solve

            set startdict [dict get $checkpoint startdict]
            array set histdata [dict get $checkpoint histdata]
            array set info [dict get $checkpoint info]
        }

        if {$option eq "-saved"} {
            set info(changed) 0
        }
    }

    # changed
    #
    # Returns 1 if saveable(i) data has changed, and 0 otherwise.
    #
    # Syntax:
    #   changed

    method changed {} {
        return $info(changed)
    }

    # Within num val eps
    #
    # num  - some number
    # val  - some value to compare num to
    # eps  - an epsilon to use to see if num is close to val
    #
    # Helper proc that checks to see if a number is within an epsilon of
    # a value. Returns 1 if it is, otherwise 0

    proc Within {num val eps} {
        let diff {abs($num-$val)}
        return [expr {$diff < $eps}]
    }
}

#-------------------------------------------------------------------
# Orders: ECON:*

# ECON:UPDATE:HIST
#
# Updates historical values from rebased economic inputs including
# not using historical values at all.

::athena::orders define ECON:UPDATE:HIST {
    meta title "Update Rebased Economic Inputs"

    meta sendstates {PREP}

    meta parmlist {
        {hist_flag 0}
        {rem 0}
        {rem_rate 0}
        {base_consumers 160M}
        {base_ur 4}
        {base_gdp 200B}
    }

    meta form {
        rcc "Start Mode:" -for hist_flag 
        selector hist_flag -defvalue 0 {
            case 0 "New Scenario" {}
            case 1 "From Previous Scenario" {
                rcc "REM:" -for rem
                text rem -defvalue 0

                rcc "REM Change Rate:" -for rem_rate
                text rem_rate -defvalue 0
                label "%"

                rcc "Base Consumers:" -for base_consumers
                text base_consumers -defvalue 160M

                rcc "Base Unemp. Rate:" -for base_ur
                text base_ur -defvalue 4
                label "%"

                rcc "Base GDP:" -for base_gdp
                text base_gdp -defvalue 200B
            }
        }
    }


    method _validate {} {
        my prepare hist_flag -num -required -type snit::boolean
        my prepare rem            -toupper  -type money
        my prepare rem_rate       -toupper  -type snit::double 
        my prepare base_consumers -toupper  -type money 
        my prepare base_ur        -toupper  -type snit::double
        my prepare base_gdp       -toupper  -type money 
    }

    method _execute {{flunky ""}} {
        my setundo [$adb econ hist [array get parms]]
    }
}

# ECON:SAM:UPDATE 
#
# Updates a single cell in the Social Accounting Matrix (SAM)

::athena::orders define ECON:SAM:UPDATE {
    meta title "Update SAM Cell Value"
    meta sendstates {PREP} 

    meta parmlist {id val}
    
    meta form {
        rcc "Cell ID:" -for id
        text id

        rcc "Value:" -for val
        text val
    }


    method _validate {} {
        my prepare id           -required -type [list $adb ptype sam]
        my prepare val -toupper -required -type money
    }

    method _execute {{flunky ""}} {
        my setundo [$adb econ samcell [array get parms]]
    }
}

# ECON:SAM:GLOBAL
#
# Updates a cell but with less restrictive validation

::athena::orders define ECON:SAM:GLOBAL {
    meta title "Update SAM Global Value"
    meta sendstates {PREP}

    meta parmlist {id val}

    meta form {
        rcc "Cell ID:" -for id
        text id

        rcc "Value:" -for val
        text val
    }


    method _validate {} {
        my prepare id           -required -type [list $adb ptype sam]
        my prepare val -toupper -required -type snit::double
    }

    method _execute {{flunky ""}} {
        my setundo [$adb econ samcell [array get parms]]
    }
}
 
# ECON:CGE:UPDATE 
#
# Updates a single cell in the CGE

::athena::orders define ECON:CGE:UPDATE {
    meta title "Update CGE Cell Value"
    meta sendstates {PAUSED TACTIC}

    meta parmlist {id val}

    meta form {
        rcc "Cell ID:" -for id
        text id

        rcc "Value:" -for val
        text val
    }


    method _validate {} {
        my prepare id           -required -type [list $adb ptype cge]
        my prepare val -toupper -required -type money
    }

    method _execute {{flunky ""}} {
        my setundo [$adb econ cgecell [array get parms]]
    }
}

# ECON:UPDATE:REMRATE
#
# Updates the change rate for remittances

::athena::orders define ECON:UPDATE:REMRATE {
    meta title "Update Remittance Change Rate"
    meta sendstates {PAUSED TACTIC}

    meta parmlist {val}

    meta form {
        rcc "Value:" -for val
        text val
        label "%"
    }


    method _validate {} {
        my prepare val -toupper -required -type snit::double
    }

    method _execute {{flunky ""}} {
        set parms(id) "Global::REMChangeRate"
        my setundo [$adb econ cgecell [array get parms]]
    }
}

