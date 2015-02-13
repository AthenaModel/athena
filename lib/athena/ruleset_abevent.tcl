#-----------------------------------------------------------------------
# TITLE:
#   ruleset_abevent.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   athena(n): Abstract Event rule sets
#
# FIRING DICTIONARY:
#
#   dtype    - The abstract event type, i.e., the rule set name
#   n        - The affected neighborhood
#   coverage - The coverage fraction
#   args     - Event-type-specific parameters and values
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# ruleset_abevent: base class

oo::class create ::athena::ruleset_abevent {
    superclass ::athena::ruleset

    meta sigparms {n}

    #-------------------------------------------------------------------
    # Public Methods

    # assess fdict
    #
    # fdict   - A firing dictionary

    method assess {fdict} {
        if {![my isactive]} {
            [my adb] log warning [my name] "driver type has been deactivated"
            return
        }

        set n [dict get $fdict n]
        if {[[my adb] demog getn $n population] == 0} {
            [my adb] log normal [my name] \
                "skipping, nbhood $n is empty."
            return
        }

        # Assess the event.
        bgcatch {
            [my adb] log detail [my name] $fdict
            my ruleset $fdict
        }

    }

    #-------------------------------------------------------------------
    # Narrative Methods
    

    # sigline signature
    #
    # signature - The driver signature, {n}
    #
    # Returns a one-line description of the driver given its signature
    # values.

    method sigline {signature} {
        lassign $signature n
        return "[my name] in $n"
    }

    # narrative fdict
    #
    # fdict - Firing dictionary; see above.
    #
    # Produces a one-line narrative text string for a given rule firing.

    method narrative {fdict} {
        dict with fdict {}

        return "[my name] in {nbhood:$n} ([string trim [percent $coverage]])"
    }

    # detail fdict 
    #
    # fdict - Firing dictionary; see above.
    # ht    - An htools(n) buffer
    #
    # Produces a narrative HTML paragraph including all fdict information.

    method detail {fdict ht} {
        dict with fdict {}

        set pcov [string trim [percent $coverage]]

        $ht putln "An abstract event of type [my name]"

        $ht putln "has occurred in neighborhood\n"
        $ht link my://app/nbhood/$n $n
        $ht put " with $pcov coverage."

        $ht para
    }

    #-------------------------------------------------------------------
    # Helper Methods

    # satinput flist cov pt con mag ?con mag...?
    #
    # flist - The groups affected
    # cov   - The coverage fraction
    # pt    - P or T
    # con   - The affected concern
    # mag   - The nominal magnitude
    #
    # Enters satisfaction inputs for flist and cov.

    method satinput {flist cov pt args} {
        assert {[llength $args] != 0 && [llength $args] % 2 == 0}

        set nomCov [parm get dam.abevent.nominalCoverage]
        let mult   {$cov/$nomCov}

        set result [list]
        foreach {con mag} $args {
            lappend result $con [mag* $mult $mag]
        }

        my sat $pt $flist {*}$result
    }

    # liking g n
    #
    # Returns a list of the civgroups in n that like group g (R >= 0.2)

    method liking {g n} {
        return [[my adb] eval {
            SELECT C.g AS f
            FROM gui_civgroups AS C
            JOIN uram_hrel AS U ON (U.f = C.g)
            WHERE U.g = $g 
            AND   C.n = $n
            AND   C.population > 0
            AND   U.hrel >= 0.2
        }]
    }

    # disliking g n
    #
    # Returns a list of the civgroups in n that dislike group g (R <= -0.2)

    method disliking {g n} {
        return [[my adb] eval {
            SELECT C.g AS f
            FROM gui_civgroups AS C
            JOIN uram_hrel AS U ON (U.f = C.g)
            WHERE U.g = $g 
            AND   C.n = $n
            AND   C.population > 0
            AND   U.hrel <= 0.2 
        }]
    }
}


#-------------------------------------------------------------------
# Rule Set: ACCIDENT
#
# Abstract Event: A small disaster in a neighborhood.

oo::class create ::athena::ruleset_ACCIDENT {
    superclass ::athena::ruleset_abevent

    meta name ACCIDENT

    method ruleset {fdict} {
        dict with fdict {}

        set flist [[my adb] demog gIn $n]

        my rule ACCIDENT-1-1 $fdict {true} {
            my satinput $flist $coverage T \
                SFT XS-
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: DEMO
#
# Abstract Event: A non-violent demonstration in a neighborhood.
#
# This event is more complex than the others, and provides its own
# sigline, narrative, and detail methods.

oo::class create ::athena::ruleset_DEMO {
    superclass ::athena::ruleset_abevent

    meta name     DEMO
    meta sigparms {n g}    

    method sigline {signature} {
        lassign $signature n g
        return "[my name] by $g in $n"
    }

    method narrative {fdict} {
        dict with fdict {}
        set pcov "[string trim [percent $coverage]]"

        return "[my name] by {group:$g} in {nbhood:$n} ($pcov)"
    }
    
    # detail fdict 
    #
    # fdict - Firing dictionary; see rulesets, below.
    # ht    - An htools(n) buffer
    #
    # Produces a narrative HTML paragraph including all fdict information.

    method detail {fdict ht} {
        dict with fdict {}

        set pcov [string trim [percent $coverage]]

        $ht putln "Group "
        $ht link my://app/group/$g $g
        $ht putln "is demonstrating in neighborhood\n"
        $ht link my://app/nbhood/$n $n
        $ht put " with $pcov coverage."

        $ht para
    }

    method ruleset {fdict} {
        dict with fdict {}

        set suplist [my liking $g $n]
        set opplist [my disliking $g $n]

        my rule DEMO-1-1 $fdict {
            [llength $suplist] > 0
        } {
            my satinput $suplist $coverage T \
                AUT XS+ \
                CUL M+
        }

        my rule DEMO-1-2 $fdict {
            [llength $opplist] > 0
        } {
            my satinput $opplist $coverage T \
                AUT XS- \
                SFT XS- \
                CUL XS- \
                QOL XS-
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: EXPLOSION
#
# Abstract Event: A large explosion or series of explosions

oo::class create ::athena::ruleset_EXPLOSION {
    superclass ::athena::ruleset_abevent

    meta name EXPLOSION

    method ruleset {fdict} {
        dict with fdict {}

        set flist [[my adb] demog gIn $n]

        my rule EXPLOSION-1-1 $fdict {true} {
            my satinput $flist $coverage P \
                AUT XS-                 \
                SFT L-
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: RIOT
#
# Abstract Event: A riot in a neighborhood.

oo::class create ::athena::ruleset_RIOT {
    superclass ::athena::ruleset_abevent

    meta name RIOT

    method ruleset {fdict} {
        dict with fdict {}

        set flist [[my adb] demog gIn $n]

        my rule RIOT-1-1 $fdict {true} {
            my satinput $flist $coverage P \
                AUT XS-                 \
                SFT L-                  \
                QOL S-
        }
    }
}


#-------------------------------------------------------------------
# Rule Set: VIOLENCE
#
# Abstract Event: Random violence in a neighborhood.

oo::class create ::athena::ruleset_VIOLENCE {
    superclass ::athena::ruleset_abevent

    meta name VIOLENCE

    method ruleset {fdict} {
        dict with fdict {}

        set flist [[my adb] demog gIn $n]

        my rule VIOLENCE-1-1 $fdict {true} {
            my satinput $flist $coverage P \
                SFT XS-
        }
    }
}
