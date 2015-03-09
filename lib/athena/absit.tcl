#-----------------------------------------------------------------------
# TITLE:
#    absit.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n) Abstract Situation module
#
#    This module defines a type, "absit", which is used to
#    manage the collection of abstract situation objects, or absits.
#
#-----------------------------------------------------------------------

snit::type ::athena::absit {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        set adb $adb_
    }

    #-------------------------------------------------------------------
    # Scenario Control
    
    # rebase
    #
    # Create a new scenario prep baseline based on the current simulation
    # state.
    
    method rebase {} {
        # FIRST, Delete all absits that have ended.
        foreach s [$adb eval {
            SELECT s FROM absits WHERE state == 'RESOLVED'
        }] {
            $adb eval {
                DELETE FROM absits WHERE s=$s;
            }
        }

        # NEXT, clean up remaining absits
        foreach {s ts} [$adb eval {
            SELECT s, ts FROM absits WHERE state != 'INITIAL'
        }] {
            $adb eval {
                UPDATE absits
                SET state='INITIAL',
                    ts=now(),
                    inception=0,
                    rduration=CASE WHEN rduration = 0 THEN 0 
                                   ELSE rduration+$ts-now() END;
            }
        }
    }
    
    #-------------------------------------------------------------------
    # Assessment of Attitudinal Effects

    # assess
    #
    # Calls the DAM rule sets for each situation requiring assessment.

    method assess {} {
        # FIRST, delete absits that were resolved during past ticks.
        $adb eval {
            DELETE FROM absits
            WHERE state == 'RESOLVED' AND tr < now()
        }

        # NEXT, Determine the correct state for each absit.  Those in the
        # INITIAL state are now ONGOING, and those ONGOING whose resolution 
        # time has been reached are now RESOLVED.
        set now [adb clock now]

        foreach {s state rduration tr} [$adb eval {
            SELECT s, state, rduration, tr FROM absits
        }] {
            # FIRST, put it in the correct state.
            if {$state eq "INITIAL"} {
                # FIRST, set the state
                $adb eval {UPDATE absits SET state='ONGOING' WHERE s=$s}
            } elseif {$rduration > 0 && $tr == $now} {
                $adb eval {UPDATE absits SET state='RESOLVED' WHERE s=$s}
            }
        }

        # NEXT, assess all absits.
        $adb eval {
            SELECT * FROM absits ORDER BY s
        } sit {
            set dtype $sit(stype)

            # Set up the rule set firing dictionary
            set fdict [dict create]
            dict set fdict dtype     $dtype
            dict set fdict s         $sit(s)
            dict set fdict state     $sit(state)
            dict set fdict n         $sit(n)
            dict set fdict inception $sit(inception)
            dict set fdict coverage  $sit(coverage)
            dict set fdict resolver  $sit(resolver)

            # Assess
            $adb ruleset $dtype assess $fdict
        }

        # NEXT, clear all inception flags.
        $adb eval {UPDATE absits SET inception=0}
    }

    #-------------------------------------------------------------------
    # Queries

    # get s ?parm?
    #
    # s     - A situation ID
    # parm  - An absits column name
    #
    # Retrieves a row dictionary, or a particular column value, from
    # absits.

    method get {s {parm ""}} {
        return [dbget $adb absits s $s $parm]
    }

    # view s ?tag?
    #
    # s     - A situation ID
    # tag   - An optional view tag (ignored)
    #
    # Retrieves a view dictionary for the absit.

    method view {s {tag ""}} {
        return [dbget $adb gui_absits s $s]
    }


    # existsInNbhood n ?stype?
    #
    # n          A neighborhood ID
    # stype      An absit type
    #
    # If stype is given, returns 1 if there's a live absit of the 
    # specified type already present in n, and 0 otherwise.  Otherwise,
    # returns a list of the absit types that exist in n.

    method existsInNbhood {n {stype ""}} {
        if {$stype eq ""} {
            return [$adb eval {
                SELECT stype FROM absits
                WHERE n     =  $n
                AND   state != 'RESOLVED'
            }]
        } else {
            return [$adb exists {
                SELECT stype FROM absits
                WHERE n     =  $n
                AND   state != 'RESOLVED'
                AND   stype =  $stype
            }]
        }
    }


    # absentFromNbhood n
    #
    # n          A neighborhood ID
    #
    # Returns a list of the absits which do not exist in this
    # neighborhood.

    method absentFromNbhood {n} {
        # TBD: Consider writing an lsetdiff routine
        set present [$self existsInNbhood $n]

        set absent [list]

        foreach stype [eabsit names] {
            if {$stype ni $present} {
                lappend absent $stype
            }
        }

        return $absent
    }


    # names
    #
    # List of absit IDs.

    method names {} {
        return [$adb eval {
            SELECT s FROM absits
        }]
    }

    # exists s
    #
    # s  - A situation ID
    #
    # Returns 1 if s is an absit and 0 otherwise.

    method exists {s} {
        return [dbexists $adb absits s $s]
    }


    # validate s
    #
    # s      A situation ID
    #
    # Verifies that s is an absit.

    method validate {s} {
        if {![$self exists $s]} {
            return -code error -errorcode INVALID \
                "Invalid abstract situation ID: \"$s\""
        }

        return $s
    }

    # initial names
    #
    # List of IDs of absits in the INITIAL state.

    method {initial names} {} {
        return [$adb eval {
            SELECT s FROM absits
            WHERE state = 'INITIAL'
        }]
    }


    # initial validate s
    #
    # s      A situation ID
    #
    # Verifies that s is in the INITIAL state

    method {initial validate} {s} {
        if {$s ni [$self initial names]} {
            if {$s in [$self live names]} {
                return -code error -errorcode INVALID \
                    "operation is invalid; time has passed."
            } else {
                return -code error -errorcode INVALID \
                    "not a \"live\" situation: \"$s\""
            }
        }

        return $s
    }

    # live names
    #
    # List of IDs of absits that are still "live"

    method {live names} {} {
        return [$adb eval {
            SELECT s FROM absits WHERE state != 'RESOLVED'
        }]
    }


    # live validate s
    #
    # s      A situation ID
    #
    # Verifies that s is still "live"

    method {live validate} {s} {
        if {$s ni [$self live names]} {
            return -code error -errorcode INVALID \
                "not a \"live\" situation: \"$s\"."
        }

        return $s
    }

    # isinitial s
    #
    # s    - A situation ID
    #
    # Returns 1 if the situation is in the initial state, and 0 otherwise.

    method isinitial {s} {
        expr {[$self get $s state] eq "INITIAL"}
    }

    # islive s
    #
    # s    - A situation ID
    #
    # Returns 1 if the situation is in the live state, and 0 otherwise.

    method islive {s} {
        expr {[$self get $s state] ne "RESOLVED"}
    }

    #-------------------------------------------------------------------
    # Mutators
    #
    # Mutators are used to implement orders that change the scenario in
    # some way.  Mutators assume that their inputs are valid, and returns
    # a script of one or more commands that will undo the change.  When
    # change cannot be undone, the mutator returns the empty string.

    # reconcile
    #
    # Updates absits as neighborhoods and groups change:
    #
    # *  If the "resolver" group no longer exists, that
    #    field is set to "NONE".
    #
    # *  Updates every absit's "n" attribute to reflect the
    #    current state of the neighborhood.
    #
    # TBD: In the long run, I want to get rid of this routine.
    # But that's a big job.  Absits can be created in PREP, and an 
    # absit's neighborhood depends on its location.  As neighborhoods come 
    # and go, an absit's neighborhood really can change; and this needs
    # to be updated at that time.  This routine handles this.

    method reconcile {} {
        set undo [list]

        # FIRST, set resolver to NONE if resolver doesn't exist.
        $adb eval {
            SELECT *
            FROM absits LEFT OUTER JOIN groups 
            ON (absits.resolver = groups.g)
            WHERE absits.resolver != 'NONE'
            AND   longname IS NULL
        } row {
            set row(resolver) NONE

            lappend undo [$self update [array get row]]
        }

        # NEXT, update location for all absits that are out of their
        # neighborhoods.
        foreach {s n location} [$adb eval {
            SELECT s, n, location FROM absits
        }] { 
            set nloc [$adb nbhood find {*}$location]

            if {$nloc ne $n} {
                set newloc [$self PickLocation $s $n]

                $adb eval {
                    UPDATE absits SET location=$newloc
                    WHERE s=$s;
                }

                lappend undo [mymethod RestoreLocation $s $location]
            }
        }

        return [join [lreverse $undo] \n]
    }


    # RestoreLocation s location
    #
    # s        - An absit
    # location - A location in map coordinates
    # 
    # Sets the absit's location.

    method RestoreLocation {s location} {
        # FIRST, save it
        $adb eval { UPDATE absits SET location=$location WHERE s=$s; }
    }



    # create parmdict
    #
    # parmdict     A dictionary of absit parms
    #
    #    stype     - The situation type
    #    n         - The situation's nbhood.
    #    coverage  - The situation's coverage
    #    inception - 1 if there are inception effects, and 0 otherwise.
    #    resolver  - The group that will resolve the situation, or ""
    #    rduration - Auto-resolution duration, in weeks
    #
    # Creates an absit given the parms, which are presumed to be
    # valid.

    method create {parmdict} {
        dict with parmdict {}

        # FIRST, get the remaining attribute values
        set location [$adb nbhood randloc $n]

        if {$rduration eq ""} {
            set rduration [$adb parm get absit.$stype.duration]
        }


        # NEXT, Create the situation.  The start time is the 
        # time of the first assessment. In PREP, that will be t=0; while
        # PAUSED, it will be t+1, i.e., the next time tick; if created
        # by a tactic or by a scheduled order, it will be t, i.e., 
        # right now.

        if {[$adb state] eq "PREP"} {
            set ts [adb clock cget -tick0]
        } elseif {[$adb state] eq "PAUSED"} {
            set ts [adb clock now 1]
        } else {
            set ts [adb clock now]
        }

        if {$rduration ne ""} {
            let tr {$ts + $rduration}
        } else {
            set tr ""
        }

        $adb eval {
            INSERT INTO 
            absits(stype, location, n, coverage, inception, 
                   state, ts, resolver, rduration, tr)
            VALUES($stype, $location, $n, $coverage, $inception,
                   'INITIAL', $ts, $resolver, $rduration,
                   nullif($tr,''))
        }

        set s [$adb last_insert_rowid]

        # NEXT, inform all clients about the new object.
        $adb log detail absit "absit $s: created for $n,$stype,$coverage"

        # NEXT, Return the undo command
        return [mymethod delete $s]
    }

    # delete s
    #
    # s     A situation ID
    #
    # Deletes the situation.  This should be done only if the
    # situation is in the INITIAL state.

    method delete {s} {
        # FIRST, delete the records, grabbing the undo information
        set data [$adb delete -grab absits {s=$s}]

        # NEXT, Return the undo script
        return [list $adb ungrab $data]
    }

    # update parmdict
    #
    # parmdict     A dictionary of entity parms
    #
    #    s           - The situation ID
    #    stype       - A new situation type, or ""
    #    n           - A new neighborhood, or ""
    #    coverage    - A new coverage, or ""
    #    inception   - A new inception, or ""
    #    resolver    - A new resolving group, or ""
    #    rduration   - A new auto-resolution duration, or ""
    #
    # Updates a situation given the parms, which are presumed to be
    # valid.  The situation must be in state INITIAL.

    method update {parmdict} {
        dict with parmdict {}

        # FIRST, get the undo information
        set data [$adb grab absits {s=$s}]

        # NEXT, get the new neighborhood if the location changed.
        if {$n ne ""} {
            set location [$self PickLocation $s $n]
        }

        # NEXT, update duration.
        if {$rduration ne ""} {
            set ts [$self get $s ts]
            let tr {$ts + $rduration}
        } else {
            set tr ""
        }

        # NEXT, update the situation
        $adb eval {
            UPDATE absits
            SET stype     = nonempty($stype,     stype),
                location  = nonempty($location,  location),
                n         = nonempty($n,         n),
                coverage  = nonempty($coverage,  coverage),
                inception = nonempty($inception, inception),
                resolver  = nonempty($resolver,  resolver),
                rduration = nonempty($rduration, rduration),
                tr        = nonempty($tr,        tr)
            WHERE s=$s;
        }

        # NEXT, Return the undo command
        return [list $adb ungrab $data] 
    }


    # move parmdict
    #
    # parmdict     A dictionary of entity parms
    #
    #    s           - The situation ID
    #    location    - A new location (map coords), or ""
    #                  (Must be in same neighborhood.)
    #
    # Updates a situation given the parms, which are presumed to be
    # valid.

    method move {parmdict} {
        dict with parmdict {}

        # FIRST, get the undo information
        set data [$adb grab absits {s=$s}]

        # NEXT, update the situation
        $adb eval {
            UPDATE absits
            SET stype     = nonempty($stype,     stype),
                location  = nonempty($location,  location)
            WHERE s=$s;
        }

        # NEXT, Return the undo command
        return [list $adb ungrab $data] 
    }

    # resolve parmdict
    #
    # parmdict     A dictionary of order parms
    #
    #    s         - The situation ID
    #    resolver  - Group responsible for resolving the situation, or "NONE"
    #                or "".
    #
    # Resolves the situation, assigning credit where credit is due.

    method resolve {parmdict} {
        dict with parmdict {}

        # FIRST, get the undo information
        set data [$adb grab absits {s=$s}]

        # NEXT, update the situation
        $adb eval {
            UPDATE absits
            SET state     = 'RESOLVED',
                resolver  = nonempty($resolver, resolver),
                tr        = now(),
                rduration = now() - ts
            WHERE s=$s;
        }

        # NEXT, Return the undo script
        return [list $adb ungrab $data] 
    }

    # PickLocation s n
    #
    # Finds a location for s in n, returning s's current location
    # if possible.

    method PickLocation {s n} {
        # FIRST, get the old location and neighborhood.
        array set old [$self get $s]

        set oldN [$adb nbhood find {*}$old(location)]

        if {$oldN ne $n} {
            return [$adb nbhood randloc $n]
        } else {
            return $old(location)
        }
    }

    #-------------------------------------------------------------------
    # Order Helpers

    # AbsentTypes n
    #
    # n  - A neighborhood
    #
    # Returns a list of the absit types that are not represented in 
    # the neighborhood.

    method AbsentTypes {n} {
        if {$n ne ""} {
            return [$self absentFromNbhood $n]
        }

        return [list]
    }

    # AbsentTypesBySit s
    #
    # s  - A situation ID
    #
    # Returns a list of the absit types that are not represented in 
    # the neighborhood containing the situation, plus the situation's
    # own type.

    method AbsentTypesBySit {s} {
        if {$s ne ""} {
            set n [$self get $s n]

            set stypes [$self absentFromNbhood $n]
            lappend stypes [$self get $s stype]

            return [lsort $stypes]
        }

        return [list]
    }

    # DefaultDuration fdict stype
    #
    # Returns the default duration for the situation type.

    method DefaultDuration {fdict stype} {
        if {$stype eq ""} {
            return {}
        }
        return [dict create rduration [$adb parm get absit.$stype.duration]]
    }
}

