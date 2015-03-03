#-----------------------------------------------------------------------
# TITLE:
#    tactic_broadcast.tcl
#
# AUTHOR:
#    Will Duquette
#    Dave Hanks
#
# DESCRIPTION:
#    athena(n): Mark II Tactic, BROADCAST tactic
#
#    This module implements the BROADCAST tactic, which broadcasts 
#    an Info Ops Message (IOM) via a particular Communications Asset
#    Package (CAP).  The message is attributed to actor a, which
#    might be the true source, some other actor, or null.  Preparing
#    the message will have the stated cost, which is separate from
#    the CAP's transmission cost.  The broadcast will have its effect
#    during the subsequent week.
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# Tactic: BROADCAST

::athena::tactic define BROADCAST "Broadcast an Info Ops Message" {actor} -onlock {
    #-------------------------------------------------------------------
    # Instance Variables

    variable cap    ;# A Communication Asset Package
    variable a      ;# An actor
    variable iom    ;# An Information Operations Message
    variable cost   ;# The cost of the broadcast

    variable trans  ;# Transient variables
    
    #------------------------------------------------------------------
    # Constructor

    constructor {pot_ args} {
        next $pot_

        # Initialize state variables
        set cap ""
        set a   ""
        set iom ""
        set cost 0.0

        set trans(cost) 0.0

        my set state invalid

        my configure {*}$args
    }

    #----------------------------------------------------------------
    # Operations

    method SanityCheck {errdict} {
        # cap
        if {$cap eq ""} {
            dict set errdict cap "No CAP selected."
        } elseif {$cap ni [[my adb] cap names]} {
            dict set errdict cap "No such CAP: \"$cap\"."
        }

        # a
        if {$a eq ""} {
            dict set errdict a "No actor selected."
        } elseif {$a ni [[my adb] ptype a+self+none names]} {
            dict set errdict a "No such actor: \"$a\"."
        }

        # iom
        set gotIOM [expr {$iom in [[my adb] iom names]}]

        if {$iom eq ""} {
            dict set errdict iom "No IOM selected."            
        } elseif {!$gotIOM} {
            dict set errdict iom "No such IOM: \"$iom\"."
        } elseif {[iom get $iom state] eq "disabled"} {
            dict set errdict iom "IOM is disabled: \"$iom\"."
        } elseif {[iom get $iom state] eq "invalid"} {
            dict set errdict iom "IOM is invalid: \"$iom\"."
        }

        # NEXT, does the IOM have any valid payloads?
        if {$gotIOM && ![[my adb] onecolumn { 
            SELECT count(payload_num) FROM payloads
            WHERE iom_id=$iom AND state='normal'
        }]} {
            dict set errdict iom "IOM has no valid payloads: \"$iom\"."     
        }

        # NEXT, does the IOM's hook have any valid topics?
        if {$gotIOM && ![[my adb] onecolumn { 
            SELECT count(HT.topic_id) 
            FROM hook_topics AS HT
            JOIN ioms AS I USING (hook_id)
            WHERE I.iom_id=$iom AND HT.state='normal'
        }]} {
            dict set errdict iom "IOM's hook has no valid topics: \"$iom\"."
        }

        return [next $errdict]
    }

    method narrative {} {
        set s(cap) [::athena::link make cap $cap]
        set s(a)   [::athena::link make actor $a]
        set s(iom) [::athena::link make iom $iom]
        set s(cost) "\$[commafmt $cost]"

        set text "Broadcast $s(iom) via $s(cap) with prep cost of $s(cost)"

        if {$a eq "SELF"} {
            append text " and attribute it to self."
        } elseif {$a eq "NONE"} {
            append text " and no attribution."
        } else {
            append text " and attribute it to $s(a)."
        }

        return $text
    }

    method ObligateResources {coffer} {
        # NOTE: We don't check for access to the CAP here; we check
        # at the end of strategy execution, so that GRANT tactics
        # can have their effect.

        # Total cost is prep cost plus cost to use CAP
        set cash [$coffer cash]
        set trans(cost) [expr {$cost + [[my adb] cap get $cap cost]}]

        if {[my InsufficientCash $cash $trans(cost)]} {
            return
        }

        $coffer spend $trans(cost)
    }

    method execute {} {
        # FIRST, spend the cash
        [my adb] cash spend [my agent] BROADCAST $trans(cost)

        # NEXT, Save the broadcast.  It can't take effect yet,
        # as CAP access might be changed by other tactics.
        [my adb] broadcast mark [self]
    }

    # assess
    #
    # This is called at the end of tactic execution, to assess the
    # effects of the attempted broadcast.

    method assess {} {
        # FIRST, does the owner have access to the CAP?
        # If not, refund his money; we're through here.
        if {![[my adb] cap hasaccess $cap [my agent]]} {
            my set execstatus FAIL_RESOURCES
            my Fail CAP "Failed during execution: [my agent] has no access to CAP $cap."
            cash refund [my agent] BROADCAST $trans(cost) 

            # NEXT, log the event
            [my adb] sigevent log 2 tactic "
                BROADCAST: Actor {actor:[my agent]} failed to broadcast
                IOM {iom:$iom} via CAP {cap:$cap}: access denied. 
            " [my agent] $iom $cap

            return
        }
        
        # NEXT, Get the entity tags, for when we log the sigevent.
        set tags [list [my agent] $iom $cap]

        if {$a eq "SELF"} {
            set attribution ", attributing it to self"
            set asource [my agent]
        } elseif {$a eq "NONE"} {
            set attribution " without attribution"
            set asource ""
        } else {
            set attribution ", attributing it to $a"
            set asource $a
            lappend tags $a
        }

        lappend tags \
            [[my adb] eval {SELECT hook_id FROM ioms WHERE iom_id=$iom}]
        lappend tags {*}[[my adb] eval {
            SELECT g,n FROM capcov 
            WHERE k=$cap AND capcov > 0.0
        }]

        # NEXT, set up the dict needed by the IOM rule set.
        set rdict [dict create]
        dict set rdict tsource [my agent]
        dict set rdict cap     $cap
        dict set rdict iom     $iom
        dict set rdict asource $asource

        # NEXT, log the event
        [my adb] sigevent log 2 tactic "
            BROADCAST: Actor {actor:[my agent]} broadcast
            IOM {iom:$iom} via CAP {cap:$cap}$attribution. 
        " {*}$tags

        # NEXT, assess the broadcast.
        ruleset IOM assess $rdict
    }
}

