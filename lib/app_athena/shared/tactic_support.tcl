#-----------------------------------------------------------------------
# TITLE:
#    tactic_support.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Mark II Tactic, SUPPORT
#
#    This module implements the SUPPORT tactic, which allows an
#    actor to give political support to another actor in one or more
#    neighborhoods.  The support continues until the next strategy tock, 
#    when it must be explicitly renewed.
# 
#-----------------------------------------------------------------------

# FIRST, create the class.
tactic define SUPPORT "Support Actor" {actor} -onlock {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    variable a       ;# An actor, SELF, or NONE
    variable nlist   ;# A gofer::NBHOODS value


    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Initialize as a tactic bean.
        next

        # NEXT, Initialize state variables
        set a     ""
        set nlist [gofer::NBHOODS blank]

        # NEXT, Initial state is invalid (empty a and nlist)
        my set state invalid

        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    # No obligate method is required; the tactic uses no resources.

    method SanityCheck {errdict} {
        # a
        if {$a eq ""} {
            dict set errdict a "No actor specified."
        } elseif {$a ni [ptype a+self+none names]} {
            dict set errdict a "No such actor: \"$a\"."
        }

        # nlist
        if {[catch {gofer::NBHOODS validate $nlist} result]} {
            dict set errdict nlist $result
        }


        return [next $errdict]
    }

    method narrative {} {
        if {$a eq "SELF"} {
            set s(a) "self"
        } elseif {$a eq "NONE"} {
            set s(a) "no one"
        } else {
            set s(a) "actor [link make actor $a]"
        }

        set s(nlist) [gofer::NBHOODS narrative $nlist]

        return "Support $s(a) in $s(nlist)."
    }


    method execute {} {
        # FIRST, get the neighborhoods.
        set nbhoods [gofer::NBHOODS eval $nlist]

        if {[llength $nbhoods] == 0} {
            # No neighborhoods to support
            return
        }

        # FIRST, support a in the neighborhoods.
        control support [my agent] $a $nbhoods

        # NEXT, log what happened.
        set logIds $nbhoods

        if {$a eq "SELF"} {
            set supports "{actor:[my agent]}"
        } elseif {$a eq "NONE"} {
            set supports "no actor"
        } else {
            set supports "{actor:$a}"
            set logIds [linsert $logIds 0 $a]
        }

        set ntext [list]

        foreach n $nbhoods {
            lappend ntext "{nbhood:$n}"
        }

        sigevent log 2 tactic "
            SUPPORT: Actor {actor:[my agent]} supports $supports 
            in [join $ntext {, }]
        " [my agent] {*}$logIds
    }

    #-------------------------------------------------------------------
    # Order Helper Typemethods

    # allButMe tactic_id
    #
    # Returns a list of SELF, NONE, and all actor names but the
    # owning agent (because a is represented by SELF)

    typemethod allButMe {tactic_id} {
        if {![pot has $tactic_id]} {
            return [list]
        }

        set tactic [pot get $tactic_id]

        set list [list SELF NONE {*}[actor names]]

        ldelete list [$tactic agent]

        return $list
    }
}

#-----------------------------------------------------------------------
# TACTIC:* orders

# TACTIC:SUPPORT
#
# Updates existing SUPPORT tactic.

myorders define TACTIC:SUPPORT {
    meta title      "Tactic: Support Actor"
    meta sendstates PREP
    meta parmlist   {tactic_id name a nlist}

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Support Actor:" -for a
        enum a -listcmd {tactic::SUPPORT allButMe $tactic_id}

        rcc "In Neighborhoods:" -for nlist
        gofer nlist -typename gofer::NBHOODS
    }


    method _validate {} {
        # FIRST, prepare the parameters
        my prepare tactic_id  -required -with {::strategy valclass tactic::SUPPORT}
        my returnOnError

        set tactic [pot get $parms(tactic_id)]

        my prepare name    -toupper   -with [list $tactic valName]
        my prepare a       -toupper
        my prepare nlist
     
        # Error checking for a and nlist is done by the SanityCheck 
        # routine.
    }

    method _execute {{flunky ""}} {
        set tactic [pot get $parms(tactic_id)]
        my setundo [$tactic update_ {name a nlist} [array get parms]]
    }
}







