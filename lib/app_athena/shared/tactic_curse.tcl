#-----------------------------------------------------------------------
# TITLE:
#    tactic_curse.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena_sim(1): Mark II Tactic, Complex User-defined Role-based 
#                   Situation and Events (CURSE)
#
#    This module implements the CURSE tactic. 
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# Tactic: CURSE

tactic define CURSE "Cause a CURSE" {system} {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    variable curse    ;# ID of a CURSE
    variable roles    ;# Mapping of roles to gofers

    # modeChar: mapping between the mode (in each inject) and 
    # mode character used by the driver
    variable modeChar 

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # Initialize as tactic bean
        next

        # Set mapping from mode name to mode character
        set modeChar(persistent) P
        set modeChar(transient)  T

        # Initialize state variables
        set curse    ""
        set roles    ""

        # Initial state is invalid (no curse, roles)
        my set state invalid

        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    # No ObligateResources method is required; the CURSE uses no resources.

    method SanityCheck {errdict} {
        # FIRST check for existence of the CURSE
        set exists [curse exists $curse]

        # NEXT, the curse this tactic uses may have been deleted, disabled,
        # or invalid
        if {$curse eq ""} {
            dict set errdict curse \
                "No curse selected."
        } elseif {!$exists} {
            dict set errdict curse \
                "No such curse: \"$curse\"."
        } else {
            set state [curse get $curse state]

            if {$state ne "normal"} {
                dict set errdict curse \
                    "Curse $curse is $state."
            }
        }

        # NEXT, it exists and is "normal", are the roles good?
        
        # Make sure it is a rolemap
        set isrolemap 0

        if {[catch {
            set roles [::projectlib::rolemap validate $roles]
        } result]} {
            dict set errdict roles $result
        } else {
            set isrolemap 1
        }

        if {$isrolemap && $exists && $state eq "normal"} {
            set keys [dict keys $roles]

            set badr [list]
            # NEXT, roles this tactic uses may have been deleted
            foreach role $keys {
                if {$role ni [curse rolenames $curse]} {
                    lappend badr "Role $role no longer exists."
                }
            }

            # NEXT, all roles must be accounted for
            foreach role [curse rolenames $curse] {
                if {$role ni $roles} {
                    lappend badr "Role $role is not defined."
                }
            }

            # NEXT, the roletype must not change out from underneath
            # the tactic
            foreach role $keys {
                set gtype [dict get [dict get $roles $role] _type]
                if {$role in [curse rolenames $curse] &&
                    $gtype ne [inject roletype $curse $role]} {
                    lappend badr "Role type of $role changed."
                }
            }

            if {[llength $badr] > 0} {
                dict set errdict roles [join $badr " "]
            }
        }

        return [next $errdict]
    }

    method narrative {} {
        set narr [curse narrative $curse]
        append narr ". "

        foreach {role goferdict} $roles {
            append narr "$role = "
            append narr [gofer narrative $goferdict]
            append narr ". "
        }

        return $narr
    }

    method execute {} {
        set fdict [dict create]
        dict set fdict curse_id $curse

        rdb eval {
            SELECT * FROM curse_injects
            WHERE curse_id=$curse AND state='normal'
        } idata {
            array unset parms
            set parms(inject_type) $idata(inject_type)

            switch -exact -- $idata(inject_type) {
                HREL {
                    # Change to horizontal relationships of group(s) in
                    # f with group(s) in g
                    set parms(f)    [gofer eval [dict get $roles $idata(f)]]
                    set parms(g)    [gofer eval [dict get $roles $idata(g)]]
                    set parms(mode) $modeChar($idata(mode))
                    set parms(mag)  $idata(mag)

                    if {$parms(f) eq "" || $parms(g) eq ""} {
                        log detail tactic \
                            "$idata(curse_id) inject $idata(inject_num) did not execute because one or more roles are empty."
                        continue
                    }
                }

                VREL {
                    # Change to verticl relationships of group(s) in
                    # g with actor(s) in a
                    set parms(g)    [gofer eval [dict get $roles $idata(g)]]
                    set parms(a)    [gofer eval [dict get $roles $idata(a)]]
                    set parms(mode) $modeChar($idata(mode))
                    set parms(mag)  $idata(mag)

                    if {$parms(g) eq "" || $parms(a) eq ""} {
                        log detail tactic \
                            "$idata(curse_id) inject $idata(inject_num) did not execute because one or more roles are empty."
                        continue
                    }
                }

                COOP {
                    # Change to cooperation of CIV group(s) in f
                    # with FRC group(s) in g
                    set parms(f)    [gofer eval [dict get $roles $idata(f)]]
                    set parms(g)    [gofer eval [dict get $roles $idata(g)]]
                    set parms(mode) $modeChar($idata(mode))
                    set parms(mag)  $idata(mag)

                    if {$parms(f) eq "" || $parms(g) eq ""} {
                        log detail tactic \
                            "$idata(curse_id) inject $idata(inject_num) did not execute because one or more roles are empty."
                        continue
                    }
                }

                SAT {
                    # Change of satisfaction of CIV group(s) in g
                    # with concern c
                    set parms(g)    [gofer eval [dict get $roles $idata(g)]]
                    set parms(c)    $idata(c)
                    set parms(mode) $modeChar($idata(mode))
                    set parms(mag)  $idata(mag)

                    if {$parms(g) eq ""} {
                        log detail tactic \
                            "$idata(curse_id) inject $idata(inject_num) did not execute because one or more roles are empty."
                        continue
                    }
                }

                default {
                    #Should never happen
                    error "Unrecognized inject type: $idata(inject_type)"
                }
            }

            # NEXT, set the inject information in the firing dict
            dict set fdict injects $idata(inject_num) [array get parms]
        }
        
        # NEXT, it's possible that gofers in every inject returned an empty
        # list, in which case the tactic executes trivially.
        if {![dict exists $fdict injects]} {
            log detail tactic \
                "$idata(curse_id) has no executable injects."
            return
        }

        driver::CURSE assess $fdict
    }
}

# TACTIC:CURSE
#
# Creates/Updates CURSE tactic.

myorders define TACTIC:CURSE {
    meta title      "Tactic: CURSE"
    meta sendstates PREP
    meta parmlist   {tactic_id name curse roles}

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "CURSE" -for curse
        curse curse

        rc "" -for roles -span 2
        roles roles -rolespeccmd {curse rolespec $curse}
    }


    method _validate {} {
        # FIRST, prepare the parameters
        my prepare tactic_id  -required -with {::strategy valclass tactic::CURSE}
        my returnOnError

        set tactic [pot get $parms(tactic_id)]

        # More validation takes place on sanity check
        my prepare name  -toupper   -with [list $tactic valName]
        my prepare curse -toupper
        my prepare roles
    }

    method _execute {{flunky ""}} {
        set tactic [pot get $parms(tactic_id)]
        my setundo [$tactic update_ {name curse roles} [array get parms]]
    }
}





