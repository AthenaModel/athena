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
        set projection [mapref %AUTO%]

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

            # NEXT, destroy projection it's about to be created again
            $projection destroy
        }

        # NEXT, load the new map.
        rdb eval {
            SELECT width,height,projtype,proj_opts,data 
            FROM maps WHERE id=1
        } {
            set mapimage [image create photo -format jpeg -data $data]

            set projection [[eprojtype as proj $projtype] %AUTO \
                                          -width $width         \
                                          -height $height       \
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
    # Returns the current map projection, or [myproc NoMap].

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
        }

        # NEXT, set the map in the rdb and load it
        rdb eval {
            INSERT OR REPLACE
            INTO maps(id,filename,width,height,projtype,proj_opts,data)
            VALUES(1,'FromWMS',$width,$height,$ptype,$proj_opts,$data);
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
        
        # NEXT, default map type is mapref(n)
        set projtype REF
        set proj_opts [list]

        # NEXT, get the image data
        set tail [file tail $filename]
        set data [$img data -format jpeg]
        set width [image width $img]
        set height [image height $img]

        # NEXT, try to load any projection metadata. For now only
        # GeoTIFF with GEOGRAPHIC model types are recognized.
        if {[catch {
            set mdata [dict create {*}[geotiff read $filename]]
            if {[dict get $mdata modeltype] eq "GEOGRAPHIC"} {
                set projtype RECT
            } else {
                log detail map "Projection type not recognized in $tail, using default."
            }
        } result]} {
            log detail map "Could not read GeoTIFF info from $tail: $result"
        }

        # NEXT compute projection information
        switch -exact -- $projtype  {
            REF {}

            RECT {
                # Extract tiepoints and scaling from projection metadata
                set tiepoints [dict get $mdata tiepoints]
                set pscale    [dict get $mdata pscale]

                # Compute lat/long bounds of map image
                set minlon [lindex $tiepoints 3]
                set maxlat [lindex $tiepoints 4]
                let maxlon {$minlon + $width* [lindex $pscale 0]}
                let minlat {$maxlat - $height*[lindex $pscale 1]}

                # Set projection options
                lappend proj_opts -minlat $minlat -minlon $minlon
                lappend proj_opts -maxlat $maxlat -maxlon $maxlon
            }

            default {
                error "Unrecognized projection type: \"$projtype\"."
            }
        }

        rdb eval {
            INSERT OR REPLACE
            INTO maps(id,filename,width,height,projtype,proj_opts,data)
            VALUES(1,$tail,$width,$height,$projtype,$proj_opts,$data);
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

        # NEXT, get the undo information
        rdb eval {
            SELECT * FROM maps WHERE id=1
        } row {
            unset row(*)
            binary scan $row(data) H* row(data)
        }

        # NEXT, try to load it into the RDB
        $type load $filename

        # NEXT, log it.
        log normal app "Import Map: $filename"
        
        app puts "Imported Map: $filename"

        # NEXT, Notify the application.
        notifier send $type <MapChanged>

        # NEXT, Return the undo script
        return [mytypemethod UndoImport [array get row]]
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

        # NEXT, get the undo information
        rdb eval {
            SELECT * FROM maps WHERE id=1
        } row {
            unset row(*)
            binary scan $row(data) H* row(data)
        }

        $type data $parmdict

        # NEXT, Notify the application.
        notifier send $type <MapChanged>

        # NEXT, Return the undo script
        return [mytypemethod UndoImport [array get row]]
    }


    # UndoImport dict
    #
    # dict    A dictionary of map parameters
    # 
    # Undoes a previous import

    typemethod UndoImport {dict} {
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
    # pdict   - dictionary of projection information, exact structure 
    #           depends on projection type
    #
    # This method checks to see if the data in the supplied projection
    # dictionary is compatible with the current laydown of neighborhoods.

    typemethod compatible {pdict} {
        dict with pdict {}

        # FIRST, if there are no neighborhoods, then it's always compatible
        if {[llength [nbhood names]] == 0} {
            return 1
        }

        # NEXT, if twe are changing projection types, then it's not 
        # compatible. Note: This could change in the future.
        set currptype [rdb onecolumn {SELECT projtype FROM maps WHERE id=1}]
        if {$currptype ne $ptype} {
            return 0
        }

        # NEXT, projection type specific checks
        switch -exact -- $ptype {
            REF {
                # Nothing to be done
                return 1
            }

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

# MAP:IMPORT:FILE
#
# Imports a map from a file into the scenario

order define MAP:IMPORT:FILE {
    title "Import Map From File"
    options -sendstates {PREP PAUSED}

    # NOTE: Dialog is not usually used.  Could define a "filepicker"
    # -editcmd, though.
    form {
        text filename
    }
} {
    # FIRST, prepare the parameters
    prepare filename -required 

    returnOnError -final

    # NEXT, validate the parameters
    if {[catch {
        # In this case, simply try it.
        setundo [map mutate import $parms(filename)]
    } result]} {
        reject filename $result
    }

    returnOnError
}

# MAP:IMPORT:DATA
#
# Imports map data into the scenario

order define MAP:IMPORT:DATA {
    title "Import Map As Data"
    options -sendstates {PREP}

    # NOTE: Dialog cannot easily be used. The format of the
    # image data is binary, it would be tough to cobble that together.
    form {
        text data
        text proj
    }
} {
    # FIRST, prepare parameters
    prepare data -required
    prepare proj -type projection

    returnOnError -final

    # NEXT, set the data in the map
    setundo [map mutate data [array get parms]]
}