#-------------------------------------------------------------------
# Orders

# ABSIT:CREATE
#
# Creates new absits.

::athena::orders define ABSIT:CREATE {
    meta title "Create Abstract Situation"
    meta sendstates {PREP PAUSED TACTIC}

    meta parmlist {
        n
        stype
        {coverage  1.0 }
        {inception 1   }
        {resolver  NONE}
        rduration
    }

    meta form {
        rcc "Neighborhood:" -for n
        nbhood n

        rcc "Type:" -for stype
        enum stype -listcmd {$adb_ absit AbsentTypes $n} \
                   -loadcmd {$adb_ absit DefaultDuration}

        rcc "Coverage:" -for coverage
        frac coverage -defvalue 1.0

        rcc "Inception?" -for inception
        yesno inception -defvalue 1

        rcc "Resolver:" -for resolver
        enum resolver -listcmd {$adb_ ptype g+none names} -defvalue NONE

        rcc "Duration:" -for rduration
        text rduration
        label "weeks"
    }

    meta parmtags {
        n nbhood
    }

    method _validate {} {
        # FIRST, prepare and validate the parameters
        my prepare n         -toupper   -required -type [list $adb nbhood]
        my prepare stype     -toupper   -required -type eabsit
        my prepare coverage  -num       -required -type rfraction
        my prepare inception -toupper   -required -type boolean
        my prepare resolver  -toupper   -required -type [list $adb ptype g+none]
        my prepare rduration -num                 -type iticks
    
        my returnOnError
    
        # NEXT, additional validation steps.
    
        my checkon coverage {
            if {$parms(coverage) == 0.0} {
                my reject coverage "Coverage must be greater than 0."
            }
        }
    
        my returnOnError
    
        my checkon stype {
            if {[$adb absit existsInNbhood $parms(n) $parms(stype)]} {
                my reject stype \
                    "An absit of this type already exists in this neighborhood."
            }
        }
    }

    method _execute {{flunky ""}} {
        # NEXT, create the situation.
        lappend undo [$adb absit create [array get parms]]
    
        my setundo [join $undo \n]
    }
}


