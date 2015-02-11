#-----------------------------------------------------------------------
# TITLE:
#    map.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Map Manager
#
#    This module is responsible for loading the map image and creating
#    the projection object, and making them available to the rest of the
#    application.  It also validates map references and map coordinates,
#    and does conversions between the two.
#
#-----------------------------------------------------------------------

snit::type map {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Components

    typecomponent mapimage    ;# Tk image of current map, or ""
    typecomponent projection  ;# A projection(i) object

    #-------------------------------------------------------------------
    # Type Variables

    # TBD

    #-------------------------------------------------------------------
    # Initialization

    typemethod init {} {
        log detail map "init"

        # FIRST, there's no map yet.
        set mapimage   ""
        set projection [maprect %AUTO%]

        # NEXT, register to receive dbsync events if there is a GUI
        if {[app tkloaded]} {
            notifier bind ::sim <DbSyncA> $type [mytypemethod DbSync]
        } else {
            log detail map "app in non-GUI mode, ignoring notifiers"
        }

        log detail map "init complete"
    }

    #-------------------------------------------------------------------
    # Event handlers

    # DbSync
    #
    # Loads the current map, gets the right projection, and notifies the
    # app.

    typemethod DbSync {} {
        # FIRST, delete the old map image.
        if {$mapimage ne ""} {
            # FIRST, delete the image
            image delete $mapimage
            set mapimage ""

        }
        
        # NEXT, load the new map.
        rdb eval {
            SELECT width,height,projtype,proj_opts,data 
            FROM maps WHERE id=1
        } {
            # May not have an image
            if {$data ne ""} {
                set mapimage [image create photo -format jpeg -data $data]                
            }

            # NEXT, destroy projection it's about to be created again
            $projection destroy

            set projection [[eprojtype as proj $projtype] %AUTO% \
                                          -width $width          \
                                          -height $height        \
                                          {*}$proj_opts]
        }
    }

    #-------------------------------------------------------------------
    # Public Typemethods

    delegate typemethod box   to projection
    delegate typemethod ref2m to projection
    delegate typemethod m2ref to projection
    delegate typemethod ref   to projection

    # image 
    #
    # Returns the current map image, or ""
    
    typemethod image {} {
        return $mapimage
    }

    # projection
    #
    # Returns the current map projection

    typemethod projection {} {
        return $projection
    }


    # data parmdict
    #
    # parmdict   Dictionary of map and projection data
    #
    # The method extracts the map and projection data from the supplied
    # dictionary and sets that data in the maps table.  The application
    # is then synchronized with the new data.

    typemethod data {parmdict} {
        # FIRST extract data
        dict with parmdict {}

        # NEXT extract projection dictionary, exact form depends on 
        # projection type
        dict with parmdict proj {}

        if {$ptype eq "RECT"} {
            # Rectangular projection, grab corners
            lappend proj_opts -minlat $minlat -minlon $minlon
            lappend proj_opts -maxlat $maxlat -maxlon $maxlon
        } else {
            # Use defaults
            lappend proj_opts -minlat 38.0 -minlon 45.0
            lappend proj_opts -maxlat 42.0 -maxlon 51.0
        }

        # NEXT, set the map in the rdb and load it
        rdb eval {
            INSERT OR REPLACE
            INTO maps(id,filename,width,height,projtype,proj_opts,data)
            VALUES(1,'rawdata',$width,$height,$ptype,$proj_opts,$data);
        }

        $type DbSync
    }

    # load filename
    #
    # filename     An image file
    #
    # Attempts to load the image into the RDB.

    typemethod load {filename} {
        # FIRST, is it a real image?
        if {[catch {
            set img [image create photo -file $filename]
        } result]} {
            error "Could not open the specified file as a map image"
        }
        
        # NEXT, get the image data
        set tail [file tail $filename]
        set data [$img data -format jpeg]
        set width [image width $img]
        set height [image height $img]

        # NEXT, set default geo locations for corners of image
        set minlon 45.0
        set maxlat 42.0
        set maxlon 51.0
        set minlat 38.0

        # NEXT, try to load any projection metadata. For now only
        # GeoTIFF with GEOGRAPHIC model types are recognized.
        if {[catch {
            set mdata [dict create {*}[marsutil::geotiff read $filename]]
            if {[dict get $mdata modeltype] eq "GEOGRAPHIC"} {
                # Extract tiepoints and scaling from projection metadata
                set tiepoints [dict get $mdata tiepoints]
                set pscale    [dict get $mdata pscale]

                # Compute lat/long bounds of map image
                set minlon [lindex $tiepoints 3]
                set maxlat [lindex $tiepoints 4]
                let maxlon {$minlon + $width* [lindex $pscale 0]}
                let minlat {$maxlat - $height*[lindex $pscale 1]}
            } else {
                log detail map \
                    "Projection type not recognized in $tail, using defaults."
            }
        } result]} {
            log detail map "Could not read GeoTIFF info from $tail: $result"
        }

        # NEXT, set projection options
        lappend proj_opts -minlat $minlat -minlon $minlon
        lappend proj_opts -maxlat $maxlat -maxlon $maxlon

        rdb eval {
            INSERT OR REPLACE
            INTO maps(id,filename,width,height,projtype,proj_opts,data)
            VALUES(1,$tail,$width,$height,'RECT',$proj_opts,$data);
        }

        image delete $img

        # NEXT, load the new map
        $type DbSync
    }

    #-------------------------------------------------------------------
    # Mutators
    #
    # Mutators are used to implement orders that change the scenario in
    # some way.  Mutators assume that their inputs are valid, and returns
    # a script of one or more commands that will undo the change.  When
    # change cannot be undone, the mutator returns the empty string.

    # mutate import filename
    #
    # filename     An image file
    #
    # Attempts to import the image into the RDB.  This command is
    # undoable.

    typemethod {mutate import} {filename} {
        # FIRST, if the app is non-GUI, this is a no-op
        if {![app tkloaded]} {
            log detail map "app in non-GUI mode, ignoring map import"
            return ""
        }

        # NEXT, undo either goes back to previous map or to 
        # default map
        if {![rdb exists {SELECT * FROM maps WHERE id=1}]} {
            set undo [mytypemethod UndoToDefault]
        } else {
            rdb eval {
                SELECT * FROM maps WHERE id=1
            } row {
                unset row(*)
                binary scan $row(data) H* row(data)
            }

            set undo [mytypemethod UndoMap [array get row]]
        }

        # NEXT, try to load it into the RDB
        $type load $filename

        # NEXT, log it.
        log normal app "Import Map: $filename"
        
        app puts "Imported Map: $filename"

        # NEXT, Notify the application.
        notifier send $type <MapChanged>

        # NEXT, Return the undo script
        return $undo
    }

    # mutate data  parmdict
    #
    # parmdict    A dictionary of map data parms
    #
    #    data     Image data in binary form
    #    proj     A dictionary of map projection data
    #
    # Imports a map and projection from a data source.

    typemethod {mutate data} {parmdict} {
        # FIRST, if the app is non-GUI, this is a no-op
        if {![app tkloaded]} {
            log detail map "app in non-GUI mode, ignoring map set"
            return ""
        }

        # NEXT, undo either goes back to previous map or to 
        # default map
        if {![rdb exists {SELECT * FROM maps WHERE id=1}]} {
            set undo [mytypemethod UndoToDefault]
        } else {
            rdb eval {
                SELECT * FROM maps WHERE id=1
            } row {
                unset row(*)
                binary scan $row(data) H* row(data)
            }

            set undo [mytypemethod UndoMap [array get row]]
        }

        $type data $parmdict

        # NEXT, Notify the application.
        notifier send $type <MapChanged>

        # NEXT, Return the undo script
        return $undo
    }

    # corners parmdict
    #
    # parmdict    A dictionary of parameters to set lat/long coords for
    #             the corners of a map image
    #
    #   ulat      Latitude of upper left hand point
    #   ulong     Longitude of upper left hand point
    #   llat      Latitude of lower right hand point
    #   llong     Longitude of lower right hand point

    typemethod corners {parmdict} {
        dict with parmdict {}

        # FIRST, grab the image width and height, there may not be
        # a map in the rdb
        lassign [map box] dummy dummy width height
        set filename ""
        set data     ""

        # NEXT, determine undo script based on whether a map currently
        # exists
        if {![rdb exists {SELECT * FROM maps WHERE id=1}]} {
            set undo [mytypemethod UndoToDefault]
        } else {
            rdb eval {
                SELECT * FROM maps WHERE id=1
            } row {                
                unset row(*)
            }

            # NEXT, grab the data from the rdb to override defaults
            set width    $row(width)
            set height   $row(height)
            set filename $row(filename)
            set data     $row(data)

            # NEXT, the undo script expects hex digits
            binary scan $row(data) H* row(data)
            set undo [mytypemethod UndoMap [array get row]]
        }

        # NEXT, fill in the projection information and update the
        # rdb
        lappend proj_opts -minlat $llat -minlon $ulong
        lappend proj_opts -maxlat $ulat -maxlon $llong

        rdb eval {
            INSERT OR REPLACE
            INTO maps(id,filename,width,height,projtype,proj_opts,data)
            VALUES(1,$filename,$width,$height,'RECT',$proj_opts,$data);
        }

        $type DbSync

        notifier send $type <MapChanged> 
        return $undo      
    }

    # UndoToDefault
    #
    # Undoes an import and sets back to default

    typemethod UndoToDefault {} {
        # FIRST, blank everything out
        rdb eval {DELETE FROM maps;}

        if {$mapimage ne ""} {
            image delete $mapimage
            set mapimage   ""
        }

        # NEXT, default projection
        set projection [maprect %AUTO%]

        log normal app "Using Default Map"
        app puts "Using Default Map"

        # NEXT, notify application
        notifier send $type <MapChanged>
    }

    # UndoMap dict
    #
    # dict    A dictionary of map parameters
    # 
    # Undoes a previous import

    typemethod UndoMap {dict} {
        # FIRST, restore the data
        dict for {key value} $dict {
            # FIRST, decode the image data
            if {$key eq "data"} {
                set value [binary format H* $value]
            }

            # NEXT, put it back in the RDB
            rdb eval "
                UPDATE maps
                SET $key = \$value
                WHERE id=1
            "
        }

        # NEXT, load the restored image
        $type DbSync

        # NEXT, log it
        set filename [dict get $dict filename]

        log normal app "Restored Map: $filename"
        app puts "Restored Map: $filename"

        # NEXT, Notify the application.
        notifier send $type <MapChanged>
    }

    # compatible pdict
    #
    # pdict   - optional dictionary of projection information
    #
    # This method checks to see if the data in the supplied projection
    # dictionary is compatible with the current laydown of neighborhoods. If 
    # no dictionary is supplied then the current projection is used to 
    # determine if any neighborhoods are outside the bounds of the map.
    #
    # TBD: may support different projection types in the future. For now
    # only rectangular projection is recognized

    typemethod compatible {{pdict ""}} {
        if {$pdict eq ""} {
            set pdict [dict create]
            dict set pdict minlat [[map projection] cget -minlat]
            dict set pdict minlon [[map projection] cget -minlon]
            dict set pdict maxlat [[map projection] cget -maxlat]
            dict set pdict maxlon [[map projection] cget -maxlon]

            dict set pdict ptype RECT
        }

        dict with pdict {}

        # FIRST, if there are no neighborhoods, then it's always compatible
        if {[llength [nbhood names]] == 0} {
            return 1
        }

        # NEXT, projection type specific checks
        switch -exact -- $ptype {
            RECT {
                # Make sure the bounding box that contains the existing
                # neighborhoods fit's in the bounding box of the 
                # projection
                lassign [nbhood bbox] nminlat nminlon nmaxlat nmaxlon
                if {$nminlon > $minlon && $nminlat > $minlat &&
                    $nmaxlat < $maxlat && $nmaxlon < $maxlon} {
                        return 1
                }

                return 0
            }

            default {
                error "Unknown projection type: $ptype"
            }
        }
    }
}

