#-----------------------------------------------------------------------
# TITLE:
#    simevent.tcl
#
# AUTHOR:
#    Will Duquette
#
# PACKAGE:
#   wintel(sim) -- Athena Intel Ingestion Wizard
#
# PROJECT:
#   Athena Regional Stability Simulation
#
# DESCRIPTION:
#    athena_ingest(1): Ingested Simulation Event
#
#    A simevent is a bean that represents a simulation event, to be 
#    ingested into Athena as one or more tactics.
#
#    This module defines a base class for event types.
#
#-----------------------------------------------------------------------

# FIRST, create the class.
oo::class create ::wintel::simevent {
    superclass ::projectlib::bean
}

# NEXT, define class methods
oo::objdefine ::wintel::simevent {
    # List of defined event types
    variable types

    # define typename title script
    #
    # typename - The event type name
    # title    - A event title
    # meaning  - HTML text explaining what the event represents.
    # effects  - HTML text explaining how the event will appear in Athena.
    # script   - The event's oo::define script
    #
    # Defines a new event type.

    method define {typename title meaning effects script} {
        # FIRST, create the new type
        set fullname ::wintel::simevent::$typename
        lappend types $fullname

        oo::class create $fullname {
            superclass ::wintel::simevent
        }

        # NEXT, define the instance members.
        oo::define $fullname $script

        # NEXT, define type commands

        oo::objdefine $fullname [format {
            method typename {} {
                return "%s"
            }

            method title {} {
                return %s
            }

            method meaning {} {
                return %s
            }

            method effects {} {
                return %s
            }
        } $typename [list $title] [list $meaning] [list $effects]]
    }

    # types
    #
    # Returns a list of the available types.  The type is the
    # fully-qualified class name, e.g., ::simevent::FLOOD.

    method types {} {
        return $types
    }

    # typenames
    #
    # Returns a list of the names of the available types.  The
    # type name is the tail of the fully-qualified class name, e.g.,
    # "FLOOD".

    method typenames {} {
        set result [list]

        foreach type [my types] {
            lappend result [$type typename]
        }

        return $result
    }

    # type typename
    #
    # name   A typename
    #
    # Returns the actual type object given the typename.

    method type {typename} {
        return ::wintel::simevent::$typename
    }

    # typedict
    #
    # Returns a dictionary of type objects and titles.

    method typedict {} {
        set result [dict create]

        foreach type [my types] {
            dict set result $type "[$type typename]: [$type title]"
        }

        return $result
    }

    # typenamedict
    #
    # Returns a dictionary of type names and titles.

    method typenamedict {} {
        set result [dict create]

        foreach type [my types] {
            dict set result [$type typename] [$type title]
        }

        return $result
    }

    # normals
    #
    # Returns the IDs of the events whose state is "normal", i.e.,
    # not disabled.

    method normals {} {
        set result [list]

        foreach id [::wintel::pot ids] {
            if {[[::wintel::pot get $id] state] eq "normal"} {
                lappend result $id
            }
        }

        return $result

    }

    #-------------------------------------------------------------------
    # Ingestion

    # ingest inum
    #
    # inum - Ingestion number
    #
    # Ingests events of all types.

    method ingest {inum} {
        # FIRST, ingest the events
        foreach typename [my typenames] {
            my IngestEtype $typename
        }

        # NEXT, assign numbers
        set i 0
        foreach id [::wintel::pot ids] {
            set e [::wintel::pot get $id]
            $e set num $inum-[incr i]
        }
    }

    # IngestEtype typename
    #
    # "Ingests" the messages associated with this event type, using
    # the related wdb view ingest_$typename, and turns them into
    # event instances.

    method IngestEtype {typename} {
        set lastEvent ""

        ::wintel::wdb eval "
            SELECT * FROM ingest_$typename
        " row {
            # FIRST, create a new event.
            set etype [my type $typename]
            set e [::wintel::pot new $etype {*}$row(optlist)]

            # NEXT, if it can extend the previous event,
            # extend the previous event.
            if {$lastEvent ne "" && [$lastEvent canmerge $e]} {
                $lastEvent merge $e
                ::wintel::pot uncreate $e  ;# Reuses $e's bean ID
            } else {
                set lastEvent $e
            }
        }
    }
   
}


