#-----------------------------------------------------------------------
# TITLE:
#    tactic_grant.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Mark II Tactic, GRANT
#
#    This module implements the GRANT tactic, which grants 
#    actors access to CAPs.  By default, only a CAP's owner has
#    access; however, the actor can grant access to anyone.
#
#    The bookkeeping is handled by the cap(sim) module.
# 
#-----------------------------------------------------------------------

# FIRST, create the class.
::athena::tactic define GRANT "Grant Access to CAP" {actor} -onlock {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    variable klist       ;# A list of CAP IDs
    variable alist       ;# A gofer::ACTORS value


    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Initialize as a tactic bean.
        next

        # NEXT, Initialize state variables
        set klist [list]
        set alist [gofer::ACTORS blank]

        # NEXT, Initial state is invalid (empty klist and alist)
        my set state invalid

        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    # No obligate method is required; the tactic uses no resources.

    method SanityCheck {errdict} {
        # klist
        if {[llength $klist] == 0} {
            dict set errdict klist "No CAPs selected."
        } else {
            foreach cap $klist {
                if {$cap ni [[my adb] cap names] || 
                    [cap get $cap owner] ne [my agent]
                } {
                    dict set errdict klist \
                    "[my agent] does not own a CAP called \"$cap\"."
                    break;
                }
            }
        }

        # alist
        if {[catch {gofer::ACTORS validate $alist} result]} {
            dict set errdict alist $result
        }


        return [next $errdict]
    }

    method narrative {} {
        set s(klist) [andlist CAP $klist]
        set s(alist) [gofer::ACTORS narrative $alist]

        return "Grant $s(alist) access to $s(klist)."
    }


    method execute {} {
        # FIRST, grant access to all actors but [my agent], who owns
        # the relevant CAPs to begin with.
        set actors [gofer eval $alist]
        ldelete actors [my agent]

        if {[llength $actors] > 0} {
            [my adb] cap access grant $klist $actors
        }

        sigevent log 2 tactic "
            GRANT: Actor {actor:[my agent]} grants access to
            [andlist CAP $klist] to [andlist actor $actors].
        " [my agent] {*}$klist {*}$actors
    }
}

#-----------------------------------------------------------------------
# TACTIC:* orders

# TACTIC:GRANT
#
# Updates existing GRANT tactic.

::athena::orders define TACTIC:GRANT {
    meta title      "Tactic: Grant Access to CAP"
    meta sendstates PREP
    meta parmlist   {tactic_id name klist alist}

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "CAP List:" -for klist
        enumlonglist klist \
            -dictcmd {$order_ capsOwnedBy $tactic_id} \
            -width   40 \
            -height  8

        rcc "Actor List:" -for alist
        gofer alist -typename gofer::ACTORS
    }


    method _validate {} {
        # FIRST, prepare the parameters
        my prepare tactic_id  -required -with {::strategy valclass ::athena::tactic::GRANT}
        my returnOnError

        set tactic [$adb pot get $parms(tactic_id)]

        my prepare name      -toupper  -with [list $tactic valName]
        my prepare klist     -toupper
        my prepare alist
     
        # Error checking for klist and alist is done by the SanityCheck 
        # routine.
    }

    method _execute {{flunky ""}} {
        set tactic [$adb pot get $parms(tactic_id)]
        my setundo [$tactic update_ {name klist alist} [array get parms]]
    }
}