#-------------------------------------------------------------------
# Orders: MAP:*

# MAP:GEOREF
#
# Allows arbitrary lat/long points to be assigned to a map image

::athena::orders define MAP:GEOREF {
    meta title "Geo-reference Map Image"
    meta sendstates {PREP PAUSED}

    meta parmlist {
        ulat 
        ulong 
        llat 
        llong
    }

    meta form {
        rcc "Upper Left Lat:" -for ulat
        text ulat

        rcc "Upper Left Long:" -for ulong
        text ulong

        rcc "Lower Right Lat:" -for llat
        text llat

        rcc "Lower Right Long:" -for llong
        text llong
    }

    method _validate {} {
        my prepare ulat  -num -required -type latpt
        my prepare ulong -num -required -type longpt
        my prepare llat  -num -required -type latpt
        my prepare llong -num -required -type longpt

        my returnOnError

        my checkon llat {
            if {$parms(llat) >= $parms(ulat)} {
                my reject llat \
                    "Latitude of lower point must be < latitude of upper point"
            }
        }

        my checkon llong {
            if {$parms(llong) <= $parms(ulong)} {
                my reject llong \
            "Longitude of lower point must be > longitude of upper point"
            }
        }
    }

    method _execute {{flunky ""}} {
        my setundo [map corners [array get parms]]
    }
}

