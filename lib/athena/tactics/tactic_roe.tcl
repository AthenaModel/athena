#-----------------------------------------------------------------------
# TITLE:
#    tactic_roe.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena(n): Mark II Tactic, ROE
#
#    An ROE tactic assigns a rule of engagement to deployed force personnel
#    along with force ratio thresholds for determining when a force group
#    should change from one posture to another.  Postures can change because 
#    a force group becomes too weak compared to other force groups it is 
#    fighting.  There is no guarantee that the ROE in this tactic is assumed
#    by the force group owned by the actor since it may go into combat too
#    weak.   
#
#-----------------------------------------------------------------------

# FIRST, create the class.
::athena::tactic define ROE "Force Group ROE" {actor} -onlock {
    #-------------------------------------------------------------------
    # Instance Variables

    # Editable Parameters
    variable f           ;# A force group owned by the actor group
    variable g           ;# A force group to engage
    variable nlist       ;# A list of neighborhoods to assume the ROE
    variable roe         ;# The ROE the group should attempt to take
    variable athresh     ;# Force ratio below which posture is defend
    variable dthresh     ;# Force ratio below which posture is withdraw
    variable civc        ;# The concern the force group assumes for civilian 
                          # casualties 

    #-------------------------------------------------------------------
    # Constructor

    constructor {pot_ args} {
        next $pot_

        # Initialize state variables
        set f          ""
        set nlist      [[my adb] gofer NBHOODS blank]
        set g          ""
        set roe        ATTACK
        set athresh    1.0
        set dthresh    0.8
        set civc       HIGH

        # Initial state is invalid (no g, nlist or f)
        my set state invalid

        # Save the options
        my configure {*}$args
    }

    #-------------------------------------------------------------------
    # Operations

    method SanityCheck {errdict} {
        # Check g
        if {$f eq ""} {
            dict set errdict g "No force group selected."
        } elseif {$f ni [[my adb] group ownedby [my agent]]} {
            dict set errdict f \
                "[my agent] does not own a force group called \"$f\"."
        }

        # nlist
        if {[catch {[my adb] gofer NBHOODS validate $nlist} result]} {
            dict set errdict nlist $result
        }

        # f
        if {$g eq ""} {
            dict set errdict g "No enemy group selected."
        } elseif {$g in [[my adb] group ownedby [my agent]]} {
            dict set errdict g \
                "[my agent] can't engage own force group: \"$g\"."
        }

        return [next $errdict]
    }

    method narrative {} {
        set s(f)     [::athena::link make group $f]
        set s(nlist) [[my adb] gofer NBHOODS narrative $nlist]
        set s(g)     [::athena::link make group $g]
        set s(roe)   [eroe longname $roe]
        set s(athresh) [format %.0f%% [expr $athresh * 100.0]]
        set s(dthresh) [format %.0f%% [expr $dthresh * 100.0]]

        set narr "$s(f) will try to $s(roe) $s(g) in $s(nlist). "
        append narr "Force/Enemy ratio: "
        if {[eroe name $roe] eq "ATTACK"} {
            append narr "DEFEND below $s(athresh) and "
        }

        append narr "WITHDRAW below $s(dthresh). "
        append narr "Concern for CIVCAS: $civc."

        return $narr
    }

    #-------------------------------------------------------------------
    # No obligate method is required; the tactic uses no resources

    #-------------------------------------------------------------------
    # Execution

    method execute {} {
        set goodn [list]
        set badn  [list]

        set nbhoods [[my adb] gofer eval $nlist]

        foreach n $nbhoods {
            if {![[my adb] aam hasroe $n $f $g]} {
                [my adb] aam setroe $n $f $g \
                    [list roe $roe athresh $athresh dthresh $dthresh civc $civc]
                lappend goodn $n 
            } else {
                lappend badn $n 
            }
        }

        if {[llength $goodn] == 0} {
            set msg "
                ROE: Actor {actor:[my agent]} ordered {group:$f} to adopt
                an ROE of $roe towards {group:$g} in 
                [[my adb] gofer NBHOODS narrative $nlist], however, $f's 
                ROE were already set in these neighborhoods by higher-priority
                 tactics.
            "

            set tags [list [my agent] $f $g {*}$nbhoods]
            [my adb] sigevent log 2 tactic $msg {*}$tags
        
            return
        }

        set msg "
            ROE: Actor {actor:[my agent]}'s group {group:$f} adopts an ROE
            of $roe towards {group:$g} in [join $goodn {, }].
        "

        if {[llength $badn] > 0} {
            append msg "
                Group {group:$f}'s ROE already set in these neighborhood(s) by
                a prior tactic: [join $badn {, }].
            "
        }

        set tags [list [my agent] $f $g {*}$goodn]
        [my adb] sigevent log 2 tactic $msg {*}$tags

        return 
    }
}

#-----------------------------------------------------------------------
# TACTIC:* orders

# TACTIC:ROE
#
# Updates existing ROE tactic.

::athena::orders define TACTIC:ROE {
    meta title      "Tactic: Force Group ROE"
    meta sendstates PREP
    meta parmlist   {
        tactic_id name f nlist g roe athresh dthresh civc
    }

    meta form {
        rcc "Tactic ID" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "Group:" -for f
        enum f -listcmd {$order_ frcgroupsOwnedByAgent $tactic_id}

        rcc "Neighborhoods:" -for nlist
        gofer nlist -typename NBHOODS

        rcc "Against:" -for g
        enum g -listcmd {$order_ frcgroupsNotOwnedByAgent $tactic_id}

        rcc "ROE:" -for roe
        selector roe {
            case ATTACK "Attempt to Attack" {
                rcc "Attack Threshold Frac:" -for athresh
                text athresh

                rcc "Defend Threshold Frac:" -for dthresh
                text dthresh
            }

            case DEFEND "Attempt to Defend" {
                rcc "Defend Threshold Frac:" -for dthresh
                text dthresh
            }
        }

        rcc "Concern For Civilian Casualties:" -for civc
        enum civc -listcmd {ecivconcern names} -defvalue HIGH
    }


    method _validate {} {
        # FIRST, prepare the parameters
        my prepare tactic_id  -required \
            -with [list $adb strategy valclass ::athena::tactic::ROE]
        my returnOnError

        # NEXT, get the tactic
        set tactic [$adb bean get $parms(tactic_id)]

        my prepare name       -toupper  -with [list $tactic valName]
        my prepare f  
        my prepare nlist
        my prepare g
        my prepare roe        -toupper  -type eroe
        my prepare athresh    -toupper  -type rmagnitude
        my prepare dthresh    -toupper  -type rmagnitude
        my prepare civc       -toupper  -type ecivconcern

        my returnOnError

        # NEXT, do the cross checks
        ::athena::fillparms parms [$tactic view]

        if {$parms(roe) eq "ATTACK"} {
            if {$parms(athresh) < $parms(dthresh)} {
                my reject athresh "Attack threshold must be >= defend threshold."
            }
        }
    }

    method _execute {{flunky ""}} {
        set tactic [$adb bean get $parms(tactic_id)]
        my setundo [$tactic update_ {
            name f nlist g roe athresh dthresh civc
        } [array get parms]]
    }
}







