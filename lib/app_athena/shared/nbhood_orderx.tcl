#-----------------------------------------------------------------------
# TITLE:
#    nbhood_orderx.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_athena(n): NBHOOD:* Orders
#
#    This is an experimental mock-up of what the NBHOOD:* group orders
#    might look like using the orderx order processing scheme.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# NBHOOD:* Order Classes

# NBHOOD:CREATE
#
# Creates new neighborhoods.

myorders define NBHOOD:CREATE {
    meta title "Create Neighborhood"
    meta sendstates PREP

    meta defaults {
        n            ""
        longname     ""
        local        1
        pcf          1.0
        urbanization URBAN
        controller   NONE
        refpoint     ""
        polygon      ""
    }

    meta form {
        rcc "Neighborhood:" -for n
        text n

        rcc "Long Name:" -for longname
        longname longname 

        rcc "Local Neighborhood?" -for local
        selector local -defvalue YES {
            case YES "Yes" {
                rcc "Prod. Capacity Factor:" -for pcf
                text pcf -defvalue 1.0
            }

            case NO "No" {}
        }

        rcc "Urbanization:" -for urbanization
        enum urbanization -listcmd {eurbanization names} -defvalue URBAN

        rcc "Controller:" -for controller
        enum controller -listcmd {ptype a+none names} -defvalue NONE

        rcc "Reference Point:" -for refpoint
        text refpoint

        rcc "Polygon:" -for polygon
        text polygon -width 40
    }

    meta parmtags {
        refpoint point
        polygon polygon
    }

    method _validate {} {
        my variable rdb

        # FIRST, prepare the parameters
        my prepare n             -toupper            -required -type ident
        my unused  n
        my prepare longname      -normalize
        my prepare local         -toupper            -required -type boolean
        my prepare urbanization  -toupper            -required -type eurbanization
        my prepare controller    -toupper            -required -type {ptype a+none}
        my prepare pcf           -num                          -type rnonneg
        my prepare refpoint      -toupper            -required -type refpoint
        my prepare polygon       -normalize -toupper -required -type refpoly

        my returnOnError

        # NEXT, perform custom checks

        # polygon
        #
        # Must be unique.

        my checkon polygon {
            if {[$rdb exists {
                SELECT n FROM nbhoods
                WHERE polygon = $parms(polygon)
            }]} {
                my reject polygon "A neighborhood with this polygon already exists"
            }
        }

        # refpoint
        #
        # Must be unique

        my checkon refpoint {
            if {[$rdb exists {
                SELECT n FROM nbhoods
                WHERE refpoint = $parms(refpoint)
            }]} {
                my reject refpoint \
                    "A neighborhood with this reference point already exists"
            }
        }

        my returnOnError

        # NEXT, do cross-validation.

        # Both refpoint and polygon are populated and not obviously in error.
        if {![ptinpoly $parms(polygon) $parms(refpoint)]} {
            my reject refpoint "not in polygon"
        }

        # NEXT, If non-local pcf is 0.0, otherwise validate it
        if {!$parms(local)} {
            set parms(pcf) 0.0
        } else {
            my checkon pcf {
                rnonneg validate $parms(pcf)
            }
        }
    }

    method _execute {{flunky ""}} {
        # FIRST, If longname is "", defaults to ID.
        if {$parms(longname) eq ""} {
            set parms(longname) $parms(n)
        }

        # NEXT, create the neighborhood and dependent entities
        lappend undo [nbhood mutate create [array get parms]]
        lappend undo [absit mutate reconcile]

        my setundo [join $undo \n]
    }
}

# NBHOOD:CREATE:RAW
#
# Creates new neighborhoods from raw lat/long data.

