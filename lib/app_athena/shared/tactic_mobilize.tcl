#-----------------------------------------------------------------------
# TITLE:
#    tactic_mobilize.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Mark II Tactic, MOBILIZE
#
#    A MOBILIZE tactic mobilizes force or organization group personnel,
#    moving new personnel into the playbox.
#
#-----------------------------------------------------------------------

# FIRST, create the class.
::athena::tactic define MOBILIZE "Mobilize Personnel" {actor} {
    #-------------------------------------------------------------------
    # Instance Variables

    variable g           ;# A FRC or ORG group
    variable mode        ;# ADD | PERCENT | UPTO | ENSURE
    variable personnel   ;# Number of personnel.
    variable percent     ;# Percentage of personnel

    # Transient data
    variable trans

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Initialize as a tactic bean.
        next

        # NEXT, Initialize state variables
        #
        # NOTE: not only is g invalid, the default personnel number is invalid 
        # for this mode, and it isn't sanity checked.  However, the user
        # will need to send TACTIC:MOBILIZE to set the group, and that
        # order will fail if the personnel/percent are not positive
        # for the selected mode.  So it's OK.

        set g         ""
        set mode      ADD
        set personnel 1
        set percent   0
        my set state invalid   ;# Initially we're invalid: no group

        # NEXT, Initialize Transient data.
        #
        # These values are set by obligate, and immediately used by
        # execute.

        set trans(personnel) 0

        # NEXT, Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    # SanityCheck
    #
    # See tactic.tcl for the API.  Only conditions that might be true
    # on paste or due to external changes in the scenario need be checked
    # here.

    method SanityCheck {errdict} {
        if {$g eq ""} {
            dict set errdict g "No group selected."
        } elseif {$g ni [group ownedby [my agent]]} {
            dict set errdict g \
                "[my agent] does not own a group called \"$g\"."
        }

        return [next $errdict]
    }

    # narrative
    #
    # Returns the human-readable narrative for this tactic.  The narrative
    # should be forgiving of unsane and missing data.

    method narrative {} {
        set gtext  [link make group $g]
        let ptext1 {$personnel > 0 ? $personnel               : "???"}
        let ptext2 {$percent > 0   ? [format %.1f%% $percent] : "???"}

        set result ""

        switch -exact -- $mode {
            ADD { 
                append result \
                    "Mobilize $ptext1 more group $gtext personnel."                 
            }
            PERCENT {
                append result \
                    "Mobilize $ptext2 more group $gtext personnel."
            }
            UPTO { 
                append result \
                    "Mobilize group $gtext personnel up to a maximum of " \
                    "$ptext1 personnel."       
            }
            ENSURE {
                append result \
                    "Mobilize enough group $gtext personnel to ensure that " \
                    "$ptext1 personnel are available for deployment."
            }
            default {
                error "Unknown mode: \"$mode\""
            }
        }

        return $result
    }

    # ObligateResources coffer
    #
    # coffer  - A coffer object with the owning agent's current
    #           resources
    #
    # Obligates the personnel to be mobilize.  Note that mobilize
    # always succeeds, and is never executed on lock.  
    #
    # Sets trans(personnel) to the selected number of personnel
    # to mobilize (possibly 0).

    method ObligateResources {coffer} {
        assert {[strategy ontick]}

        set mobilized [$coffer troops $g mobilized]
        set undeployed [$coffer troops $g undeployed]

        switch -exact -- $mode {
            ADD {
                set trans(personnel) $personnel                  
            }
            PERCENT {
                let trans(personnel) {entier(ceil($mobilized*$percent/100.0))}
            }
            UPTO { 
                let trans(personnel) {max(0,$personnel - $mobilized)}
            }
            ENSURE {
                let trans(personnel) {max(0,$personnel - $undeployed)}
            }
            default {
                error "Unknown mode: \"$mode\""
            }
        }


        # NOTE: For PERCENT, UPTO, and ENSURE, it's OK if trans(personnel)
        # is 0.
        if {$trans(personnel) > 0} {
            $coffer mobilize $g $trans(personnel)
        }
    }

    # execute
    #
    # Mobilizes the selected number of personnel, and logs the result.

    method execute {} {
        # PERCENT, UPTO and ENSURE work on a best efforts basis; they
        # can succeed with 0 troops. 

        if {$trans(personnel) > 0} {
            personnel mobilize $g $trans(personnel)
        }

        sigevent log 1 tactic "
            MOBILIZE: Actor {actor:[my agent]} mobilizes $trans(personnel) 
            new {group:$g} personnel.
        " [my agent] $g
    }
}

#-----------------------------------------------------------------------
# TACTIC:* orders

# TACTIC:MOBILIZE
#
# Updates an existing MOBILIZE tactic.
#
# NOTE: The order body only requires that "g" be syntactically correct; 
# it does not require it to be a valid group.  This is because this order will
# be used to paste tactics from one actor's strategy to another, where
# a valid "g" can't possibly ever be right.  But since the sanity check
# has to check that anyway, it's OK; it simply means that the pasted
# tactic's state will be "invalid" to begin with.

::athena::orders define TACTIC:MOBILIZE {
    meta title      "Tactic: Mobilize Personnel"
    meta sendstates PREP
    meta parmlist {tactic_id name g mode personnel percent}

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Group:" -for g
        enum g -listcmd {$order_ groupsOwnedByAgent $tactic_id}

        rcc "Mode:" -for mode
        selector mode {
            case ADD "Increase mobilized personnel by some number" {
                rcc "Personnel:" -for personnel
                text personnel
            }

            case PERCENT "Increase mobilized personnel by some percentage" {
                rcc "Percentage:" -for percent
                text percent
                label "%"
            }

            case UPTO "Reinforce mobilized personnel up to some number" {
                rcc "Personnel:" -for personnel
                text personnel
            }

            case ENSURE "Reinforce undeployed personnel up to some number" {
                rcc "Personnel:" -for personnel
                text personnel
            }
        }
    }


    method _validate {} {
        # FIRST, prepare the parameters
        my prepare tactic_id  -required -with {::strategy valclass ::athena::tactic::MOBILIZE}
        my returnOnError

        set tactic [pot get $parms(tactic_id)]

        my prepare name       -toupper  -with [list $tactic valName]
        my prepare g          -toupper  -type  ident
        my prepare mode       -toupper  -selector
        my prepare personnel  -num      -type  iquantity
        my prepare percent    -num      -type  rpercent

        my returnOnError

        fillparms parms [$tactic getdict]

        switch -exact -- $parms(mode) {
            ADD    -
            UPTO   -
            ENSURE {
                if {$parms(personnel) == 0} {
                    my reject personnel "Mode requires personnel greater than 0."
                }
            }

            PERCENT {
                if {$parms(percent) == 0.0} {
                    my reject percent "Mode requires a percentage greater than 0.0%."
                }
            }

            default {
                error "Unexpected mode: \"$parms(mode)\""
            }
        }
    }

    method _execute {{flunky ""}} {
        set tactic [pot get $parms(tactic_id)]
        my setundo [$tactic update_ {
            name g mode personnel percent
        } [array get parms]]
    }
}







