#-----------------------------------------------------------------------
# TITLE:
#   wmsclient.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Client type for accessing WMS servers.  Uses httpagent(n); 
#   one request can be active at a time.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export wmsclient
}


#-----------------------------------------------------------------------
# wmsclient

snit::type ::projectlib::wmsclient {
    #-------------------------------------------------------------------
    # Type Variables

    typevariable wmsVersion 1.3.0

    #-------------------------------------------------------------------
    # Components

    component agent -public agent ;# The httpagent(n) object.

    #-------------------------------------------------------------------
    # Options

    delegate option -timeout to agent

    # -servercmd cmd
    #
    # A command to call when the [$o server state] changes.

    option -servercmd

    # -agent httpagent
    #
    # If supplied, the agent for processing http requests. Normally
    # this is left empty and wmsclient(n) then defaults to httpagent(n)
    # However, in a test environment there is no guarantee that there
    # will be a network present so an http agent simulator is used.

    option -agent -default ""

    #-------------------------------------------------------------------
    # Instance Variables

    # info - Array of state data
    #
    # server-url     - Base server URL.
    # server-state   - Server state: UNKNOWN, WAITING, ERROR, OK, EXCEPTION
    # server-status  - Human-readable text for server-state
    # server-error   - Detailed debugging info for connection errors 
    #
    # server-wmscap  - Server capabilities dictionary from wmscap(n).
    #
    # GetMap-url     - URL for GetMap request
    #
    # For GetMap requests:
    # map-maxwidth   - max width 
    # map-maxheight  - max height 
    # map-layerlimit - max number of layers  
    # map-maxbbox    - bounding box for which map requests can be made
    # map-crs        - the coordinate reference system (use EPSG:4326 for now)

    variable info -array {
        server-url     ""
        server-state   IDLE
        server-status  "No connection attempted"
        server-error   ""
        server-wmscap  {}

        GetMap-url     ""
        map-data       ""
        map-maxwidth   4000
        map-maxheight  3000
        map-layerlimit 20
        map-maxbbox    {-180 -90 180 90}
        map-crs        "EPSG:4326"
    }


    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the HTTP agent.
        install agent using httpagent ${selfns}::agent

        # NEXT, configure the options
        $self configurelist $args

        # NEXT, if -agent supplied, use it instead
        if {$options(-agent) ne ""} {
            $agent destroy
            set agent $options(-agent)
        }
    }

    #-------------------------------------------------------------------
    # server API

    # server connect url
    #
    # url  - The server's base URL
    #
    # Attempts to connect to the given WMS server.  The connection
    # is done asynchronously, and can time out.

    method {server connect} {url} {
        set info(server-url)    $url
        set info(server-state)  WAITING
        set info(server-status) "Waiting for server"
        set info(server-error)  ""

        # FIRST, make sure we have a valid protocol in the URL (only http)
        if {[string range $url 0 6] ne "http://" } {
            set url "http://$url"
        }

        set query [dict create      \
            SERVICE WMS             \
            VERSION $wmsVersion     \
            REQUEST GetCapabilities]

        if {[string range $url end end] ne "?"} {
            append url "?"
        }

        foreach {parm value} $query {
            lappend qlist "$parm=$value"
        }

        append url [join $qlist "&"]

        set u [uri::split $url]
        
        if {[string first " " [dict get $u path]] > -1} {
            set info(server-state) ERROR
            set info(server-status) "Malformed URL"
            set info(server-error) \
                "Invalid URL: $url"
            
            callwith $options(-servercmd) WMSCAP
            return
        }

        $agent get $url \
            -command [mymethod CapabilitiesCmd] 
    }

    # CapabilitiesCmd
    #
    # This command is called when Capabilities 
    # data is returned from the WMS server (or when the request fails).

    method CapabilitiesCmd {} {
        # FIRST, handle HTTP errors.
        set info(server-state)  [$agent state]
        set info(server-status) [$agent status]

        if {$info(server-state) ne "OK"} {
            set info(server-status) [$agent status]
            set info(server-error)  [$agent error]
            callwith $options(-servercmd)
            return
        }

        # NEXT, we got the data we wanted; let's make sure it really
        # is the data we wanted.

        if {[$agent meta Content-Type] ne "text/xml"} {
            set info(server-state) ERROR
            set info(server-status) \
                "Could not retrieve WMS Server Capabilities"
            set info(server-error) \
                "Expected text/xml, got [$agent meta Content-Type]"

            callwith $options(-servercmd) WMSCAP
            return
        }

        if {[catch {
            set data [$agent data]
            set wmscap [wmscap parse $data]
        } result eopts]} {
            set ecode [dict get $eopts -errorcode]

            set info(server-state) ERROR

            if {$ecode eq "INVALID"} {
                set info(server-status) \
                    "Could not retrieve WMS Server Capabilities"
                set info(server-error) $result
            } elseif {$ecode eq "VERSION"} {
                set info(server-status) \
                    "WMS Server version mismatch; expected $wmsVersion"
                set info(server-error) $result
            } else {
                # Unexpected error; rethrow.
                return {*}$eopts $result
            }

            callwith $options(-servercmd) WMSCAP
            return
        }

        # NEXT, We have success, check the returned data
        set info(server-wmscap) $wmscap

        # NEXT, extract default capabilities 
        set info(GetMap-url)     [dict get $wmscap Request GetMap Xref]
        set info(map-maxwidth)   [dict get $wmscap Service MaxWidth]
        set info(map-maxheight)  [dict get $wmscap Service MaxHeight]
        set info(map-layerlimit) [dict get $wmscap Service LayerLimit]

        if {[string range $info(GetMap-url) end end] ne "?"} {
            append info(GetMap-url) "?"
        }

        # NEXT, see if we have a coordinate reference system that is
        # supported
        set crslist [dict get $wmscap Service CRS]
        set idx1 [lsearch $crslist "CRS:84"]
        set idx2 [lsearch $crslist "EPSG:4326"]
        if {$idx1 > -1} {
            set crs [lindex $crslist $idx1]
            set bbox [lindex [dict get $wmscap Service BoundingBox] $idx1]
        } elseif {$idx2 > -1} {
            set crs [lindex $crslist $idx2]
            set bbox [lindex [dict get $wmscap Service BoundingBox] $idx2]
        } else {
            error "No supported coordinate reference systems found."
        }

        set info(map-crs)      $crs
        set info(map-maxbbox)  $bbox

        # NEXT, set the defaults in the transient values
        set info(map-bbox)       $info(map-maxbbox)
        set info(map-width)      $info(map-maxwidth)
        set info(map-height)     $info(map-maxheight)

        # FINALLY, notify the user.
        callwith $options(-servercmd) WMSCAP
    }

    # server getmap qparms
    #
    # qparms   - The query parameters
    #
    # Requests a map from the connected server.  Default parameters
    # are included but can be overridden with supplied qparms. 
    # At least one layer must be supplied in qparms or the request will
    # fail.

    method {server getmap} {qparms} {
        # FIRST, set server state
        set url $info(GetMap-url)

        if {$url eq ""} {
            error "No URL defined for GetMap requests."
        }

        set info(server-state) WAITING
        set info(server-status) "Waiting for server"
        set info(server-error) ""

        # NEXT, set defaults for query parms
        set qdefault [dict create              \
            SERVICE WMS                        \
            VERSION $wmsVersion                \
            REQUEST GetMap                     \
            FORMAT  image/png                  \
            CRS     $info(map-crs)             \
            BBOX    [join $info(map-bbox) ","] \
            WIDTH   $info(map-width)           \
            HEIGHT  $info(map-height)]

        # NEXT, merge user parms and format the URL to be WMS compliant
        set query [dict merge $qdefault $qparms]
        set info(map-bbox) [split [dict get $query BBOX] ","]
        set info(map-width) [dict get $query WIDTH]
        set info(map-height) [dict get $query HEIGHT]

        foreach {parm value} $query {
            lappend qlist "$parm=$value"
        }

        append url [join $qlist "&"]

        $agent get $url \
            -command [mymethod MapCmd]
    }

    # MapCmd
    #
    # This method is called when a map image is returned from the
    # server or if the request fails.

    method MapCmd {} {
        set info(server-state) [$agent state]

        # FIRST, handle error state
        if {$info(server-state) ne "OK"} {
            set info(server-status) [$agent status]
            set info(server-error) [$agent error]
            callwith $options(-servercmd) WMSMAP
            return
        }

        # NEXT, deal with expected content types
        if {[$agent meta Content-Type] eq "text/xml"} {
            # NEXT, try to parse the content as a service exception
            if {[catch {
                set edata [wmsexcept parse [$agent data]]
            } result eopts]} {
                set ecode [dict get $eopts -errorcode]

                set info(server-state) ERROR

                if {$ecode eq "INVALID"} {
                    set info(server-status) \
                        "Could not retrieve WMS Server Map"
                    set info(server-error) $result
                } elseif {$ecode eq "VERSION"} {
                    set info(server-status) \
                        "WMS Server version mismatch; expected $wmsVersion"
                    set info(server-error) $result
                } else {
                    # Unexpected error; rethrow.
                    return {*}$eopts $result
                }

                callwith $options(-servercmd) WMSMAP
                return
            }

            # NEXT, parsing of exception succeeded report the exception
            set info(server-state) ERROR
            set info(server-status) \
                "Could not retrive WMS Server Map"
            set info(server-error) ""
            set elist [dict get $edata ServiceException exception]
            set clist [dict get $edata ServiceException code]

            foreach e $elist c $clist {
                if {$c ne ""} {
                    append info(server-error) "ERROR CODE: $c "
                }
                append info(server-error) "$e\n"
            }

        } elseif {[$agent meta Content-Type] eq "image/png"} {
            # Got the map data, store it
            set info(map-data) [$agent data]
        } else {
            # Unexpected content
            set info(server-state) ERROR
            set info(server-status) \
                "Could not retrieve WMS Server Map"
            set info(server-error) \
                "Unexpected content type: [$agent meta Content-Type]"
        }

        callwith $options(-servercmd) WMSMAP
    }

    # server url
    #
    # Returns the server's base URL

    method {server url} {} {
        return $info(server-url)
    }

    # server state
    #
    # Returns the current server state code.    

    method {server state} {} {
        return $info(server-state)
    }

    # server status
    #
    # Returns the current server status text.    

    method {server status} {} {
        return $info(server-status)
    }

    # server error
    #
    # Returns the current server status text.    

    method {server error} {} {
        return $info(server-error)
    }

    # server wmscap
    #
    # Returns the wmscap dictionary.

    method {server wmscap} {} {
        return $info(server-wmscap)
    }

    # map data
    #
    # This method returns the current map image as binary data

    method {map data} {} {
        return $info(map-data)
    }

    # map bbox
    #
    # Returns the current bounding box in CRS coordinates

    method {map bbox} {} {
        return $info(map-bbox)
    }

    # map crs
    #
    # Returns the coordinate reference system in use

    method {map crs} {} {
        return $info(map-crs)
    }

    # map width
    #
    # Returns the map width in pixels

    method {map width} {} {
        return $info(map-width)
    }

    # map height
    #
    # Returns the map height in pixels

    method {map height} {} {
        return $info(map-height)
    }

}
