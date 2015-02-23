#-----------------------------------------------------------------------
# TITLE:
#    ruleset.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n) Driver Assessment Ruleset base class
#
#    This module provides the base class for all driver assessment
#    rule sets.  These rules assess the implications of various events 
#    and situations and provide inputs to URAM (and eventually to other 
#    models as well).
#
#    The rule sets themselves are defined in other modules.
#
# META PARAMETERS:
#    Rule sets must define the following meta parameters:
#
#    name     - The rule set name
#    sigparms - The signature parameters in the firing dictionary
#
#    The above are defined automatically by [::athena::ruleset define].
#
#    rules    - A metadict of rule names and title strings.
#
# TBD: global refs: parm, aram
#
#-----------------------------------------------------------------------

# FIRST, create the class
oo::class create ::athena::ruleset

# NEXT, define class methods
oo::objdefine ::athena::ruleset {
    # Dictionary of rule set classes by rule set name.
    variable rulesets

    # define setname script
    #
    # setname  - The rule set name
    # script   - The rule set's oo::define script
    #
    # Defines a new rule set.

    method define {setname sigparms script} {
        # FIRST, create the new type
        set fullname ::athena::ruleset_$setname
        dict set rulesets $setname $fullname

        oo::class create $fullname {
            superclass ::athena::ruleset
        }

        # NEXT, define the instance members.
        oo::define $fullname meta name $setname
        oo::define $fullname meta sigparms $sigparms
        oo::define $fullname $script
    }

    # names
    #
    # Returns a list of the available rule sets

    method names {} {
        return [lsort [dict keys $rulesets]]
    }

    # getclass setname
    #
    # setname  - A rule set name
    #
    # Returns the class name.

    method getclass {setname} {
        return [dict get $rulesets $setname]
    }
}

