#-----------------------------------------------------------------------
# FILE: wizard.tcl
#
#   Wizard Main Ensemble.
#
# PACKAGE:
#   wnbhood(n) -- package for athena(1) intel ingestion wizard.
#
# PROJECT:
#   Athena Regional Stability Simulation
#
# AUTHOR:
#   Dave Hanks
#
#-----------------------------------------------------------------------

 
#-----------------------------------------------------------------------
# wizard
#
# Intel Ingestion Wizard main module.

snit::type ::wnbhood::wizard {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Variables

    # Wizard Window Name

    typevariable win .wnbhoodwizard   

    # pdictlist
    #
    # pdictlist => list of polygon dictionaries read from .npf file
    #           -> id       => Integer number, the nth polygon read
    #           -> polyset  => filename that this polygon is in 
    #           -> setnum   => Integer ID of file, not yet used
    #           -> name     => Name to display for polygon in wizard
    #           -> ptype    => Type of polygon (ie. National, District)
    #           -> children => list of names of other polygons that are
    #                          embedded in this polygon, if any
    #           -> parent   => The name of the parent polygon, if any

    typevariable pdictlist

    #-------------------------------------------------------------------
    # Wizard Invocation

    # invoke
    #
    # Invokes the wizard.  This initializes the underlying modules, and
    # creates the wizard window.  We enter the WIZARD state when the
    # window is created, and remain in it until the wizard window
    # has completed or is destroyed.

    typemethod invoke {} {
        assert {[$type caninvoke]}

        # FIRST, check that there is a geo-referenced map already defined
        # in Athena
        if {![$type MapExists]} {
            messagebox popup   \
                -title "Unsuitable Map" \
                -icon  error            \
                -buttons {ok "Ok"}      \
                -default ok             \
                -parent [app topwin]    \
                -message [normalize "
                    This scenario does not yet have a suitable geo-referenced
                    map loaded.  Please go to the File menu and
                    either import a map from disk or retrieve one from a web
                    map service.
                "]

           return
        }

        # NEXT, init non-GUI modules
        wizdb ::wnbhood::wdb

        # NEXT, create the real main window.
        wizwin $win
    }

    # cleanup
    #
    # Cleans up all transient wizard data.

    typemethod cleanup {} {
        bgcatch {
            wdb destroy
        }

        # Reset the sim state, if necessary.
        sim wizard off
    }

    #-------------------------------------------------------------------
    # Queries

    # caninvoke
    #
    # Returns 1 if it's OK to invoke the wizard, and 0 otherwise.  We
    # can invoke the wizard if we are in the PREP state, and the wizard
    # window isn't already in existence.

    typemethod caninvoke {} {
        expr {[sim state] eq "PREP" && ![winfo exists $win]}
    }

    #-------------------------------------------------------------------
    # Predicates
    #
    # These subcommands indicate whether we've acquired needed information
    # or not.

    # MapExists
    #
    # Checks if a suitable map is available for placing neighborhoods
    # on.

    typemethod MapExists {} {
        set projtype [rdb onecolumn {SELECT projtype FROM maps WHERE id=1}]

        # Must be a rectangular projection
        if {$projtype ne "RECT"} {
            return 0
        }

        return 1
    }

    #-------------------------------------------------------------------
    # Mutators

    # retrievePolygons fname
    #
    # fname   - the name of a .npf file that contains metadata about the
    #           polygons to be read. Currently, only KML is supported for
    #           the actual polygon data

    typemethod retrievePolygons {fname} {
        # FIRST, blow away the contents of the WDB
        wdb eval {DELETE FROM polygons;}

        # NEXT, read them and notify the wizard
        $type readnpf $fname

        notifier send ::wnbhood::wizard <update>
    }
    
    # readnpf fname
    #
    # fname   - the name of a .npf file that contains metadata about the
    #           polygons to be read.  Currently, only KML is supported for
    #           the actual polygon data
    #
    # The .npf file format is a flat text file of polygon records with the
    # following structure:
    #
    # poly {
    #     id       N
    #     polyset  filename
    #     setnum   M
    #     name     string
    #     ptype    string
    #     children list of strings
    #     parent   string
    # }
    # ...
    #
    # Where 
    #    id       - the nth polygon to read, this ID must correspond to the
    #               position of the polygon data in the KML file
    #    polyset  - the name of the KML file to read, this polygons data from 
    #    setnum   - an integer ID for the KML file, not yet used
    #    name     - the name to display in the wizard for the nth polygon read
    #    ptype    - free form string for polygon type (ie. National, District)
    #    children - list of names of other polygons

    typemethod readnpf {fname} {
        # FIRST, initialize the list of polygon dictionaries
        set pdictlist [list]

        # NEXT, read in the polygon metadata
        set f [open $fname "r"]
        set data [read $f]
        close $f

        # NEXT, parse the polygon data out into a dictionary
        foreach {keyword pdata} $data {
            switch -exact -- $keyword {
                poly {
                    $type ParsePolyRecord $pdata
                }

                default {
                    error "Unknown keyword found in $fname: $keyword"
                }
            }
        }

        # NEXT, put the specified polygon metadata in the WDB, the
        # polygon coordinate data will be read in later.  Each polygon 
        # has a unique ID of the following form:
        #
        #      <ID>_<filename>
        #
        # Where ID is an integer representing the nth polygon read from
        # the file.  The "id" field in the .npf must correspond to this
        # integer so that the metadata in it can be associated to it.

        set polydir [file dirname $fname]
        set filenames [list]

        foreach pdict $pdictlist {
            set name       [dict get $pdict name]
            set pid        [dict get $pdict id]
            set children   [dict get $pdict children]
            set parent     [dict get $pdict parent]
            set filen      [dict get $pdict polyset]
            append pid "_" $filen

            wdb eval {
                INSERT INTO polygons(pid, dispname, children, parent, fname)
                VALUES ($pid, $name, $children, $parent, $filen)
            }

            set fullname [file join $polydir $filen]

            if {$fullname ni $filenames} {
                lappend filenames $fullname
            }
        }

        # NEXT, read all the KML polygon coordinate data
        $type readfiles $filenames

        # NEXT, the polygons with no parent are set to "root", this is
        # what the tablelist widget uses as a the base parent
        wdb eval {
            UPDATE polygons
            SET parent = 'root'
            WHERE parent = ""
        }
    }

    # ParsePolyRecord  pdata
    #
    # pdata   - a list of keyword/value pairs for a polygon record read from
    #           an .npf file
    #
    # The method puts the polygon metadata into a dictionary and adds it
    # to the list of growing metdata records that will be associated with
    # the actual polygon coordinates read from KML.

    typemethod ParsePolyRecord {pdata} {
        set pdict [dict create]

        foreach {key val} $pdata {
            dict set pdict $key [normalize $val]
        }

        lappend pdictlist $pdict
    }

    # readfiles flist
    #
    # flist  - a list of file names
    #
    # This method goes through the list of filenames provided and parses out
    # KML polygons from them.

    typemethod readfiles {flist} {
        set info(errmsgs) [dict create]

        foreach fname $flist {
            $type ParseFile $fname
        }

        return [dict size $info(errmsgs)]
    }

    # ParseFile fname
    #
    # fname  - the name of a KML file that contains polygons
    #
    # This method extracts polygons and thier names from a KML file
    # and inserts the data into the wdb.

    typemethod ParseFile {fname} {
        # FIRST, use the kmlpoly object to parse the data
        if {[catch {
            set kmldict [kmlpoly parsefile $fname]
        } result]} {
            dict set info(errmsgs) $fname $result
            return
        }

        # NEXT, extract the data from the returned dictionary and add it
        # it to the wdb.
        set names [dict get $kmldict NAMES]
        set polys [dict get $kmldict POLYGONS]
        set ids   [dict get $kmldict IDS]

        if {[llength $names] != [llength $polys]} {
            dict set info(errmsgs) $fname "Name/Polygon size mismatch."
            return
        }

        set tailf [file tail $fname]
        foreach name $names poly $polys id $ids {
            set pid $id
            append pid "_$tailf"
            wdb eval {
                UPDATE polygons
                SET polygon = $poly,
                    name    = $name,
                    id      = $id
                WHERE pid = $pid
            }
        }
    }

    # errmsgs
    #
    # returns any error message found during KML parsing
    typemethod errmsgs {} {
        return [dict get $info(errmsgs)]
    }

    # docs
    #
    # Returns HTML documentation

    typemethod docs {} {
        # TBD
    }

    # saveFile filename text
    #
    # filename   - A user selected file name
    # text       - The text to save
    #
    # Attempts to save the text to disk.
    # Errors are handled by caller.
    # Not yet used.

    typemethod saveFile {filename text} {
        set f [open $filename w]
        puts $f $text
        close $f
        return
    }

    #-------------------------------------------------------------------
    # Finish: Ingest the neighborhoods into the scenario

    # finish
    #
    # Ingests the selected neighborhoods into the scenario.

    typemethod finish {} {
        # FIRST, the wizard is done; we're about to make things happen.
        sim wizard off

        # NEXT, have the wizwin save the selected nbhoods
        $win save

        # NEXT, cleanup.
        destroy $win
    }
}



