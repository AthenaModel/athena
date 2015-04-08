#-----------------------------------------------------------------------
# TITLE:
#    tactic_hide.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena(n): Mark II Tactic HIDE
#
#    This tactic is used by actors to attempt to hide an owned force
# group in one or more neighborhood(s).  The Athena Attrition Model 
# (AAM) takes into account whether a force group is hiding when computing
# the number of troops actually involved in combat.  Essentially, hiding
# force groups have fewer personnel involved than they otherwise would
# have.
#    
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# Tactic: HIDE

::athena::tactic define HIDE "Hide Force Group" {actor} -onlock {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    variable f         ;# A force group owned by the actor
    variable nlist     ;# A NBHOODS gofer value

    #-------------------------------------------------------------------
    # Constructor
    constructor {pot_ args} {
        next $pot_

        # NEXT, Initialize state variables
        set f    {}
        set nlist [[my adb] gofer NBHOODS blank]

        # NEXT, Initial state is invalid (empty f, nlist and glist)
        my set state invalid

        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations
    
    method SanityCheck {errdict} {
        # f
        if {$f eq ""} {
            dict set errdict f \
                "No force group selected."
        } elseif {$f ni [[my adb] group ownedby [my agent]]} {
            dict set errdict f \
                "[my agent] does not own a force group called \"$f\"."
        }

        # nlist

        if {[catch {[my adb] gofer NBHOODS validate $nlist} result]} {
            dict set errdict nlist $result
        }

        return [next $errdict]
    }


    method narrative {} {
        set fgrp [::athena::link make group $f]

        set result "Group $fgrp attempts to hide its personnel in"
        append result  " [[my adb] gofer NBHOODS narrative $nlist]."

        return $result
    }

    method execute {} {
        set nbhoods [[my adb] gofer eval $nlist]

        set goodn   [list]
        set badn    [list]
        set attackn [list]
        set defendn [list]

        foreach n $nbhoods {
            if {![[my adb] aam hasattack $n $f]} {
                lappend defendn $n
            } else {
                lappend attackn $n
            }
        }

        if {[llength $defendn] == 0} {
            set msg "
                HIDE: Actor {actor:[my agent]} ordered {group:$f} to hide
                in [[my adb] gofer NBHOODS narrative $nlist], however, $f's
                personnel were already ordered to assume an ATTACK ROE in these
                neighborhoods.
            "

            set tags [list [my agent] $f {*}$nbhoods]
            [my adb] sigevent log 2 tactic $msg {*}$tags

            return
        }

        foreach n $defendn {
            if {[[my adb] aam hiding $n $f]} {
                lappend badn $n
            } else {
                lappend goodn $n
            }
        }

        foreach n $goodn {
            [my adb] aam hide $n $f
        }

        if {[llength $goodn] == 0} {
            set msg "
                HIDE: Actor {actor:[my agent]} ordered {group:$f} to hide
                in: [join $defendn {, }], however, $f's 
                personnel were already set to hide in these neighborhoods.
            "

            if {[llength $attackn] > 0} {
                append msg "
                    Group $f cannot hide in [join $attackn {, }] since $f
                    was given an ROE of ATTACK.
                "
            }

            set tags [list [my agent] $f {*}$nbhoods]
            [my adb] sigevent log 2 tactic $msg {*}$tags
        
            return
        }

        set msg "
            HIDE: Actor {actor:[my agent]}'s group {group:$f} hides
            in [join $goodn {, }].
        "

        if {[llength $attackn] > 0} {
            append msg "
                Group $f will not hide in [join $attackn {, }] since it has
                already been given an ATTACK ROE there by a prior tactic.
            "
        }

        if {[llength $badn] > 0} {
            append msg "
                Group {group:$f} already set to hide in [join $badn {, }] 
                by a prior tactic.
            "
        }
        
        set tags [list [my agent] $f {*}$nbhoods]
        [my adb] sigevent log 2 tactic $msg [my agent] {*}$tags

        return 
    }
}

# TACTIC:HIDE
#
# Updates a HIDE tactic.

::athena::orders define TACTIC:HIDE {
    meta title      "Tactic: Hide Force Group"
    meta sendstates PREP
    meta parmlist   {tactic_id name f nlist}

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Force Group:" -for f
        enum f -listcmd {$order_ frcgroupsOwnedByAgent $tactic_id}

        rcc "Neighborhoods:" -for nlist
        gofer nlist -typename NBHOODS
    }


    method _validate {} {
        # FIRST, prepare and validate the parameters
        my prepare tactic_id -required \
            -with [list $adb strategy valclass ::athena::tactic::HIDE]
        my returnOnError

        set tactic [$adb bean get $parms(tactic_id)]

        my prepare name -toupper -with [list $tactic valName]
        my prepare f    -toupper
        my prepare nlist
    }

    method _execute {{flunky ""}} {
        set tactic [$adb bean get $parms(tactic_id)]
        my setundo [$tactic update_ {
            name f nlist
        } [array get parms]]
    }
}