# NEXT, define instance methods
oo::define ::wintel::simevent {
    #-------------------------------------------------------------------
    # Instance Variables

    # Every event has a "id", due to being a bean.

    variable num        ;# Event number, used for output reporting.
    variable state      ;# The event's state: normal, disabled, invalid
    variable n          ;# The neighborhood
    variable week       ;# The start week, as a week(n) string.
    variable t          ;# The start week, as a sim week integer.
    variable coverage   ;# The neighborhood coverage fraction
    variable deltap     ;# The change in actual level of service
    variable duration   ;# The duration in weeks.
    variable cidlist    ;# The message ID list: messages that drove this
                         # event.

    # Event types will add their own variables.

    #-------------------------------------------------------------------
    # Constructor

    constructor {} {
        next
        set num      ""
        set state    normal
        set n        ""
        set week     ""
        set t        ""
        set coverage 0.5
        set deltap   -10.0
        set duration 1
        set cidlist  [list]

        set np [namespace path]
        lappend np ::wintel
        namespace path $np
    }

    #-------------------------------------------------------------------
    # Queries
    #
    # These methods will rarely if ever be overridden by subclasses.

    # num
    #
    # Returns the event sequence number.

    method num {} {
        return $num
    }

    # subject
    #
    # Set subject for notifier events.

    method subject {} {
        return "::wintel::simevent"
    }


    # typename
    #
    # Returns the event's typename

    method typename {} {
        return [namespace tail [info object class [self]]]
    }

    # state
    #
    # Returns the event's state: normal, disabled, invalid

    method state {} {
        return $state
    }

    # endtime
    #
    # Returns the sim week in which the event will have its last
    # effect, given t and the duration.

    method endtime {} {
        expr {$t + $duration - 1}
    }

    # intent
    #
    # An "intent" string for the event's strategy block.

    method intent {} {
        return "Event [my num]: [my narrative]"
    }

    #-------------------------------------------------------------------
    # Views

    # view ?view?
    #
    # view - The flavor of view to retrieve
    #
    # Returns a view dictionary.

    method view {{view ""}} {
        set vdict [next $view]

        dict set vdict typename  [my typename]
        dict set vdict narrative [my narrative]
        dict set vdict cidcount  [llength $cidlist]

        return $vdict
    }

    # htmltext
    #
    # Returns an HTML page describing this event, including the 
    # TIGR events associated with it.

    method htmltext {} {
        set ht [htools %AUTO%]

        try {
            $ht hr
            $ht h1 "Event [my num]: [my typename]"
            $ht putln "At time $week: "
            $ht putln [my narrative]
            $ht para

            $ht putln [[info object class [self]] meaning]
            $ht para

            $ht h2 "Event Effects"

            $ht putln [[info object class [self]] effects]

            $ht para

            $ht h2 "Event Sources"

            $ht putln {
                The TIGR messages for which this event was 
                created are listed below.
            }

            $ht para

            foreach cid $cidlist {
                $ht putln [tigr detail $cid]
                $ht para
            }

            return [$ht get]
        } finally {
            $ht destroy            
        }
    }

    #-------------------------------------------------------------------
    # Merging Events

    # canmerge evt
    #
    # evt   - Another event of the same type.
    #
    # This method determines whether this event and the given evt can
    # be merged into a single event.  In general, two events can be 
    # merged if they share the same distinguishing attributes and
    # compatible times.
    #
    # The default assumption is that two events can be merged if they
    # have the same n, and the second event's t is either the same week
    # or only one week later.
    #
    # Other possibilities are as follows:
    #
    # * This event type has additional distinguishing variables, i.e.,
    #   a group or an actor.
    #
    # * This event type can not extend over multiple weeks, and so
    #   t must be the same.

    method canmerge {evt} {
        assert {[$evt typename] eq [my typename]}

        # FIRST, to merge events the distinguishing attributes must
        # be identical.
        foreach var [my distinguishers] {
            if {[$evt cget -$var] ne [my cget -$var]} {
                return 0
            }
        }

        # NEXT, we can always merge events with the same distinguishing
        # attributes that take place at exactly the same time.
        if {[$evt cget -t] == $t} {
            return 1
        }

        # NEXT, we cannot always extend an event over into subsequent
        # weeks.  But if we can, we can merge if the new event takes
        # place during the same duration or in the week immediately
        # following.

        if {[my canextend]} {
            set tnew [$evt cget -t]

            if {$t <= $tnew && $tnew <= $t + $duration} {
                return 1
            }
        }

        # FINALLY, the time settings are inconsistent; no merge.
        return 0
    }

    # merge evt
    #
    # evt   - Another event of the same type.
    #
    # Merges evt into this event, incrementing the duration if
    # necessary.

    method merge {evt} {
        assert {[$evt typename] eq [my typename]}
        assert {[$evt cget -t] <= $t + $duration}

        lappend cidlist {*}[$evt cget -cidlist]

        if {[$evt cget -t] == $t + $duration} {
            incr duration
        }
    }

    #-------------------------------------------------------------------
    # Tools for sending events

    # send order parms....
    #
    # Sends the order and its parameters to the scenario.

    method send {order args} {
        return [flunky senddict gui $order $args]
    }

    # block agent ?dur?
    #
    # agent   - The name of the agent that will own the block.
    # dur     - The duration of the block, overriding the duration attribute.
    #
    # Creates a strategy block for the event to put its tactics in.
    # Returns the block ID.

    method block {agent {dur ""}} {
        # FIRST, get the time options.
        if {$dur eq ""} {
            set dur $duration
        }

        if {$dur == 1} {
            set parms(tmode) AT
            set parms(t1)    $week
        } else {
            set parms(tmode) DURING
            set parms(t1)    $week
            set parms(t2)    "$week+[expr {$dur - 1}]"
        }

        # NEXT, get the other options
        set parms(block_id) [my send STRATEGY:BLOCK:ADD agent $agent]
        set parms(intent)   [my intent]

        # NEXT, send the order.
        my send BLOCK:UPDATE {*}[array get parms]

        # NEXT, return the block ID.
        return $parms(block_id)
    }

    # tactic block_id ttype ?parms...?
    #
    # block_id   - The block ID
    # ttype      - The tactic type
    #
    # Creates a new tactic of the given type, and configures it with
    # the given parameters.

    method tactic {block_id ttype args} {
        set tid [my send BLOCK:TACTIC:ADD block_id $block_id typename $ttype]
        my send TACTIC:$ttype tactic_id $tid {*}$args
    } 
    

    #-------------------------------------------------------------------
    # Operations
    #
    # These methods represent operations whose actions may
    # vary by event type.
    #
    # Subclasses will usually need to override the SanityCheck, narrative,
    # obligate, and IngestEvent methods.  If they define additional
    # distinguishing attributes, they will need to extend 
    # "distinguishers" as well.  If they cannot have an extended duration,
    # then canextend should be override to return false.

    # canedit
    #
    # Returns 1 if it is possible edit events of this kind, and 0
    # otherwise.  We assume that in general you can.

    method canedit {} {
        return 1
    }

    # canextend
    #
    # Returns 1 if the event type allows duration > 1, and 0 otherwise.

    method canextend {} {
        return 1
    }

    # distinguishers
    #
    # Returns the names of the variables that distinguish between
    # events of the same type.

    method distinguishers {} {
        return [list n]
    }

    # narrative
    #
    # Computes a narrative for this event, for use in the GUI.

    method narrative {} {
        return "no narrative defined"
    }

    # sendevent
    #
    # Sends the event to the scenario as a sequence of order calls.

    method sendevent {} {
        # Every event should override this.
        error "sendevent method is undefined"
    }


}


# EVENT:STATE
#
# Sets a event's state to normal or disabled.  The order dialog
# is not generally used.

order define EVENT:STATE {
    title "Set Event State"

    options -sendstates PREP

    form {
        label "Event ID:" -for event_id
        text event_id -context yes

        rc "State:" -for state
        text state
    }
} {
    # FIRST, prepare and validate the parameters
    prepare event_id -required          -with {::wintel::pot valclass ::wintel::simevent}
    prepare state    -required -tolower -type ebeanstate
    returnOnError    -final

    set event [::wintel::pot get $parms(event_id)]

    # NEXT, update the event.
    setundo [$event update_ {state} [array get parms]]
}





