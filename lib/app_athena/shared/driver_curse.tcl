#-----------------------------------------------------------------------
# TITLE:
#   driver_curse.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#    Athena Complex User-defined Role-based Situations and Events (CURSE)
#    module: CURSE
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# CURSE 

driver type define CURSE {curse_id} {
    #-------------------------------------------------------------------
    # Public Type Methods

    # assess fdict
    #
    # fdict - A CURSE rule firing dictionary; see "ruleset", below.
    #
    # Assesses a particular CURSE.

    typemethod assess {fdict} {
        # FIRST, see if the CURSE driver is deactivated
        set dtype CURSE

        if {![dam isactive $dtype]} {
            log warning $dtype "driver type has been deactivated"
            return
        }
        
        # NEXT, set the driver type in the dictionary
        dict set fdict dtype $dtype

        # NEXT, go through the injects checking for any zero population
        # civilian groups
        dict for {id idict} [dict get $fdict injects] {
            dict with idict {
                array unset idata
                switch -exact -- $inject_type {
                    HREL {
                        # Pare out any zero pop CIV groups
                        set flist [$type GroupsWithPop $f]
                        set glist [$type GroupsWithPop $g]

                        if {[llength $flist] == 0 ||
                            [llength $glist] == 0} {
                                continue
                        }

                        dict set fdict injects $id f $flist
                        dict set fdict injects $id g $glist
                    }

                    VREL {
                        # Pare out any zero pop CIV groups
                        set glist [$type GroupsWithPop $g]

                        if {[llength $glist] == 0} {
                            continue
                        }

                        dict set fdict injects $id g $glist
                    }

                    COOP {
                        # Pare out any zero pop CIV groups, g is FRC grps
                        set flist [$type GroupsWithPop $f]

                        if {[llength $flist] == 0} {
                            continue
                        }

                        dict set fdict injects $id f $flist
                    }

                    SAT {
                        # Pare out any zero pop CIV groups
                        set glist [$type GroupsWithPop $g]

                        if {[llength $glist] == 0} {
                            continue
                        }

                        dict set fdict injects $id g $glist
                    }
                }
            }
        }

        # NEXT, fire the ruleset
        log detail $dtype $fdict
        $type ruleset $fdict
    }

    #--------------------------------------------------------------------
    # Helper Methods

    # GroupsWithPop grps
    #
    # grps  - an arbitrary list of groups defined in Athena
    #
    # This method goes through the list of groups provided and returns
    # only those groups in the list that are either:
    #
    #      * Not a civilian group
    #      * A civilian group with non-zero population
    #
    # The new list is returned (perhaps unchanged, perhaps empty).

    typemethod GroupsWithPop {grps} {
        set glist [list]
        foreach grp $grps {
            if {$grp ni [civgroup names]} {
                lappend glist $grp
            } elseif {[demog getg $grp population]} {
                lappend glist $grp
            }
        }

        return $glist
    }

    #-------------------------------------------------------------------
    # Narrative Type Methods

    # sigline signature
    #
    # signature - The driver signature
    #
    # Returns a one-line description of the driver given its signature
    # values.

    typemethod sigline {signature} {
        # The signature is the curse_id
        return [rdb onecolumn {
            SELECT longname FROM curses WHERE curse_id=$signature
        }]
    }

    # narrative fdict
    #
    # fdict - Firing dictionary
    #
    # Produces a one-line narrative text string for a given rule firing

    typemethod narrative {fdict} {
        dict with fdict {}

        set narr [list]
        dict for {id idict} [dict get $fdict injects] {
            dict with idict {
                switch -exact -- $inject_type {
                    COOP { 
                        set msg \
                            "cooperation of [join $f {, }] with [join $g {, }]" 
                    }
                    HREL { 
                        set msg \
                    "horiz. relationships of [join $f {, }] with [join $g {, }]"
                        }
                    SAT  { 
                        set msg "satisfaction of [join $g {, }] with $c" 
                    }
                    VREL { 
                        set msg \
                    "vert. relationships of [join $g {, }] with [join $a {, }]" 
                    }

                    default {
                        error "unexpected atype: \"$inject_type\""
                    }
                }

                lappend narr $msg
            }
        }

        return "{curse:$curse_id} affects [join $narr {, }]"
    }
    
    # detail fdict 
    #
    # fdict - Firing dictionary
    # ht    - An htools(n) buffer
    #
    # Produces a narrative HTML paragraph including all fdict information.

    typemethod detail {fdict ht} {
        dict with fdict {}

        # FIRST, load the mad data.
        rdb eval {
            SELECT * FROM curses WHERE curse_id=$curse_id
        } curse {}

        $ht link my://app/curse/$curse_id "CURSE $curse_id"
        $ht put ": $curse(longname)"
        $ht para
    }

    #-------------------------------------------------------------------
    # Rule Set: CURSE --
    #    Complex User-defined Role-based Situations and Events

    # fdict - Nested dictionary containing CURSE data
    #
    #   dtype     -> CURSE
    #   curse_id  -> CURSE ID
    #   cause     -> The cause, or UNIQUE for a unique cause
    #   s         -> Here factor
    #   p         -> Near factor
    #   q         -> Far factor
    #   injects   => dictionary of injects
    #             -> inject_num  -> ID of inject
    #             -> inject_type -> COOP | HREL | SAT | VREL
    #             -> mode        -> P | T
    #             -> mag         -> Magnitude (numeric)
    #             -> f           -> groups  (if COOP or HREL)
    #             -> g           -> groups  (all inject types)
    #             -> c           -> concern (if SAT)
    #             -> a           -> actors  (if VREL)
    #
    # Executes the rule set for the magic input

    typemethod ruleset {fdict} {
        dict with fdict {}

        rdb eval {
            SELECT * FROM curses WHERE curse_id=$curse_id
        } data {}

        # UNIQUE causes get set to the empty string causing URAM to
        # associate the cause to the driver
        if {$data(cause) eq "UNIQUE"} {
            set data(cause) ""
        }

        lappend opts \
            -cause $data(cause) \
            -s     $data(s)     \
            -p     $data(p)     \
            -q     $data(q)

        # Rule fires trivially
        dam rule CURSE-1-1 $fdict {*}$opts {1} {
            dict for {id idict} [dict get $fdict injects] {
                dict with idict {
                    switch -exact -- $inject_type {
                        COOP { dam coop $mode $f $g $mag }
                        HREL { dam hrel $mode $f $g $mag }
                        SAT  { dam sat  $mode $g $c $mag }
                        VREL { dam vrel $mode $g $a $mag }
                    }
                }
            }
        }
    }
}


