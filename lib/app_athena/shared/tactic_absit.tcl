#-----------------------------------------------------------------------
# TITLE:
#    tactic_absit.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Mark II Tactic, ABSIT creation
#
#    This module implements the ABSIT tactic. 
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# Tactic: ABSIT

tactic define ABSIT "Abstract Situation" {system actor} -onlock {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    variable n          ;# Neighborhood in which to create absit
    variable stype      ;# Absit type
    variable coverage   ;# Coverage fraction
    variable duration   ;# Duration of absit in weeks
    variable resolver   ;# Resolving group, or "NONE"

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # Initialize as tactic bean
        next

        # Initialize state variables
        set n          ""
        set stype      ""
        set coverage   1.0
        set duration   1
        set resolver   "NONE"

        # Initial state is invalid (no n, stype)
        my set state invalid

        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    # No ObligateResources method is required; the tactic uses no resources.

    method SanityCheck {errdict} {
        if {$n eq ""} {
            dict set errdict n "No neighborhood selected."
        } elseif {$n ni [nbhood names]} {
            dict set errdict n "No such neighborhood: \"$n\"."
        }

        if {$stype eq ""} {
            dict set errdict stype "No situation type selected."
        } elseif {$stype ni [eabsit names]} {
            dict set errdict stype "No such abstraction situation type: \"$stype\"."
        }

        if {$resolver ne "NONE" && $resolver ni [frcgroup names]} {
            dict set errdict resolver "No such FRC group: \"$resolver\"."
        }

        return [next $errdict]
    }

    method narrative {} {
        set narr ""

        set s(stype)    [expr {$stype ne "" ? $stype : "???"}]
        set s(n)        [link make nbhood $n]
        set s(resolver) [link make group $resolver]
        set s(coverage) [format "%.2f" $coverage]

        set narr "$s(stype) abstract situation in $s(n) "
        append narr "(cov=$s(coverage)) "

        if {$resolver eq "NONE"} {
            append narr "for"
        } else {
            append narr "resolved by $s(resolver) after"
        }

        append narr " $duration week(s)."
        
        return $narr
    }

    method execute {} {
        set owner [my agent]
        set objects [list]

        set s(n)        [link make nbhood $n]
        set s(resolver) [link make group $resolver]
        set s(coverage) [format "%.2f" $coverage]

        # FIRST, is there already an absit of this type in n? If so,
        # there's nothing to do.
        if {[absit existsInNbhood $n $stype]} {
            sigevent log 2 tactic "
                ABSIT([my id]):  Absit of type $stype already exists in $s(n).
            " $owner $n
            return 1
        }

        # NEXT, log execution
        set objects [list $owner $n]
        if {$resolver ne "NONE"} {
            lappend objects $resolver
        }

        set msg "ABSIT([my id]): [my narrative]"

        sigevent log 2 tactic $msg {*}$objects

        # NEXT, create the absit.
        set p(n)         $n
        set p(stype)     $stype
        set p(coverage)  $coverage
        set p(inception) 1
        set p(resolver)  $resolver
        set p(rduration) $duration

        absit mutate create [array get p]
    }
}

# TACTIC:ABSIT
#
# Creates/Updates ABSIT tactic.

order define TACTIC:ABSIT {
    title "Tactic: Abstract Situation"
    options -sendstates PREP

    form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {beanload}

        rcc "Neighborhood:" -for n
        nbhood n

        rcc "Type:" -for stype
        enum stype -listcmd {absit AbsentTypes $n}

        rcc "Coverage:" -for coverage
        frac coverage

        rcc "Resolver:" -for resolver
        enum resolver -listcmd {ptype g+none names}

        rcc "Duration:" -for duration
        text duration
        label "weeks"
    }

} {
    # FIRST, prepare the parameters
    prepare tactic_id  -required -type tactic::ABSIT
    returnOnError

    set tactic [tactic get $parms(tactic_id)]

    # Validation of initially invalid items or contingent items
    # takes place on sanity check.
    prepare n         -toupper
    prepare stype     -toupper
    prepare coverage  -num       -type rfraction
    prepare resolver  -toupper
    prepare duration  -num       -type iticks

    returnOnError

    validate coverage {
        if {$parms(coverage) == 0.0} {
            reject coverage "Coverage must be greater than 0."
        }
    }

    returnOnError -final


    # NEXT, modify the tactic
    setundo [$tactic update_ {
        n stype coverage inception resolver duration
    } [array get parms]]
}




