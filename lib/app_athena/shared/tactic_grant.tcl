#-----------------------------------------------------------------------
# TITLE:
#    tactic_grant.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Mark II Tactic, GRANT
#
#    This module implements the GRANT tactic, which grants 
#    actors access to CAPs.  By default, only a CAP's owner has
#    access; however, the actor can grant access to anyone.
#
#    The bookkeeping is handled by the cap(sim) module.
# 
#-----------------------------------------------------------------------

# FIRST, create the class.
tactic define GRANT "Grant Access to CAP" {actor} -onlock {
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
                if {$cap ni [cap names] || 
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
            cap access grant $klist $actors
        }

        sigevent log 2 tactic "
            GRANT: Actor {actor:[my agent]} grants access to
            [andlist CAP $klist] to [andlist actor $actors].
        " [my agent] {*}$klist {*}$actors
    }

    #-------------------------------------------------------------------
    # Order Helper Typemethods


    # capsOwnedBy tactic_id
    #
    # tactic_id     - A GRANT tactic id
    #
    # Returns a namedict of CAPs owned by the tactic's agent.
    
    typemethod capsOwnedBy {tactic_id} {
        if {![tactic exists $tactic_id]} {
            return [list]
        }

        set tactic [tactic get $tactic_id]
        set owner  [$tactic agent]

        return [rdb eval {
            SELECT k,longname FROM caps
            WHERE owner=$owner
            ORDER BY k
        }]
    }


}

#-----------------------------------------------------------------------
# TACTIC:* orders

# TACTIC:GRANT
#
# Updates existing GRANT tactic.

order define TACTIC:GRANT {
    title "Tactic: Grant Access to CAP"
    options -sendstates PREP

    form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {beanload}

        rcc "CAP List:" -for klist
        enumlonglist klist \
            -dictcmd {tactic::GRANT capsOwnedBy $tactic_id} \
            -width   40 \
            -height  8

        rcc "Actor List:" -for alist
        gofer alist -typename gofer::ACTORS
    }
} {
    # FIRST, prepare the parameters
    prepare tactic_id  -required -type tactic::GRANT
    prepare klist      -toupper
    prepare alist
 
    # Error checking for klist and alist is done by the SanityCheck 
    # routine.

    returnOnError -final

    # NEXT, update the tactic, saving the undo script, and clearing
    # historical state data.
    set tactic [tactic get $parms(tactic_id)]
    set undo [$tactic update_ {klist alist} [array get parms]]

    # NEXT, save the undo script
    setundo $undo
}