myorders define NBHOOD:CREATE:RAW {
    meta title "Create Neighborhood From Raw Data"
    meta sendstates PREP

    meta defaults {
        n            ""
        longname     ""
        local        1
        pcf          1.0
        urbanization URBAN
        controller   NONE
        refpoint     ""
        polygon      ""
    }
    
    meta form {
        rcc "Neighborhood:" -for n
        text n

        rcc "Long Name:" -for longname
        longname longname 

        rcc "Local Neighborhood?" -for local
        selector local -defvalue YES {
            case YES "Yes" {
                rcc "Prod. Capacity Factor:" -for pcf
                text pcf -defvalue 1.0
            }

            case NO "No" {}
        }

        rcc "Urbanization:" -for urbanization
        enum urbanization -listcmd {eurbanization names} -defvalue URBAN

        rcc "Controller:" -for controller
        enum controller -listcmd {ptype a+none names} -defvalue NONE

        rcc "Reference Point:" -for refpoint
        text refpoint

        rcc "Polygon:" -for polygon
        text polygon -width 40
    }

    meta parmtags {
        refpoint point
        polygon polygon
    }

    method _validate {} {
        my variable rdb

        # FIRST, prepare the parameters
        my prepare n             -required -toupper  -type ident
        my unused  n
        my prepare longname      -normalize
        my prepare refpoint      -required  
        my prepare polygon       -required           
        my prepare local         -toupper            -type boolean
        my prepare urbanization  -toupper            -type eurbanization
        my prepare controller    -toupper            -type {ptype a+none}
        my prepare pcf           -num                -type rnonneg

        my returnOnError

        # NEXT, perform custom checks

        # polygon
        #
        
        # Generic tests, this is raw data
        # TBD: Should probably define a type for this.

        my checkon polygon {
            # Must have at least 6 points
            if {[llength $parms(polygon)] < 6} {
                my reject polygon "Not enough coordinate pairs to be lat/long poly"
            }

            # The must be an even number of coordinates
            if {[llength $parms(polygon)] % 2 != 0} {
                my reject polygon "Odd number of points in polygon."
            }
        }

        my returnOnError

        my checkon polygon {
            # The coordinates must make sense
            foreach {lat lon} $parms(polygon) {
                set loc [list $lat $lon]

                try {
                    # latlong validate doesn't throw INVALID.  It should
                    latlong validate $loc
                } on error {result} {
                    my reject polygon $result
                }
            }
        }

        # Must be unique.
        my checkon polygon {
            if {[$rdb exists {
                SELECT n FROM nbhoods
                WHERE polygon = $parms(polygon)
            }]} {
                my reject polygon "A neighborhood with this polygon already exists"
            }
        }


        # refpoint
        #
        # Must be lat/long pair
        my checkon refpoint {
            try {
                latlong validate $parms(refpoint)
            } on error {result} {
                my reject refpoint $result
            }
        }
    
        # Must be unique
        my checkon refpoint {
            if {[$rdb exists {
                SELECT n FROM nbhoods
                WHERE refpoint = $parms(refpoint)
            }]} {
                my reject refpoint \
                    "A neighborhood with this reference point already exists"
            }
        }

        my returnOnError

        # NEXT, do cross-validation.

        # Both refpoint and polygon are populated and not obviously in error.
        if {![ptinpoly $parms(polygon) $parms(refpoint)]} {
            my reject refpoint "not in polygon"
        }

        # NEXT, check for missing unrequired parms and default them
        if {$parms(local) eq ""} {
            set parms(local) 1
        }

        if {$parms(pcf) eq ""} {
            set parms(pcf) 1.0
        }

        # NEXT, If non-local pcf is 0.0, otherwise validate it
        if {!$parms(local)} {
            set parms(pcf) 0.0
        } else {
            my checkon pcf {
                rnonneg validate $parms(pcf)
            }
        }
    }

    method _execute {{flunky ""}} {
        # FIRST, if urbanization is not been supplied, defaults to URBAN
        if {$parms(urbanization) eq ""} {
            set parms(urbanization) URBAN
        }

        # NEXT, If longname is "", defaults to ID.
        if {$parms(longname) eq ""} {
            set parms(longname) $parms(n)
        }

        # NEXT, create the neighborhood and dependent entities
        lappend undo [nbhood mutate create [array get parms]]
        lappend undo [absit mutate reconcile]

        my setundo [join $undo \n]
    }

}

# NBHOOD:DELETE

myorders define NBHOOD:DELETE {
    meta title "Delete Neighborhood"
    meta sendstates PREP

    meta defaults {
        n            ""
    }
    
    meta form {
        rcc "Neighborhood:" -for n
        nbhood n
    }

    method _validate {} {
        my prepare n  -toupper -required -type nbhood
    }

    method _execute {{flunky ""}} {
        if {[my mode] eq "gui"} {
            set answer [messagebox popup \
                            -title         "Are you sure?"                  \
                            -icon          warning                          \
                            -buttons       {ok "Delete it" cancel "Cancel"} \
                            -default       my cancel                           \
                            -onclose       my cancel                           \
                            -ignoretag     NBHOOD:DELETE                    \
                            -ignoredefault ok                               \
                            -parent        [app topwin]                     \
                            -message       [normalize {
                                Are you sure you
                                really want to delete this neighborhood, along
                                with all of the entities that depend upon it?
                            }]]

            if {$answer eq "cancel"} {
                my cancel
            }
        }

        # NEXT, delete the neighborhood and dependent entities
        lappend undo [nbhood mutate delete $parms(n)]
        lappend undo [absit mutate reconcile]

        my setundo [join $undo \n]
    }
}

# NBHOOD:LOWER

myorders define NBHOOD:LOWER {
    meta title "Lower Neighborhood"
    meta sendstates PREP

    meta defaults {
        n            ""
    }
    

    meta form {
        rcc "Neighborhood:" -for n
        nbhood n
    }

    method _validate {} {
        my prepare n  -toupper -required -type nbhood
    }

    method _execute {{flunky ""}} {
        lappend undo [nbhood mutate lower $parms(n)]
        lappend undo [absit mutate reconcile]

        my setundo [join $undo \n]
    }
}

# NBHOOD:RAISE

myorders define NBHOOD:RAISE {
    meta title "Raise Neighborhood"
    meta sendstates PREP

    meta defaults {
        n            ""
    }
    
    meta form {
        rcc "Neighborhood:" -for n
        nbhood n
    }

    method _validate {} {
        my prepare n  -toupper -required -type nbhood
    }

    method _execute {{flunky ""}} {
        lappend undo [nbhood mutate raise $parms(n)]
        lappend undo [absit mutate reconcile]

        my setundo [join $undo \n]
    }
}