# NEXT, define instance methods.
oo::define ::athena::ruleset {
    #-------------------------------------------------------------------
    # Instance Variables

    variable adb          ;# The athenadb(n) handle
    variable abbrev       ;# Abbreviation Expansions
    variable input        ;# Data about the current input.

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb   - The athenadb(n) handle
    #
    # Initializes the rule set.

    constructor {adb_} {
        # FIRST, save the athenadb(n) handle
        set adb $adb_

        # NEXT, initialize the variables
        array set abbrev {
            P persistent
            T transient
        }

        # Input array: data related to the rule currently firing
        #
        # driver_id  - The driver ID
        # firing_id  - The $adb ID of this rule firing
        # count      - The count of inputs for the given rule
        # opts       - Dictionary of options and values used as defaults 
        #              for the URAM inputs:
        #
        #               -s       - Here effects factor.
        #               -p       - Near effects factor.
        #               -q       - Far effects factor.
        #               -cause   - "Cause" (ecause(n)).
        array set input {
            driver_id ""
            firing_id ""
            count     ""
            opts      {}
        }
    }
    
    #-------------------------------------------------------------------
    # Public methods

    # isactive
    #
    # Returns 1 if this rule set is active and 0 otherwise.

    method isactive {} {
        return [my parm dam.[my name].active]
    }

    # signature fdict
    # 
    # fdict  - A firing dictionary
    #
    # Returns the signature for the firing dictionary.

    method signature {fdict} {
        set signature [list]

        foreach key [my sigparms] {
            lappend signature [dict get $fdict $key]
        }

        return $signature
    }


    #-------------------------------------------------------------------
    # Private methods for use in rule sets
    
    # adb
    #
    # Returns the ADB

    method adb {} {
        return $adb
    }

    # rule rule fdict ?options? expr body
    #
    # rule       - The rule name
    # fdict      - The firing dictionary
    # expr       - The logical expression; the rule fires if it is true
    # body       - The rule's body
    #
    # The options determine the cause and here, near, and far factors
    # to be used for this rule's URAM inputs.  By default they are read
    # from the parmdb, based on the rule set name, but they can also be
    # overridden by individual rules.
    #
    #   -cause  - The cause
    #   -s      - The here factor, 0.0 to 1.0
    #   -p      - The near factor, 0.0 to 1.0
    #   -q      - The far factor, 0.0 to 1.0

    unexport rule
    method rule {rule fdict args} {
        # FIRST, get the firing condition and the body
        set expr [lindex $args end-1]
        set body [lindex $args end]

        # NEXT, evaluate the expression.  If it's false, just return.
        # The rule didn't fire.
        if {![uplevel 1 [list expr $expr]]} {
            return
        }

        # NEXT, get the rule set name
        set ruleset [my name]
        
        # NEXT, get the driver ID
        set driver_id [$adb ruleset getid $ruleset $fdict]

        # NEXT, get the default option values
        set input(opts) [dict create]
        dict set input(opts) -cause [$adb parm get dam.$ruleset.cause]
        dict set input(opts) -s     1.0
        dict set input(opts) -p     [$adb parm get dam.$ruleset.nearFactor]
        dict set input(opts) -q     [$adb parm get dam.$ruleset.farFactor]
        
        # TBD: Could check validity...but this is not a user API
        foreach {opt val} $args {
            dict set input(opts) $opt $val 
        }

        # NEXT, Create the rule_firings entry and get the firing_id.
        $adb eval {
            INSERT INTO rule_firings(t, driver_id, ruleset, rule, fdict)
            VALUES(now(),
                   $driver_id,
                   $ruleset,
                   $rule,
                   $fdict);
        }
        
        # NEXT, initialize the data needed by the input routines
        set input(driver_id) $driver_id
        set input(firing_id) [$adb last_insert_rowid]
        set input(count) 0      
        
        # NEXT, evaluate the body
        set code [catch {uplevel 1 $body} result catchOpts]

        # Rethrow errors
        if {$code == 1} {
            return {*}$catchOpts $result
        }
    }

    #-------------------------------------------------------------------
    # Attitude Inputs

    # hrel mode flist glist mag ?note?
    #
    # mode   - P or T
    # flist  - A list of one or more groups
    # glist  - A list of one or more groups
    # mag    - A qmag(n) value
    # note   - A brief descriptive note
    #
    # Enters a horizontal relationship input with the given mode 
    # and magnitude for all pairs of groups in flist with glist
    # (but never for a group with itself).

    unexport hrel
    method hrel {mode flist glist mag {note ""}} {
        assert {$mode in {P T}}

        array set opts $input(opts)

        # NEXT, get the input gain.
        set gain [$adb parm get attitude.HREL.gain]
        set mag [qmag value $mag]
        let gmag {$gain * $mag}

        foreach f $flist {
            foreach g $glist {
                if {$f eq $g} {
                    continue
                }

                incr input(count)
                
                $adb eval {
                    INSERT INTO rule_inputs(
                        firing_id, input_id, t, atype, mode,
                        f, g, gain, mag, cause, note)
                    VALUES($input(firing_id), $input(count), now(),
                           'hrel', $mode, $f, $g, $gain, $mag,
                           $opts(-cause), $note)
                }
            
                aram hrel $abbrev($mode) $input(driver_id) $opts(-cause) \
                    $f $g $gmag 
            }
        }
    }

    # vrel mode glist alist mag ?note?
    #
    # mode   - P or T
    # glist  - A list of one or more groups
    # alist  - A list of one or more actors
    # mag    - A qmag(n) value
    # note   - A brief descriptive note
    #
    # Enters a vertical relationship input with the given mode 
    # and magnitude for all pairs of groups in glist with actors
    # in alist.

    unexport vrel
    method vrel {mode glist alist mag {note ""}} {
        assert {$mode in {P T}}

        array set opts $input(opts)

        # NEXT, get the input gain.
        set gain [$adb parm get attitude.VREL.gain]
        set mag [qmag value $mag]
        let gmag {$gain * $mag}

        foreach g $glist {
            foreach a $alist {
                incr input(count)

                $adb eval {
                    INSERT INTO rule_inputs(
                        firing_id, input_id, t, atype, mode,
                        g, a, gain, mag, cause, note)
                    VALUES($input(firing_id), $input(count), now(),
                           'vrel', $mode, $g, $a, $gain, $mag,
                           $opts(-cause), $note)
                }
                
                aram vrel $abbrev($mode) $input(driver_id) $opts(-cause) \
                    $g $a $gmag 
            }
        }
    }

    # sat mode glist c mag ?c mag...? ?note?
    #
    # mode   - P or T
    # glist  - A list of one or more civilian groups
    # c      - A concern
    # mag    - A qmag(n) value
    # note   - A brief descriptive note
    #
    # Enters satisfaction inputs with the given mode for all groups in
    # glist and the concerns and magnitudes as listed.

    unexport sat
    method sat {mode glist args} {
        assert {[llength $args] != 0}
        assert {$mode in {P T}}

        # FIRST, extract a note from the input, if any.
        if {[llength $args] %2 == 1} {
            set note [lindex $args end]
            set args [lrange $args 0 end-1]
        } else {
            set note ""
        }

        # NEXT, get the options.
        array set opts $input(opts)

        # NEXT, get the input gain.
        set gain [$adb parm get attitude.SAT.gain]

        foreach g $glist {
            foreach {c mag} $args {
                incr input(count)
                set mag [qmag value $mag]
                let gmag {$gain * $mag}

                $adb eval {
                    INSERT INTO rule_inputs(
                        firing_id, input_id, t, atype, mode,
                        g, c, gain, mag, cause, s, p, q, note)
                    VALUES($input(firing_id), $input(count), now(),
                           'sat', $mode, $g, $c, $gain, $mag, $opts(-cause),
                           $opts(-s), $opts(-p), $opts(-q), $note)
                }
                
                aram sat $abbrev($mode) $input(driver_id) $opts(-cause) \
                    $g $c $gmag -s $opts(-s) -p $opts(-p) -q $opts(-q)
            }
        }
    }

    # coop mode flist glist mag ?note?
    #
    # mode   - P or T
    # flist  - A list of one or more civilian groups
    # glist  - A list of one or more force groups
    # mag    - A qmag(n) value
    # note   - A brief descriptive note.
    #
    # Enters a cooperation input with the given mode and magnitude
    # for all pairs of groups in flist with glist.

    unexport coop
    method coop {mode flist glist mag {note ""}} {
        assert {$mode in {P T}}

        array set opts $input(opts)

        # NEXT, get the input gain.
        set gain [$adb parm get attitude.COOP.gain]
        set mag [qmag value $mag]
        let gmag {$gain * $mag}

        foreach f $flist {
            foreach g $glist {
                incr input(count)

                $adb eval {
                    INSERT INTO rule_inputs(
                        firing_id, input_id, t, atype, mode,
                        f, g, gain, mag, cause, s, p, q, note)
                    VALUES($input(firing_id), $input(count), now(),
                           'coop', $mode, $f, $g, $gain, $mag, $opts(-cause),
                           $opts(-s), $opts(-p), $opts(-q), $note)
                }
                
                aram coop $abbrev($mode) $input(driver_id) $opts(-cause) \
                    $f $g $gmag -s $opts(-s) -p $opts(-p) -q $opts(-q)
            }
        }
    }

    #-------------------------------------------------------------------
    # Other Helpers

    # parm name
    #
    # Retrieves a parmdb parameter.

    method parm {name} {
        [my adb] parm get $name
    }

    # actor args...
    #
    # Easy access to actor.

    method actor {args} {
        return [[my adb] actor {*}$args]
    }

    # bsys args...
    #
    # Easy access to bsys.

    method bsys {args} {
        return [[my adb] bsys {*}$args]
    }

    # civgroup args...
    #
    # Easy access to civgroup.

    method civgroup {args} {
        return [[my adb] civgroup {*}$args]
    }

    # demog args...
    #
    # Easy access to demog.

    method demog {args} {
        return [[my adb] demog {*}$args]
    }

    # group args...
    #
    # Easy access to group.

    method group {args} {
        return [[my adb] group {*}$args]
    }

    # hook args...
    #
    # Easy access to hook.

    method hook {args} {
        return [[my adb] hook {*}$args]
    }

    # iom args...
    #
    # Easy access to iom.

    method iom {args} {
        return [[my adb] iom {*}$args]
    }

    # mag* multiplier mag
    #
    # multiplier    A numeric multiplier
    # mag           A qmag(n) value
    #
    # Returns the numeric value of mag times the multiplier.

    method mag* {multiplier mag} {
        set result [expr {$multiplier * [qmag value $mag]}]

        if {$result == -0.0} {
            set result 0.0
        }

        return $result
    }

    # mag+ stops mag
    #
    # stops      Some number of "stops"
    # mag        A qmag symbol
    #
    # Returns the symbolic value of mag, moved up or down the specified
    # number of stops, or 0.  I.e., XL +1 stop is XXL; XL -1 stop is L.  
    # Stopping up or down never changes the sign.  Stopping down from
    # from XXXS returns 0; stopping up from XXXXL returns the value
    # of XXXXL.

    method mag+ {stops mag} {
        set symbols [qmag names]
        set index [qmag index $mag]

        if {$index <= 9} {
            # Sign is positive; 0 is XXXXL+, 9 is XXXS+

            let index {$index - $stops}

            if {$index < 0} {
                return [lindex $symbols 0]
            } elseif {$index > 9} {
                return 0
            } else {
                return [lindex $symbols $index]
            }
        } else {
            # Sign is negative; 10 is XXXS-, 19 is XXXXL-

            let index {$index + $stops}

            if {$index > 19} {
                return [lindex $symbols 19]
            } elseif {$index < 10} {
                return 0
            } else {
                return [lindex $symbols $index]
            }
        }


        expr {$stops * [qmag value $mag]}
    }

    # mag/ factor mag
    #
    # factor   - A numeric value
    # mag      - A magnitude symbol
    #
    # Divides |factor| by the value of the magnitude symbol.
    # We use the absolute value so that the magnitude symbol controls
    # the sign.

    method mag/ {factor mag} {
        expr {abs($factor) / [qmag value $mag]}
    }

    # hrel.fg f g
    #
    # f    A group
    # g    Another group
    #
    # Returns the relationship of f with g.

    method hrel.fg {f g} {
        set hrel [[my adb] eval {
            SELECT hrel FROM uram_hrel
            WHERE f=$f AND g=$g
        }]

        return $hrel
    }

    # vrel.ga g a
    #
    # g - A civ group
    # a - An actor
    #
    # Returns the vertical relationship between the group and the 
    # actor.

    method vrel.ga {g a} {
        [my adb] onecolumn {SELECT vrel FROM uram_vrel WHERE g=$g AND a=$a}
    }

}


