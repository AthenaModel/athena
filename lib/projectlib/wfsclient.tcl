#-----------------------------------------------------------------------
# TITLE:
#   wfsclient.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   Client type for accessing WFS servers.  Uses httpagent(n); 
#   one request can be active at a time.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export wfsclient
}


#-----------------------------------------------------------------------
# wfsclient

snit::type ::projectlib::wfsclient {
    #-------------------------------------------------------------------
    # Type Variables

    typevariable wfsVersion 1.1.0

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

    #-------------------------------------------------------------------
    # Instance Variables

    # info - Array of state data
    #
    # server-url     - Base server URL.
    # server-state   - Server state: UNKNOWN, WAITING, ERROR, OK, EXCEPTION
    # server-status  - Human-readable text for server-state
    # server-error   - Detailed debugging info for connection errors 
    #
    # server-wfscap  - Server capabilities dictionary from wfscap(n).
    #

    variable info -array {
        server-url     ""
        server-state   IDLE
        server-status  "No connection attempted"
        server-error   ""
        server-wfscap  {}
    }


    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the HTTP agent.
        install agent using httpagent ${selfns}::agent

        # NEXT, configure the options
        $self configurelist $args
    }

    #-------------------------------------------------------------------
    # server API

    # server connect url
    #
    # url  - The server's base URL
    #
    # Attempts to connect to the given WFS server.  The connection
    # is done asynchronously, and can time out.

    method {server connect} {url} {
        set info(server-url)    $url
        set info(server-state)  WAITING
        set info(server-status) "Waiting for server"
        set info(server-error)  ""

        set query [dict create      \
            SERVICE WFS             \
            VERSION $wfsVersion     \
            REQUEST GetCapabilities]


        foreach {parm value} $query {
            lappend qlist "$parm=$value"
        }

        append url [join $qlist "&"]

        $agent get $url \
            -command [mymethod CapabilitiesCmd] 
    }

    # CapabilitiesCmd
    #
    # This command is called when Capabilities 
    # data is returned from the WFS server (or when the request fails).

    method CapabilitiesCmd {} {
        # FIRST, handle HTTP errors.
        set info(server-state) [$agent state]

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
                "Could not retrieve WFS Server Capabilities"
            set info(server-error) \
                "Expected text/xml, got [$agent meta Content-Type]"

            callwith $options(-servercmd) WFSCAP
            return
        }

        if {[catch {
            set wfscap [wfscap parse [$agent data]]
        } result eopts]} {
            set ecode [dict get $eopts -errorcode]

            set info(server-state) ERROR

            if {$ecode eq "INVALID"} {
                set info(server-status) \
                    "Could not retrieve WFS Server Capabilities"
                set info(server-error) $result
            } elseif {$ecode eq "VERSION"} {
                set info(server-status) \
                    "WFS Server version mismatch; expected $wfsVersion"
                set info(server-error) $result
            } else {
                # Unexpected error; rethrow.
                return {*}$eopts $result
            }

            callwith $options(-servercmd) WFSCAP
            return
        }

        # NEXT, We have success!
        set info(server-wfscap) $wfscap

        # FINALLY, notify the user.
        callwith $options(-servercmd) WFSCAP
    }

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

    # server wfscap
    #
    # Returns the wfscap dictionary.

    method {server wfscap} {} {
        return $info(server-wfscap)
    }
}