# ABSIT:DELETE
#
# Deletes an absit.

::athena::orders define ABSIT:DELETE {
    meta title      "Delete Abstract Situation"
    meta sendstates {PREP PAUSED}
    meta parmlist   {s}

    meta form {
        rcc "Situation:" -for s
        dbkey s -table gui_absits_initial -keys s -dispcols longid
    }

    meta parmtags {
        s situation
    }


    method _validate {} {
        my prepare s -required -type [list $adb absit initial]
    }

    method _execute {{flunky ""}} {
        lappend undo [$adb absit delete $parms(s)]
        my setundo [join $undo \n]
    }
}


# ABSIT:UPDATE
#
# Updates existing absits.

::athena::orders define ABSIT:UPDATE {
    meta title      "Update Abstract Situation"
    meta sendstates {PREP PAUSED TACTIC} 
    meta parmlist {
        s n stype coverage inception resolver rduration
    }

    meta form {
        rcc "Situation:" -for s
        dbkey s -table gui_absits_initial -keys s -dispcols longid \
            -loadcmd {$order_ keyload s *}

        rcc "Neighborhood:" -for n
        nbhood n

        rcc "Type:" -for stype
        enum stype -listcmd {$adb_ absit AbsentTypesBySit $s}

        rcc "Coverage:" -for coverage
        frac coverage

        rcc "Inception?" -for inception
        yesno inception

        rcc "Resolver:" -for resolver
        enum resolver -listcmd {$adb_ ptype g+none names}

        rcc "Duration:" -for duration
        text rduration
        label "weeks"
    }

    meta parmtags {
        s situation
        n nbhood
    }

    method _validate {} {

        # FIRST, check the situation
        my prepare s  -required -type [list $adb absit initial]
    
        my returnOnError
    
        set stype [$adb absit get $parms(s) stype]
    
        # NEXT, prepare the remaining parameters
        my prepare n         -toupper  -type [list $adb nbhood] 
        my prepare stype     -toupper  -type eabsit
        my prepare coverage  -num      -type rfraction
        my prepare inception -toupper  -type boolean
        my prepare resolver  -toupper  -type [list $adb ptype g+none]
        my prepare rduration -num      -type iticks
    
        my returnOnError
    
        # NEXT, validate the other parameters.
        my checkon stype {
            if {$parms(stype) ne $stype &&
                [$adb absit existsInNbhood $parms(n) $parms(stype)]
            } {
                my reject stype \
                    "An absit of this type already exists in this neighborhood."
            }
        }

        my checkon coverage {
            if {$parms(coverage) == 0.0} {
                my reject coverage "Coverage must be greater than 0."
            }
        }
    }

    method _execute {{flunky ""}} {
        my setundo [$adb absit update [array get parms]]
    }
}


