#-----------------------------------------------------------------------
# TITLE:
#    wfscap.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#
#    Parses XML returned from a WFS server resulting from a
#    GetCapabilities call. A nested dictionary is returned with the
#    following structure. If data is not found for a particular tag,
#    the value for that key in the dictionary corresponding to that tag 
#    is the empty string.
#
#    Version -> The version of the WFS 
#    Operation => dictionary of WFS operations available
#              -> $operation => dictionary of metadata for the operation
#                               defined
#                            -> Xref => string, base URL for $operation
#    FeatureType => dictionary of WFS features available
#                -> $feature => dictionary of metadata for the feature
#                               defined
#                            -> Title => string, human readable description
#                            -> SRS => Default spatial reference system 
#                                      for the defined feature
#    Constraints => list of constraint name/value pairs, constraints are
#                   defined by the WFS
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export wfscap
}

#-----------------------------------------------------------------------
# wscap

snit::type ::projectlib::wfscap {
    #-------------------------------------------------------------------
    # Type Variables

    # wfsdata - the Web Feature Service data returned
    typevariable wfsdata 

    # wfsversion - the WMS version this parser supports
    typevariable wfsversion "1.1.0"

    #-------------------------------------------------------------------
    # Type Components

    typecomponent dp  ;# domparser(n) object

    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        namespace import ::marsutil::*
        set dp ::projectlib::domparser
    }

    #-------------------------------------------------------------------
    # Type Methods

    # parse xml
    #
    # xml    - the XML to parse, it must comply with v1.1.0 of the open GIS
    #          WFS capabilities schema
    #
    # This method takes a chunk of XML and creates a DOM tree which is then
    # traversed and the WFS dictionary filled in.

    typemethod parse {xml} {

        # FIRST, default values for the WFS dictionary of data
        dict set wfsdata Version "unknown"
        dict set wfsdata Operation ""
        dict set wfsdata FeatureType ""
        dict set wfsdata Constraints ""

        # NEXT, create the DOM and get the top node
        set doc     [$dp doc $xml]
        set root    [$dp root]
        set topNode [$dp nodebyname WFS_Capabilities]

        # NEXT check to see if this is the right format and version
        if {$topNode eq ""} {
            return -code error -errorcode INVALID \
                "Not WFS Capabilities data."
        }

        set vers [$dp attr $topNode "version"]

        if {$vers ne $wfsversion} {
            return -code error -errorcode VERSION \
                "Version mismatch: $vers"
        }

        # NEXT, set version
        dict set wfsdata Version $vers

        # NEXT, parse constraints
        foreach node [$root selectNodes /*] {
            foreach cons [$node getElementsByTagName ows:Constraint] {
                set name [$dp attr $cons name]
                set val [$dp ctextbyname $cons "ows:Value"]
                dict lappend wfsdata Constraints $name $val
            }
        }

        # NEXT, parse available WFS operations
        foreach node [$root selectNodes /*] {
             foreach op [$node getElementsByTagName ows:Operation] {
                 set operation [$dp attr $op name]
                 set urlNode [$dp cnodebyname $op "ows:Get"]
                 set url [$dp attr $urlNode xlink:href]

                 set d [dict create $operation [dict create Xref $url]]
                 set newd [dict merge $d [dict get $wfsdata Operation]]
                 dict set wfsdata Operation $newd
             }
        }
        
        # NEXT, parse available WFS feature types
        foreach node [$root selectNodes /*] {
            foreach feature [$node getElementsByTagName FeatureType] {
                set name [$dp ctextbyname $feature Name]
                set title [$dp ctextbyname $feature Title]
                set srs   [$dp ctextbyname $feature DefaultSRS]

                set d [dict create $name [dict create Title $title SRS $srs]]
                set newd [dict merge $d [dict get $wfsdata FeatureType]]
                dict set wfsdata FeatureType $newd
            }
        }

        # NEXT, delete DOM and return data
        $dp delete

        return $wfsdata
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
}

