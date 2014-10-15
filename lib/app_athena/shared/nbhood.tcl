#-----------------------------------------------------------------------
# TITLE:
#    nbhood.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Neighborhood Manager
#
#    This module is responsible for managing neighborhoods and operations
#    upon them.  As such, it is a type ensemble.
#
#-----------------------------------------------------------------------

snit::type nbhood {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Components

    typecomponent geo   ;# A geoset, for polygon computations

    #-------------------------------------------------------------------
    # Initialization

    typemethod init {} {
        log detail nbhood "init"

        # FIRST, create the geoset
        set geo [geoset ${type}::geo]

        # NEXT, register to receive dbsync events.
        notifier bind ::sim <DbSyncA> $type [mytypemethod dbsync]

        log detail nbhood "init complete"
    }

    #-------------------------------------------------------------------
    # Notifier Event Handlers

    # dbsync
    #
    # Refreshes the geoset with the current neighborhood data from
    # the database.
    
    typemethod dbsync {} {
        # FIRST, populate the geoset
        $geo clear

        rdb eval {
            SELECT n, polygon FROM nbhoods
            ORDER BY stacking_order
        } {
            # Create the polygon with the neighborhood's name and
            # polygon coordinates; tag it with "nbhood".
            $geo create polygon $n $polygon nbhood
        }

        # NEXT, update the obscured_by fields
        $type SetObscuredBy
    }

    #-------------------------------------------------------------------
    # Delegated methods

    delegate typemethod bbox to geo

    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.


    # find mx my
    #
    # mx,my    A point in map coordinates
    #
    # Returns the short name of the neighborhood which contains the
    # coordinates, or the empty string.

    typemethod find {mx my} {
        return [$geo find [list $mx $my] nbhood]
    }

    # randloc n
    #
    # n       A neighborhood short name
    #
    # Tries to get a random location from the neighborhood.
    # If it fails after ten tries, returns the neighborhood's 
    # reference point.

    typemethod randloc {n} {
        # FIRST, get the neighborhood polygon's bounding box
        foreach {x1 y1 x2 y2} [$geo bbox $n] {}

        # NEXT, no more than 10 tries
        for {set i 0} {$i < 10} {incr i} {
            # Get a random lat/lon
            let x {($x2 - $x1)*rand() + $x1}
            let y {($y2 - $y1)*rand() + $y1}

            # Is it in the neighborhood (taking stacking order
            # into account)?
            set pt [list $x $y]

            if {[geo find $pt] eq $n} {
                return $pt
            }
        }

        # Didn't find one; just return the refpoint.
        return [rdb onecolumn {
            SELECT refpoint FROM nbhoods
            WHERE n=$n
        }]
    }

    # names
    #
    # Returns the list of neighborhood names

    typemethod names {} {
        return [rdb eval {
            SELECT n FROM nbhoods ORDER BY n
        }]
    }

    # fullname n
    #
    # Returns the full name of the neighborhood: "$longname ($n)"

    typemethod fullname {n} {
        return "[$type get $n longname] ($n)"
    }

    # get n ?parm?
    #
    # n  - A neighborhood ID
    #
    # Returns the neighborhood's data dictionary; or the specific
    # parameter, if given.

    typemethod get {n {parm ""}} {
        # FIRST, get the data
        rdb eval {SELECT * FROM nbhoods WHERE n=$n} row {
            if {$parm ne ""} {
                return $row($parm)
            } else {
                unset row(*)
                return [array get row]
            }
        }

        return ""
    }

    # namedict
    #
    # Returns ID/longname dictionary

    typemethod namedict {} {
        return [rdb eval {
            SELECT n, longname FROM nbhoods ORDER BY n
        }]
    }

    # validate n
    #
    # n         Possibly, a neighborhood short name.
    #
    # Validates a neighborhood short name

    typemethod validate {n} {
        if {![rdb exists {SELECT n FROM nbhoods WHERE n=$n}]} {
            set names [join [nbhood names] ", "]

            if {$names ne ""} {
                set msg "should be one of: $names"
            } else {
                set msg "none are defined"
            }

            return -code error -errorcode INVALID \
                "Invalid neighborhood, $msg"
        }

        return $n
    }

    # local names
    #
    # Returns the list of nbhoods that have the local flag set

    typemethod {local names} {} {
        return [rdb eval {
            SELECT n FROM local_nbhoods ORDER BY n
        }]
    }

    # local namedict
    #
    # Returns ID/longname dictionary for local nbhoods

    typemethod {local namedict} {} {
        return [rdb eval {
            SELECT n, longname FROM local_nbhoods ORDER BY n
        }]
    }

    # local validate n
    #
    # n    Possibly, a local nbhood short name
    #
    # Validates a local nbhood short name

    typemethod {local validate} {n} {
        if {![rdb exists {SELECT n FROM local_nbhoods WHERE n=$n}]} {
            set names [join [nbhood local names] ", "]

            if {$names ne ""} {
                set msg "should be one of: $names"
            } else {
                set msg "none are defined"
            }

            return -code error -errorcode INVALID \
                "Invalid local neighborhood, $msg"
        }

        return $n
    }

    #-------------------------------------------------------------------
    # Private Type Methods

    # SetObscuredBy
    #
    # Checks the neighborhoods for obscured reference points, and
    # sets the obscured_by field accordingly.
    #
    # TBD: This could be more efficient if it took into account
    # the neighborhood that changed and only looked at overlapping
    # neighborhoods.

    typemethod SetObscuredBy {} {
        rdb eval {
            SELECT n, refpoint, obscured_by FROM nbhoods
        } {
            set in [$geo find $refpoint nbhood]

            if {$in eq $n} {
                set in ""
            }

            if {$in ne $obscured_by} {
                rdb eval {
                    UPDATE nbhoods
                    SET obscured_by=$in
                    WHERE n=$n
                }
            }
        }
    }


    #-------------------------------------------------------------------
    # Mutators
    #
    # Mutators are used to implement orders that change the scenario in
    # some way.  Mutators assume that their inputs are valid, and returns
    # a script of one or more commands that will undo the change.  When
    # change cannot be undone, the mutator returns the empty string.


    # mutate create parmdict
    #
    # parmdict     A dictionary of neighborhood parms
    #
    #    n              The neighborhood's ID
    #    longname       The neighborhood's long name
    #    local          The nbhood's local flag
    #    urbanization   eurbanization level
    #    controller     Initial controller, or NONE
    #    pcf            Production capacity factor
    #    refpoint       Reference point, map coordinates
    #    polygon        Boundary polygon, in map coordinates.
    #
    # Creates a nbhood given the parms, which are presumed to be
    # valid.  When validity checks are needed, use the NBHOOD:CREATE
    # order.

    typemethod {mutate create} {parmdict} {
        dict with parmdict {
            # FIRST, Put the neighborhood in the database
            rdb eval {
                INSERT INTO nbhoods(n,longname,local,urbanization,
                                    controller,pcf,refpoint,
                                    polygon)
                VALUES($n,
                       $longname,
                       $local,
                       $urbanization,
                       nullif($controller,'NONE'),
                       $pcf,
                       $refpoint,
                       $polygon);

                INSERT INTO nbrel_mn(m,n)
                SELECT $n, n FROM nbhoods WHERE n != $n;

                INSERT INTO nbrel_mn(m,n)
                SELECT n, $n FROM nbhoods WHERE n != $n;

                INSERT INTO nbrel_mn(m,n,proximity)
                VALUES($n,$n,'HERE');

                INSERT INTO econ_n(n)  VALUES($n);
            } {}

            # NEXT, set the stacking order
            rdb eval {
                SELECT COALESCE(MAX(stacking_order)+1, 1) AS top FROM nbhoods
            } {
                rdb eval {
                    UPDATE nbhoods
                    SET stacking_order=$top
                    WHERE n=$n;
                }
            }

            # NEXT, add the nbhood to the geoset
            $geo create polygon $n $polygon nbhood

            # NEXT, recompute the obscured_by field; this nbhood might
            # have obscured some other neighborhood's refpoint.
            $type SetObscuredBy

            # NEXT, Set the undo command
            return [mytypemethod mutate delete $n]
        }
    }

    # mutate delete n
    #
    # n     A neighborhood short name
    #
    # Deletes the neighborhood, including all references.

    typemethod {mutate delete} {n} {
        # FIRST, get this neighborhood's undo information and
        # delete the relevant records.
        set data [rdb delete -grab nbhoods {n=$n}]
        lappend undo [mytypemethod UndoDelete $data]

        # NEXT, delete all CIV groups that depend on this
        # neighborhood.
        foreach g [rdb eval {
            SELECT g FROM civgroups
            WHERE n=$n
        }] {
            lappend undo [civgroup mutate delete $g]
        }

        # NEXT, update the $geo module
        $geo delete $n

        # NEXT, recompute the obscured_by field; this nbhood might
        # have obscured some other neighborhood's refpoint.
        $type SetObscuredBy

        # NEXT, return aggregate undo script.
        return [join $undo \n]
    }

    # UndoDelete grabData
    #
    # grabData     Rows to be restored.
    #
    # Restores a neighborhood.

    typemethod UndoDelete {grabData} {
        # FIRST, restore the database rows
        rdb ungrab $grabData

        # NEXT, resync with the RDB: this will update the geoset and the 
        # stacking order, as well as the econ_n changes.
        $type dbsync
    }

    # mutate lower n
    #
    # n     A neighborhood short name
    #
    # Sends the neighborhood to the bottom of the stacking order.

    typemethod {mutate lower} {n} {
        # FIRST, reorder the neighborhoods
        set oldNames [rdb eval {
            SELECT n FROM nbhoods 
            ORDER BY stacking_order
        }]

        set names $oldNames
        ldelete names $n
        set names [linsert $names 0 $n]

        return [$type RestackNbhoods $names $oldNames]
    }

    # mutate raise n
    #
    # n     A neighborhood short name
    #
    # Brings the neighborhood to the top of the stacking order.

    typemethod {mutate raise} {n} {
        # FIRST, reorder the neighborhoods
        set oldNames [rdb eval {
            SELECT n FROM nbhoods 
            ORDER BY stacking_order
        }]

        set names $oldNames

        ldelete names $n
        lappend names $n

        return [$type RestackNbhoods $names $oldNames]
    }
  
    # RestackNbhoods new ?old?
    #
    # new      A list of all nbhood names in the desired stacking
    #          order
    # old      The previous order
    #
    # Sets the stacking_order according to the order of the names.

    typemethod RestackNbhoods {new {old ""}} {
        # FIRST, set the stacking_order
        set i 0

        foreach name $new {
            incr i

            rdb eval {
                UPDATE nbhoods
                SET stacking_order=$i
                WHERE n=$name
            }
        }

        # NEXT, refresh the geoset and set the "obscured_by" field
        $type dbsync
        
        # NEXT, notify the GUI of the change.
        notifier send ::nbhood <Stack>

        # NEXT, set the undo information
        return [mytypemethod RestackNbhoods $old]
    }

    # mutate update parmdict
    #
    # parmdict     A dictionary of neighborhood parms
    #
    #    n              A neighborhood short name
    #    longname       A new long name, or ""
    #    local          A new local flag, or ""
    #    urbanization   A new eurbanization level, or ""
    #    controller     A new controller, or ""
    #    pcf            A new production capacity factor, or ""
    #    refpoint       A new reference point, or ""
    #    polygon        A new polygon, or ""
    #
    # Updates a nbhood given the parms, which are presumed to be
    # valid.  When validity checks are needed, use the NBHOOD:UPDATE
    # order.

    typemethod {mutate update} {parmdict} {
        dict with parmdict {
            # FIRST, get the undo information
            rdb eval {
                SELECT *
                FROM nbhoods
                WHERE n=$n
            } row {
                unset row(*)
                if {$row(controller) eq ""} {
                    set row(controller) "NONE"
                }
            }

            # NEXT, Put the neighborhood in the database
            rdb eval {
                UPDATE nbhoods
                SET longname     = nonempty($longname,     longname),
                    local        = nonempty($local,        local),
                    urbanization = nonempty($urbanization, urbanization),
                    controller   = CASE WHEN $controller = '' THEN controller
                                        WHEN $controller = 'NONE' THEN null
                                        ELSE $controller END,
                    pcf          = nonempty($pcf,          pcf),
                    refpoint     = nonempty($refpoint,     refpoint),
                    polygon      = nonempty($polygon,      polygon)
                WHERE n=$n
            } {}

            # NEXT, if the polygon has changed update the geoset, etc.
            if {$polygon ne ""} {
                $type dbsync
            }

            # NEXT, Set the undo command
            return [mytypemethod mutate update [array get row]]
        }
    }
}

