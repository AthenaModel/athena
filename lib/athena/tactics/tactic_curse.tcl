#-----------------------------------------------------------------------
# TITLE:
#    tactic_curse.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena(n): Mark II Tactic, Complex User-defined Role-based 
#                   Situation and Events (CURSE)
#
#    This module implements the CURSE tactic. 
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# Tactic: CURSE

::athena::tactic define CURSE "Cause a CURSE" {system} {
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

    constructor {pot_ args} {
        next $pot_

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
        set exists [[my adb] curse exists $curse]

        # NEXT, the curse this tactic uses may have been deleted, disabled,
        # or invalid
        if {$curse eq ""} {
            dict set errdict curse \
                "No curse selected."
        } elseif {!$exists} {
            dict set errdict curse \
                "No such curse: \"$curse\"."
        } else {
            set state [[my adb] curse get $curse state]

            if {$state ne "normal"} {
                dict set errdict curse \
                    "Curse $curse is $state."
            }
        }

        # NEXT, it exists and is "normal", are the roles good?
        
        # Make sure it is a valid rolespec
        set valid 0

        if {[catch {
            set roles [[my adb] curse rolespec validate $roles]
        } result]} {
            dict set errdict roles $result
        } else {
            set valid 1
        }

        if {$valid && $exists && $state eq "normal"} {
            set keys [dict keys $roles]

            set badr [list]
            # NEXT, roles this tactic uses may have been deleted
            foreach role $keys {
                if {$role ni [[my adb] curse rolenames $curse]} {
                    lappend badr "Role $role no longer exists."
                }
            }

            # NEXT, all roles must be accounted for
            foreach role [[my adb] curse rolenames $curse] {
                if {$role ni $roles} {
                    lappend badr "Role $role is not defined."
                }
            }

            # NEXT, the roletype must not change out from underneath
            # the tactic
            foreach role $keys {
                set gtype [dict get [dict get $roles $role] _type]
                if {$role in [[my adb] curse rolenames $curse] &&
                    $gtype ne [[my adb] inject roletype $curse $role]} {
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
        set narr [[my adb] curse narrative $curse]
        append narr ". "

        foreach {role goferdict} $roles {
            append narr "$role = "
            append narr [[my adb] gofer narrative $goferdict]
            append narr ". "
        }

        return $narr
    }

    method execute {} {
        set fdict [dict create]
        dict set fdict curse_id $curse

        [my adb] eval {
            SELECT * FROM curse_injects
            WHERE curse_id=$curse AND state='normal'
        } idata {
            array unset parms
            set parms(inject_type) $idata(inject_type)

            switch -exact -- $idata(inject_type) {
                HREL {
                    # Change to horizontal relationships of group(s) in
                    # f with group(s) in g
                    set parms(f)    [[my adb] gofer eval [dict get $roles $idata(f)]]
                    set parms(g)    [[my adb] gofer eval [dict get $roles $idata(g)]]
                    set parms(mode) $modeChar($idata(mode))
                    set parms(mag)  $idata(mag)

                    if {$parms(f) eq "" || $parms(g) eq ""} {
                        [my adb] log detail tactic \
                            "$idata(curse_id) inject $idata(inject_num) did not execute because one or more roles are empty."
                        continue
                    }
                }

                VREL {
                    # Change to verticl relationships of group(s) in
                    # g with actor(s) in a
                    set parms(g)    [[my adb] gofer eval [dict get $roles $idata(g)]]
                    set parms(a)    [[my adb] gofer eval [dict get $roles $idata(a)]]
                    set parms(mode) $modeChar($idata(mode))
                    set parms(mag)  $idata(mag)

                    if {$parms(g) eq "" || $parms(a) eq ""} {
                        [my adb] log detail tactic \
                            "$idata(curse_id) inject $idata(inject_num) did not execute because one or more roles are empty."
                        continue
                    }
                }

                COOP {
                    # Change to cooperation of CIV group(s) in f
                    # with FRC group(s) in g
                    set parms(f)    [[my adb] gofer eval [dict get $roles $idata(f)]]
                    set parms(g)    [[my adb] gofer eval [dict get $roles $idata(g)]]
                    set parms(mode) $modeChar($idata(mode))
                    set parms(mag)  $idata(mag)

                    if {$parms(f) eq "" || $parms(g) eq ""} {
                        [my adb] log detail tactic \
                            "$idata(curse_id) inject $idata(inject_num) did not execute because one or more roles are empty."
                        continue
                    }
                }

                SAT {
                    # Change of satisfaction of CIV group(s) in g
                    # with concern c
                    set parms(g)    [[my adb] gofer eval [dict get $roles $idata(g)]]
                    set parms(c)    $idata(c)
                    set parms(mode) $modeChar($idata(mode))
                    set parms(mag)  $idata(mag)

                    if {$parms(g) eq ""} {
                        [my adb] log detail tactic \
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
            [my adb] log detail tactic \
                "$idata(curse_id) has no executable injects."
            return
        }

        [my adb] ruleset CURSE assess $fdict
    }
}

# TACTIC:CURSE
#
# Creates/Updates CURSE tactic.

::athena::orders define TACTIC:CURSE {
    meta title      "Tactic: CURSE"
    meta sendstates PREP
    meta parmlist   {tactic_id name curse roles}

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "CURSE" -for curse
        curse curse

        rc "" -for roles -span 2
        roles roles -rolespeccmd {$adb_ curse rolespec get $curse}
    }


    method _validate {} {
        # FIRST, prepare the parameters
        my prepare tactic_id  -required \
            -with [list $adb strategy valclass ::athena::tactic::CURSE]
        my returnOnError

        set tactic [$adb bean get $parms(tactic_id)]

        # More validation takes place on sanity check
        my prepare name  -toupper   -with [list $tactic valName]
        my prepare curse -toupper
        my prepare roles
    }

    method _execute {{flunky ""}} {
        set tactic [$adb bean get $parms(tactic_id)]
        my setundo [$tactic update_ {name curse roles} [array get parms]]
    }
}