# MAP:IMPORT:FILE
#
# Imports a map from a file into the scenario

::athena::orders define MAP:IMPORT:FILE {
    meta title "Import Map From File"
    meta sendstates {PREP PAUSED}

    # NOTE: Dialog is not usually used.  Could define a "filepicker"
    # -editcmd, though.
    meta form {
        text filename
    }

    meta parmlist {filename}

    method _validate {} {
        my prepare filename -required 

            my checkon filename {
            if {![file exists $parms(filename)]} {
                my reject filename \
                    "Error, file not found: \"$parms(filename)\""
            }

        }

        my returnOnError
    }

    method _execute {{flunky ""}} {
        if {[catch {
            # In this case, simply try it.
            my setundo [map mutate import $parms(filename)]
        } result]} {
            # TBD: what do we do here? bgerror for now
            error $result
        }
    }
}

# MAP:IMPORT:DATA
#
# Imports map data into the scenario

::athena::orders define MAP:IMPORT:DATA {
    meta title "Import Map As Data"
    meta sendstates {PREP}

    meta parmlist {data proj}

    # NOTE: Dialog cannot easily be used. The format of the
    # image data is binary, it would be tough to cobble that together.
    meta form {
        text data
        text proj
    }


    method _validate {} {
        my prepare data -required
        my prepare proj -type projection
    }

    method _execute {{flunky ""}} {
        my setundo [map mutate data [array get parms]]
    }
}