# NBHOOD:UPDATE
#
# Updates existing neighborhoods.

myorders define NBHOOD:UPDATE {
    meta title "Update Neighborhood"
    meta sendstates PREP

    meta defaults {
        n            ""
        longname     ""
        local        ""
        pcf          ""
        urbanization ""
        controller   ""
        refpoint     ""
        polygon      ""
    }
    
    meta form {
        rcc "Select Neighborhood:" -for n
        dbkey n -table gui_nbhoods -keys n \
            -loadcmd {$order_ keyload n *}
        
        rcc "Long Name:" -for longname
        longname longname
        
        rcc "Local Neighborhood?" -for local
        selector local -defvalue YES {
            case YES "Yes" {
                rcc "Prod. Capacity Factor:" -for pcf
                text pcf -defvalue 1.0
            }

            case NO "No" {}
        }  

        rcc "Urbanization:" -for urbanization
        enum urbanization -listcmd {eurbanization names}

        rcc "Controller:" -for controller
        enum controller -listcmd {ptype a+none names}

        rcc "Reference Point:" -for refpoint
        text refpoint

        rcc "Polygon:" -for polygon
        text polygon -width 40
    }

    meta parmtags {
        refpoint point
        polygon polygon
    }

    method _validate {} {
        my variable rdb
        
        # FIRST, prepare the parameters
        my prepare n            -toupper   -required -type nbhood
        my prepare longname     -normalize
        my prepare local        -toupper             -type boolean
        my prepare urbanization -toupper             -type eurbanization
        my prepare controller   -toupper             -type {ptype a+none}
        my prepare pcf          -num                 -type rnonneg
        my prepare refpoint     -toupper             -type refpoint
        my prepare polygon      -normalize -toupper  -type refpoly

        my returnOnError

        # NEXT, validate the other parameters

        # polygon
        #
        # Must be unique

        my checkon polygon {
            $rdb eval {
                SELECT n FROM nbhoods
                WHERE polygon = $parms(polygon)
            } {
                if {$n ne $parms(n)} {
                    my reject polygon \
                        "A neighborhood with this polygon already exists"
                }
            }
        }

        # refpoint
        #
        # Must be unique

        my checkon refpoint {
            $rdb eval {
                SELECT n FROM nbhoods
                WHERE refpoint = $parms(refpoint)
            } {
                if {$n ne $parms(n)} {
                    my reject polygon \
                        "A neighborhood with this reference point already exists"
                }
            }
        }

        my returnOnError

        # NEXT, is the refpoint in the polygon?
        $rdb eval {SELECT refpoint, polygon FROM nbhoods WHERE n = $parms(n)} {}

        if {$parms(refpoint) ne ""} {
            set refpoint $parms(refpoint)
        }

        if {$parms(polygon) ne ""} {
            set polygon $parms(polygon)
        }

        if {![ptinpoly $polygon $refpoint]} {
            my reject refpoint "not in polygon"
        }
        
    }

    method _execute {{flunky ""}} {
        # FIRST, If non-local pcf is 0.0
        if {$parms(local) ne "" && !$parms(local)} {
            set parms(pcf) 0.0
        }

        # NEXT, modify the neighborhood
        lappend undo [nbhood mutate update [array get parms]]
        lappend undo [absit mutate reconcile]

        my setundo [join $undo \n]
    }
}

# NBHOOD:UPDATE:MULTI
#
# Updates multiple neighborhoods.

myorders define NBHOOD:UPDATE:MULTI {
    meta title "Update Multiple Neighborhoods"
    meta sendstates PREP

    meta defaults {
        ids          ""
        local        ""
        urbanization ""
        controller   ""
        pcf          ""
    }
    
    meta form {
        rcc "Neighborhoods:" -for ids
        dbmulti ids -table gui_nbhoods -key id -context yes \
            -loadcmd {$order_ multiload ids *}

        rcc "Local Neighborhood?" -for local
        enum local -listcmd {eyesno names}

        rcc "Urbanization:" -for urbanization
        enum urbanization -listcmd {eurbanization names}

        rcc "Controller:" -for controller
        enum controller -listcmd {ptype a+none names}

        rcc "Prod. Capacity Factor:" -for pcf
        text pcf
    }

    method _validate {} {
        my variable rdb

        # FIRST, prepare the parameters
        my prepare ids          -toupper -required -listof nbhood
        my prepare local        -toupper           -type   boolean
        my prepare urbanization -toupper           -type   eurbanization
        my prepare controller   -toupper           -type   {ptype a+none}
        my prepare pcf          -num               -type   rnonneg
    }

    method _execute {{flunky ""}} {
        # FIRST, clear the other parameters expected by the mutator
        set parms(longname) ""
        set parms(refpoint) ""
        set parms(polygon)  ""

        # NEXT, modify the neighborhoods
        set undo [list]

        foreach parms(n) $parms(ids) {
            lappend undo [nbhood mutate update [array get parms]]
        }

        lappend undo [absit mutate reconcile]

        my setundo [join $undo \n]
    }
}








