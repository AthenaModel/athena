#-----------------------------------------------------------------------
# TITLE:
#    condition_control.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Mark II Condition, CONTROL
#
#    Does actor $a control all of the neighborhoods in $nlist?
#
#-----------------------------------------------------------------------

# FIRST, create the class.
condition define CONTROL "Control of Neighborhoods" {
    #-------------------------------------------------------------------
    # Instance Variables

    variable a          ;# An actor
    variable sense      ;# edoes: DOES|DOESNT control
    variable anyall     ;# eanyall: ANY|ALL
    variable nlist      ;# A gofer::NBHOODS value
    
    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # Initialize as tactic bean.
        next

        # Initialize state variables
        set a      ""
        set sense  DOES
        set anyall ALL
        set nlist  [gofer::NBHOODS blank]

        # Initial state is invalid; no actor.
        my set state invalid

        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    method narrative {} {
        set s(a)      [link make actor $a]
        set s(sense)  [string tolower [edoes as longname $sense]]
        set s(anyall) [string tolower [eanyall longname $anyall]]
        set s(nlist)  [gofer::NBHOODS narrative $nlist]

        return "Actor $s(a) $s(sense) control $s(anyall) $s(nlist)."
    }

    method SanityCheck {errdict} {
        if {$a eq ""} {
            dict set errdict a "No actor selected."
        } elseif {$a ni [actor names]} {
            dict set errdict a "No such actor: \"$a\"."
        }

        if {[catch {gofer::NBHOODS validate $nlist} result]} {
            dict set errdict nlist $result
        }

        return [next $errdict]
    }

    method Evaluate {} {
        # FIRST, get the neighborhoods
        set nbhoods [gofer::NBHOODS eval $nlist]

        # NEXT, if the neighborhood list is empty, then the actor doesn't
        # control the desired set of neighborhoods.
        set totalNbhoods  [llength $nbhoods]

        if {$totalNbhoods == 0} {
            return 0
        }

        # NEXT, count the number of neighborhoods in the set that the
        # actor controls.
        set nbhoodsControlled [rdb onecolumn " 
            SELECT count(n) FROM control_n
            WHERE n IN ('[join $nbhoods ',']')
            AND controller = \$a
        "]

        # NEXT, cases
        if {$sense eq "DOES"} {
            if {$anyall eq "ALL"} {
                return [expr {$nbhoodsControlled == $totalNbhoods}]
            } else {
                # ANY
                return [expr {$nbhoodsControlled > 0}]
            }
        } else {
            # DOESNT
            if {$anyall eq "ALL"} {
                return [expr {$nbhoodsControlled < $totalNbhoods}]
            } else {
                # ANY
                return [expr {$nbhoodsControlled == 0}]
            }
        }
    }
}

#-----------------------------------------------------------------------
# CONDITION:* Orders


# CONDITION:CONTROL
#
# Updates the condition's parameters

order define CONDITION:CONTROL {
    title "Condition: Control of Neighborhoods"

    options -sendstates PREP

    form {
        rcc "Condition ID:" -for condition_id
        text condition_id -context yes \
            -loadcmd {beanload}

        rc "" -span 2
        label {
            This condition is met when
        }

        rcc "Actor:" -for a
        actor a

        rc "" -span 2
        enumlong sense -dictcmd  {::edoes asdict longname}

        label "control"

        enumlong anyall -dictcmd {::eanyall deflist}

        rc "These neighborhoods:" -for nlist -span 2
        rc "" -span 2
        gofer nlist -typename gofer::NBHOODS
    }
} {
    # FIRST, prepare and validate the parameters
    prepare condition_id -required -type condition::CONTROL
    prepare a      -toupper -type actor
    prepare sense  -toupper -type edoes
    prepare anyall -toupper -type eanyall                
    prepare nlist                      
    returnOnError -final

    set cond [condition get $parms(condition_id)]

    # NEXT, update the block
    setundo [$cond update_ {a sense anyall nlist} [array get parms]]
}




