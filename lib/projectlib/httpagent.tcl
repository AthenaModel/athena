#-----------------------------------------------------------------------
# TITLE:
#   httpagent.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Snit wrapper for http(n).
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export httpagent
}

# FIRST, enable use of https.
::http::register https 443 ::tls::socket

#-----------------------------------------------------------------------
# httpagent

snit::type ::projectlib::httpagent {
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

    #-------------------------------------------------------------------
    # Instance Variables

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
    }

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        $self configurelist $args

        install timeout using timeout ${selfns}::timeout \
            -interval   idle                             \
            -repetition off                              \
            -command    [mymethod UserCommand]
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

    method UserCommand {} {
        callwith $info(callback)
    }
    

    #-------------------------------------------------------------------
    # User API

    # reset
    #
    # Resets any pending request.  The -command will not be called.

    method reset {} {
        if {$info(token) ne ""} {
            if {$info(state) eq "WAITING"} {
                http::reset $info(token)
            }

            http::cleanup $info(token)
            
            set info(token) ""

        }

        $timeout cancel

        set info(state)    IDLE
        set info(status)   "Idle"
        set info(error)    ""
        set info(url)      ""
        set info(callback) ""

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
        set info(url) [MakeURL $url $opts(-query)]

        # NEXT, set up the status data
        set info(state)  WAITING
        set info(status) "Waiting for server"
        set info(error)  ""
        set info(token)  ""

        # NEXT, do the HTTP request.  GetURL does the dirty
        # work.
        if {[catch {$self GetURL}]} {
            set info(state)  ERROR
            set info(status) "Error connecting to server"
            set info(error)  "Could not connect with URL: $info(url)"
         
            # Schedule a -command callback.   
            $timeout schedule
        }
    }


    # GetURL
    #
    # Does the actual work of sending the request.

    method GetURL {} {
        # FIRST, configure the user agent
        http::config -accept $options(-contenttypes)

        # NEXT, do a GET request to the server.
        set info(token) \
            [http::geturl $info(url) \
                -timeout $options(-timeout) \
                -command [mymethod GetResponse]]
    }

    # GetResponse token
    #
    # token   - The HTTP connection token
    #
    # This command is called when data is returned from the 
    # web server (or when the request fails).

    method GetResponse {token} {
        # WARNING: http(n) will silently swallow any errors that occur
        # in this routine.  Consequently, wrap them in bgcatch.
        bgcatch {
            # FIRST, we handle connection errors.
            switch -exact -- [http::status $token] {
                ok { 
                    # If it's a 300 error, redirect (if possible).
                    set ncode [http::ncode $token]

                    if {$ncode >= 300 && $ncode < 400} {
                        set newurl [$self meta Location]

                        if {$newurl ne ""} {
                            # TBD: Need to copy query?
                            $self get $newurl
                            return
                        }
                    }
                }

                reset {
                    # Ignore; the request was reset by the user.
                    return 
                }

                timeout {
                    set info(state)  ERROR
                    set info(status) "Error connecting to server"
                    set info(error)  "Server timed out"
                    http::cleanup $info(token)
                    set info(token)  ""

                    callwith $info(callback)
                    return
                }

                error {
                    set info(state)  ERROR
                    set info(status) "Error connecting to server"
                    set info(error)  [http::error $token]
                    
                    callwith $info(callback)
                    return
                }
            }
        
            # NEXT, The request returned an HTTP status.  Handle all of the
            # cases.
            #
            # TBD: Should probably handle redirection.

            if {[http::ncode $token] != 200} {
                # Unsuccessful HTTP code?
                set info(state)  ERROR
                set info(status) "Could not retrieve data"
                set info(error)  [http::code $token]
            } else {
                # Success!
                set info(state)  OK
                set info(status) "Success"
                set info(error)  ""
            }

            callwith $info(callback)

        }
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
        if {$info(token) eq ""} {
            return ""
        }

        return [http::data $info(token)]
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

        set meta [http::meta $info(token)]

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
            dict set result status [http::status $info(token)]
            dict set result code   [http::code   $info(token)]
            dict set result ncode  [http::ncode  $info(token)]
            dict set result error  [http::error  $info(token)]
        }

        return $result
    }

    #-------------------------------------------------------------------
    # Helper Commands

    # MakeURL url qdict
    #
    # url   - A URL lacking a query, or with only a "?" at the end.
    # qdict - A dictionary of query keywords and values
    #
    # Packages the url and qdict together into one URL. Makes sure that
    # there is an http protocol specified.

    proc MakeURL {url qdict} {
        # FIRST, if there's no query there's no query.
        if {[dict size $qdict] == 0} {
            return $url
        }

        # NEXT, if the url doesn't end in "?", add one.
        if {[string index $url end] ne "?"} {
            append url "?"
        }

        # NEXT, append the formatted qdict.
        puts "calling format"
        append url [::http::formatQuery {*}$qdict]
        puts "done"

        return $url
    }
    
}
