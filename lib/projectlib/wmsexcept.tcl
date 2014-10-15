#-----------------------------------------------------------------------
# TITLE:
#    wmsexcept.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#
#    Parses XML returned from a WMS server resulting from a service
#    exception.  Service exceptions are generated if a WMS server cannot
#    process a request for some reason. The following dict is returned
#    after parsing the XML.
#
#    Version -> The version of the WMS 
#    SeviceException => dictionary of exceptions
#                    -> code => list of strings, one per exception
#                    -> locator => list of strings, one per exception
#                    -> exception => list of strings, one per exception
#
#    The code is present only if the server has a code for the exception
#    raised. The locator is TBD. The exception is a long description
#    of the exception and is always present.
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export wmsexcept
}

#-----------------------------------------------------------------------
# wscap

snit::type ::projectlib::wmsexcept {
    #-------------------------------------------------------------------
    # Type Constructor
    typeconstructor {
        namespace import ::marsutil::*
    }

    #-------------------------------------------------------------------
    # Type Variables

    # wmsdata - the Web Map Service data returned
    typevariable wmsdata 

    # wmsversion - the WMS version this parser supports
    typevariable wmsversion "1.3.0"

    # info array
    #
    # root       - The root element of the XML file
    # currkey    - The current dictionary key that we are parsing data for
    # currcap    - The current capability
    # name       - The XML tag name
    # parent     - The parent name of the XML tag
    # stack      - The current stack of tags 
    # path       - The current stack of tags joined with "." between tags.

    typevariable info -array {
        root    {}
        currkey {}
        name    {}
        stack   {}
        path    {}
    }

    # rkeys   - The list of keys that correspond to XML tags that are of
    #           special interest
    typevariable rkeys [list ServiceException]

    #-------------------------------------------------------------------
    # Type Methods

    # parse xml
    #
    # xml    - the XML to parse, it must comply with v1.3.0 of the open GIS
    #          WMS capabilities schema

    typemethod parse {xml} {
        # FIRST, initialize the dictionary and the info array
        set wmsdata [dict create]

        foreach val [array names info] {
            set info($val) ""
        }

        dict set wmsdata Version "unknown"

        dict set wmsdata ServiceException [dict create \
                                      code {}          \
                                      locator {}       \
                                      exception {}]
                                 

        # NEXT create the parser and parse the XML, the actual handling
        # of the XML data is done in the callbacks defined here
        set parser [expat -elementstartcommand [mytypemethod HandleStart] \
                          -characterdatacommand [mytypemethod HandleData] \
                          -elementendcommand [mytypemethod HandleEnd]]

        # NEXT, any  errors encountered while parsing will propagate up
        $parser parse $xml

        # NEXT, parsing is done, free it and return the collected data
        $parser free

        return [dict get $wmsdata]
    }

    # parsefile fname
    #
    # fname  - a name of an XML file that complies with v1.3.0 of the open
    #          GIS WMS capabilities schema.
    #
    # This method opens the file provided and stores the XML data as a 
    # string and passes it into the parse method.

    typemethod parsefile {fname} {
        # FIRST, open the file and get the contents
        set f [open $fname "r"]
        set xml [read $f]
        close $f

        # NEXT, parse the data
        return [$type parse $xml]
    }

    #-------------------------------------------------------------------
    # Parser Callbacks

    # HandleStart name atts
    #
    # name   - The name of the start tag
    # atts   - Any attributes that may be part of the start tag
    #
    # This typemethod handles any parsing that must be done due to
    # encountering a start tag that is interesting.

    typemethod HandleStart {name atts} {
        # FIRST, if we are just starting check the root tag
        if {$info(root) eq ""} {
            set info(root) $name
            if {$info(root) ne "ServiceExceptionReport"} {
                return -code error -errorcode INVALID \
                    "Not a service exception."
            }
        }

        # NEXT, push the tag on the stack and set the path, name and parent
        lappend info(stack) $name
        set info(path) [join $info(stack) "."]
        set info(name) $name

        # NEXT, see if this is a top key in the dictionary
        if {$name in $rkeys} {
            set info(currkey) $name
        }

        # NEXT, operations performed based on the value of the current tag
        switch -exact -- $info(name) {
            ServiceExeptionReport {
                # Extract version number from the attributes
                set idx [lsearch $atts "version"]
                if {$idx > -1} {
                    set val [lindex $atts [expr {$idx+1}]]
                    if {$val ne $wmsversion} {
                        return -code error -errorcode VERSION \
                            "Version mismatch: $val"
                    }

                    dict set wmsdata Version $val
                }
            }

            ServiceException {
                # Extract code and locator if they exist
                set val ""
                set idx [lsearch $atts "code"]
                if {$idx > -1} {
                    set val [lindex $atts [expr {$idx+1}]]
                } 

                set clist [dict get $wmsdata ServiceException code]
                lappend clist $val
                dict set wmsdata ServiceException code $clist

                set val ""
                set idx [lsearch $atts "locator"]
                if {$idx > -1} {
                    set val [lindex $atts [expr {$idx+1}]]
                }

                set llist [dict get $wmsdata ServiceException locator]
                lappend llist $val
                dict set wmsdata ServiceException locator $llist
            }

            default {}
        }
    }

    # HandleData s
    #
    # s  - XML data between a start and end tag
    #
    # This method operates on data found between a start and end tag. The
    # stack is queried to see which tag we are currently parsing and then
    # acts accordingly

    typemethod HandleData {s} {
        # FIRST, extract the tag from the stack and normalize data.
        set tag [lindex $info(stack) end]
        set data [normalize $s]

        switch -exact -- $info(currkey) {
            ServiceException {
                set elist [dict get $wmsdata ServiceException exception]
                lappend elist $s
                dict set wmsdata ServiceException exception $elist
            }

            default {}
        }
    }

    # HandleEnd name
    #
    # name  -   the name of the end tag
    #
    # This method handles any processing that must be done based on
    # encountering an end tag

    typemethod HandleEnd {name} {
        set info(stack) [lrange $info(stack) 0 end-1]
        set info(path) [join $info(stack) "."]
    }

    #------------------------------------------------------------------
    # Helper Methods 

    # StackIs path
    #
    # path   - a path of tags
    #
    # The method prepends the WMS_Capabilities tag to the supplied path
    # and compares it to the current path of the parser. If the
    # paths match, 1 is returned otherwise 0.
    
    typemethod StackIs {path} {
        set ipath "ServiceExceptionReport.$path"
        return [expr {$ipath eq $info(path)}]
    }

    # StackContains args
    #
    # args   - A list of XML tags
    #
    # Given an arbitrary list of XML tags, return 1 if ALL of the tags
    # are in the stack, 0 otherwise

    typemethod StackContains {args} {
        set flag 1

        foreach e $args {
            set flag [expr {$e in $info(stack) & $flag}]
        }
        
        return $flag
    }
}

