#-----------------------------------------------------------------------
# TITLE:
#    tactic_support.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Mark II Tactic, SUPPORT
#
#    This module implements the SUPPORT tactic, which allows an
#    actor to give political support to another actor in one or more
#    neighborhoods.  The support continues until the next strategy tock, 
#    when it must be explicitly renewed.
# 
#-----------------------------------------------------------------------

# FIRST, create the class.
::athena::tactic define SUPPORT "Support Actor" {actor} -onlock {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    variable a       ;# An actor, SELF, or NONE
    variable nlist   ;# A NBHOODS gofer value


    #-------------------------------------------------------------------
    # Constructor

    constructor {pot_ args} {
        next $pot_

        # NEXT, Initialize state variables
        set a     ""
        set nlist [[my adb] gofer NBHOODS blank]

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
        if {[catch {[my adb] gofer NBHOODS validate $nlist} result]} {
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

        set s(nlist) [[my adb] gofer NBHOODS narrative $nlist]

        return "Support $s(a) in $s(nlist)."
    }


    method execute {} {
        # FIRST, get the neighborhoods.
        set nbhoods [[my adb] gofer NBHOODS eval $nlist]

        if {[llength $nbhoods] == 0} {
            # No neighborhoods to support
            return
        }

        # FIRST, support a in the neighborhoods.
        [my adb] control support [my agent] $a $nbhoods

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

        [my adb] sigevent log 2 tactic "
            SUPPORT: Actor {actor:[my agent]} supports $supports 
            in [join $ntext {, }]
        " [my agent] {*}$logIds
    }
}

#-----------------------------------------------------------------------
# TACTIC:* orders

# TACTIC:SUPPORT
#
# Updates existing SUPPORT tactic.

::athena::orders define TACTIC:SUPPORT {
    meta title      "Tactic: Support Actor"
    meta sendstates PREP
    meta parmlist   {tactic_id name a nlist}

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Support Actor:" -for a
        enum a -listcmd {$order_ agents+SelfNone $tactic_id}

        rcc "In Neighborhoods:" -for nlist
        gofer nlist -typename NBHOODS
    }


    method _validate {} {
        # FIRST, prepare the parameters
        my prepare tactic_id  -required \
            -with [list $adb strategy valclass ::athena::tactic::SUPPORT]
        my returnOnError

        set tactic [$adb pot get $parms(tactic_id)]

        my prepare name    -toupper   -with [list $tactic valName]
        my prepare a       -toupper
        my prepare nlist
     
        # Error checking for a and nlist is done by the SanityCheck 
        # routine.
    }

    method _execute {{flunky ""}} {
        set tactic [$adb pot get $parms(tactic_id)]
        my setundo [$tactic update_ {name a nlist} [array get parms]]
    }
}







