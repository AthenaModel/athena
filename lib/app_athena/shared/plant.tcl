#-----------------------------------------------------------------------
# FILE: plant.tcl
#
#   Athena Infrastructure Plant Model singleton
#
# PACKAGE:
#   app_sim(n) -- athena_sim(1) implementation package
#
# PROJECT:
#   Athena S&RO Simulation
#
# AUTHOR:
#   Dave Hanks 
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# plant 
#
# athena_sim(1): Infrastructure Plant Model, main module.
#
# This module is responsible for allowing the user to specify the shares
# each agent in Athena owns in each neighborhood and compute the number and
# laydown of plants each agent has based upon those shares.  It is also
# responsible for degrading the repair level of plants based upon the 
# amount of repair (or lack thereof) each actor undertakes in keeping 
# their allocation of plants in operation.
#
# Note that plants owned by the SYSTEM agent are automatically kept at
# their initial state of repair and do not need to be maintained.
#
#-----------------------------------------------------------------------

snit::type plant {
    # Make it a singleton
    pragma -hasinstances no

    typevariable optParms {
        rho    ""
        shares ""
    }

    #-------------------------------------------------------------------
    # Scenario Control

    # start
    #
    # Computes the allocation of plants at scenario lock.

    typemethod start {} {
        # FIRST, fill in any local neighborhoods that are not specified in the
        # shares table with the SYSTEM agent
        set nbhoods [nbhood local names]

        foreach n $nbhoods {
            if {[demog getn $n consumers] == 0} {
                continue
            }

            if {![rdb exists {SELECT * FROM plants_shares WHERE n=$n}]} {
                rdb eval {
                    INSERT INTO plants_shares(n, a, num, rho)
                    VALUES($n, 'SYSTEM', 1, 1.0);
                }
            }
        }

        # NEXT, populate the plants_na table.
        rdb eval {
            INSERT INTO plants_na(n, a, rho)
            SELECT n, 
                   a,
                   rho
            FROM plants_shares;
        }

        # NEXT, laydown plants in neighborhoods
        if {[econ state] eq "ENABLED"} {
            $type LaydownPlants
        } else {
            log warning plant "econ is disabled"
        }
    }

    # load
    #
    # This method loads the current build levels into the working table
    # in anticipation of the execution of BUILD tactics.

    typemethod load {} {
        rdb eval {DELETE FROM working_build;}

        rdb eval {
            SELECT n, a, levels FROM plants_build
        } {
            # Sort by build level, most completed first
            set sorted [lsort -decreasing -real $levels]

            set progress [list]

            foreach level $sorted {
                lappend progress $level 0.0
            }

            rdb eval {
                INSERT INTO working_build(n, a, progress)
                VALUES($n, $a, $progress)
            }
        }
    }

    # LaydownPlants
    #
    # This method computes the actual number of plants needed by
    # neighborhood and agent based upon initial repair level. The
    # actual repair level is then computed since, in general, there
    # will be more capacity than is needed because fractional plants
    # are not allowed.

    typemethod LaydownPlants {} {
        # FIRST, compute adjusted population based on pcf
        set adjpop [rdb onecolumn {SELECT total(nbpop*pcf) FROM plants_n_view}]

        set nbhoods [list]

        # NEXT, set the fraction of plants by nbhood
        rdb eval {
            SELECT n, pcf, nbpop FROM plants_n_view
        } row {
            let pfrac($row(n)) {$row(nbpop)*$row(pcf)/$adjpop}
            lappend nbhoods $row(n)
        }

        # FIRST, get the amount of goods each plant is capable of producing
        # at max capacity
        set goodsPerPlant [money validate [parmdb get plant.bktsPerYear.goods]]

        # NEXT, get the calibrated values from the CGE for the quantity of
        # goods baskets and their price
        set QSgoods [dict get [econ get] Cal::QS.goods]
        set Pgoods  [dict get [econ get] Cal::P.goods]

        # NEXT, adjust the the maximum number of goods baskets that could
        # possible be produced given that the initial capacity of the 
        # goods sector may be degraded
        let initCapFrac {[parmdb get econ.initCapPct]/100.0}
        let maxBkts     {$QSgoods / $Pgoods / $initCapFrac}
        
        # NEXT, go through the neighborhoods laying down plants for each
        # agent that owns them
        foreach n $nbhoods {
            # NEXT, if no plants in the neighborhood nothing to do
            if {$pfrac($n) == 0.0} {
                continue
            }

            # NEXT, compute the total shares of plants in the 
            # neighborhood for all agents
            set tshares [rdb onecolumn {
                SELECT total(num) FROM plants_shares
                WHERE n=$n
            }]

            # NEXT, compute the maximum number of goods baskets
            # that could be made in this neighborhood
            let maxBktsN {$pfrac($n)*$maxBkts}

            # NEXT, go through each agent in the neighborhood assigning
            # the appropriate number of plants to each one based on 
            # shares and initial repair level
            rdb eval {
                SELECT a, num, rho FROM plants_shares
                WHERE n=$n
            } {
                # The fraction of plants this agent gets
                let afrac {double($num) / double($tshares)}

                # The number of plants this agent needs in this neighborhood
                # to produce the number of baskets required if they were
                # operating at 100% repair level
                let plantsNA {($maxBktsN * $afrac) / $goodsPerPlant}

                # The actual number of plants given the repair level and
                # that fractional plants do not exist
                # Note: floor() could be used here, resulting in an increase
                # to rho, but then that leaves the possiblity of a rho > 1.0
                if {$rho == 0.0} {
                    let actualPlantsNA {entier(ceil($plantsNA))}
                    set adjRho 0.0
                } else {
                    let actualPlantsNA {entier(ceil($plantsNA/$rho))}
                    # The actual repair level
                    let adjRho {($plantsNA) / double($actualPlantsNA)}
                }

                rdb eval {
                    UPDATE plants_na
                    SET num = $actualPlantsNA,
                        rho = $adjRho
                    WHERE n=$n AND a=$a
                }
            }
        }
    }

    # save
    #
    # This is called after strategy execution has taken place.  The 
    # working table of plants under construction is used to update the
    # actual table of plant construction.  That table is then inspected
    # to see if there are any newly completed plants that need to be 
    # added to the set of infrastructure that is actually producing
    # goods.

    typemethod save {} {
        # FIRST, update the levels of construction in all plants being
        # worked on
        rdb eval {
            SELECT n, a, progress
            FROM working_build
        } {
            set newlevels [list]
            foreach {level amount} $progress {
                let newlevel {min(1.0,$level+$amount)}

                # NEXT, if we are within 1 ten-thousandths of complete, 
                # we are done
                if {[Within $newlevel 1.0 0.0001]} {
                    set newlevel 1.0
                }

                lappend newlevels $newlevel 
            }

            set num [llength $newlevels]

            rdb eval {
                INSERT OR REPLACE INTO plants_build(n, a, levels, num)
                VALUES($n, $a, $newlevels, $num)
            }
        }

        # NEXT, add completed plants (if any) to the table of completed
        # plants; they will begin to produce goods
        rdb eval {
            SELECT n, a, levels FROM plants_build
        } {
            set newplant 0
            set newlevels [list]

            foreach lvl $levels {
                if {$lvl == 1.0} {
                    incr newplant
                } else {
                    lappend newlevels $lvl
                }
            }

            # This removes the completed plant from the set of plants
            # under construction
            rdb eval {
                UPDATE plants_build
                SET levels=$newlevels
                WHERE n=$n AND a=$a
            }

            # No new plants, done
            if {!$newplant} {
                continue
            }

            # NEXT, add new plants to the set of completed plants and compute
            # average level of repair provided this actor already has plants
            # in the neighborhood
            if {[rdb exists {SELECT * FROM plants_na WHERE n=$n AND a=$a}]} {
                # NEXT, retrieve old data to compute new average repair
                # level given new plants 
                set oldVals [rdb eval {
                    SELECT num,rho FROM plants_na
                    WHERE n=$n AND a=$a
                }]

                lassign $oldVals oldNum oldRho

                # NEXT, weighted average of old and new. Note: we can
                # assume a rho of 1.0 for all new plants
                let newRho \
                    {($oldNum*$oldRho + $newplant)/($oldNum+$newplant)}

                rdb eval {
                    UPDATE plants_na
                    SET num=num+$newplant,
                        rho=$newRho
                    WHERE n=$n AND a=$a
                }
            } else {
                # No plants yet, average level of repair is 1.0
                rdb eval {
                    INSERT INTO plants_na(n, a, num, rho)
                    VALUES($n, $a, $newplant, 1.0)
                }
            }
        }
    }

    #-----------------------------------------------------------------------
    # Helper proc

    proc Within {num val eps} {
        let diff {abs($num-$val)}
        return [expr {$diff < $eps}]
    }

    #-----------------------------------------------------------------------
    # Infrastructure degradation

    # degrade
    #
    # This method applies a week's worth of degradation to all the plants
    # not owned by the SYSTEM agent, which do not degrade and require no
    # repair.  If plants owned by actors are not maintained via the 
    # MAINTAIN tactic, they will produce less and less affecting the 
    # capacity of the goods sector.

    typemethod degrade {} {
        # FIRST, if the econ model is disabled, do nothing
        if {[econ state] eq "DISABLED"} {
            return
        }

        # NEXT, get the plant lifetime
        set lt [parmdb get plant.lifetime]

        # NEXT, if the lifetime is zero, degradation is disabled
        if {$lt == 0} {
            return
        }

        # NEXT, the inverse of the lifetime is one weeks worth of 
        # degradation
        let deltaRho {1.0 / $lt}

        # NEXT, degrade repair levels for plants owned by actors
        # that do not have auto-maintenance enabled
        # NOTE: Plants owned by the SYSTEM do not degrade
        rdb eval {
            SELECT a FROM actors
            WHERE auto_maintain = 0
        } {
            rdb eval {
                UPDATE plants_na
                SET rho = max(rho - $deltaRho, 0.0)
                WHERE a=$a AND num > 0
            }
        }
    }

    #----------------------------------------------------------------------
    # Infrastructure repair

    # repairlevel n a cash
    #
    # n    - a neighborhood that contains GOODS production plants
    # a    - an actor that owns plants in n
    # cash - some amount of cash
    #
    # This method converts cash to some amount of repair and returns
    # the repair level that would result from the expenditure of that
    # cash on repairs
    
    typemethod repairlevel {n a cash} {
        # FIRST, get the number of plants
        set num [rdb eval {
                     SELECT num
                     FROM plants_na
                     WHERE n=$n AND a=$a
                 }]

        if {$num eq "" || $num == 0} {
            return 0.0
        }

        # NEXT, retrieve parms
        set bCost [money validate [parmdb get plant.buildcost]]
        set rFrac [parmdb get plant.repairfrac]

        # NEXT, the amount of money spent per plant
        let cashPerPlant {$cash / $num}

        # NEXT, the average amount of repair per plant that this amount
        # of money can do
        if {$rFrac == 0.0} {
            return 1.0
        } else {
            let dRho {$cashPerPlant / ($bCost * $rFrac)}
        }

        return $dRho
    }


    # repaircost n a lvl
    #
    # n     - a neighborhood that contains GOODS production plants
    # a     - an actor that owns some plants in n
    # dRho  - the desired change in level of repair
    #
    # This method computes the cost to repair all the plants owned by
    # actor a in neighborhood n for one weeks worth of repair or to the
    # requested level of repair, whichever is smaller.

    typemethod repaircost {n a dRho} {
        # FIRST, if the desired change is zero, no cost 
        if {$dRho == 0} {
            return 0.0
        }

        # FIRST get the number of plants 
        set num [rdb eval {
                      SELECT num 
                      FROM plants_na
                      WHERE n=$n AND a=$a
                }]

        if {$num eq "" || $num == 0} {
            return 0.0
        }

        # NEXT, retrieve parms
        set bCost [money validate [parmdb get plant.buildcost]]
        set rFrac [parmdb get plant.repairfrac]

        # NEXT, determine the cost of repairing one plant in this
        # neighborhood
        let maxCostPerWk {$bCost * $rFrac * $dRho}

        # NEXT, multiply by number of plants to get total cost 
        let totalCost {$maxCostPerWk * $num}

        return $totalCost 
    }

    # repair a nlist amount level 
    #
    # a     - an actor that owns infrastructure
    # n     - a neighborhood that a has infrastructure
    # dRho  - the change in level of repair for the plants
    #

    typemethod repair {a n dRho} {
        # FIRST, if this actor has auto-maitenance enabled, nothing to do
        if {[actor get $a auto_maintain]} {
            return
        }

        # NEXT, change rho by the amount requested
        rdb eval {
            UPDATE plants_na
            SET rho = min(1.0,rho + $dRho)
            WHERE n=$n AND a=$a
        }
    }

    #------------------------------------------------------------------
    # New Infrastructure Construction

    # buildcost n a num
    #
    # n   - A neighborhood that has infrastructure
    # a   - An actor owning infrastructure in n
    # num - The number of plants to work on
    #
    # This method computes the cost to work on a number of plants. It
    # takes into account any work that may have already been done by
    # other BUILD tactics and makes sure that not more than one weeks 
    # worth of work is costed for each plant to be worked on.

    typemethod buildcost {n a num} {
        set cost 0.0

        # FIRST, extract the current progress
        set progress [rdb onecolumn {
            SELECT progress FROM working_build
            WHERE n=$n AND a=$a
        }]

        # NEXT, the request may be for more or fewer than the plants
        # that this actor has in the nbhood.
        # Note: if this is the first construction project for the actor
        # in n then diff is num.
        let diff {$num - ([llength $progress]/2)} 

        # NEXT, if it's more, add plants to be worked on to the list
        # otherwise, trim the list.
        if {$diff > 0} {
            lappend progress {*}[string repeat {0.0 0.0 } $diff]
        } elseif {$diff < 0} {
            set progress [lrange $progress 0 [expr {$num*2-1}]]
        }

        # NEXT, retrieve relevant parameters and compute one weeks worth of
        # construction
        set bCost [money validate [parmdb get plant.buildcost]]
        set bTime [parmdb get plant.buildtime]

        set bRate 1.0
        if {$bTime > 0.0} {
            let bRate {1.0 / $bTime}
        }

        # NEXT, compute cost based upon the list, which has already been
        # sorted so we know we work on most complete plants first
        foreach {level amount} $progress {
            # NEXT, if the max amount of construction possible has been
            # reached OR if the plant is complete, nothing to do
            if {$amount >= $bRate || $level+$amount >= 1.0} {
                continue
            }

            # NEXT, the amount of construction that could possible be done
            # cannot exceed 1.0 or one weeks worth of work, whichever is less
            let bRemain {min(1.0-$level,$bRate-$amount)}

            # NEXT, add the cost to the growing total
            let cost {$cost + $bCost*$bRemain}
        }

        return $cost
    }

    # build n a funds
    #
    # n     - A nbhood that has infrastructure
    # a     - An actor owning infrastructure in n
    # funds - An amount of money to spend on construction
    #
    # The method converts the supplied amount of money into units of
    # construction and applies it to this actors list of plants under
    # construction in the neighborhood.  Most completed plants are worked
    # on first. 

    typemethod build {n a funds} {
        # FIRST, keep track of the number of existing plants worked on and
        # the number of new plants started
        set oldplants 0
        set newplants 0

        # NEXT, retrieve relevant parameters
        set bCost [money validate [parmdb get plant.buildcost]]
        set bTime [parmdb get plant.buildtime]

        # NEXT, one weeks worth of construction
        set bRate 1.0
        if {$bTime > 0.0} {
            let bRate {1.0 / $bTime}
        }

        # NEXT, retrieve the current level of progress on the plants
        set progress [rdb onecolumn {
            SELECT progress FROM working_build
            WHERE n=$n AND a=$a
        }]

        # NEXT, prepare for construction
        set newlevels [list]

        # NEXT, expend funds on plants already under construction in priority
        # order (they are already sorted)
        foreach {level amount} $progress {
            # Out of money, just copy current levels
            if {$funds <= 0.0} {
                lappend newlevels $level $amount
                continue
            }

            # Construction remaining to get to 1.0
            let Cmax {1.0-$level}

            # Construction amount/cost is the lesser of whatever it takes 
            # to get to 1.0 or one weeks worth of work taking into account
            # that this plant may have already been worked on
            let Camount {min($Cmax, $bRate-$amount)}
            let Ccost   {$Camount*$bCost}

            # If the cost is more than what is available, prorate the 
            # construction
            if {$Ccost > $funds} {
                let Camount {$Camount * ($funds/$Ccost)}
                let Ccost {$Camount*$bCost}
            } 

            # New construction levels, and decrement funds
            let newAmount {$amount+$Camount}
            let funds {$funds-$Ccost}

            lappend newlevels $level $newAmount

            # Bump the counter of existing plants worked on
            incr oldplants
        }

        # NEXT, if there's at least one penny left over start work on new 
        # plant(s)
        # Note: This could probably be done better?
        while {$funds >= 0.01} {
            # NEXT, stopgap measure. If free is allowed then any amount 
            # of money results in an infinite number of new plants
            if {$bCost == 0.0} {
                break
            }

            # Cost of one weeks worth of work
            let Ccost {$bRate*$bCost}
            set Camount $bRate

            # If cost is greater than what's available, prorate
            if {$Ccost > $funds} {
                let Camount {$bRate * ($funds/$Ccost)}
                set Ccost $funds
            }

            # New construction on a new plant
            lappend newlevels 0.0 $Camount

            # Expend the funds
            let funds {$funds-$Ccost}

            # Bumpt the counter of new plants worked on
            incr newplants
        }

        # NEXT, all funds expended, updated the working table
        rdb eval {
            INSERT OR REPLACE INTO working_build(n, a, progress)
            VALUES($n, $a, $newlevels)
        }

        # NEXT, return the plant counters for reporting purposes
        return [list $oldplants $newplants]
    }

    # get  id ?parm?
    #
    # id      ID {n a} of a record in the plants_na table
    # parm    optional parm to retrieve from the record
    #
    # Returns the value of supplied parm from the requested record 
    # or a dictionary of parm/value pairs for the entire record.

    typemethod get {id {parm ""}} {
        lassign $id n a

        rdb eval {
            SELECT * FROM plants_na
            WHERE n=$n AND a=$a
        } row {
            if {$parm eq ""} {
                unset row(*)
                return [array get row]
            } else {
                return $row($parm)
            }
        }

        return ""
    }

    # validate id
    #
    # id    A list containing the neighborhood where plants are owned and
    #       the agent that owns them there.
    #
    # Validates a neighborhood/agent pair corresponding to plant ownership

    typemethod validate {id} {
        lassign $id n a

        if {![rdb exists {SELECT * FROM plants_shares WHERE n=$n AND a=$a}]} {
            return -code error -errorcode INVALID \
                "Invalid plant ID \"$id\"."
        }
        
        return $id
    }

    # exists  id
    #
    # id    A list containing the neighborhood where plants are owned and
    #       the agent that owns them there.
    #
    # Returns 1 if there are plants owned by the supplied agent, 0
    # otherwise.

    typemethod exists {id} {
        lassign $id n a

        return [rdb exists {
            SELECT * FROM plants_na WHERE n=$n AND a=$a
        }]
    }

    # capacity total
    #
    # Returns the total output capacity of all GOODS production plants

    typemethod {capacity total} {} {
        set goodsPerPlant [money validate [parmdb get plant.bktsPerYear.goods]]

        set totBkts [rdb onecolumn {
            SELECT total(num*rho) FROM plants_na
        }]

        return [expr {$totBkts * $goodsPerPlant}]
    }

    # capacity n
    #
    # Returns the total output capacity of all GOODS production plants given
    # a neighborhood

    typemethod {capacity n} {n} {
        set goodsPerPlant [money validate [parmdb get plant.bktsPerYear.goods]]

        set totBkts [rdb onecolumn {
            SELECT total(num*rho) FROM plants_na
            WHERE n=$n
        }]

        return [expr {$totBkts * $goodsPerPlant}]
    }

    # capacity a
    #
    # Returns the total output capacity of all GOODS production plants given
    # an agent

    typemethod {capacity a} {a} {
        set goodsPerPlant [money validate [parmdb get plant.bktsPerYear.goods]]

        set totBkts [rdb onecolumn {
            SELECT total(num*rho) FROM plants_na
            WHERE a=$a
        }]

        return [expr {$totBkts * $goodsPerPlant}]
    }

    # number total
    #
    # Returns the total number of plants in the playbox

    typemethod {number total} {} {
        return [rdb eval {SELECT total(num) FROM plants_na}]
    }

    # number n
    #
    # n   - A neighborhood
    #
    # Returns the total number of plants in the supplied neighborhood

    typemethod {number n} {n} {
        return [rdb eval {SELECT total(num) FROM plants_na WHERE n=$n}]
    }

    # number a
    #
    # a   - An agent
    #
    # Returns the total number of plants owned by the supplied agent

    typemethod {number a} {a} {
        return [rdb eval {SELECT total(num) FROM plants_na WHERE a=$a}]
    }

    #-----------------------------------------------------------------------
    # Mutators
    #
    # Mutators are used to implement orders that change the scenario in
    # some way.  Mutators assume that their inputs are valid, and returns
    # a script of one or more commands that will undo the change.  When
    # change cannot be undone, the mutator returns the empty string.

    # mutate create parmdict
    #
    # parmdict     A dictionary of plant shares parms
    #
    #
    #    n       A neighborhood ID
    #    a       An agent ID, this may include 'SYSTEM'
    #    rho     The average repair level for plants owned by a in n
    #    shares  The number of shares of plants that a should own in n
    #            when the scenario is locked
    #
    # Creates a record in the rdb that will be used at scenario lock to 
    # determine the actual number of plants owned by a in n
    
    typemethod {mutate create} {parmdict} {
        dict with parmdict {}

        rdb eval {
            INSERT INTO plants_shares(n, a, rho, num)
            VALUES($n, $a, $rho, $num);
        }

        return [list rdb delete plants_shares "n='$n' AND a='$a'"]
    }

    # mutate delete id
    #
    # id   A neighborhood/agent pair that corresponds to a plant shares
    #      record that should be deleted.

    typemethod {mutate delete} {id} {
        lassign $id n a

        set data [rdb delete -grab plants_shares \
            {n=$n AND a=$a}]

        return [list rdb ungrab $data]
    }

    # mutate update parmdict
    #
    # parmdict   A dictionary of plant shares parameters
    #
    # id       A neighborhood/agent pair corresponding to a record that 
    #          should already exist.
    # rho      A repair level, or ""
    # num      The number of shares owned by a in n, or ""
    #
    # Updates a plant shares record in the database given the parms.

    typemethod {mutate update} {parmdict} {
        set parmdict [dict merge $optParms $parmdict]

        dict with parmdict {}

        lassign $id n a

        set data [rdb grab plants_shares {n=$n AND a=$a}]

        rdb eval {
            UPDATE plants_shares
            SET rho = nullif(nonempty($rho, rho), ''),
                num = nullif(nonempty($num, num), '')
            WHERE n=$n AND a=$a
        } {}
        
        return [list rdb ungrab $data]
    }

    #---------------------------------------------------------------------
    # Order Helpers

    typemethod actorOwnsShares {n a} {
        return [rdb exists {
            SELECT * FROM plants_shares WHERE n=$n AND a=$a
        }]
    }

    # notAllocatedTo   a
    #
    # a     An agent
    #
    # This method returns a list of neighborhoods that do not have any
    # ownership of plants by the agent already specified.

    typemethod notAllocatedTo {a} {
        set nballoc [rdb eval {SELECT n FROM plants_shares WHERE a = $a}]

        set nbnotalloc [nbhood local names]

        foreach n $nballoc {
            ldelete nbnotalloc $n
        }

        return $nbnotalloc
    }
}