# ABSIT:MOVE
#
# Moves an existing absit.

::athena::orders define ABSIT:MOVE {
    meta title      "Move Abstract Situation"
    meta sendstates {PREP PAUSED}
    meta parmlist   {s location}

    meta parmtags {
        s situation
        location nbpoint
    }

    method _validate {} {
        my prepare s  -required -type [list $adb absit]
    
        my returnOnError
    
        # NEXT, prepare the remaining parameters
        my prepare location  -toupper  -required -type refpoint 
    
        my returnOnError
    
        # NEXT, validate the other parameters.  
    
        my checkon location {
            set n [$adb nbhood find {*}$parms(location)]
    
            if {$n ne [$adb absit get $parms(s) n]} {
                my reject location \
                    "Cannot remove situation from its neighborhood"
            }
        }

    }

    method _execute {{flunky ""}} {
        my setundo [$adb absit move [array get parms]]
    }
}


# ABSIT:RESOLVE
#
# Resolves an absit.

::athena::orders define ABSIT:RESOLVE {
    meta title "Resolve Abstract Situation"
    meta sendstates {PREP PAUSED TACTIC}

    meta defaults {
        s        ""
        resolver ""
    }

    meta form {
        rcc "Situation:" -for s
        dbkey s -table gui_absits -keys s -dispcols longid \
            -loadcmd {$order_ keyload s *}

        rcc "Resolved By:" -for resolver
        enum resolver -listcmd {$adb_ ptype g+none names}
    }

    meta parmtags {
        s situation
    }

    method _validate {} {
        # FIRST, prepare the parameters
        my prepare s         -required -type [list $adb absit live]
        my prepare resolver  -toupper  -type [list $adb ptype g+none]
    }

    method _execute {{flunky ""}} {
        lappend undo [$adb absit resolve [array get parms]]
        
        my setundo [join $undo \n]
    }
}







