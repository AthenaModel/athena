#-----------------------------------------------------------------------
# TITLE:
#   driver_abevent.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Athena Driver Assessment Model (DAM): Abstract Events
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# driver::abevent: Family ensemble

snit::type driver::abevent {
    # Make it an ensemble
    pragma -hasinstances 0

    #-------------------------------------------------------------------
    # Type Variables

    # Pending list: event dictionaries for events that haven't yet been
    # assessed.

    typevariable pending {}
    

    #-------------------------------------------------------------------
    # Public Typemethods

    # create dtype n cov args...
    #
    # dtype    - The abstract event type, i.e., the rule set name
    # n        - The affected neighborhood
    # coverage - The coverage fraction
    # args     - Event-type-specific parameters and values
    #
    # Creates an abstract event given the inputs.  The event is saved
    # in the pending events list for assessment at the end of the tick.

    typemethod create {dtype n coverage args} {
        # Set up the rule set firing dictionary
        dict set fdict dtype      $dtype
        dict set fdict n          $n
        dict set fdict coverage   $coverage

        set fdict [dict merge $fdict $args]

        # Save it for later assessment.
        lappend pending $fdict
    }

    # reset 
    #
    # Clears the pending list.

    typemethod reset {} {
        set pending [list]
    }

    # pending
    #
    # Returns the events in the pending list.

    typemethod pending {} {
        return $pending
    }

    # assess 
    #
    # Assesses all pending abstract events.
    
    typemethod assess {} {
        # FIRST, ensure that the pending list is cleared, even if there's
        # a bug in a ruleset.
        set alist $pending
        set pending [list]

        # NEXT, assess each pending event.
        foreach fdict $alist {
            array set evt $fdict

            set dtype $evt(dtype)

            if {![dam isactive $dtype]} {
                log warning $dtype \
                    "driver type has been deactivated"
                return
            }

            if {[demog getn $evt(n) population] == 0} {
                log normal $dtype \
                    "skipping, nbhood $evt(n) is empty."
                return
            }

            # Assess the event.
            bgcatch {
                log detail $dtype $fdict
                driver::$dtype ruleset $fdict
            }
        }
    }

    #-------------------------------------------------------------------
    # Event definition

    # define name defscript
    #
    # name        - The event driver type name
    # defscript   - The definition script
    #
    # Defines a single event driver type.  All required public
    # subcommands are defined automatically.  The driver type must
    # define the "ruleset" subcommand containing the actual rule set.
    #
    # Note that rule sets can make use of procs defined in the
    # driver::abevent namespace.

    typemethod define {name defscript} {
        # FIRST, define the shared definitions
        set footer "
            delegate typemethod sigline   using {driver::abevent %m $name}
            delegate typemethod narrative using {driver::abevent %m}
            delegate typemethod detail    using {driver::abevent %m}

            typeconstructor {
                namespace path ::driver::abevent::
            }
        "

        driver type define $name {n} "$defscript\n$footer" 
    }

    #-------------------------------------------------------------------
    # Narrative Type Methods

    # sigline dtype signature
    #
    # dtype     - The driver type
    # signature - The driver signature, {n}
    #
    # Returns a one-line description of the driver given its signature
    # values.

    typemethod sigline {dtype signature} {
        lassign $signature n
        return "$dtype in $n"
    }

    # narrative fdict
    #
    # fdict - Firing dictionary; see [create], above.
    #
    # Produces a one-line narrative text string for a given rule firing.

    typemethod narrative {fdict} {
        dict with fdict {}

        return "$dtype in {nbhood:$n} ([string trim [percent $coverage]])"
    }
    
    # detail fdict 
    #
    # fdict - Firing dictionary; see rulesets, below.
    # ht    - An htools(n) buffer
    #
    # Produces a narrative HTML paragraph including all fdict information.

    typemethod detail {fdict ht} {
        dict with fdict {}

        set pcov [string trim [percent $coverage]]

        $ht putln "An abstract event of type $dtype"

        $ht putln "has occurred in neighborhood\n"
        $ht link my://app/nbhood/$n $n
        $ht put " with $pcov coverage."

        $ht para
    }

    #-------------------------------------------------------------------
    # Helper Routines

    # satinput flist cov pt con mag ?con mag...?
    #
    # flist - The groups affected
    # cov   - The coverage fraction
    # pt    - P or T
    # con   - The affected concern
    # mag   - The nominal magnitude
    #
    # Enters satisfaction inputs for flist and cov.

    proc satinput {flist cov pt args} {
        assert {[llength $args] != 0 && [llength $args] % 2 == 0}

        set nomCov [parmdb get dam.abevent.nominalCoverage]
        let mult   {$cov/$nomCov}

        set result [list]
        foreach {con mag} $args {
            lappend result $con [mag* $mult $mag]
        }

        dam sat $pt $flist {*}$result
    }

    # liking g n
    #
    # Returns a list of the civgroups in n that like group g (R >= 0.2)

    proc liking {g n} {
        return [rdb eval {
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

    proc disliking {g n} {
        return [rdb eval {
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

driver::abevent define ACCIDENT {
    typemethod ruleset {fdict} {
        dict with fdict {}

        set flist [demog gIn $n]

        dam rule ACCIDENT-1-1 $fdict {true} {
            satinput $flist $coverage T \
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

driver type define DEMO {n g} {
    typeconstructor {
        namespace path ::driver::abevent::
    }

    # sigline dtype signature
    #
    # dtype     - The driver type
    # signature - The driver signature, {n}
    #
    # Returns a one-line description of the driver given its signature
    # values.

    typemethod sigline {signature} {
        lassign $signature n g
        return "DEMO by $g in $n"
    }

    # narrative fdict
    #
    # fdict - Firing dictionary; see [create], above.
    #
    # Produces a one-line narrative text string for a given rule firing.

    typemethod narrative {fdict} {
        dict with fdict {}
        set pcov "[string trim [percent $coverage]]"

        return "$dtype by {group:$g} in {nbhood:$n} ($pcov)"
    }
    
    # detail fdict 
    #
    # fdict - Firing dictionary; see rulesets, below.
    # ht    - An htools(n) buffer
    #
    # Produces a narrative HTML paragraph including all fdict information.

    typemethod detail {fdict ht} {
        dict with fdict {}

        set pcov [string trim [percent $coverage]]

        $ht putln "Group "
        $ht link my://app/group/$g $g
        $ht putln "is demonstrating in neighborhood\n"
        $ht link my://app/nbhood/$n $n
        $ht put " with $pcov coverage."

        $ht para
    }

    typemethod ruleset {fdict} {
        dict with fdict {}

        set suplist [liking $g $n]
        set opplist [disliking $g $n]

        dam rule DEMO-1-1 $fdict {
            [llength $suplist] > 0
        } {
            satinput $suplist $coverage T \
                AUT XS+ \
                CUL M+
        }

        dam rule DEMO-1-2 $fdict {
            [llength $opplist] > 0
        } {
            satinput $opplist $coverage T \
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

driver::abevent define EXPLOSION {
    typemethod ruleset {fdict} {
        dict with fdict {}

        set flist [demog gIn $n]

        dam rule EXPLOSION-1-1 $fdict {true} {
            satinput $flist $coverage P \
                AUT XS-                 \
                SFT L-
        }
    }
}

#-------------------------------------------------------------------
# Rule Set: RIOT
#
# Abstract Event: A riot in a neighborhood.

driver::abevent define RIOT {
    typemethod ruleset {fdict} {
        dict with fdict {}

        set flist [demog gIn $n]

        dam rule RIOT-1-1 $fdict {true} {
            satinput $flist $coverage P \
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

driver::abevent define VIOLENCE {
    typemethod ruleset {fdict} {
        dict with fdict {}

        set flist [demog gIn $n]

        dam rule VIOLENCE-1-1 $fdict {true} {
            satinput $flist $coverage P \
                SFT XS-
        }
    }
}