#--------------------------------------------------------------------
# Orders:  PLANT:SHARES:*

# PLANT:SHARES:CREATE
#
# Creates an allocation of shares of GOODS production plants for an
# agent in a neighborhood.

myorders define PLANT:SHARES:CREATE {
    meta title "Allocate GOODS Production Capacity Shares"

    meta parmlist {a n {rho 1.0} {num 1}}

    meta sendstates PREP

    meta form {
        rcc "Owning Agent:" -for a
        agent a 

        rcc "In Nbhood:" -for n
        enum n -listcmd {::plant notAllocatedTo $a}

        rcc "Initial Repair Frac:" -for rho
        frac rho -defvalue 1.0

        rcc "Shares:" -for num
        text num -defvalue 1
    }


    method _validate {} {
        my prepare a      -toupper -required -type agent
        my prepare n      -toupper -required -type {nbhood local}
        my prepare rho    -toupper           -type rfraction
        my prepare num    -toupper           -type ipositive
    
        my returnOnError
    
        # Cross check n 
        my checkon n {
            if {[plant actorOwnsShares $parms(n) $parms(a)]} {
                my reject n \
                    "Agent $parms(a) already ownes a share of the plants in $parms(n)"
            }
        }
    }

    method _execute {{flunky ""}} {
        my setundo [plant mutate create [array get parms]]
    }
}

