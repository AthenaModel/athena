#-----------------------------------------------------------------------
# TITLE:
#    map.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Map Manager
#
#    This module is responsible for loading the map image and creating
#    the projection object, and making them available to the rest of the
#    application.  It also validates map references and map coordinates,
#    and does conversions between the two.
#
#-----------------------------------------------------------------------

snit::type ::athena::map {
    #-------------------------------------------------------------------
    # Components

    component adb         ;# The athenadb(n) instance
    component mapimage    ;# Tk image of current map, or ""
    component projection  ;# A projection(i) object

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance

    constructor {adb_} {
        set adb $adb_
    }

    # data parmdict
    #
    # parmdict   Dictionary of map and projection data
    #
    # The method extracts the map and projection data from the supplied
    # dictionary and sets that data in the maps table.  The application
    # is then synchronized with the new data.

    method data {parmdict} {
        # FIRST extract data
        dict with parmdict {}

        # NEXT, Rectangular projection, grab corners
        set ulat $ulat
        set ulon $ulon
        set llat $llat
        set llon $llon

        $adb eval {DELETE FROM maps;}

        # NEXT, set the map in the adb and load it
        $adb eval {
            INSERT INTO maps(id,filename,width,height,
                      projtype,ulat,ulon,llat,llon,data)
            VALUES(1,'rawdata',$width,$height,
                   'RECT',$ulat,$ulon,$llat,$llon,$data);
        }
    }

    # load filename
    #
    # filename     An image file
    #
    # Attempts to load the image into the RDB.

    method load {filename} {
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
        set ulat 42.0
        set ulon 45.0
        set llat 38.0
        set llon 51.0

        # NEXT, try to load any projection metadata. For now only
        # GeoTIFF with GEOGRAPHIC model types are recognized.
        if {[catch {
            set mdata [dict create {*}[marsutil::geotiff read $filename]]
            if {[dict get $mdata modeltype] eq "GEOGRAPHIC"} {
                # Extract tiepoints and scaling from projection metadata
                set tiepoints [dict get $mdata tiepoints]
                set pscale    [dict get $mdata pscale]

                # Compute lat/long bounds of map image
                set ulat [lindex $tiepoints 4]
                set ulon [lindex $tiepoints 3]
                let llat {$ulat - $height*[lindex $pscale 1]}
                let llon {$ulon + $width* [lindex $pscale 0]}
            } else {
                log detail map \
                    "Projection type not recognized in $tail, using defaults."
            }
        } result]} {
            log detail map "Could not read GeoTIFF info from $tail: $result"
        }

        $adb eval {DELETE FROM maps;}

        $adb eval {
            INSERT INTO maps(id,filename,width,height,
                      projtype,ulat,ulon,llat,llon,data)
            VALUES(1,$tail,$width,$height,
                   'RECT',$ulat,$ulon,$llat,$llon,$data);
        }

        image delete $img
    }

    #-------------------------------------------------------------------
    # Mutators
    #
    # Mutators are used to implement orders that change the scenario in
    # some way.  Mutators assume that their inputs are valid, and returns
    # a script of one or more commands that will undo the change.  When
    # change cannot be undone, the mutator returns the empty string.

    # importf filename
    #
    # filename     An image file
    #
    # Attempts to import the image from a file into the RDB.  This command 
    # is undoable.

    method importf {filename} {
        # FIRST, importing from a file without Tk is an error.
        require {[info command tk] ne ""} \
            "Cannot import $filename, Tk is not loaded"

        # NEXT, undo either goes back to previous map or to 
        # default map
        if {![$adb exists {SELECT * FROM maps WHERE id=1}]} {
            set undo [mymethod UndoToDefault]
        } else {
            $adb eval {
                SELECT * FROM maps WHERE id=1
            } row {
                unset row(*)
                binary scan $row(data) H* row(data)
            }

            set undo [mymethod UndoMap [array get row]]
        }

        # NEXT, try to load it into the RDB
        $self load $filename

        # NEXT, log it.
        log normal app "Import Map: $filename"
        
        app puts "Imported Map: $filename"

        # NEXT, Notify the application.
        $adb notify map <MapChanged>

        # NEXT, Return the undo script
        return $undo
    }

    # importd parmdict
    #
    # parmdict    A dictionary of map data parms
    #
    #    data     Image data in binary form
    #    proj     A dictionary of map projection data
    #
    # Imports a map and projection from a data source.

    method importd {parmdict} {
        # FIRST, undo either goes back to previous map or to 
        # default map
        if {![$adb exists {SELECT * FROM maps WHERE id=1}]} {
            set undo [mymethod UndoToDefault]
        } else {
            $adb eval {
                SELECT * FROM maps WHERE id=1
            } row {
                unset row(*)
                binary scan $row(data) H* row(data)
            }

            set undo [mymethod UndoMap [array get row]]
        }

        $self data $parmdict

        # NEXT, Notify the application.
        $adb notify map <MapChanged>

        # NEXT, Return the undo script
        return $undo
    }

    # georef parmdict
    #
    # parmdict    A dictionary of parameters to set lat/long coords for
    #             the corners of a map image
    #
    #   ulat     Latitude of upper left hand point
    #   ulon     Longitude of upper left hand point
    #   llat     Latitude of lower right hand point
    #   llon     Longitude of lower right hand point

    method georef {parmdict} {
        dict with parmdict {}

        # FIRST, default width and height, there may not be
        # a map in the adb
        set width 1000
        set height 1000
        set filename ""
        set data     ""

        # NEXT, determine undo script based on whether a map currently
        # exists
        if {![$adb exists {SELECT * FROM maps WHERE id=1}]} {
            set undo [mymethod UndoToDefault]
        } else {
            $adb eval {
                SELECT * FROM maps WHERE id=1
            } row {                
                unset row(*)
            }

            # NEXT, grab the data from the adb to override defaults
            set width    $row(width)
            set height   $row(height)
            set filename $row(filename)
            set data     $row(data)

            # NEXT, the undo script expects hex digits
            binary scan $row(data) H* row(data)
            set undo [mymethod UndoMap [array get row]]
        }

        # NEXT, fill in the projection information and update the
        # adb

        $adb eval {
            INSERT OR REPLACE
            INTO maps(id,filename,width,height,
                      projtype,ulat,ulon,llat,llon,data)
            VALUES(1,$filename,$width,$height,
                   'RECT',$ulat,$ulon,$llat,$llon,$data);
        }

        $adb notify map <MapChanged> 
        return $undo      
    }

    # UndoToDefault
    #
    # Undoes an import and sets back to default

    method UndoToDefault {} {
        # FIRST, blank everything out
        $adb eval {DELETE FROM maps;}

        log normal app "Using Default Map"
        app puts "Using Default Map"

        # NEXT, notify application
        $adb notify map <MapChanged>
    }

    # UndoMap dict
    #
    # dict    A dictionary of map parameters
    # 
    # Undoes a previous import

    method UndoMap {dict} {
        # FIRST, restore the data
        dict for {key value} $dict {
            # FIRST, decode the image data
            if {$key eq "data"} {
                set value [binary format H* $value]
            }

            # NEXT, put it back in the RDB
            $adb eval "
                UPDATE maps
                SET $key = \$value
                WHERE id=1
            "
        }

        # NEXT, log it
        set filename [dict get $dict filename]

        log normal app "Restored Map: $filename"
        app puts "Restored Map: $filename"

        # NEXT, Notify the application.
        $adb notify map <MapChanged>
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
        ulon 
        llat 
        llon
    }

    meta form {
        rcc "Upper Left Lat:" -for ulat
        text ulat

        rcc "Upper Left Long:" -for ulon
        text ulon

        rcc "Lower Right Lat:" -for llat
        text llat

        rcc "Lower Right Long:" -for llon
        text llon
    }

    method _validate {} {
        my prepare ulat -num -required -type latpt
        my prepare ulon -num -required -type longpt
        my prepare llat -num -required -type latpt
        my prepare llon -num -required -type longpt

        my returnOnError

        my checkon llat {
            if {$parms(llat) >= $parms(ulat)} {
                my reject llat \
                    "Latitude of lower point must be < latitude of upper point"
            }
        }

        my checkon llon {
            if {$parms(llon) <= $parms(ulon)} {
                my reject llon \
            "Longitude of lower point must be > longitude of upper point"
            }
        }
    }

    method _execute {{flunky ""}} {
        my setundo [$adb map georef [array get parms]]
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

            if {[info command tk] eq ""} {
                my reject filename \
                    "Error, Tk is not loaded."
            }
        }

        my returnOnError
    }

    method _execute {{flunky ""}} {
        if {[catch {
            # In this case, simply try it.
            my setundo [$adb map importf $parms(filename)]
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

    meta parmlist {data projtype width height ulat ulon llat llon}

    # NOTE: Dialog cannot easily be used. The format of the
    # image data is binary, it would be tough to cobble that together.
    meta form {
        text data
        text projtype
        text width
        text height
        text ulat
        text ulon
        text llat
        text llon
    }

    method _validate {} {
        my prepare data        -required
        my prepare projtype    -required 
        my prepare width  -num -required -type ipositive
        my prepare height -num -required -type ipositive
        my prepare ulat   -num -required -type latpt
        my prepare ulon   -num -required -type longpt
        my prepare llat   -num -required -type latpt
        my prepare llon   -num -required -type longpt
    }

    method _execute {{flunky ""}} {
        my setundo [$adb map importd [array get parms]]
    }
}

