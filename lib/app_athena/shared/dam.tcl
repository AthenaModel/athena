#-----------------------------------------------------------------------
# TITLE:
#    dam.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n) Driver Assessment Model
#
#    This module provides the interface used to define the DAM Rules.
#    These rules assess the implications of various events and situations
#    and provide inputs to URAM (and eventually to other models as well).
#
#    The rule sets themselves are defined in other modules.
#
#-----------------------------------------------------------------------


#-----------------------------------------------------------------------
# dam

snit::type dam {
    # Make it an ensemble
    pragma -hastypedestroy 0 -hasinstances 0


    #-------------------------------------------------------------------
    # Non-Checkpointed Variables
    #
    # These variables are used to accumulate the inputs resulting from
    # a single rule firing.  They do not need to be checkpointed, as
    # they contain only transient data.
    
    # Abbreviation Expansions
    
    typevariable abbrev -array {
        P persistent
        T transient
    }

    # Input array: data related to the rule currently firing
    #
    # driver_id  - The driver ID
    # firing_id  - The RDB ID of this rule firing
    # count      - The count of inputs for the given rule
    # opts       - Dictionary of options and values used as defaults for
    #              the URAM inputs:
    #
    #               -s       - Here effects factor.
    #               -p       - Near effects factor.
    #               -q       - Far effects factor.
    #               -cause   - "Cause" (ecause(n)).

    typevariable input -array {
        firing_id ""
        count     ""
        opts      {}
    }

    #-------------------------------------------------------------------
    # Public Typemethods

    # isactive ruleset
    #
    # ruleset - a Rule Set name
    #
    # Returns 1 if the result is active, and 0 otherwise.

    typemethod isactive {ruleset} {
        return [parmdb get dam.$ruleset.active]
    }

    # rule rule driver_id fdict ?options? expr body
    #
    # rule       - The rule name
    # driver_id  - The driver ID
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

    typemethod rule {rule fdict args} {
        # FIRST, get the firing condition and the body
        set expr [lindex $args end-1]
        set body [lindex $args end]

        # NEXT, evaluate the expression.  If it's false, just return.
        # The rule didn't fire.
        if {![uplevel 1 [list expr $expr]]} {
            return
        }

        # NEXT, get the driver ID
        set driver_id [driver getid $fdict]
        
        # NEXT, get the ruleset name.
        set ruleset [lindex [split $rule -] 0]
        
        # NEXT, get the default option values
        set input(opts) [dict create]
        dict set input(opts) -cause [parmdb get dam.$ruleset.cause]
        dict set input(opts) -s     1.0
        dict set input(opts) -p     [parmdb get dam.$ruleset.nearFactor]
        dict set input(opts) -q     [parmdb get dam.$ruleset.farFactor]
        
        # TBD: Could check validity...but this is not a user API
        foreach {opt val} $args {
            dict set input(opts) $opt $val 
        }

        # NEXT, Create the rule_firings entry and get the firing_id.
        rdb eval {
            INSERT INTO rule_firings(t, driver_id, ruleset, rule, fdict)
            VALUES(now(),
                   $driver_id,
                   $ruleset,
                   $rule,
                   $fdict);
        }
        
        # NEXT, initialize the data needed by the input routines
        set input(driver_id) $driver_id
        set input(firing_id) [rdb last_insert_rowid]
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

    typemethod hrel {mode flist glist mag {note ""}} {
        assert {$mode in {P T}}

        array set opts $input(opts)

        # NEXT, get the input gain.
        set gain [parm get attitude.HREL.gain]
        set mag [qmag value $mag]
        let gmag {$gain * $mag}

        foreach f $flist {
            foreach g $glist {
                if {$f eq $g} {
                    continue
                }

                incr input(count)
                
                rdb eval {
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

    typemethod vrel {mode glist alist mag {note ""}} {
        assert {$mode in {P T}}

        array set opts $input(opts)

        # NEXT, get the input gain.
        set gain [parm get attitude.VREL.gain]
        set mag [qmag value $mag]
        let gmag {$gain * $mag}

        foreach g $glist {
            foreach a $alist {
                incr input(count)

                rdb eval {
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

    typemethod sat {mode glist args} {
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
        set gain [parm get attitude.SAT.gain]

        foreach g $glist {
            foreach {c mag} $args {
                incr input(count)
                set mag [qmag value $mag]
                let gmag {$gain * $mag}

                rdb eval {
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

    typemethod coop {mode flist glist mag {note ""}} {
        assert {$mode in {P T}}

        array set opts $input(opts)

        # NEXT, get the input gain.
        set gain [parm get attitude.COOP.gain]
        set mag [qmag value $mag]
        let gmag {$gain * $mag}

        foreach f $flist {
            foreach g $glist {
                incr input(count)

                rdb eval {
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
}


