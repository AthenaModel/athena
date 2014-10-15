#-----------------------------------------------------------------------
# TITLE:
#   httpagentsim.tcl
#
# AUTHOR:
#   Dave hanks
#
# DESCRIPTION:
#   A simulator for httpagent(n) for use in testing clients that use
#   httpagent(n).
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export httpagentsim
}

# FIRST, enable use of https.

#-----------------------------------------------------------------------
# httpagentsim

snit::type ::projectlib::httpagentsim {
    #-------------------------------------------------------------------
    # Type Variables

    # TBD

    #-------------------------------------------------------------------
    # Components

    component timeout ;# Timeout used for callbacks

    #-------------------------------------------------------------------
    # Options

    # -command cmd
    #
    # Command to be called when a request is complete (whether
    # successfully or not).

    option -command

    # -timeout msec
    # 
    # The timeout on server requests, in milliseconds

    option -timeout \
        -type    {snit::integer -min 0} \
        -default 10000

    # -contenttypes list
    #
    # List of mime types acceptable to the user.

    option -contenttypes \
        -default {text/xml text/plain text/html}

    # -testfile
    #
    # file to extract data from to use in a simulated server response

    option -testfile -default ""

    # -imgfile
    #
    # file to extract an image from to use in a simulated server response

    option -imgfile -default ""

    # -forcetimeout
    #
    # Forces the simulated server to timeout

    option -forcetimeout -default 0

    #-------------------------------------------------------------------
    # Instance Variables

    # waitvar
    # 
    # Since there's no real server involved, this variable is used in
    # a vwait to wait for callbacks in a timout(n) to occur

    variable waitvar

    # info - Array of state data
    #
    # token     - http(n) token for HTTP request
    # url       - Actual URL used in GET request
    # state     - State of the agent: IDLE WAITING TIMEOUT ERROR OK
    # status    - Human-readable status string
    # error     - Detailed error when state is ERROR
    # callback  - Callback to call for current request.

    variable info -array {
        token    ""
        url      ""
        state    IDLE
        status   ""
        error    ""
        callback ""
        wmsxml   ""
        wmsmap   ""
    }

    variable token -array {
        status  ok
        meta    {}
        body    {}
        code    {}
        ncode   {}
        type    {}
        url     {}
        error   {}
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        $self configurelist $args

        install timeout using timeout ${selfns}::timeout \
            -interval   idle                             \
            -repetition off                              \
            -command    [mymethod ServerResponse]

        # Open up the test data for WMS capabilities
        set fname $options(-testfile)

        set f [open $fname "r"]
        if {[catch {
            set info(wmsxml) [read $f]
        } result]} {
            error "Could not read XML test data: $result"
        }

        set imgfile $options(-imgfile)
        if {$imgfile ne ""} {
            if {[catch {
                set info(wmsmap) [image create photo -file $imgfile]
            } result]} {
                error "Could not open file as image: $imgfile"
            }
        }
    }

    destructor {
        catch {$timeout destroy}
    }

    #-------------------------------------------------------------------
    # Event Handlers

    # UserCommand
    #
    # Calls the user's callback in response to an immediate error.
    # This is called by a timeout object, to make immediate responses 
    # look like asynchronous responses, so that they can be handled in 
    # the same way.

    method ServerResponse {} {
        if {$options(-forcetimeout)} {
            set token(status) timeout
        }

        switch -exact -- $token(status) {
            ok { 
            }

            reset {
                # Ignore; the request was reset by the user.
                set waitvar 1
                return 
            }

            timeout {
                set info(state)  ERROR
                set info(status) "Error connecting to server"
                set info(error)  "Server timed out"
                set info(token)  ""

                callwith $info(callback)
                set waitvar 1
                return
            }

            error {
                set info(state)  ERROR
                set info(status) "Error connecting to server"
                set info(error)  "Error connecting to server"
                
                callwith $info(callback)
                set waitvar 1
                return
            }
        }
    
        set info(state)  OK
        set info(status) "Success"
        set info(error)  ""

        callwith $info(callback)
        set waitvar 1
    }
    

    #-------------------------------------------------------------------
    # User API

    # reset
    #
    # Resets any pending request.  The -command will not be called.

    method reset {} {
        if {$info(token) ne ""} {
            set info(token) ""
        }

        $timeout cancel

        set info(state)    IDLE
        set info(status)   "Idle"
        set info(error)    ""
        set info(url)      ""
        set info(callback) ""

        set token(status) ok
        set token(meta)   ""
        set token(body)   ""
        set token(type)   ""
        set token(url)    ""
        set token(error)  ""

        set waitvar 1
        return
    }

    # get url ?option value...?
    #
    # url   - The URL to GET
    #
    # Options:
    #
    #   -query    - dictionary of query keywords and values
    #   -command  - Callback command to use.
    # 
    # Does an asynchronous GET of the URL.  Calls the default -command
    # or the -command specified here the context of the event loop when 
    # the GET is complete, one way or another.

    method get {url args} {
        # FIRST, cancel any pending request
        $self reset

        # NEXT, get the options
        set opts(-query)   ""
        set opts(-command) $options(-command)

        while {[llength $args] > 0} {
            set opt [lshift args]

            switch -exact -- $opt {
                -query   -
                -command {
                    set value [lshift args]

                    if {$value ne ""} {
                        set opts($opt) $value
                    }
                }
                default {
                    error "Unexpected option: \"$opt\""
                }
            }
        }

        # NEXT, if there's no callback we can't do a request
        if {$opts(-command) eq ""} {
            error "No callback -command specified"
        }

        set info(callback) $opts(-command)

        # NEXT, put the URL together
        set info(url) $url

        # NEXT, set up the status data
        set info(state)  WAITING
        set info(status) "Waiting for server"
        set info(error)  ""
        set info(token)  ""

        # NEXT, do the HTTP request.  GetURL does the dirty
        # work.
        if {[catch {$self GetURL} result]} {
            set info(state)  ERROR
            set info(status) "Error connecting to server"
            set info(error)  $result
         
            set waitvar {}
            $timeout schedule
            vwait [myvar waitvar]
        }
    }


    # GetURL
    #
    # Does the actual work of sending the request.

    method GetURL {} {
        # NEXT, do a simulated GET request to the server.
        set token(url) $info(url)

        if {[string first "GetCapabilities" $info(url)] != -1} {
            set token(body) $info(wmsxml)
            set info(token) [dict create Content-Type "text/xml"]
        } elseif {[string first "GetMap" $info(url)] != -1} {
            set token(body) {}
            set info(token) [dict create Content-Type "image/png"]
        } else {
            error "Cannot process URL: $token(url)"
        }

        set token(state) ok
        set token(status) "Success"

        set waitvar {}
        $timeout schedule
        vwait [myvar waitvar]
    }

    # url
    #
    # Returns the current URL.

    method url {} {
        return $info(url)
    }

    # state
    #
    # Returns the current agent state.    

    method state {} {
        return $info(state)
    }

    # status
    #
    # Returns the current status text.    

    method status {} {
        return $info(status)
    }

    # error
    #
    # Returns the current error text.    

    method error {} {
        return $info(error)
    }

    # token
    #
    # Returns the token for the current status, or ""

    method token {} {
        return $info(token)
    }

    # data
    # 
    # Returns the data from the last request, or "" if none.

    method data {} {
        return $token(body)
    }
    
    # meta ?name?
    #
    # name - An http meta header name
    # 
    # When state is OK, returns the header value, or the entire
    # header dictionary.  If the header doesn't exist, returns
    # the empty string.

    method meta {{name ""}} {
        if {$info(token) eq ""} {
            return ""
        }

        set meta $info(token)

        if {$name eq ""} {
            return $meta
        }

        if {[dict exists $meta $name]} {
            return [dict get $meta $name]
        }

        return ""
    }

    # httpinfo 
    #
    # Returns a dictionary of the low level http results from the
    # last request.  The dictionary has the following keys; if
    # there is no valid request data, their values will be the
    # the empty string:
    #
    #   status  -  http::status
    #   code    -  http::code
    #   ncode   -  http::ncode
    #   error   -  http::error

    method httpinfo {} {
        set result [dict create status "" code "" ncode "" error ""]

        if {$info(token) ne ""} {
            dict set result status $token(status)
            dict set result code   $token(code)
            dict set result ncode  $token(ncode)
            dict set result error  $token(error)
        }

        return $result
    }
}
