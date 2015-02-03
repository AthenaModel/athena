#-----------------------------------------------------------------------
# TITLE:
#    nbhood.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Neighborhood Manager
#
#    This module is responsible for managing neighborhoods and operations
#    upon them.
#
# TBD: Global references: notifier send, ptype, 
#      refpoint, app/messagebox, sim
#
#-----------------------------------------------------------------------

snit::type ::athena::nbhood {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance
    component geo ;# A geoset, for polygon computations

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        # FIRST, save/create components
        set adb $adb_
        install geo using geoset ${selfns}::geo

        # NEXT, register to receive dbsync events.
        notifier bind ::sim <DbSyncA> $self [mymethod dbsync]
    }

    destructor {
        notifier forget $self
    }

    #-------------------------------------------------------------------
    # Notifier Event Handlers

    # dbsync
    #
    # Refreshes the geoset with the current neighborhood data from
    # the database.
    
    method dbsync {} {
        # FIRST, populate the geoset
        $geo clear

        $adb eval {
            SELECT n, polygon FROM nbhoods
            ORDER BY stacking_order
        } {
            # Create the polygon with the neighborhood's name and
            # polygon coordinates; tag it with "nbhood".
            $geo create polygon $n $polygon nbhood
        }

        # NEXT, update the obscured_by fields
        $self SetObscuredBy
    }

    #-------------------------------------------------------------------
    # Delegated methods

    delegate method bbox to geo

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

    method find {mx my} {
        return [$geo find [list $mx $my] nbhood]
    }

    # randloc n
    #
    # n       A neighborhood short name
    #
    # Tries to get a random location from the neighborhood.
    # If it fails after ten tries, returns the neighborhood's 
    # reference point.

    method randloc {n} {
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

            if {[$geo find $pt] eq $n} {
                return $pt
            }
        }

        # Didn't find one; just return the refpoint.
        return [$adb onecolumn {
            SELECT refpoint FROM nbhoods
            WHERE n=$n
        }]
    }

    # names
    #
    # Returns the list of neighborhood names

    method names {} {
        return [$adb eval {
            SELECT n FROM nbhoods ORDER BY n
        }]
    }

    # fullname n
    #
    # Returns the full name of the neighborhood: "$longname ($n)"

    method fullname {n} {
        return "[$self get $n longname] ($n)"
    }

    # get n ?parm?
    #
    # n  - A neighborhood ID
    #
    # Returns the neighborhood's data dictionary; or the specific
    # parameter, if given.

    method get {n {parm ""}} {
        # FIRST, get the data
        $adb eval {SELECT * FROM nbhoods WHERE n=$n} row {
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

    method namedict {} {
        return [$adb eval {
            SELECT n, longname FROM nbhoods ORDER BY n
        }]
    }

    # validate n
    #
    # n         Possibly, a neighborhood short name.
    #
    # Validates a neighborhood short name

    method validate {n} {
        if {![$adb exists {SELECT n FROM nbhoods WHERE n=$n}]} {
            set names [join [$self names] ", "]

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

    method {local names} {} {
        return [$adb eval {
            SELECT n FROM local_nbhoods ORDER BY n
        }]
    }

    # local namedict
    #
    # Returns ID/longname dictionary for local nbhoods

    method {local namedict} {} {
        return [$adb eval {
            SELECT n, longname FROM local_nbhoods ORDER BY n
        }]
    }

    # local validate n
    #
    # n    Possibly, a local nbhood short name
    #
    # Validates a local nbhood short name

    method {local validate} {n} {
        if {![$adb exists {SELECT n FROM local_nbhoods WHERE n=$n}]} {
            set names [join [$self local names] ", "]

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

    method SetObscuredBy {} {
        $adb eval {
            SELECT n, refpoint, obscured_by FROM nbhoods
        } {
            set in [$geo find $refpoint nbhood]

            if {$in eq $n} {
                set in ""
            }

            if {$in ne $obscured_by} {
                $adb eval {
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


    # create parmdict
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

    method create {parmdict} {
        dict with parmdict {
            # FIRST, Put the neighborhood in the database
            $adb eval {
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
            $adb eval {
                SELECT COALESCE(MAX(stacking_order)+1, 1) AS top FROM nbhoods
            } {
                $adb eval {
                    UPDATE nbhoods
                    SET stacking_order=$top
                    WHERE n=$n;
                }
            }

            # NEXT, add the nbhood to the geoset
            $geo create polygon $n $polygon nbhood

            # NEXT, recompute the obscured_by field; this nbhood might
            # have obscured some other neighborhood's refpoint.
            $self SetObscuredBy

            # NEXT, Set the undo command
            return [mymethod delete $n]
        }
    }

    # delete n
    #
    # n     A neighborhood short name
    #
    # Deletes the neighborhood, including all references.

    method delete {n} {
        # FIRST, get this neighborhood's undo information and
        # delete the relevant records.
        set data [$adb delete -grab nbhoods {n=$n}]
        lappend undo [mymethod UndoDelete $data]

        # NEXT, delete all CIV groups that depend on this
        # neighborhood.
        foreach g [$adb eval {
            SELECT g FROM civgroups
            WHERE n=$n
        }] {
            lappend undo [$adb civgroup delete $g]
        }

        # NEXT, update the $geo module
        $geo delete $n

        # NEXT, recompute the obscured_by field; this nbhood might
        # have obscured some other neighborhood's refpoint.
        $self SetObscuredBy

        # NEXT, return aggregate undo script.
        return [join $undo \n]
    }

    # UndoDelete grabData
    #
    # grabData     Rows to be restored.
    #
    # Restores a neighborhood.

    method UndoDelete {grabData} {
        # FIRST, restore the database rows
        $adb ungrab $grabData

        # NEXT, resync with the $adb: this will update the geoset and the 
        # stacking order, as well as the econ_n changes.
        $self dbsync
    }

    # lower n
    #
    # n     A neighborhood short name
    #
    # Sends the neighborhood to the bottom of the stacking order.

    method lower {n} {
        # FIRST, reorder the neighborhoods
        set oldNames [$adb eval {
            SELECT n FROM nbhoods 
            ORDER BY stacking_order
        }]

        set names $oldNames
        ldelete names $n
        set names [linsert $names 0 $n]

        return [$self RestackNbhoods $names $oldNames]
    }

    # raise n
    #
    # n     A neighborhood short name
    #
    # Brings the neighborhood to the top of the stacking order.

    method raise {n} {
        # FIRST, reorder the neighborhoods
        set oldNames [$adb eval {
            SELECT n FROM nbhoods 
            ORDER BY stacking_order
        }]

        set names $oldNames

        ldelete names $n
        lappend names $n

        return [$self RestackNbhoods $names $oldNames]
    }
  
    # RestackNbhoods new ?old?
    #
    # new      A list of all nbhood names in the desired stacking
    #          order
    # old      The previous order
    #
    # Sets the stacking_order according to the order of the names.

    method RestackNbhoods {new {old ""}} {
        # FIRST, set the stacking_order
        set i 0

        foreach name $new {
            incr i

            $adb eval {
                UPDATE nbhoods
                SET stacking_order=$i
                WHERE n=$name
            }
        }

        # NEXT, refresh the geoset and set the "obscured_by" field
        $self dbsync
        
        # NEXT, notify the GUI of the change.
        notifier send ::nbhood <Stack>

        # NEXT, set the undo information
        return [mymethod RestackNbhoods $old]
    }

    # update parmdict
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

    method update {parmdict} {
        dict with parmdict {
            # FIRST, get the undo information
            $adb eval {
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
            $adb eval {
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
                $self dbsync
            }

            # NEXT, Set the undo command
            return [mymethod update [array get row]]
        }
    }
}

#-------------------------------------------------------------------
# Orders: NBHOOD:*

# NBHOOD:CREATE
#
# Creates new neighborhoods.

::athena::orders define NBHOOD:CREATE {
    meta title      "Create Neighborhood"
    meta sendstates PREP
    meta parmlist   {
        n
        longname
        {local        1}
        {pcf          1.0}
        {urbanization URBAN}
        {controller   NONE}
        refpoint
        polygon
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
        my variable adb

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
            if {[$adb exists {
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
            if {[$adb exists {
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
        lappend undo [$adb nbhood create [array get parms]]
        lappend undo [$adb absit reconcile]

        my setundo [join $undo \n]
    }
}

# NBHOOD:CREATE:RAW
#
# Creates new neighborhoods from raw lat/long data.

::athena::orders define NBHOOD:CREATE:RAW {
    meta title      "Create Neighborhood From Raw Data"
    meta sendstates PREP
    meta parmlist {
        n
        longname
        {local        1}
        {pcf          1.0}
        {urbanization URBAN}
        {controller   NONE}
        refpoint
        polygon
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
        my variable adb

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
            if {[$adb exists {
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
            if {[$adb exists {
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
        lappend undo [$adb nbhood create [array get parms]]
        lappend undo [$adb absit reconcile]

        my setundo [join $undo \n]
    }

}

# NBHOOD:DELETE

::athena::orders define NBHOOD:DELETE {
    meta title      "Delete Neighborhood"
    meta sendstates PREP
    meta parmlist   {n}
    
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
                my cancel
            }
        }

        # NEXT, delete the neighborhood and dependent entities
        lappend undo [$adb nbhood delete $parms(n)]
        lappend undo [$adb absit reconcile]

        my setundo [join $undo \n]
    }
}

# NBHOOD:LOWER

::athena::orders define NBHOOD:LOWER {
    meta title      "Lower Neighborhood"
    meta sendstates PREP
    meta parmlist   {n}

    meta form {
        rcc "Neighborhood:" -for n
        nbhood n
    }

    method _validate {} {
        my prepare n  -toupper -required -type nbhood
    }

    method _execute {{flunky ""}} {
        lappend undo [$adb nbhood lower $parms(n)]
        lappend undo [$adb absit reconcile]

        my setundo [join $undo \n]
    }
}

# NBHOOD:RAISE

::athena::orders define NBHOOD:RAISE {
    meta title "Raise Neighborhood"
    meta sendstates PREP
    meta parmlist   {n}
    
    meta form {
        rcc "Neighborhood:" -for n
        nbhood n
    }

    method _validate {} {
        my prepare n  -toupper -required -type nbhood
    }

    method _execute {{flunky ""}} {
        lappend undo [$adb nbhood raise $parms(n)]
        lappend undo [$adb absit reconcile]

        my setundo [join $undo \n]
    }
}

# NBHOOD:UPDATE
#
# Updates existing neighborhoods.

::athena::orders define NBHOOD:UPDATE {
    meta title      "Update Neighborhood"
    meta sendstates PREP
    meta parmlist {
        n longname local pcf urbanization controller refpoint polygon
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
        my variable adb
        
        # FIRST, prepare the parameters
        my prepare n            -toupper   -required -type [list $adb nbhood]
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
            $adb eval {
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
            $adb eval {
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
        $adb eval {SELECT refpoint, polygon FROM nbhoods WHERE n = $parms(n)} {}

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
        lappend undo [$adb nbhood update [array get parms]]
        lappend undo [$adb absit reconcile]

        my setundo [join $undo \n]
    }
}

# NBHOOD:UPDATE:MULTI
#
# Updates multiple neighborhoods.

::athena::orders define NBHOOD:UPDATE:MULTI {
    meta title      "Update Multiple Neighborhoods"
    meta sendstates PREP
    meta parmlist   {ids local urbanization controller pcf}
    
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
        # FIRST, prepare the parameters
        my prepare ids          -toupper -required -listof [list $adb nbhood]
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
            lappend undo [$adb nbhood update [array get parms]]
        }

        lappend undo [$adb absit reconcile]

        my setundo [join $undo \n]
    }
}