#-------------------------------------------------------------------
# Orders: NBHOOD:*

# NBHOOD:CREATE
#
# Creates new neighborhoods.

order define NBHOOD:CREATE {
    title "Create Neighborhood"
    options -sendstates PREP

    form {
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

    parmtags refpoint point
    parmtags polygon polygon
} {
    # FIRST, prepare the parameters
    prepare n             -toupper            -required -unused -type ident
    prepare longname      -normalize
    prepare local         -toupper            -required -type boolean
    prepare urbanization  -toupper            -required -type eurbanization
    prepare controller    -toupper            -required -type {ptype a+none}
    prepare pcf           -num                          -type rnonneg
    prepare refpoint      -toupper            -required -type refpoint
    prepare polygon       -normalize -toupper -required -type refpoly

    returnOnError

    # NEXT, perform custom checks

    # polygon
    #
    # Must be unique.

    if {[valid polygon] && [rdb exists {
        SELECT n FROM nbhoods
        WHERE polygon = $parms(polygon)
    }]} {
        reject polygon "A neighborhood with this polygon already exists"
    }

    # refpoint
    #
    # Must be unique

    if {[valid refpoint] && [rdb exists {
        SELECT n FROM nbhoods
        WHERE refpoint = $parms(refpoint)
    }]} {
        reject refpoint \
            "A neighborhood with this reference point already exists"
    }

    # NEXT, do cross-validation.

    if {[valid refpoint] && [valid polygon]} {
        if {![ptinpoly $parms(polygon) $parms(refpoint)]} {
            reject refpoint "not in polygon"
        }
    }

    # NEXT, If non-local pcf is 0.0, otherwise validate it
    if {!$parms(local)} {
        set parms(pcf) 0.0
    } elseif {[catch {rnonneg validate $parms(pcf)} result]} {
        reject pcf $result
    }
   
    returnOnError -final

    # NEXT, If longname is "", defaults to ID.
    if {$parms(longname) eq ""} {
        set parms(longname) $parms(n)
    }

    # NEXT, create the neighborhood and dependent entities
    lappend undo [nbhood mutate create [array get parms]]
    lappend undo [absit mutate reconcile]

    setundo [join $undo \n]
}

# NBHOOD:CREATE:RAW
#
# Creates new neighborhoods from raw lat/long data.

order define NBHOOD:CREATE:RAW {
    title "Create Neighborhood From Raw Data"
    options -sendstates PREP

    form {
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

    parmtags refpoint point
    parmtags polygon polygon
} {
    # FIRST, prepare the parameters
    prepare n             -required -toupper -unused -type ident
    prepare longname      -normalize
    prepare refpoint      -required  
    prepare polygon       -required           
    prepare local         -toupper            -type boolean
    prepare urbanization  -toupper            -type eurbanization
    prepare controller    -toupper            -type {ptype a+none}
    prepare pcf           -num                -type rnonneg

    returnOnError

    # NEXT, perform custom checks

    # polygon
    #
    
    # Generic tests, this is raw data

    if {[valid polygon]} {
        # Must have at least 6 points
        if {[llength $parms(polygon)] < 6} {
            reject polygon "Not enough coordinate pairs to be lat/long poly"
        }

        # The must be an even number of coordinates
        if {[llength $parms(polygon)] % 2 != 0} {
            reject polygon "Odd number of points in polygon."
        }

    }

    returnOnError

    if {[valid polygon]} {
        # The coordinates must make sense
        foreach {lat lon} $parms(polygon) {
            set loc [list $lat $lon]
            if {[catch {
                latlong validate $loc
            } result]} {
                reject polygon $result
            }
        }
    }

    # Must be unique.

    if {[valid polygon] && [rdb exists {
        SELECT n FROM nbhoods
        WHERE polygon = $parms(polygon)
    }]} {
        reject polygon "A neighborhood with this polygon already exists"
    }

    # refpoint
    #
    # Must be lat/long pair
    if {[valid refpoint]} {
        if {[catch {
            latlong validate $parms(refpoint)
        } result]} {
            reject refpoint $result
        }
    }

    # Must be unique

    if {[valid refpoint] && [rdb exists {
        SELECT n FROM nbhoods
        WHERE refpoint = $parms(refpoint)
    }]} {
        reject refpoint \
            "A neighborhood with this reference point already exists"
    }

    # NEXT, do cross-validation.

    if {[valid refpoint] && [valid polygon]} {
        if {![ptinpoly $parms(polygon) $parms(refpoint)]} {
            reject refpoint "not in polygon"
        }
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
    } elseif {[catch {rnonneg validate $parms(pcf)} result]} {
        reject pcf $result
    }

    returnOnError -final

    # NEXT, if urbanization is not been supplied, defaults to URBAN
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

    setundo [join $undo \n]
}

# NBHOOD:DELETE

order define NBHOOD:DELETE {
    title "Delete Neighborhood"
    options -sendstates PREP

    form {
        rcc "Neighborhood:" -for n
        nbhood n
    }
} {
    # FIRST, prepare the parameters
    prepare n  -toupper -required -type nbhood

    returnOnError -final

    # NEXT, make sure the user knows what he is getting into.

    if {[sender] eq "gui"} {
        set answer [messagebox popup \
                        -title         "Are you sure?"                  \
                        -icon          warning                          \
                        -buttons       {ok "Delete it" cancel "Cancel"} \
                        -default       cancel                           \
                        -onclose       cancel                           \
                        -ignoretag     NBHOOD:DELETE                    \
                        -ignoredefault ok                               \
                        -parent        [app topwin]                     \
                        -message       [normalize {
                            Are you sure you
                            really want to delete this neighborhood, along
                            with all of the entities that depend upon it?
                        }]]

        if {$answer eq "cancel"} {
            cancel
        }
    }

    # NEXT, delete the neighborhood and dependent entities
    lappend undo [nbhood mutate delete $parms(n)]
    lappend undo [absit mutate reconcile]

    setundo [join $undo \n]
}

# NBHOOD:LOWER

order define NBHOOD:LOWER {
    title "Lower Neighborhood"
    options -sendstates PREP

    form {
        rcc "Neighborhood:" -for n
        nbhood n
    }
} {
    # FIRST, prepare the parameters
    prepare n  -toupper -required -type nbhood

    returnOnError -final

    # NEXT, raise the neighborhood
    lappend undo [nbhood mutate lower $parms(n)]
    lappend undo [absit mutate reconcile]

    setundo [join $undo \n]
}

# NBHOOD:RAISE

order define NBHOOD:RAISE {
    title "Raise Neighborhood"
    options -sendstates PREP

    form {
        rcc "Neighborhood:" -for n
        nbhood n
    }
} {
    # FIRST, prepare the parameters
    prepare n  -toupper -required -type nbhood

    returnOnError -final

    # NEXT, raise the neighborhood
    lappend undo [nbhood mutate raise $parms(n)]
    lappend undo [absit mutate reconcile]

    setundo [join $undo \n]
}

# NBHOOD:UPDATE
#
# Updates existing neighborhoods.

order define NBHOOD:UPDATE {
    title "Update Neighborhood"
    options -sendstates PREP

    form {
        rcc "Select Neighborhood:" -for n
        key n -table gui_nbhoods -keys n \
            -loadcmd {orderdialog keyload n *}
        
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

    parmtags refpoint point
    parmtags polygon polygon
} {
    # FIRST, prepare the parameters
    prepare n            -toupper   -required -type nbhood
    prepare longname     -normalize
    prepare local        -toupper             -type boolean
    prepare urbanization -toupper             -type eurbanization
    prepare controller   -toupper             -type {ptype a+none}
    prepare pcf          -num                 -type rnonneg
    prepare refpoint     -toupper             -type refpoint
    prepare polygon      -normalize -toupper  -type refpoly

    returnOnError

    # NEXT, validate the other parameters

    # polygon
    #
    # Must be unique

    if {[valid polygon]} { 
        rdb eval {
            SELECT n FROM nbhoods
            WHERE polygon = $parms(polygon)
        } {
            if {$n ne $parms(n)} {
                reject polygon \
                    "A neighborhood with this polygon already exists"
            }
        }
    }

    # refpoint
    #
    # Must be unique

    if {[valid refpoint]} { 
        rdb eval {
            SELECT n FROM nbhoods
            WHERE refpoint = $parms(refpoint)
        } {
            if {$n ne $parms(n)} {
                reject polygon \
                    "A neighborhood with this reference point already exists"
            }
        }
    }

    returnOnError

    # NEXT, is the refpoint in the polygon?
    rdb eval {SELECT refpoint, polygon FROM nbhoods WHERE n = $parms(n)} {}

    if {$parms(refpoint) ne ""} {
        set refpoint $parms(refpoint)
    }

    if {$parms(polygon) ne ""} {
        set polygon $parms(polygon)
    }

    if {![ptinpoly $polygon $refpoint]} {
        reject refpoint "not in polygon"
    }
    
    returnOnError -final

    # NEXT, If non-local pcf is 0.0
    if {!$parms(local)} {
        set parms(pcf) 0.0
    }

    # NEXT, modify the neighborhood
    lappend undo [nbhood mutate update [array get parms]]
    lappend undo [absit mutate reconcile]

    setundo [join $undo \n]
}

# NBHOOD:UPDATE:MULTI
#
# Updates multiple neighborhoods.

order define NBHOOD:UPDATE:MULTI {
    title "Update Multiple Neighborhoods"
    options -sendstates PREP

    form {
        rcc "Neighborhoods:" -for ids
        multi ids -table gui_nbhoods -key id -context yes \
            -loadcmd {orderdialog multiload ids *}

        rcc "Local Neighborhood?" -for local
        enum local -listcmd {eyesno names}

        rcc "Urbanization:" -for urbanization
        enum urbanization -listcmd {eurbanization names}

        rcc "Controller:" -for controller
        enum controller -listcmd {ptype a+none names}

        rcc "Prod. Capacity Factor:" -for pcf
        text pcf
    }
} {
    # FIRST, prepare the parameters
    prepare ids          -toupper -required -listof nbhood
    prepare local        -toupper           -type   boolean
    prepare urbanization -toupper           -type   eurbanization
    prepare controller   -toupper           -type   {ptype a+none}
    prepare pcf          -num               -type   rnonneg

    returnOnError -final

    # NEXT, clear the other parameters expected by the mutator
    prepare longname
    prepare refpoint
    prepare polygon

    # NEXT, modify the neighborhoods
    set undo [list]

    foreach parms(n) $parms(ids) {
        lappend undo [nbhood mutate update [array get parms]]
    }

    lappend undo [absit mutate reconcile]

    setundo [join $undo \n]
}