# PLANT:SHARES:DELETE
#
# Removes an allocation of shares from the database

myorders define PLANT:SHARES:DELETE {
    meta title "Delete Production Capacity Shares"

    meta sendstates PREP
    
    meta parmlist {id}

    meta form {
        rcc "Record ID:" -for id
        plant id -context yes
    }


    method _validate {} {
        my prepare id -toupper -required -type plant
    }

    method _execute {{flunky ""}} {
        my setundo [plant mutate delete $parms(id)]
    }
}

# PLANT:SHARES:UPDATE
#
# Updates an existing allocation of shares for an agent in a neighborhood

myorders define PLANT:SHARES:UPDATE {
    meta title "Update Production Capacity Shares"

    meta sendstates PREP
    
    meta parmlist {id rho num}

    meta form {
        rcc "ID:" -for id
        dbkey id -context yes -table gui_plants_shares \
            -keys {n a} \
            -loadcmd {$order_ keyload id {rho num}}

        rcc "Initial Repair Frac:" -for rho
        frac rho 

        rcc "Shares:" -for num
        text num
    }


    method _validate {} {
        my prepare id  -required -type plant
        my prepare rho -toupper  -type rfraction
        my prepare num -toupper  -type iquantity
    }

    method _execute {{flunky ""}} {
        set undo [list]
        lappend undo [plant mutate update [array get parms]]
        my setundo [join $undo \n]
    }
}

# PLANT:SHARES:UPDATE:MULTI
#
# Updates multiple allocations of shares for a list of agent/neighborhood
# pairs.

myorders define PLANT:SHARES:UPDATE:MULTI {
    meta title "Update Production Capacity Shares"

    meta sendstates PREP

    meta parmlist {ids rho num}
    
    meta form {
        rcc "IDs:" -for ids
        dbmulti ids -context yes -key id -table gui_plants_shares \
            -loadcmd {$order_ multiload ids *}

        rcc "Initial Repair Frac:" -for rho
        frac rho 

        rcc "Shares:" -for num
        text num
    }


    method _validate {} {
        my prepare ids -required -listof plant
        my prepare rho -toupper -type rfraction
        my prepare num -toupper -type iquantity
    }

    method _execute {{flunky ""}} {
        foreach parms(id) $parms(ids) {
            lappend undo [plant mutate update [array get parms]]
        }

        my setundo [join $undo \n]
    }
}
