#-----------------------------------------------------------------------
# TITLE:
#    tigrmsg.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#
#    Parses XML in the TIGR message format and returns a dictionary
# of the parsed data.  The dictionary returned contains the following
# structure:
#
#    CID          -> The unique ID of the message
#    BODY         -> Full XML body of the TIGR message    
#    TITLE        -> Human readable title of the message
#    DESCRIPTION  -> Human readable description of the message
#    LOCATIONLIST -> List of lat/lon pairs: {{lat1 lon1} {lat2 lon2}...}
#    TIMEPERIOD   => dictionary of time period info for this message
#                 -> START => dictionary of start time info
#                          -> STRING => Time string, as parsed from file
#                          -> ZULUSEC => Integer, unix time stamp of 
#                                        start time corresponding to GMT
#                          -> TIMEZONE => String, time zone suitable to be
#                                         used with [clock format]
#                -> END => dictionary of end time info
#                       -> STRING => Time string, as parsed from file
#                       -> ZULUSEC => Integer, unix time stamp of 
#                                     end time corresponding to GMT
#                       -> TIMEZONE => String, time zone suitabl to be
#                                      used with [clock format]
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export tigrmsg
}

#-----------------------------------------------------------------------
# tigrmsg

snit::type ::projectlib::tigrmsg {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Constructor
    typeconstructor {
        namespace import ::marsutil::*
        set dp ::projectlib::domparser
    }

    #-------------------------------------------------------------------
    # Type Variables

    # tigrmsgdata - the TIGR message data returned
    typevariable tigrmsgdata

    # tigrversion - the TIGR version this parser supports
    typevariable tigrversion "Unknown"

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
        set tigrmsgdata {
            CID          "unknown"
            TITLE        ""
            DESCRIPTION  ""
            LOCATIONLIST ""
            TIMEPERIOD   ""
            BODY         ""
        }

        dict set tigrmsgdata BODY $xml

        # NEXT, create the DOM and get the top node
        set doc     [$dp doc $xml]
        set root    [$dp root]
        set topNode [$dp nodebyname PLACE]

        # NEXT check to see if this is the right format and version
        if {$topNode eq ""} {
            return -code error -errorcode INVALID \
                "Unable to parse TIGR message, expected PLACE data."
        }

        # NEXT, extract CID from the attributes of the PLACE take
        dict set tigrmsgdata CID [$dp attr $topNode CID]

        # NEXT, parse for title and description
        dict set tigrmsgdata TITLE [$dp ctextbyname $topNode "TITLE"]
        dict set tigrmsgdata DESCRIPTION \
            [$dp ctextbyname $topNode "DESCRIPTION"]

        # NEXT, extract the location list
        set pnode [$topNode getElementsByTagName "LOCATIONLIST"]
        set locs [$dp cnodesbyname $pnode "COORDINATES"]

        dict set tigrmsgdata LOCATIONLIST [$type ConvertLocs $locs]

        # NEXT, extract the timeperiod
        set tnode [$topNode getElementsByTagName "TIMEPERIOD"]
        set start [$dp ctextbyname $tnode "START"]
        set end   [$dp ctextbyname $tnode "END"]

        set zulusec  [$type ToZuluSec $start]
        set timezone [$type TimeZone  $start]

        dict set tigrmsgdata TIMEPERIOD START STRING $start
        dict set tigrmsgdata TIMEPERIOD START ZULUSEC $zulusec
        dict set tigrmsgdata TIMEPERIOD START TIMEZONE $timezone

        set zulusec  [$type ToZuluSec $end]
        set timezone [$type TimeZone  $end]

        dict set tigrmsgdata TIMEPERIOD END STRING $end
        dict set tigrmsgdata TIMEPERIOD END ZULUSEC $zulusec
        dict set tigrmsgdata TIMEPERIOD END TIMEZONE $timezone

        # NEXT, delete DOM and return data
        $dp delete

        return $tigrmsgdata
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

    # ToZuluSec  timestr
    #
    # timestr  - a valid timestring
    #
    # This method takes a time string and returns a Unix timestamp that
    # corresponds to the time at GMT. Valid time strings are ones that
    # have a time and date separated by a capital "T" with the time
    # being on the right and date on the left. Followed by 5 charaters
    # of the form:
    #
    #    signHHMM 
    #
    # Where sign is either a "+" or a "-" and HH is the hour of the 
    # timezone offset from GMT and MM is the minutes of the timezone
    # offset from GMT.  Most of the time minutes will be "00", but it
    # doesn't have to be. Valid time strings are
    # any of those recognized by the Tcl [clock scan] command. Valid date
    # strings are any of those recognized by the Tcl [clock scan] command.
    #
    # Example of valid time string:
    #
    #   2010-07-26T13:42:35-0400
    #
    
    typemethod ToZuluSec {timestr} {
        # FIRST, trim off the trailing time zone
        set zulu [string range $timestr 0 end-5]

        # NEXT, split the time and date up, it turns out that the
        # time and date can be interchanged
        lassign [split $zulu "T"] d t

        # NEXT, basic check of time string. All other errors handled
        # by the clock scan command.
        if {$d eq "" || $t eq ""} {
            set msg "Invalid time string, \"$timestr\"."

            error $msg
        }

        return [clock scan "$d $t"]
    }

    # TimeZone  timestr
    #
    # timestr  - a valid timestring
    #
    # See the ToZuluSec typemethod for valid time string requirements.
    #
    # This method extracts the time zone of the timestring and returns
    # it.  Basic error checking is done on the time string.  The time
    # zone returned is suitable to be used with the [clock format]
    # command.

    typemethod TimeZone {timestr} {
        # FIRST, extract the time zone and validate it.
        set tz [string range $timestr end-4 end]

        if {![regexp {^[+-][01][0-9][0-5][0-9]} $tz]} {
            error "Invalid time zone offset format, \"$tz\"."
        }

        # NEXT, return the unix time stamp with the offset
        return $tz
    }


    # ConvertLocs  locs
    #
    # locs  - a list of location strings as specified in the TIGR location
    #         format
    #
    # This method takes a list of TIGR location strings and converts
    # them to lat/long pairs returned as a list.

    typemethod ConvertLocs {locs} {
        foreach lstr $locs {
            # FIRST, figure out where to break lat and long
            set Nidx [string first "N" $lstr]
            set Sidx [string first "S" $lstr]
            set Eidx [string first "E" $lstr]
            set Widx [string first "W" $lstr]

            # NEXT, check for egregious errors
            if {$Nidx == -1 && $Sidx == -1} {
                error "Invalid location string, missing latitude: $lstr"
            }

            if {$Eidx == -1 && $Widx == -1} {
                error "Invalid location string, missing longitude: $lstr"
            }

            # NEXT, convert based on north/south hemisphere
            if {$Nidx > -1} {
                lappend rlocs [$type ConvertNorthingLoc $lstr]
            } else {
                lappend rlocs [$type ConvertSouthingLoc $lstr]
            }
        }

        return $rlocs
    }

    # ConvertNorthingLog lstr
    #
    # lstr  - a location string in the TIGR location format
    #
    # This method converts a string that contains a northing component
    # of latitude to a lat/long pair.

    typemethod ConvertNorthingLoc {lstr} {
        # FIRST, extract key locations within the string
        set Nidx [string first "N" $lstr]
        set Eidx [string first "E" $lstr]
        set Widx [string first "W" $lstr]

        # NEXT, parse based on whether an easting or westing of
        # longitude is present
        # Note: care is taken to trim leading zeroes
        if {$Eidx > -1} {
            # Easting
            if {$Nidx < $Eidx} {
                lassign [split $lstr "N"] lat lon
                set lon [string trimright $lon "E"]
            } else {
                lassign [split $lstr "E"] lon lat
                set lat [string trimright $lat "N"]
            }

            set lon [string trimleft $lon "0"]
        } else {
            # Westing
            if {$Nidx < $Widx} {
                lassign [split $lstr "N"] lat lon
                set lon [string trimright $lon "W"]
            } else {
                lassign [split $lstr "W"] lon lat
                set lat [string trimright $lat "N"]
            }

            set lon [string trimleft $lon "0"]
            let lon {-1.0 * $lon}
        }

        set lat [string trimleft $lat "0"]

        # NEXT, format has 6 digits of precision
        let lat {$lat / 1000000.0}
        let lon {$lon / 1000000.0}

        return [list $lat $lon]
    }


    # ConvertSouthingLoc lstr
    #
    # lstr  - a location string in the TIGR location format
    #
    # This method converts a string that contains a southing component
    # of latitude to a lat/long pair.

    typemethod ConvertSouthingLoc {lstr} {
        # FIRST, extract key positions in the string
        set Sidx [string first "S" $lstr]
        set Eidx [string first "E" $lstr]
        set Widx [string first "W" $lstr]

        # NEXT, parse based on presence of easting or westing of 
        # longitude
        # Note: care is taken to trim leading zeroes
        if {$Eidx > -1} {
            # Easting
            if {$Sidx < $Eidx} {
                lassign [split $lstr "S"] lat lon
                set lon [string trimright $lon "E"]
            } else {
                lassign [split $lstr "E"] lon lat
                set lat [string trimright $lat "S"]
            }

            set lon [string trimleft $lon "0"]
            set lat [string trimleft $lat "0"]
            let lat {-1.0 * $lat}

        } else {
            # Westing
            if {$Sidx < $Widx} {
                lassign [split $lstr "S"] lat lon
                set lon [string trimright $lon "W"]
            } else {
                lassign [split $lstr "W"] lon lat
                set lat [string trimright $lat "S"]
            }

            set lon [string trimleft $lon "0"]
            set lat [string trimleft $lat "0"]
            let lat {-1.0 * $lat}
            let lon {-1.0 * $lon}
        }

        # NEXT, there is six digits of precision
        let lat {$lat / 1000000.0}
        let lon {$lon / 1000000.0}

        return [list $lat $lon]
    }

}

