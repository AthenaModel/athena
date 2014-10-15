#-----------------------------------------------------------------------
# TITLE:
#    tactic_deploy.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Mark II Tactic, DEPLOY
#
#    A DEPLOY tactic deploys force or organization group personnel into
#    neighborhoods, without or without redeployment.
#
# NEW AND OLD DEPLOYMENTS:
# 
# * When a DEPLOY tactic executes for the first time, this is called
#   a "new" deployment.  The number of troops to deploy will be 
#   determined by the pmode and related parameters.
#
# * If the tactic executes again the next week, this is called an
#   "old" deployment.  Whatever troops remain from the previous week's
#   deployment will be deployed again; the modes and other parameters
#   will be ignored.
#
# * If the tactic is edited by the user, it is effectively a new
#   tactic; its next execution will always be a new deployment.
#
# * If the tactic's "redeploy" flag is set, it always executes as
#   a new deployment.  "redeploy" defaults to false.
#
#-----------------------------------------------------------------------

# FIRST, create the class.
tactic define DEPLOY "Deploy Personnel" {actor} -onlock {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    variable g           ;# A FRC or ORG group
    variable pmode       ;# ALL, SOME, UPTO, ALLBUT
    variable personnel   ;# SOME, ALLBUT: Number of personnel.
    variable min         ;# UPTO: Minimum number of personnel.
    variable max         ;# UPTO: Maximum number of personnel.
    variable percent     ;# PERCENT: percentage of personnel remaining.
    variable nlist       ;# gofer::NBHOODS value; nbhoods to deploy in
    variable nmode       ;# EQUAL or BY_POP
    variable redeploy    ;# If true, each deployment is a new deployment.

    # Other State Variables
    #
    # These are cleared on update.

    variable last_tick       ;# Tick at which tactic last executed

    # Transient data
    #
    # old          - If 1, an existing deployment; if 0, a new deployment
    # nbhoods      - Neighborhoods for deployment
    # deployment   - Deployment dictionary, troops by neighborhood.
    # cost         - Amount of cash obligated
    variable trans

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # Initialize as tactic bean.
        next

        # Initialize state variables
        set g              ""
        set nlist          [gofer::NBHOODS blank]
        set nmode          BY_POP
        set pmode          ALL
        set personnel      0
        set min            0
        set max            0
        set percent        0
        set redeploy       0
        set last_tick      ""

        # Initial state is invalid (no g, nlist)
        my set state invalid

        # Initialize transient data
        set trans(old)        0
        set trans(nbhoods)    [list]
        set trans(deployment) [dict create]
        set trans(cost)       0.0

        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    # reset
    #
    # On reset, clear the "last_tick".  This happens when the 
    # tactic is updated by the user.

    method reset {} {
        my set last_tick ""
        next
    }
    

    # SanityCheck errdict
    #
    # errdict - Error dictionary, error message by parameter name.
    #
    # Sanity checks the tactic, adding any errors to the errdict
    # and returning it.

    method SanityCheck {errdict} {
        # Check g
        if {$g eq ""} {
            dict set errdict g "No group selected."
        } elseif {$g ni [group ownedby [my agent]]} {
            dict set errdict g \
                "[my agent] does not own a group called \"$g\"."
        }

        # nlist
        if {[catch {gofer::NBHOODS validate $nlist} result]} {
            dict set errdict nlist $result
        }

        return [next $errdict]
    }

    # narrative
    #
    # Returns a human-readable narrative string for this tactic.

    method narrative {} {
        set s(g)     [link make group $g]
        set s(nlist) [gofer::NBHOODS narrative $nlist]

        if {$redeploy} {
            set s(redeploy) "as a new deployment"
        } else {
            set s(redeploy) "as an existing deployment"
        }

        switch -exact -- $pmode {
            "ALL" {
                set s(pmode) "all"
            }
            "SOME" {
                set s(pmode) "$personnel"
            }
            "UPTO" {
                set s(pmode) "at least $min and up to $max"
            }
            "ALLBUT" {
                set s(pmode) "all but $personnel"
            }
            "PERCENT" {
                set s(pmode) "[format %.1f%% $percent]"
            }
            default { error "Unknown pmode: \"$pmode\"" }
        }

        switch -exact -- $nmode {
            "BY_POP" {
                set s(nmode) \
        "allocating personnel to neighborhoods in proportion to population"
            }
            "EQUAL" {
                set s(nmode) \
        "allocating an equal number of personnel to each neighborhood"
            }
            default { error "Unknown nmode: \"$nmode\"" }
        }


        append output \
            "Deploy $s(pmode) of group $s(g)'s undeployed personnel " \
            "into $s(nlist) $s(redeploy), $s(nmode)."

        return $output
    }

    # trans name
    #
    # name   - A trans() array index
    #
    # Returns the current value of a trans() element.
    # NOTE: This method is intended to support testing only; the values
    # are valid only between obligate and execute.

    method trans {name} {
        return $trans($name)
    }

    #-------------------------------------------------------------------
    # Obligation

    # ObligateResources coffer
    #
    # coffer  - A coffer object with the owning agent's current
    #           resources
    #
    # Obligates the personnel and cash required for the deployment.

    method ObligateResources {coffer} {
        # FIRST, is this an existing deployment?
        set trans(old) [my IsExistingDeployment]

        # NEXT, if it is an existing deployment, obligate it as such;
        # otherwise, obligate it as a new deployment.
        if {$trans(old)} {
            my ObligateExistingDeployment $coffer
        } else {
            my ObligateNewDeployment $coffer
        }
    }

    # IsExistingDeployment
    #
    # When called during strategy execution, returns 1 if this is an
    # existing deployment and 0 if it is a new deployment.
    #
    # We have a new deployment if:
    #
    # * We are locking, and so couldn't have had an existing deployment
    # * The redeploy flag is set, and so all deployments are new
    # * last_tick is not set, and so this is a new or edited tactic
    # * last_tick is earlier than last week, and so we didn't deploy
    #   last week.
    #
    # If none of these things are true, we have an existing deployment.

    method IsExistingDeployment {} {
        if {[strategy locking]
            || $redeploy
            || $last_tick eq ""
            || $last_tick < [simclock now] - 1
        } {
            return 0
        }

        return 1
    }

    # ObligateExistingDeployment coffer
    #
    # coffer  - The owning agent's coffer of resources.
    #
    # Obligates the personnel and cash required for the existing deployment.

    method ObligateExistingDeployment {coffer} {
        # FIRST, retrieve relevant data.
        set tactic_id [my id]
        set available [$coffer troops $g undeployed]
        set cash      [$coffer cash]

        # NEXT, what did the old deployment look like?
        rdb eval {
            SELECT total(personnel) AS troops
           FROM working_deploy_tng
           WHERE tactic_id = $tactic_id
        } {}

        # SQLite gives us a float.
        let troops {entier($troops)}

        # NEXT, if there are no troops then the existing deployment was
        # wiped out.  This must be a success; our alternative is to
        # redeploy the empty garrison, which isn't something we should
        # do without instructions from the analyst.
        if {$troops == 0} {
            my ObligateEmptyDeployment
            return
        }

        # NEXT, If there are insufficient troops or insufficent funds
        # available, we're done.
        if {[my InsufficientPersonnel $available $troops]} {
            return
        }

        set trans(cost) [my TroopCost $troops]

        if {[my InsufficientCash $cash $trans(cost)]} {
            return
        }

        # NEXT, deploy the troops just as they were from the previous
        # week.
        set trans(deployment) [rdb eval {
            SELECT n, personnel 
            FROM working_deploy_tng
            WHERE tactic_id=$tactic_id
        }]
        set trans(nbhoods) [dict keys $trans(deployment)]

        # NEXT, obligate the cash and personnel.
        my DeductResourcesFromCoffer $coffer
    }

    # ObligateEmptyDeployment
    #
    # In some cases we will successfully deploy no one.  This
    # method sets up the trans() variables for these cases,
    # and returns 1 for a successful deployment.

    method ObligateEmptyDeployment {} {
        set trans(deployment) [dict create]
        set trans(cost) 0.0
        return 1
    }

    # TroopCost troops
    #
    # troops   - Some number of personnel.
    #
    # Returns the cost of deploying the specified number of troops.

    method TroopCost {troops} {
        return [expr {$troops * [group maintPerPerson $g]}]
    }

    # TroopsFor coffer cash
    #
    # coffer - The owning agent's coffer of resources.
    # cash   - Some amount of money.
    #
    # Returns the maximum number of troops one can afford to deploy
    # given the cash available.

    method TroopsFor {coffer cash} {
        set costPerPerson [group maintPerPerson $g]

        if {$costPerPerson == 0.0} {
            return [$coffer troops $g undeployed]
        }

        return [expr {entier(double($cash)/$costPerPerson)}]
    }

    # DeductResourcesFromCoffer coffer
    #
    # coffer  - The owning agent's coffer of resources.
    #
    # Deducts the resources called for in trans() from
    # the coffer.

    method DeductResourcesFromCoffer {coffer} {
        $coffer spend $trans(cost)

        dict for {n ntroops} $trans(deployment) {
            $coffer deploy $g $n $ntroops
        }
    }


    # ObligateNewDeployment coffer
    #
    # coffer  - The owning agent's coffer of resources.
    #
    # Obligates the personnel and cash required for a new deployment,
    # as indicated by the pmode and nmode.

    method ObligateNewDeployment {coffer} {
        # FIRST, get the list of neighborhoods.  If there are none,
        # we fail with a warning.
        set trans(nbhoods) [my GetNbhoods]

        if {[llength $trans(nbhoods)] == 0} {
            return 0
        }

        # NEXT, Obligate by mode.  We can't simply compute the number
        # of troops for the selected mode, because different modes
        # have different failure policies.

        switch -exact -- $pmode {
            ALL     { set flag [my ObligateALL     $coffer] }
            SOME    { set flag [my ObligateSOME    $coffer] }
            UPTO    { set flag [my ObligateUPTO    $coffer] }
            ALLBUT  { set flag [my ObligateALLBUT  $coffer] }
            PERCENT { set flag [my ObligatePERCENT $coffer] }

            default { error "Invalid pmode: \"$pmode\""     }
        }

        if {$flag} {
            my DeductResourcesFromCoffer $coffer
        }

        return $flag
    }

    # GetNbhoods
    #
    # Evaluates the nlist gofer value to retrieve the list of neighborhoods
    # to which we will deploy.  If the nmode is BY_POP, exclude empty
    # neighborhoods, since we will only deploy to neighborhoods with
    # a civilian population.

    method GetNbhoods {} {
        # FIRST, get the neighborhoods
        set nbhoods [gofer::NBHOODS eval $nlist]

        if {[llength $nbhoods] == 0} {
            my Fail WARNING "Gofer retrieved no neighborhoods."
        }

        # NEXT, if nmode is BY_POP, filter out empty neighborhoods now.
        if {$nmode eq "BY_POP" && [llength $nbhoods] > 0} {
            set nbhoods [rdb eval "
                SELECT n FROM demog_n
                WHERE population > 0
                AND n IN ('[join $nbhoods ',']')
            "]

            if {[llength $nbhoods] == 0} {
                my Fail WARNING "All retrieved neighborhoods are empty."
            }
        }

        return $nbhoods
    }

    # ObligateALL coffer
    #
    # coffer  - The owning agent's coffer of resources.
    #
    # When mode is ALL, figures out how many troops we can
    # afford to deploy, and obligates the deployment.  Returns 1 on
    # success, and 0 on failure.
    #
    # This tactic operates on a "best efforts" basis with respect to
    # personnel.  If there are no troops, it succeeds; if there are
    # troops, but we can't afford to deploy any of them, it fails.

    method ObligateALL {coffer} {
        # FIRST, retrieve relevant data.
        set available     [$coffer troops $g undeployed]
        set cash          [$coffer cash]
        set costPerPerson [group maintPerPerson $g]


        # NEXT, if no troops are available, then we've done what we
        # can; we succeed on a best efforts basis.
        if {$available == 0} {
            return [my ObligateEmptyDeployment]
        }

        # NEXT, How many troops can we afford? All of them if we
        # are locking or they are free.  Otherwise, it depends
        # on the cost per person.
        if {[strategy locking] || $costPerPerson == 0.0} {
            set troops $available
        } else {
            # FIRST, compute the number of troops we can afford.
            let maxTroops [my TroopsFor $coffer $cash]
            let troops {min($available,$maxTroops)}

            if {$troops == 0} {
                my Fail CASH "Could not afford to deploy any troops."
                return 0
            }            
        }

        # NEXT, obligate the deployment, allocating troops to
        # neighborhoods.
        my AllocateTroops $troops

        return 1
    }

    # ObligateSOME coffer
    #
    # coffer  - The owning agent's coffer of resources.
    #
    # When mode is SOME, obligates the specified number of personnel,
    # failing if the troops are not available or cannot be paid for.

    method ObligateSOME {coffer} {
        # FIRST, retrieve relevant data.
        set tactic_id [my id]
        set available [$coffer troops $g undeployed]
        set cash      [$coffer cash]

        # NEXT, Fail if there are insufficient troops.
        if {[my InsufficientPersonnel $available $personnel]} {
            return 0
        }

        # NEXT, cost only matters on tick.
        if {[my InsufficientCash $cash [my TroopCost $personnel]]} {
            return 0
        }

        # NEXT, obligate the deployment, allocating troops to
        # neighborhoods.
        my AllocateTroops $personnel

        return 1
    }

    # ObligateUPTO coffer
    #
    # coffer  - The owning agent's coffer of resources.
    #
    # When mode is UPTO, figures out how many troops we can
    # afford to deploy, from min up to max, and obligates the deployment.  
    # Returns 1 on success, and 0 on failure.
    #
    # This tactic fails if it can't deploy at least min troops.  It
    # will deploy up to max if we can afford them.

    method ObligateUPTO {coffer} {
        # FIRST, retrieve relevant data.
        set available [$coffer troops $g undeployed]
        set cash      [$coffer cash]

        # NEXT, compute the cost of the minimum amount of troops, 
        # and the maximum quantity of troops we can afford.
        set minCost          [my TroopCost $min]

        if {[strategy locking]} {
            set affordableTroops $max
        } else {
            set affordableTroops [my TroopsFor $coffer $cash]
        }

        # NEXT, Fail if there are insufficient troops.
        if {[my InsufficientPersonnel $available $min]} {
            return 0
        }

        # NEXT, cost only matters on tick.
        if {[my InsufficientCash $cash $minCost]} {
            return 0
        }

        let troops {min($max,$affordableTroops, $available)}

        # NEXT, obligate the deployment, allocating troops to
        # neighborhoods.
        my AllocateTroops $troops

        return 1
    }

    # ObligateALLBUT coffer
    #
    # coffer  - The owning agent's coffer of resources.
    #
    # When mode is ALLBUT, figures out how many troops we can
    # afford to deploy, and obligates the deployment.  Returns 1 on
    # success, and 0 on failure.
    #
    # This tactic operates on a "best efforts" basis with respect to
    # personnel.  If there are personnel troops or less, it still succeeds; 
    # if there are troops to deploy, but we can't afford to deploy 
    # them, it fails.

    method ObligateALLBUT {coffer} {
        # FIRST, retrieve relevant data.
        set available [$coffer troops $g undeployed]
        set cash      [$coffer cash]


        # NEXT, if no troops are available, then we've done what we
        # can; we succeed on a best efforts basis.
        let troops {$available - $personnel}

        if {$troops <= 0} {
            return [my ObligateEmptyDeployment]
        }

        # NEXT, cost only matters on tick.
        if {[my InsufficientCash $cash [my TroopCost $troops]]} {
            return 0
        }

        # NEXT, obligate the deployment, allocating troops to
        # neighborhoods.
        my AllocateTroops $troops

        return 1
    }

    # ObligatePERCENT coffer
    #
    # coffer  - The owning agent's coffer of resources.
    #
    # When mode is PERCENT, figures out how many troops we can
    # afford to deploy, and obligates the deployment.  Returns 1 on
    # success, and 0 on failure.
    #
    # This tactic operates on a "best efforts" basis with respect to
    # personnel.  It will always attempt to deploy at least one troop.
    # If 0 are available, it succeeds with an empty deployment.
    # If there are troops to deploy, but we can't afford to deploy  
    # them, it fails.

    method ObligatePERCENT {coffer} {
        # FIRST, retrieve relevant data.
        set available [$coffer troops $g undeployed]
        set cash      [$coffer cash]


        # NEXT, if no troops are available, then we've done what we
        # can; we succeed on a best efforts basis.
        if {$available == 0} {
            return [my ObligateEmptyDeployment]
        }

        let troops {
            entier(ceil(double($percent)*$available/100.0))
        }


        # NEXT, cost only matters on tick.
        if {[my InsufficientCash $cash [my TroopCost $troops]]} {
            return 0
        }

        # NEXT, obligate the deployment, allocating troops to
        # neighborhoods.
        my AllocateTroops $troops

        return 1
    }

    # AllocateTroops troops 
    #
    # troops  - The number of troops to deploy
    #
    # Allocates the specified number of troops across the neighborhoods
    # according to the nmode, and saves the cost and deployment to trans().  
    # It is assumed that the troops and cash are available.

    method AllocateTroops {troops} {
        assert {[llength $trans(nbhoods)] > 0}

        # FIRST, compute the cost
        set trans(cost) [my TroopCost $troops]

        # NEXT, allocate the troops to neighborhoods.
        switch -exact -- $nmode {
            EQUAL   { set trans(deployment) [my AllocateEqually $troops] }
            BY_POP  { set trans(deployment) [my AllocateByPop   $troops] }
            default { error, "Invalid nmode: \"$nmode\"" }
        }
    }

    # AllocateByPop troops
    #
    # troops - The number of troops to allocate
    #
    # Allocates the troops to each of n nbhoods in proportion
    # to their populations, returning a dictionary with the allocation.

    method AllocateByPop {troops} {
        # FIRST, get the population profile for the neighborhoods.
        array set share [demog shares $trans(nbhoods)]

        # NEXT, the first n-1 nbhoods get their share; the nth gets
        # whatever remains.
        set nbhoods [lrange $trans(nbhoods) 0 end-1]
        set nth [lindex $trans(nbhoods) end]

        set total 0
        foreach n $nbhoods {
            let ntroops {entier($share($n)*$troops)}
            incr total $ntroops
            dict set deployment $n $ntroops
        }

        dict set deployment $nth [expr {$troops - $total}]

        return $deployment
    }

    # AllocateEqually troops
    #
    # troops - The number of troops to allocate
    #
    # Allocates 1/n of the troops to each of n nbhoods,
    # returning a dictionary with the allocation.  

    method AllocateEqually {troops} {
        # FIRST, allocate the troops to neighborhoods.
        set deployment [dict create]

        set num       [llength $trans(nbhoods)]
        let each      {$troops / $num}
        let remainder {$troops % $num}

        set count 0
        foreach n $trans(nbhoods) {
            set ntroops $each

            if {[incr count] <= $remainder} {
                incr ntroops
            }

            dict set deployment $n $ntroops
        }

        return $deployment
    }

    #-------------------------------------------------------------------
    # Execution
    
    # execute
    #
    # Execute the tactic given the results of obligating it.

    method execute {} {
        # FIRST, prepare to log data.
        set s(a) "{actor:[my agent]}"
        set s(g) "{group:$g}"

        # NEXT, set last_tick
        my set last_tick [simclock now]

        # NEXT, Pay the deployment cost, which might be zero.
        cash spend [my agent] DEPLOY $trans(cost)

        # NEXT, if the deployment is empty, log that.
        if {[dict size $trans(deployment)] == 0} {
            if {$trans(old)} {
                set message "
                    Actor $s(a)'s deployment of $s(g) troops has
                    been wiped out. 
                "
            } else {
                set message "
                    Actor $s(a) had no more $s(g) troops 
                    to deploy.
                "
            }

            sigevent log 2 tactic "DEPLOY([my id]): $message" \
                [my agent] $g

            return
        }

        # NEXT, deploy the troops and log the deployments.
        dict for {n ntroops} $trans(deployment) {
            personnel deploy [my id] $n $g $ntroops

            if {$trans(old)} {
                set message "
                    Actor $s(a)'s $ntroops $s(g) personnel 
                    remain deployed in {nbhood:$n}
                "
            } else {
                set message "
                    Actor $s(a) deploys $ntroops $s(g) personnel
                    to {nbhood:$n}
                "
            }

            sigevent log 2 tactic "DEPLOY([my id]): $message" \
                [my agent] $g $n
        }
    }
}

#-----------------------------------------------------------------------
# TACTIC:* orders

# TACTIC:DEPLOY
#
# Updates existing DEPLOY tactic.

order define TACTIC:DEPLOY {
    title "Tactic: Deploy Personnel"
    options -sendstates PREP

    form {
        rcc "Tactic ID:" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {beanload}

        rcc "Group:" -for g
        enum g -listcmd {tactic groupsOwnedByAgent $tactic_id}

        rcc "Personnel Mode:" -for pmode
        selector pmode {
            case ALL "Deploy all of the group's remaining personnel" {}

            case SOME "Deploy some of the group's personnel" {
                rcc "Personnel:" -for personnel
                text personnel
            }

            case UPTO "Deploy no less than" {
                rcc "Min Personnel:" -for min
                text min
                label "and up to"

                rcc "Max Personnel:" -for max
                text max
            }

            case ALLBUT "Deploy all but some of the group's personnel" {
                rcc "Personnel:" -for personnel
                text personnel
            }

            case PERCENT "Deploy a percentage of the group's personnel" {
                rcc "Percentage:" -for percent
                text percent
            }
        }

        rcc "In Neighborhoods:" -for nlist
        gofer nlist -typename gofer::NBHOODS

        rcc "Allocation:" -for nmode
        selector nmode {
            case BY_POP "Allocate troops to neighborhoods by population" {}
            case EQUAL  "Allocate troops to neighborhoods equally"       {}
        } 

        rcc "Redeploy each week?" -for redeploy
        yesno redeploy -defvalue 0
    }
} {
    # FIRST, prepare the parameters
    prepare tactic_id  -required -type tactic::DEPLOY
    returnOnError

    # NEXT, get the tactic
    set tactic [tactic get $parms(tactic_id)]

    prepare g                    
    prepare pmode      -toupper  -selector
    prepare personnel  -num      -type iquantity
    prepare min        -num      -type iquantity
    prepare max        -num      -type iquantity
    prepare percent    -num      -type rpercent
    prepare nlist 
    prepare nmode                -selector
    prepare redeploy             -type boolean
    returnOnError

    # NEXT, do the cross checks
    fillparms parms [$tactic view]

    if {$parms(pmode) eq "SOME" && $parms(personnel) == 0} {
        reject personnel "For pmode SOME, personnel must be positive."
    }

    if {$parms(pmode) eq "UPTO"} {
        if {$parms(max) < $parms(min)} {
            reject max "For pmode UPTO, max must be greater than min."
        }

        if {$parms(max) == 0} {
            reject max "For pmode UPTO, max must be greater than 0."
        }
    }

    if {$parms(pmode) eq "PERCENT"} {
        if {$parms(percent) == 0} {
            reject max "For pmode PERCENT, percent must be positive."
        }
    }


    returnOnError -final

    # NEXT, update the tactic, saving the undo script, and clearing
    # historical state data.

    set undo [$tactic update_ {
        g pmode personnel min max percent nlist nmode redeploy
    } [array get parms]]

    # NEXT, save the undo script
    setundo $undo
}






