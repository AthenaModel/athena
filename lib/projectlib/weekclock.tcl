#-----------------------------------------------------------------------
# TITLE:
#	weekclock.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#   week(n)-based simclock(i) object.
#
# This package defines a simlock(i) object based on julian weeks.  It
# has only the features required by Athena, as compared to simclock(n)
# which implements a GEEP-like game ratio mechanism and is ultimately
# based on seconds.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported commands

namespace eval ::projectlib:: {
    namespace export weekclock
}


#-----------------------------------------------------------------------
# week Ensemble

snit::type ::projectlib::weekclock {
    #-------------------------------------------------------------------
    # Options
    
    # -tick0
    #
    # The integer tick at the beginning of simulation, nominally 0.
    # Configure -tick0 resets the clock.
    
    option -tick0 -default 0 -configuremethod CfgTick0
    
    method CfgTick0 {opt val} {
        set options($opt) $val
        $self reset
    }

    # -week0
    #
    # A Zulu-time string representing the simulation start date.
    
    option -week0 -default "2012W01" -configuremethod CfgWeek0

    method CfgWeek0 {opt val} {
        # First, set week0 in absolute weeks.
        set info(week0) [week toInteger $val]

        # Next, it's valid, so save it.
        set options($opt) $val
    }

    #-------------------------------------------------------------------
    # Instance variables
    
    # info array
    #
    # week0 - Integer value for -week0 start date.  Initially, 2012W01.
    # t     - The simulation time in ticks, where t >= tick0 and
    #         tick0 corresponds to week0
    # marks - A dictionary of mark names and time ticks.

    variable info -array {
        week0 0
        t     0
        marks {}
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # Save default -week0
        $self configure -week0 $options(-week0)

        # Save user's input
        $self configurelist $args
    }

    #-------------------------------------------------------------------
    # Public methods

    # advance t
    #
    # t  - A time in ticks no less than -tick0.
    #
    # Advances sim time to time t. 
    
    method advance {t} {
        require {[string is integer -strict $t]} \
            "expected integer ticks: \"$t\""
        require {$t >= $options(-tick0)} \
            "expected t >= $options(-tick0), got \"$t\""

        set info(t) $t
        return
    }

    # tick
    #
    # Advances sim time by one tick.
    
    method tick {} {
        incr info(t)
        return
    }

    # reset
    #
    # Resets sim time to tick0.

    method reset {} {
        set info(t) $options(-tick0)
        set info(marks) {}
        return
    }

    # mark set mark ?offset?
    #
    # mark   - A named mark
    # offset - An offset to the current time.
    #
    # Associates the named mark with now+offset.  The mark name
    # can be used as a base time in timespec strings.

    method {mark set} {mark {offset 0}} {
        dict set info(marks) [string toupper $mark] [$self now $offset]
    }

    # mark get mark
    #
    # mark  - A named mark
    #
    # Retrieves the time tick associated with the named mark, or "" if
    # none.

    method {mark get} {mark} {
        set mark [string toupper $mark]
        
        if {[dict exists $info(marks) $mark]} {
            return [dict get $info(marks) $mark]
        } else {
            return ""
        }
    }

    # mark names
    #
    # Retrieves the names of the currently defined marks.

    method {mark names} {} {
        return [dict keys $info(marks)]
    }

    #-------------------------------------------------------------------
    # Queries

    # now ?offset?
    #
    # offset  - Ticks; defaults to 0.
    #
    # Returns the current sim time (plus the offset) in ticks.

    method now {{offset 0}} {
        return [expr {$info(t) + $offset}]
    }

    # delta
    #
    # returns the number of ticks since -tick0, i.e., the number of
    # ticks since simulation began.  On lock, delta = 0.
    
    method delta {} {
        expr {$info(t) - $options(-tick0)}
    }
    
    
    # asString ?offset?
    #
    # offset  - Ticks; defaults to 0.
    #
    # Return the current time (plus the offset) as a time string.

    method asString {{offset 0}} {
        $self toString $info(t) $offset
    }

    #-------------------------------------------------------------------
    # Conversions

    # toString ticks ?offset?
    #
    # ticks      - A sim time in ticks.
    # offset     - Interval in ticks; defaults to 0.
    #
    # Converts the sim time plus offset to a time string.

    method toString {ticks {offset 0}} {
        set week [expr {
            $info(week0) + $ticks + $offset
        }]
        return [week toString $week]
    }

    # fromString wstring
    #
    # wstring    - A week string
    #
    # Converts the week string into a sim time in weeks.

    method fromString {wstring} {
        return [expr {
            [week toInteger $wstring] - $info(week0)
        }]
    }

    # timespec validate spec
    #
    # spec         - A time-spec string
    #
    # Converts a time-spec string to a sim time in ticks.
    #
    # A time-spec string specifies a time in ticks as a base time 
    # optionally plus or minus an offset.  The offset is always in ticks;
    # the base time can be a time in ticks, a week time-string, or
    # a "named" time, e.g., "T0" or "NOW" or a mark name.  If the base time 
    # is omitted, "NOW" is assumed.  For example,
    #
    #    +5             simclock now 5
    #    -5             simclock now -5
    #    <week>+30      Week string time plus 30 ticks
    #    NOW-30         simclock now -30
    #    40             40
    #    40+5           45
    #    T0+45          45
    #    T0             0
    #
    # Note that T0 is equivalent to -tick0.

    method {timespec validate} {spec} {
        # FIRST, split the spec into base time, op, and offset.
        set result [regexp -expanded {
            # FIRST, Start from beginning of string
            ^

            # NEXT, capture the base time, which (at this point)
            # can be any string that doesn't contain +, -, or whitespace.
            # It can, however, be empty.
            ([^-+[:space:]]*)

            # NEXT, skip any amount of white space
            \s*

            # NEXT, capture the offset, if any
            (

            # NEXT, it begins with a + or -, which we need to capture
            ([-+])

            # NEXT, skip any amount of white space
            \s*
 
            # NEXT, the actual offset is an arbitrary integer at least
            # one character long
            (\d+)

            # NEXT, we need 0 or 1 offsets, including the operator and
            # the number.
            )?

            # NEXT, continue to the end of the string.
            $
        } $spec dummy basetime dummy2 op offset]

        if {!$result} {
            throw INVALID \
                "invalid time spec \"$spec\", should be <basetime><+/-><offset>"
        }

        # NEXT, convert the base time to ticks
        set basetime [string toupper $basetime]

        if {$basetime eq "T0"} {
            set t $options(-tick0)
        } elseif {[dict exists $info(marks) $basetime]} {
            set t [dict get $info(marks) $basetime]
        } elseif {$basetime eq "NOW" || $basetime eq ""} {
            set t [$self now]
        } elseif {[string is integer -strict $basetime]} {
            set t $basetime
        } elseif {![catch {$self fromString $basetime} result]} {
            set t $result
        } else {
            if {[dict size $info(marks)] > 0} {
                set marks "\"[join [lsort [dict keys $info(marks)]] {", "}]\", "
            } else {
                set marks ""
            }

            append error \
                "invalid time spec \"$spec\", base time should be " \
                "\"NOW\", \"T0\", ${marks}an integer tick, or a week string"

            throw INVALID $error
        }

        if {$offset ne ""} {
            incr t $op$offset
        }

        return $t
    }
    
    #-----------------------------------------------------------------
    # Checkpoint/Restore
    #
    # This object doesn't implemement the full saveable(i)
    # interface, as it's saved with the sim(sim) module.  However, it
    # is convenient to be able to save and restore the clock's state,
    # and these methods are used for that.
    
    # checkpoint
    #
    # returns the string containing the state of the object.
    
    method checkpoint {} {
        list [array get options] [array get info]
    }
    
    # restore checkpoint
    #
    # checkpoint - A checkpoint string returned by [checkpoint]
    #
    # Restores the state of the clock to the given checkpoint.
    
    method restore {checkpoint} {
        array set options [lindex $checkpoint 0]
        array set info    [lindex $checkpoint 1]
    }
}

