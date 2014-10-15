#-----------------------------------------------------------------------
# TITLE:
#    kmlpoly.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#
#    Parses XML in the KML format and returns a dictionary
# of the parsed data for polygons. If no polygons are contained
# within the KML, nothing is returned. The dictionary returned
# has the following structure:
#
#     NAMES    -> List of names of the polygons, one for each nbhood
#     POLYGONS -> List of the polygons coordinates in lat/lon pairs,
#                 one for each nieghborhood.
#     IDS      -> List of assigned IDs, a monotonically increasing number
#                 starting at 1
# 
# There should be one name for each polygon and vice-versa and 
# their position in the list should correspond.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export kmlpoly
}

#-----------------------------------------------------------------------
# kml

snit::type ::projectlib::kmlpoly {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Constructor
    typeconstructor {
        namespace import ::marsutil::*
        set dp ::projectlib::domparser
    }

    #-------------------------------------------------------------------
    # Type Variables

    # kmldata - the KML data returned
    typevariable kmldata

    #-------------------------------------------------------------------
    # Type Components

    typecomponent dp  ;# domparser(n) object
    
    #-------------------------------------------------------------------
    # Type Methods

    # parse xml
    #
    # xml    - the XML to parse, it must comply with TIGR message data
    #          which, at this point, is really unknown what the exact formt
    #          is
    #
    # This method takes a chunk of XML and creates a DOM tree which is then
    # traversed and the TIGR message dictionary filled in.

    typemethod parse {xml} {
        # FIRST, default values for the TIGR message dictionary of data
        set kmldata {
            NAMES    ""
            POLYGONS ""
        }

        set nodectr 0

        # NEXT, create the DOM and get the top node
        set doc     [$dp doc $xml]
        set root    [$dp root]
        set topNode [$dp nodebyname kml]

        # NEXT check to see if this is the right format and version
        if {$topNode eq ""} {
            return -code error -errorcode INVALID \
                "Unable to parse KML, no \"kml\" root element found."
        }

        set pmnodes [$topNode getElementsByTagName "Placemark"]

        set names {}
        set polys {}

        # NEXT, we only consider Polygon tags within Placemarks
        foreach node $pmnodes {
            if {[$node getElementsByTagName "Polygon"] ne ""} {
                lappend names [$dp ctextbyname $node "name"]

                # Take the first set of coordinates presented, Athena doesn't
                # deal with multiple sets of LinearRings per polygon
                set cnode [lindex [$node getElementsByTagName "coordinates"] 0]
                lappend polys [$type NormalizePoly [$cnode text]]
                lappend ids [incr nodectr]
            }
        }

        dict set kmldata NAMES $names
        dict set kmldata POLYGONS $polys
        dict set kmldata IDS $ids

        # NEXT, delete DOM and return data
        $dp delete

        return $kmldata
    }

    # parsefile fname
    #
    # fname   - the name of an XML file that complies with v1.1.0 of the
    #           Open GIS Consortium WFS Capabilities schema
    #
    # The method opens the file extracts the XML and then calls the DOM
    # parse method.

    typemethod parsefile {fname} {
        set f [open $fname "r"]

        set xml [read $f]
        close $f

        $type parse $xml
    }

    #-------------------------------------------------------------------
    # Helper Type Methods

    # NormalizePoly coords
    #
    # coords  - the raw coordinates as read from the KML file
    #
    # This method takes the raw coordinates from a KML file and converts
    # it into a list of lat/lon pairs suitable for use by Athena in 
    # creating neighborhood polygons.

    typemethod NormalizePoly {coords} {
        # FIRST, map commas to spaces and normalize the string
        set nstr  [normalize [string map {"," " "} $coords]]

        # NEXT, split on space to convert to a proper list
        set clist [split $nstr " "]

        # NEXT, extract just latitude and longitude in the order in which
        # Athena wants it
        foreach {lon lat alt} $clist {
            lappend poly $lat $lon
        }

        # NEXT, see if the last point is the same as the first, if so, dump
        # the last point (arbitrarily).
        if {[lindex $poly 0] == [lindex $poly end-1] &&
            [lindex $poly 1] == [lindex $poly end]} {
                set poly [lrange $poly 0 end-2]
        } 

        return $poly
    }

}