# TACTIC:BROADCAST
#
# Updates a BROADCAST tactic.

::athena::orders define TACTIC:BROADCAST {
    meta title      "Tactic: Broadcast IOM"
    meta sendstates PREP
    meta parmlist   {tactic_id name cap a iom cost}

    meta form {
        rcc "Tactic ID:" -for tactic_id
        text tactic_id -context yes \
            -loadcmd {$order_ beanload}

        rcc "Name:" -for name
        text name -width 20

        rcc "CAP:" -for cap
        cap cap
        
        rcc "Attr. Source:" -for a
        enum a -listcmd {$adb_ ptype a+self+none names} -defvalue SELF

        rcc "Message ID:" -for iom
        enumlong iom -showkeys yes -dictcmd {$adb iom normal namedict}

        rcc "Prep. Cost:"
        text cost
        label "$/week"
    }


    method _validate {} {
        # FIRST, there must be a tactic ID
        my prepare tactic_id  -required \
            -with [list $adb strategy valclass ::athena::tactic::BROADCAST]
        my returnOnError

        # NEXT, get the tactic
        set tactic [$adb bean get $parms(tactic_id)]

        # NEXT, the parameters
        my prepare name     -toupper   -with [list $tactic valName]
        my prepare cap      -toupper   
        my prepare a        -toupper  
        my prepare iom      -toupper   
        my prepare cost     -toupper -type money
    }

    method _execute {{flunky ""}} {
        set tactic [$adb bean get $parms(tactic_id)]
        ::athena::fillparms parms [$tactic view]
        my setundo [$tactic update_ {name cap a iom cost} [array get parms]]
    }
}





