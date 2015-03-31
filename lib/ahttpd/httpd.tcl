#-----------------------------------------------------------------------
# TITLE:
#    httpd.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    ahttpd(n): HTTP Protocol
#
#    HTTP 1.0 protocol stack, plus connection keep-alive and 1.1 subset.
#    This accepts connections and calls out to [url dispatch] once a 
#    request has been received.  There are several utilities for returning
#    different errors, redirects, challenges, files, and data.
#
#    For async operation, such as long-lasting server-side operations, use
#    [httpd suspend]
#
#    Matt Newman (c) 1999 Novadigm Inc.
#    Stephen Uhler / Brent Welch (c) 1997 Sun Microsystems
#    Brent Welch (c) 1998-2000 Ajuba Solutions
#    Brent Welch (c) 2001-2004 Panasas Inc
#    Will Duquette (c) 2015 California Institute of Technology
#
#    See the file "license.terms" for information on usage and 
#    redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# CONNECTION STATE ARRAY:
#
#    The per-connection state is kept in the "data" array, which is
#    really an array named ::ahttpd::Httpd$sock (note the upvar #0 trick 
#    throughout this package). The elements of this array are documented 
#    here.  URL implementations are free to hang additional state off the 
#    data array so long as they do not clobber the elements documented 
#    here.
#    
#    Well-Known Fields:  These fields are semi-public, or "well known".  
#    There are a few API's to access them, but URL implementations can rely 
#    on them being present:
#    
#    self        - A list of protocol (http or https), name, and port that
#                  capture the server-side of the socket address
#                  Available with [httpd protocol], [httpd name], and
#                  [httpd port].
#    uri         - The complete URL, including proto, servername, and query
#    proto       - http or https
#    url         - The URL after the server name and before the ?.  
#                  Includes leading "/".
#    query       - The URL after the ?
#    ipaddr      - The remote client's IP address
#    cert        - Client certificate (The result of tls::status)
#    host        - The host specified in the URL, if any (proxy case)
#    port        - The port specified in the URL, if any
#    mime,*      - HTTP header request lines (e.g., mime,content-type)
#    count       - Content-Length
#    set-cookie  - List of Set-Cookie headers to stick into the response
#                  Use [httpd setCookie] to append to this.
#    headers     - List of http headers to stick into the response
#                  Use [httpd addHeaders] to append to this.
#    
#    prefix      - Set by [url dispatch] to be the URL domain prefix
#    suffix      - Set by [url dispatch] to be the URL domain suffix
#    auth_type   - Set by the auth.tcl module to "Basic", etc.
#    remote_user - Set by the auth.tcl to username from Basic 
#                  authentication.
#    session     - Set by the auth.tcl to "realm,$username" from Basic 
#                  auth.  You can overwrite this session ID with something 
#                  more useful.
#    
#    Internal fields used by this module:
#
#    left           - The number of keep-alive connections allowed
#    cancel         - AfterID of event that will terminate the connection 
#                     on timeout
#    state          - State of request processing
#    version        - 1.0 or 1.1
#    line           - The current line of the HTTP request
#    mimeorder      - List indicating order of MIME header lines
#    key            - Current header key
#    checkNewline   - State bit for Netscape SSL newline bug hack
#    callback       - Command to invoke when request has completed
#    file_size      - Size of file returned by ReturnFile
#    infile         - Open file used by fcopy to return a file, or CGI pipe
#
#-----------------------------------------------------------------------

snit::type ::ahttpd::httpd {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables
    
    # HTTP/1.0 error names by code (the ones we use)
    typevariable errorNames -array {
        200 {Data follows}
        204 {No Content}
        302 {Found}
        304 {Not Modified}
        400 {Bad Request}
        401 {Authorization Required}
        403 {Permission denied}
        404 {Not Found}
        408 {Request Timeout}
        411 {Length Required}
        419 {Expectation Failed}
        500 {Server Internal Error}
        501 {Server Busy}
        503 {Service Unavailable}
        504 {Service Temporarily Unavailable}
    }

    # errorFormat: generic error response
    typevariable errorFormat {
        <title>httpd error: %1$s</title>
        Got the error <b>%2$s</b><br>
        while trying to obtain <b>%3$s</b>.
    }

    # redirectFormat: generic redirect message.
    typevariable redirectFormat {
        <html><head>
        <title>Found</title>
        </head><body>
        This document has moved to a new <a href="%s">location</a>.
        Please update your documents and hotlists accordingly.
        </body></html>
    }

    # authorizationFormat: generic auth message
    typevariable authorizationFormat {
        <HTML><HEAD>
        <TITLE>401 Authorization Required</TITLE>
        </HEAD><BODY>
        <H1>Authorization Required</H1>
        This server could not verify that you
        are authorized to access the document you
        requested.  Either you supplied the wrong
        credentials (e.g., bad password), or your
        browser doesn't understand how to supply
        the credentials required.<P>
        </BODY></HTML>
    }



    # info array: TBD: rename at end of conversion.
    #
    # bufsize       - Chunk size for copies
    # initialized   - True after server started.
    # ipaddr        - Non-default ipaddr for the server (for multiple 
    #                 interfaces)
    # https_ipaddr  - The SSL ipaddr
    # listen        - The main listening socket id
    # https_listen  - The SSL listening socket id.
    # maxused       - Max number of transactions per socket (keep alive)
    # port          - The port this server is serving
    # https_port    - The SSL port
    # server        - The server ID for the HTTP protocol.
    # shutdown      - A list of Tcl callbacks made when the server shuts 
    #                 down.
    # sockblock     - Blocking mode value for sockets (normally this should
    #                 be 0)
    # timeout1      - Time before the server closes a kept-alive socket
    #                 (msecs)
    # timeout2      - Time before the server kills an in-progress 
    #                 transaction.  (msecs)
    # timeout3      - Time allowed to drain extra post data
    # version       - The server code version number.

    typevariable Httpd -array {
        bufsize      16384
        initialized  0
        ipaddr       ""
        https_ipaddr ""
        listen       ""
        https_listen ""
        maxused      25
        port         ""
        https_port   ""
        server       ""
        server       "ahttpd(n)/"
        shutdown     ""
        sockblock    0
        timeout1     120000
        timeout2     120000
        timeout3     2000
        version      ""
    }

    #-------------------------------------------------------------------
    # Public Type Methods

    # init
    #
    # Finishes initializing the module.

    typemethod init {} {
        set Httpd(version)     [ahttpd version]
        set Httpd(server)      "ahttpd(n)/[ahttpd version]"
        set Httpd(initialized) 1
    }
    
    # server ?port? ?name? ?ipaddr?
    #
    # port   - The TCP listening port number
    # name   - The qualified host name returned in the Host field.  
    #          Defaults to [info hostname]
    # ipaddr - Non-default interface address.  Otherwise IP_ADDR_ANY is 
    #          used so the server can accept connections from any 
    #          interface.
    #
    # Start the server by listening for connections on the desired port.
    # This may be re-run to re-start the server.  Call this late,
    # after [httpd init] and the init calls for the other modules.
    #
    # This sets up a callback to HttpdAccept for new connections.

    typemethod server {{port 80} {name {}} {ipaddr 127.0.0.1}} {
        if {!$Httpd(initialized)} {
            httpd init
        }

        catch {close $Httpd(listen)}

        set Httpd(name)   $name
        set Httpd(ipaddr) $ipaddr
        set Httpd(port)   $port

        if {[string length $name] == 0} {
            set Httpd(name) [info hostname]
        }

        set cmd \
            [list socket -server [myproc HttpdAccept [list http $name $port]]]

        if {[string length $ipaddr] != 0} {
            lappend cmd -myaddr $ipaddr
        }

        lappend cmd $port

        if {[catch $cmd Httpd(listen)]} {
            return -code error "$Httpd(name):$port $Httpd(listen)\ncmd=$cmd"
        }
    }

    # ServerShutdown
    #
    # Closes the server's HTTP socket. Returns "" if the socket was 
    # successfully closed, otherwise an error string.

    proc ServerShutdown {} {
        ::ahttpd::log add {} ServerShutdown
        catch {close $Httpd(listen)} err
        return $err
    }

    # secureserver ?port? ?name? ?ipaddr?
    #
    # port   - The TCP listening port number
    # name   - The qualified host name returned in the Host field.  
    #          Defaults to [info hostname]
    # ipaddr - Non-default interface address.  Otherwise IP_ADDR_ANY is 
    #          used so the server can accept connections from any 
    #          interface.
    #
    # Like [httpd server], but with additional setup for SSL.  This 
    # requires the TLS extension.
    #
    # This sets up a callback to HttpdAccept for new connections.

    typemethod secureserver {{port 443} {name {}} {ipaddr {}}} {
        if {!$Httpd(initialized)} {
            httpd init
        }

        catch {close $Httpd(https_listen)}

        set Httpd(name)         $name
        set Httpd(https_ipaddr) $ipaddr
        set Httpd(https_port)   $port

        if {[string length $name] == 0} {
            set Httpd(name) [info hostname]
        }

        set cmd [list tls::socket -server \
            [myproc HttpdAccept [list https $name $port]]]

        if {[string length $ipaddr] != 0} {
            lappend cmd -myaddr $ipaddr
        }

        lappend cmd $port

        if {[catch $cmd Httpd(https_listen)]} {
            return -code error "$Httpd(name):$port $Httpd(https_listen)\ncmd=$cmd"
        }
    }

    # SecureServerShutdown
    #
    # Close the server's secure socket. Returns "" if the socket was 
    # successfully closed, otherwise an error string.

    proc SecureServerShutdown {} {        
        ::ahttpd::log add {} SecureServerShutdown
        catch {close $Httpd(https_listen)} err
        return $err
    }

    # shutdown
    #
    # Kill the server gracefully, closing any listening sockets
    # and invoking any registered shutdown procedures.

    typemethod shutdown {} {
        set ok 1

        foreach handler $Httpd(shutdown) {
            if {[catch {eval $handler} err]} {
                ::ahttpd::log add "" "Shutdown: $handler" $err
                set ok 0
            }
        }

        ::ahttpd::log add {} Shutdown
        ServerShutdown
        SecureServerShutdown

        return $ok
    }

    # onShutdown cmd
    #
    # cmd   - The command to call on shutdown.
    #
    # Register a Tcl command to be called by [httpd shutdown].

    typemethod onShutdown {cmd} {
        if {$cmd ni $Httpd(shutdown)} {
            lappend Httpd(shutdown) $cmd
        }
    }

    # HttpdAccept self sock ipaddr port
    #
    # self    - A list of {protocol name port} that identifies the server
    # sock    - The new socket connection
    # ipaddr  - The client's IP address
    # port    - The client's port
    #
    # This is the socket accept callback invoked by Tcl when
    # clients connect to the server.
    #
    # It sets up a handler, HttpdRead, to read the request from the client.
    # The per-connection state is kept in Httpd$sock, (e.g., Httpdsock6),
    # and upvar is used to create a local "data" alias for this global 
    # array.

    proc HttpdAccept {self sock ipaddr port} {        
        upvar #0 ::ahttpd::Httpd$sock data

        stats count accepts
        stats count sockets

        set data(self) $self
        set data(ipaddr) $ipaddr
        
        if {[httpd protocol $sock] eq "https"} {
            # There is still a lengthy handshake that must occur.
            # We do that by calling tls::handshake in a fileevent
            # until it is complete, or an error occurs.

            stats count accept_https
            fconfigure $sock -blocking 0
            fileevent $sock readable [myproc HttpdHandshake $sock]
        } else {
            HttpdReset $sock $Httpd(maxused)
        }
    }

    # HttpdHandshake sock
    #
    # sock   - The socket connection
    #
    # Complete the SSL handshake. This is called from a fileevent
    # on a new https connection.  It calls tls::handshake until done.
    #
    # If the handshake fails, close the connection.
    # Otherwise, call HttpdReset to set up the normal HTTP protocol.

    proc HttpdHandshake {sock} {
        upvar #0 ::ahttpd::Httpd$sock data
        global errorCode
        
        if {[catch {tls::handshake $sock} complete]} {
            if {[lindex $errorCode 1] == "EAGAIN"} {
                # This seems to occur normally on UNIX systems
                return
            }
            ::ahttpd::log add $sock "HttpdHandshake" "\{$data(self)\} $sock \
                $data(ipaddr) $complete"
            httpd sockclose $sock 1 "$complete"
        } elseif {$complete} {
            set data(cert) [tls::status $sock]
            HttpdReset $sock $Httpd(maxused)
        }
    }

    # HttpdReset sock left
    #
    # sock   - The socket connection
    # left   - (optional) The keepalive connection count.
    #
    # Initialize or reset the socket state.
    # We allow multiple transactions per socket (keep alive).
    #
    # Resets the "data" array. Cancels any after events.
    # Closes the socket upon error or if the reuse counter goes to 0.
    # Sets up the fileevent for HttpdRead

    proc HttpdReset {sock {left {}}} {
        upvar #0 ::ahttpd::Httpd$sock data

        if {[catch {
            flush $sock
        } err]} {
            httpd sockclose $sock 1 $err
            return
        }

        stats count connections

        # Count down transactions.

        if {[string length $left]} {
            set data(left) $left
        } else {
            set left [incr data(left) -1]
        }
        if {[info exists data(cancel)]} {
            after cancel $data(cancel)
        }

        # Clear out (most of) the data array.

        set ipaddr $data(ipaddr)
        set self $data(self)

        if {[info exist data(cert)]} {
            set cert $data(cert)
        }

        unset data
        array set data [list state start version 0 \
            left $left ipaddr $ipaddr self $self]
        if {[info exist cert]} {
            set data(cert) $cert
        }

        # Set up a timer to close the socket if the next request
        # is not completed soon enough.  The request has already
        # been started, but a bad URL domain might not finish.

        set data(cancel) \
            [after $Httpd(timeout1) \
                [mytypemethod sockclose $sock 1 "timeout"]]
        fconfigure $sock -blocking 0 -buffersize $Httpd(bufsize) \
            -translation {auto crlf}
        fileevent $sock readable [myproc HttpdRead $sock]
        fileevent $sock writable {}
    }

    # peername sock
    #
    # sock   - The socket connection
    #
    # Returns The client's DNS name.

    typemethod peername {sock} {
        # This is expensive!
        fconfigure $sock -peername
    }

    # HttpdRead
    #
    # sock   - The socket connection
    #
    # Read request from a client.  This is the main state machine
    # for the protocol.  Reads the request from the socket and dispatches 
    # the URL request when ready.

    proc HttpdRead {sock} {
        upvar #0 ::ahttpd::Httpd$sock data

        # Use line mode to read the request and the mime headers
        if {[catch {gets $sock line} readCount]} {
            httpd sockclose $sock 1 "read error: $readCount"
            return
        }

        # State machine is a function of our state variable:
        # start: the connection is new
        # mime: we are reading the protocol headers
        # and how much was read. Note that
        # [string compare $readCount 0] maps -1 to -1, 0 to 0, and > 0 to 1
        set state [string compare $readCount 0],$data(state)

        switch -glob -- $state {
            1,start {
                if {[regexp {^([^ ]+) +([^?]+)\??([^ ]*) +HTTP/(1.[01])} \
                    $line x data(proto) data(url) data(query) data(version)]
                } { 
                    # data(uri) is the complete URI

                    set data(uri) $data(url)
                    if {[string length $data(query)]} {
                        append data(uri) ?$data(query)
                    }

                    # Strip leading http://server and look for the proxy case.
                    if {[regexp {^https?://([^/:]+)(:([0-9]+))?(.*)$} \
                        $data(url) x xserv y xport urlstub]
                    } {
                        set myname [httpd name $sock]
                        set myport [httpd port $sock]

                        if {([string compare \
                            [string tolower $xserv] \
                            [string tolower $myname]] != 0) ||
                            ($myport != $xport)
                        } {
                            set data(host) $xserv
                            set data(port) $xport
                        }
                        # Strip it out if it is for us (i.e., redundant)
                        # This makes it easier for doc handlers to
                        # look at the "url"
                        set data(url) $urlstub
                    }

                    set data(state) mime
                    set data(line) $line
                    stats counthist urlhits

                    # Limit the time allowed to serve this request
                    if {[info exists data(cancel)]} {
                        after cancel $data(cancel)
                    }

                    set data(cancel) [after $Httpd(timeout2) \
                        [myproc HttpdCancel $sock]]
                } else {
                    # Could check for FTP requests, here...
                    ::ahttpd::log add $sock HttpError $line
                    httpd sockclose $sock 1
                }
            }
            0,start {
                # This can happen in between requests.
            }
            1,mime  {
                # This regexp picks up
                # key: value
                # MIME headers.  MIME headers may be continue with a line
                # that starts with spaces.
                if {[regexp {^([^ :]+):[    ]*(.*)} $line dummy key value]} {
                    # The following allows something to
                    # recreate the headers exactly

                    lappend data(headerlist) $key $value

                    # The rest of this makes it easier to pick out
                    # headers from the data(mime,headername) array
                    set key [string tolower $key]
                    if [info exists data(mime,$key)] {
                        append data(mime,$key) ,$value
                    } else {
                        set data(mime,$key) $value
                        lappend data(mimeorder) $key
                    }
                    set data(key) $key

                } elseif {[regexp {^[   ]+(.*)}  $line dummy value]} {
                    # Are there really continuation lines in the spec?
                    if [info exists data(key)] {
                        append data(mime,$data(key)) " " $value
                    } else {
                        httpd error $sock 400 $line
                    }
                } else {
                    httpd error $sock 400 $line
                }
            }
            0,mime  {
                if {$data(proto) == "POST"} {
                    fconfigure $sock  -translation {binary crlf}
                    if {![info exists data(mime,content-length)]} {
                        httpd error $sock 411
                        return
                    }

                    set data(count) $data(mime,content-length)

                    if {$data(version) >= 1.1 && 
                        [info exists data(mime,expect)]
                    } {
                        if {$data(mime,expect) == "100-continue"} {
                            puts $sock "100 Continue HTTP/1.1\n"
                            flush $sock
                        } else {
                            httpd error $sock 419 $data(mime,expect)
                            return
                        }
                    }

                    # Flag the need to check for an extra newline
                    # in SSL connections by some browsers.
                    set data(checkNewline) 1

                    # Facilitate a backdoor hook between ::ahttpd::url decodequery
                    # where it will read the post data on behalf of the
                    # domain handler in the case where the domain handler
                    # doesn't use an Httpd call to read the post data itself.

                    url posthook $sock $data(count)
                } else {
                    url posthook $sock 0    ;# Clear any left-over hook
                    set data(count) 0
                }

                # Disabling this fileevent makes it possible to use
                # http::geturl in domain handlers reliably
                fileevent $sock readable {}

                # The use of HTTP_CHANNEL is a disgusting hack.
                set ::env(HTTP_CHANNEL) $sock

                # Do a different dispatch for proxies.  By default, no proxy.
                if {[info exist data(host)]} {
                    if {[catch {
                        Proxy_Dispatch $sock
                    } err]} {
                        httpd error $sock 400 "No proxy support\n$err"
                    }
                } else {
                    # Dispatch to the URL implementation.

                    # As a service for domains that loose track of their
                    # context (e.g., .tml pages) we save the socket in a 
                    # global. If a domain implementation would block and 
                    # re-enter the event loop, it must use 
                    # [httpd suspend] to clear this state,
                    # and use [httpd resume] later to restore it.

                    set Httpd(currentSocket) $sock
                    stats countstart serviceTime $sock
                    url dispatch $sock
                }
            }
            -1,* {
                if {[fblocked $sock]} {
                    # Blocked before getting a whole line
                    return
                }
                if {[eof $sock]} {
                    httpd sockclose $sock 1 ""
                    return
                }
            }
            default {
                httpd error $sock 404 \
                    "$state ?? [expr {[eof $sock] ? "EOF" : ""}]"
            }
        }
    }

    # postDataSize sock
    #
    # sock   - Client connection
    #
    # The amount of post data available.

    typemethod postDataSize {sock} {
        upvar #0 ::ahttpd::Httpd$sock data

        return $data(count)
    }

    # getPostData sock varName size
    #
    # sock    - Client connection
    # varName - Name of buffer variable to append post data to
    # size    - Amount of data to read this call. -1 to read all available.
    #
    # Returns the amount of data left to read.  When this goes to zero, 
    # you are done.

    typemethod getPostData {sock varName {size -1}} {
        upvar #0 ::ahttpd::Httpd$sock data
        upvar 1 $varName buffer

        if {$size < 0} {
            set size $Httpd(bufsize)
        }
        HttpdReadPost $sock buffer $size
        return $data(count)
    }

    # readPostDataAsync --
    #
    # Convenience layer on getPostDataAsync to
    # read the POST data into a the data(query) variable.
    #
    # Arguments:
    # (Same as HttpdReadPost)
    #
    # Side Effects:
    # (See getPostDataAsync)

    typemethod readPostDataAsync {sock cmd} {
        upvar #0 ::ahttpd::Httpd$sock data

        if {[string length $data(query)]} {
            # This merges query data from the GET/POST URL
            append data(query) &
        }

        httpd suspend $sock

        fileevent $sock readable \
            [myproc HttpdReadPostGlobal $sock Httpd${sock}(query) \
                    $Httpd(bufsize) $cmd]
        return
    }

    # getPostDataAsync --
    #
    # Read the POST data into a Tcl variable, but do it in the
    # background so the server doesn't block on the socket.
    #
    # Arguments:
    # (Same as HttpdReadPost)
    #
    # Side Effects:
    # This schedules a readable fileevent to read all the POST data
    # asynchronously.  The data is appened to the named variable.
    # The callback is made 

    typemethod getPostDataAsync {sock varName blockSize cmd} {
        httpd suspend $sock
        fileevent $sock readable \
           [myproc HttpdReadPostGlobal $sock $varName $blockSize $cmd]
        return
    }

    # HttpdReadPostGlobal --
    #
    # This fileevent callback can only access a global variable.
    # But HttpdReadPost needs to affect a local variable in its
    # caller so it can be shared with getPostData.
    # So, the fileevent case has an extra procedure frame.
    #
    # Arguments:
    # (Same as HttpdReadPost)
    #
    # Results:
    # None
    #
    # Side Effects:
    # Accumulates POST data into the named variable

    proc HttpdReadPostGlobal {sock varName blockSize {cmd {}}} {
        upvar #0 $varName buffer
        HttpdReadPost $sock buffer $blockSize $cmd
    }

    # HttpdReadPost --
    #
    # sock      - Client connection
    # varName   - Name of buffer variable to append post data to.  This
    #             must be a global or fully scoped namespace variable, or
    #             this can be the empty string, in which case the data
    #             is discarded.
    # blockSize - Default read block size.
    # cmd       - Callback to make when the post data has been read.
    #             It is called like this:
    #
    #                cmd $sock $varName $errorString
    #
    #             Where the errorString is only passed if an error 
    #             occurred.
    #
    # The core procedure that reads post data and accumulates it
    # into a Tcl variable.

    proc HttpdReadPost {sock varName blockSize {cmd {}}} {        
        upvar #0 ::ahttpd::Httpd$sock data

        # Ensure that the variable, if specified, exists by appending "" 
        # to it
        if {[string length $varName]} {
            upvar 1 $varName buffer
            append buffer ""
        }

        if {[eof $sock]} {
            if {$data(count)} {
                set doneMsg \
"Short read: got [string length $buffer] bytes, expected $data(count) more bytes"
                set data(count) 0
            } else {
                set doneMsg ""
            }
        } else {
            if {[info exist data(checkNewline)]} {
                # Gobble a single leading \n from the POST data
                # This is generated by various versions of Netscape
                # when using https/SSL.  This extra \n is not counted
                # in the content-length (thanks!)

                set nl [read $sock 1]

                if {[string compare $nl \n] != 0} {
                    # It was not an extra newline.

                    incr data(count) -1
                    if {[info exist buffer]} {
                        append buffer $nl
                    }
                }
                unset data(checkNewline)
            }

            set toRead [expr {
                $data(count) > $blockSize ? $blockSize : $data(count)
            }]
            if {[catch {read $sock $toRead} block]} {
                set doneMsg $block
                set data(count) 0
            } else {
                if {[info exist buffer]} {
                    append buffer $block
                }

                set data(count) [expr {$data(count) - [string length $block]}]
                if {$data(count) == 0} {
                    set doneMsg ""
                }
            }
        }

        if {[info exist doneMsg]} {
            url posthook $sock 0
            catch {fileevent $sock readable {}}
            $self resume $sock
            if {[string length $cmd]} {
                eval $cmd [list $sock $varName $doneMsg]
            }
            return $doneMsg
        } else {
            return ""
        }
    }

    # copyPostData sock channel cmd
    #
    # sock    - Client connection
    # channel - Channel, e.g., to a local file or to a proxy socket.
    # cmd     - Callback to make when the post data has been read.
    #           It is called like this:
    #
    #               cmd $sock $channel $bytes $errorString
    #
    #           Bytes is the number of bytes transferred by fcopy.
    #           errorString is only passed if an error occurred,
    #            otherwise it is an empty string
    #
    # Copy the POST data to a channel and make a callback when that
    # has completed.  This uses fcopy to transfer the data from the socket 
    # to the channel.

    typemethod copyPostData {sock channel cmd} {
        upvar #0 ::ahttpd::Httpd$sock data
        fcopy $sock $channel -size $data(count) \
            -command [concat $cmd $sock $channel]
        url posthook $sock 0
        return
    }

    # getPostChannel --
    #
    # sock       - Client connection
    # sizeName   - Name of variable to get the amount of post
    #              data expected to be read from the channel
    #
    # The socket, as long as there is POST data to read

    typemethod getPostChannel {sock sizeName} {
        upvar #0 ::ahttpd::Httpd$sock data
        upvar 1 $sizeName size

        if {$data(count) == 0} {
            error "no post data"
        }
        set size $data(count)
        return $sock
    }

    # The following are several routines that return replies

    # HttpdCloseP sock
    #
    # sock   - The connection handle
    #
    # Returns 1 if the connection should be closed now, 0 if keep-alive

    proc HttpdCloseP {sock} {
        upvar #0 ::ahttpd::Httpd$sock data

        if {[info exists data(mime,connection)]} {
            if {[string tolower $data(mime,connection)] == "keep-alive"} {
                stats count keepalive
                set close 0
            } else {
                stats count connclose
                set close 1
            }
        } elseif {[info exists data(mime,proxy-connection)]} {
            if {[string tolower $data(mime,proxy-connection)] eq "keep-alive"} {
                stats count keepalive
                set close 0
            } else {
                stats count connclose
                set close 1
            }
        } elseif {$data(version) >= 1.1} {
            stats count http1.1
            set close 0
        } else {
            # HTTP/1.0
            stats count http1.0
            set close 1
        }
        if {[expr {$data(left) == 0}]} {
            # Exceeded transactions per connection
            stats count noneleft
            set close 1
        }
        return $close
    }

    # onCompletion sock cmd
    #
    # sock   - The connection handle
    # cmd    - The callback to make.  These arguments are added:
    #          sock   - the connection
    #          errmsg - An empty string, or an error message.
    #
    # Register a procedure to be called when an HTTP request is
    # completed, either normally or forcibly closed.  This gives a
    # URL implementation a guaranteed callback to clean up or log
    # requests.

    typemethod onCompletion {sock cmd} {
        upvar #0 ::ahttpd::Httpd$sock data
        set data(callback) $cmd
    }

    # HttpdDoCallback sock errmsg
    #
    # sock    - The connection handle
    # errmsg  - The empty string, or an error message.
    #
    # Invokes the completion callback.

    proc HttpdDoCallback {sock {errmsg {}}} {
        upvar #0 ::ahttpd::Httpd$sock data

        if {[info exists data(callback)]} {
            catch {eval $data(callback) {$sock $errmsg}}

            # Ensure it is only called once
            unset data(callback)
        }
        stats countstop serviceTime $sock
    }

    # addHeaders sock args
    #
    # sock    - handle on the connection
    # args    - a list of header value ...
    #
    # Add http headers to be used in a reply
    # Call this before using [httpd returnFile] or
    # [httpd returnData].

    typemethod addHeaders {sock args} {
        upvar #0 ::ahttpd::Httpd$sock data

        lappend data(headers) {*}$args
    }

    # removeHeaders sock ?pattern?
    #
    # sock    - handle on the connection
    # pattern - glob pattern to match agains cookies.
    #
    # Remove previously set headers from the reply.
    # Any headers that match the glob pattern are removed.

    typemethod removeHeaders {sock {pattern *}} {
        upvar #0 ::ahttpd::Httpd$sock data

        if {[info exists data(headers)] && $data(headers) != {}} {
            set tmp {}
            foreach {header value} $data(headers) {
                if {![string match $pattern $header]} {
                    lappend tmp $header $value
                }
            }
            set data(headers) $tmp
        }
        return
    }

    # noCache sock
    #
    # sock    - handle on the connection
    #
    # Insert header into http header to indicate that this page
    # should not be cached

    typemethod noCache {sock} {
        httpd removeHeaders $sock Cache-Control
        httpd addHeaders $sock Cache-Control no-cache
        httpd addHeaders $sock Expires content '-1'
    }

    # refresh sock time ?url?
    #
    # sock    - handle on the connection
    # time    - time in seconds before refresh
    # url     - optional: url to refresh to
    #
    # Insert header into http header to cause browser to refresh
    # after a delay, optionally to a different URL

    typemethod refresh {sock time {url ""}} {
        httpd removeHeaders $sock Cache-Control

        if {$url == ""} {
            httpd addHeaders $sock Refresh $time
        } else {
            httpd addHeaders $sock Refresh ${time}\;url=${url}
        }
    }

    # HttpdRespondHeader sock mtype close size ?code?
    #
    # sock    - The connection handle
    # mtype   - The mime type of this response
    # close   - If true, signal connection close headers.  See HttpdCloseP
    # size    - The size "in bytes" of the response
    # code    - The return code - defualts to 200
    #
    # Utility routine for outputting response headers for normal data Does
    # not output the end of header markers so additional header lines can be
    # added.

    proc HttpdRespondHeader {sock mtype close size {code 200}} {
        upvar #0 ::ahttpd::Httpd$sock data

        set data(code) $code
        append reply "HTTP/$data(version) $code [HttpdErrorString $code]" \n
        append reply "Date: [HttpdDate [clock seconds]]" \n
        append reply "Server: $Httpd(server)\n"

        if {$close} {
            append reply "Connection: Close" \n
        } elseif {$data(version) == 1.0 && !$close} {
            append reply "Connection: Keep-Alive" \n
        }
        
        append reply "Content-Type: $mtype" \n
        
        if {[string length $size]} {
            append reply "Content-Length: $size" \n
        }

        if {[info exists data(headers)]} {
            foreach {header value} $data(headers) {
                catch {
                    append reply "[string trimright $header :]: " $value \n
                }
            }
        }

        puts -nonewline $sock $reply
    }

    # HttpdErrorString code
    #
    # code  - An HTTP error code, e.g., 200 or 404
    #
    # Map from an error code to a meaningful string.

    proc HttpdErrorString {code} {
        if {[info exist errorNames($code)]} {
            return $errorNames($code)
        } else {
            return "Error $code"
        }
    }

    # removeCookies sock pattern
    #
    # sock     - handle on the connection
    # pattern  - glob pattern to match agains cookies.
    #
    # Remove previously set cookies from the reply.
    # Any cookies that match the glob pattern are removed.
    # This is useful for expiring a cookie that was previously set.

    typemethod removeCookies {sock pattern} {
        upvar #0 ::ahttpd::Httpd$sock data

        if {[info exists data(set-cookie)] && $data(set-cookie) != {}} {
            set tmp {}
            foreach c $data(set-cookie) {
                if {![string match $pattern $c]} {
                    lappend tmp $c
                }
            }
            set data(set-cookie) $tmp
        }
        return
    }

    # setCookie sock cookie ?modify?
    #
    # sock    - handle on the connection
    # cookie  - Set-Cookie line
    # modify  - (optional) If true, overwrite any preexisting
    #           cookie that matches.  This way you can change
    #           the expiration time.
    #
    # Define a cookie to be used in a reply
    # Call this before using [httpd returnFile] or
    # [httpd returnData].

    typemethod setCookie {sock cookie {modify 0}} {
        upvar #0 ::ahttpd::Httpd$sock data
        lappend data(set-cookie) $cookie
    }

    # HttpdSetCookie sock
    #
    # sock    - handle on the connection
    #
    # Generate the Set-Cookie headers in a reply
    # Use setCookie to register cookies earlier

    proc HttpdSetCookie {sock} {
        upvar #0 ::ahttpd::Httpd$sock data

        if {[info exist data(set-cookie)]} {
            foreach item $data(set-cookie) {
                puts $sock "Set-Cookie: $item"
            }
            unset data(set-cookie)
        }
    }

    # returnFile sock ctype path ?offset?
    #
    # sock    - handle on the connection
    # ctype   - is a Content-Type
    # path    - is the file pathname
    # offset  - amount to skip at the start of file
    #
    # Return a file's contents back as the reply.

    typemethod returnFile {sock ctype path {offset 0}} {
        upvar #0 ::ahttpd::Httpd$sock data

        # Set file size early so it gets into all log records

        set data(file_size) [file size $path]
        set data(code) 200

        stats count urlreply

        if {[info exists data(mime,if-modified-since)]} {
            # No need for complicated date comparison, if they're 
            # identical then 304.
            if {$data(mime,if-modified-since) == [HttpdDate [file mtime $path]]} {
                httpd notModified $sock
                return
            }
        }

        # Some files have a duality, when the client sees X bytes but the
        # file is really X + n bytes (the first n bytes reserved for server
        # side accounting information.

        incr data(file_size) -$offset

        if {[catch {
            set close [HttpdCloseP $sock]
            HttpdRespondHeader $sock $ctype $close $data(file_size) 200
            HttpdSetCookie $sock
            puts $sock "Last-Modified: [HttpdDate [file mtime $path]]"
            puts $sock ""
            if {$data(proto) != "HEAD"} {
                set in [open $path]     ;# checking should already be done
                fconfigure $in -translation binary -blocking 1
                if {$offset != 0} {
                    seek $in $offset
                }
                fconfigure $sock -translation binary -blocking $Httpd(sockblock)
                set data(infile) $in
                httpd suspend $sock 0
                fcopy $in $sock -command [myproc HttpdCopyDone $in $sock $close]
            } else {
                httpd sockclose $sock $close
            }
        } err]} {
            HttpdCloseFinal $sock $err
        }
    }

    # returnData sock ctype content ?code? ?close?
    #
    # sock     - handle on the connection
    # ctype    - a Content-Type
    # content  - the data to return
    # code     - the HTTP reply code.
    # close    - Close flag.
    #
    # Return data for a page.

    typemethod returnData {sock ctype content {code 200} {close 0}} {
        upvar #0 ::ahttpd::Httpd$sock data

        stats count urlreply

        if {$close == 0} {
            set close [HttpdCloseP $sock]
        }

        if {[catch {
            HttpdRespondHeader $sock $ctype $close [string length $content] $code
            HttpdSetCookie $sock
            puts $sock ""
            if {$data(proto) != "HEAD"} {
                fconfigure $sock -translation binary -blocking $Httpd(sockblock)
                puts -nonewline $sock $content
            }
            httpd sockclose $sock $close
        } err]} {
            HttpdCloseFinal $sock $err
        }
    }

    # returnCacheableData sock ctype content date ?code?
    #
    # sock     - Client connection
    # ctype     - a Content-Type
    # content  - the data to return
    # date     - Modify date of the date
    # code     - the HTTP reply code.
    #
    # Return data with a Last-Modified time so
    # that proxy servers can cache it.  Or they seem to, anyway.

    typemethod returnCacheableData {sock ctype content date {code 200}} {
        upvar #0 ::ahttpd::Httpd$sock data

        stats count urlreply
        set close [HttpdCloseP $sock]

        if {[catch {
            HttpdRespondHeader $sock $ctype $close [string length $content] $code
            HttpdSetCookie $sock
            puts $sock "Last-Modified: [HttpdDate $date]"
            puts $sock ""
            if {$data(proto) != "HEAD"} {
                fconfigure $sock -translation binary -blocking $Httpd(sockblock)
                puts -nonewline $sock $content
            }
            httpd sockclose $sock $close
        } err]} {
            HttpdCloseFinal $sock $err
        }
    }

    # HttpdCopyDone in sock close bytes error 
    #
    # in      - Input channel, typically a file
    # sock    - Socket connection
    # close   - If true, the socket is closed after the copy.
    # bytes   - How many bytes were copied
    # error   - Optional error string.
    #
    # This is used with fcopy when the copy completes.
    #
    # Side Effects: See httpd sockclose

    proc HttpdCopyDone {in sock close bytes {error {}}} {
        if {$error eq ""} {
            # This special value signals a normal close,
            # and triggers a log record so static files are counted
            set error Close
        }
        httpd sockclose $sock $close $error
    }

    # HttpdCancel sock
    #
    # sock    - Socket connection
    #
    # Cancel a transaction if the client doesn't complete the request 
    # fast enough. Terminates the connection by returning an error page.

    proc HttpdCancel {sock} {
        upvar #0 ::ahttpd::Httpd$sock data
        stats count cancel
        httpd error $sock 408
    }

    # error sock code ?detail? 
    #
    # sock    - Socket connection
    # code    - HTTP error code, e.g., 500
    # detail  - Optional string to append to standard error message.
    #
    # send the error message, log it, and close the socket.
    # Note that the Doc module tries to present a more palatable
    # error display page, but falls back to this if necessary.
    #
    # Generates a HTTP response.

    typemethod error {sock code {detail ""}} {
        upvar #0 ::ahttpd::Httpd$sock data

        stats count errors
        append data(url) ""

        set message [format $errorFormat $code [HttpdErrorString $code] $data(url)]
        append message <br><pre>$detail</pre>

        if {$code == 500} {
            append message "<h2>Tcl Call Trace</h2>"
            for {set l [expr [info level]-1]} {$l > 0} {incr l -1} {
                append message "<pre>$l: [protect_text [info level $l]]</pre><br>"
            }
        }
        ::ahttpd::log add $sock Error $code $data(url) $detail

        # We know something is bad here, so we make the completion callback
        # and then unregister it so we don't get an extra call as a side
        # effect of trying to reply.

        HttpdDoCallback $sock $message

        if {[info exists data(infile)]} {
            # We've already started a reply, so just bail out
            httpd sockclose $sock 1
            return
        }

        if [catch {
            HttpdRespondHeader $sock text/html 1 [expr {[string length $message] + 4}] $code
            puts $sock ""
            puts $sock $message
        } err] {
            ::ahttpd::log add $sock LostSocket $data(url) $err
        }
        httpd sockclose $sock 1
    }


    # redirect newurl sock
    #
    # newurl  - New URL to redirect to.
    # sock    - Socket connection
    #
    # Generate a redirect reply (code 302).

    typemethod redirect {newurl sock} {
        upvar #0 ::ahttpd::Httpd$sock data

        set message [format $redirectFormat $newurl]
        set close [HttpdCloseP $sock]
        HttpdRespondHeader $sock text/html $close [string length $message] 302
        HttpdSetCookie $sock

        puts $sock "Location: $newurl"
        puts $sock "URI: $newurl"
        puts $sock ""

        # The -nonewline is important here to work properly with
        # keep-alive connections

        puts -nonewline $sock $message
        httpd sockclose $sock $close
    }

    # notModified sock
    #
    # sock    - Socket connection
    #
    # Generate a Not Modified reply (code 304)

    typemethod notModified {sock} {
        upvar #0 ::ahttpd::Httpd$sock data

        set message [HttpdErrorString 304]
        set close 1
        HttpdRespondHeader $sock text/html $close [string length $message] 304
        puts $sock ""

        # The -nonewline is important here to work properly with
        # keep-alive connections

        puts -nonewline $sock $message
        httpd sockclose $sock $close
    }

    # redirectSelf newurl sock
    #
    # newurl  - Server-relative URL to redirect to.
    # sock    - Socket connection
    #
    # Generate a redirect to another URL on this server.

    typemethod redirectSelf {newurl sock} {
        httpd redirect [httpd selfUrl $newurl $sock] $sock
    }

    # selfUrl url ?sock?
    #
    # url    - A server-relative URL on this server.
    # sock   - The current connection so we can tell if it
    #          is the regular port or the secure port.
    #
    # Return an absolute URL for this server

    typemethod selfUrl {url {sock ""}} {
        if {$sock == ""} {
            set sock $Httpd(currentSocket)
        }
        upvar #0 ::ahttpd::Httpd$sock data

        set ptype [httpd protocol $sock]
        set port  [httpd port $sock]

        if {[info exists data(mime,host)]} {
            # Use in preference to our "true" name because
            # the client might not have a DNS entry for use.
            set name $data(mime,host)
        } else {
            set name [httpd name $sock]
        }

        set newurl $ptype://$name

        if {[string first : $name] == -1} {
            # Add in the port number, which may or may not be present in
            # the name already.  IE5 sticks the port into the Host: header,
            # while Tcl's own http package does not...

            if {$ptype == "http" && $port != 80} {
                append newurl :$port
            }

            if {$ptype == "https" && $port != 443} {
                append newurl :$port
            }
        }

        append newurl $url
    }

    # protocol sock
    #
    # sock    - Socket connection
    #
    # Return the protocol for the connection, either "http" or "https".

    typemethod protocol {sock} {
        upvar #0 ::ahttpd::Httpd$sock data
        return [lindex $data(self) 0]
    }

    # name sock
    #
    # sock    - Socket connection
    #
    # Return the server name for the connection

    typemethod name {sock} {
        upvar #0 ::ahttpd::Httpd$sock data
        return [lindex $data(self) 1]
    }

    # port ?sock?
    #
    # sock   - The current connection. If empty, then the
    #          regular (non-secure) port is returned.  Otherwise
    #          the port of this connection is returned.
    #
    # Return the port for the connection

    typemethod port {{sock {}}} {
        if {[string length $sock]} {
            # Return the port for this connection
            upvar #0 ::ahttpd::Httpd$sock data
            return [lindex $data(self) 2]
        } else {
            # Return the non-secure listening port    
            if {[info exist Httpd(port)]} {
                return $Httpd(port)
            } else {
                return {}
            }
        }
    }

    # secureport
    #
    # Return the secure port of this server

    typemethod secureport {} {
        if {[info exist Httpd(https_port)]} {
            return $Httpd(https_port)
        } else {
            return {}
        }
    }


    # redirectDir --
    #
    # sock    - Socket connection
    #
    # Generate a redirect because the trailing slash isn't present
    # on a URL that corresponds to a directory.

    typemethod redirectDir {sock} {        
        upvar #0 ::ahttpd::Httpd$sock data
        set url $data(url)/

        if {[info exist data(query)] && [string length $data(query)]} {
            append url ?$data(query)
        }
        httpd redirect $url $sock
    }


    # requestAuth sock atype realm args
    #
    # sock    - Socket connection
    # atype   - usually "Basic"
    # realm   - browsers use this to cache credentials
    # args    - additional name value pairs for request
    #
    # Generate the (401) Authorization required reply.
    # Generate an authorization challenge response.

    typemethod requestAuth {sock atype realm args} {
        upvar #0 ::ahttpd::Httpd$sock data

        set additional ""
        foreach {name value} $args {
            append additional ", " ${name}=$value
        }

        set close [HttpdCloseP $sock]
        HttpdRespondHeader $sock text/html $close [string length $authorizationFormat] 401
        puts $sock "Www-Authenticate: $atype realm=\"$realm\" $additional"
        puts $sock ""
        puts -nonewline $sock $authorizationFormat
        httpd sockclose $sock $close
    }

    # HttpdDate seconds
    #
    # seconds   - Clock seconds value
    #
    # generate a date string in HTTP format

    proc HttpdDate {seconds} {
        return [clock format $seconds -format {%a, %d %b %Y %T GMT} -gmt true]
    }

    # sockclose sock closeit ?message?
    #
    # sock     - Identifies the client connection
    # closeit  - 1 if the socket should close no matter what
    # message  - Logging message.  If this is "Close", which is the 
    #            default, then an entry is made to the standard log.  
    #            Otherwise an entry is made to the debug log.
    #
    # "Close" a connection, although the socket might actually
    # remain open for a keep-alive connection.
    # This means the HTTP transaction is fully complete.
    #
    # Cleans up all state associated with the connection, including
    # after events for timeouts, the data array, and fileevents.

    typemethod sockclose {sock closeit {message Close}} {
        upvar #0 ::ahttpd::Httpd$sock data

        if {[string length $message]} {
            ::ahttpd::log add $sock $message
            if {$message == "Close"} {
                # This is a normal close.  Any other message
                # is some sort of error.
                set message ""
            }
        }

        # Call back to the URL domain implementation so they are
        # sure to see the end of all their HTTP transactions.
        # There is a slight chance of an error reading any un-read
        # Post data, but if the URL domain didn't want to read it,
        # then they obviously don't care.

        HttpdDoCallback $sock $message

        stats count connections -1
        if {[info exist data(infile)]} {
            # Close file or CGI pipe.  Still need catch because of CGI pipe.
            catch {close $data(infile)}
        }
        if {$closeit} {
            if {[info exists data(count)] && $data(count) > 0} {
                # There is unread POST data.  To ensure that the client
                # can read our reply properly, we must read this data.
                # The empty variable name causes us to discard the POST data.

                if {[info exists data(cancel)]} {
                    after cancel $data(cancel)
                }
                set data(cancel) [after $Httpd(timeout3) \
                    [myproc HttpdCloseFinal $sock "timeout reading extra POST data"]]

                httpd getPostDataAsync $sock "" $data(count) \
                    [myproc HttpdReadPostDone]
            } else {
                HttpdCloseFinal $sock
            }
        } else {
            HttpdReset $sock
        }
    }

    # HttpdReadPostDone sock varname errmsg
    #
    # sock     - Socket connection
    # varname  - Name of variable with post data
    # errmsg   - If not empty, an error occurred on the socket.
    #
    # Callback is made to this when we are done cleaning up any
    # unread post data.

    proc HttpdReadPostDone {sock var errmsg} {
        HttpdCloseFinal $sock $errmsg
    }

    # HttpdCloseFinal sock ?errmsg?
    #
    # sock    - Socket connection
    # errmsg  - If non-empty, then something went wrong on the socket.
    #
    # Central close procedure.  All close operations should funnel
    # through here so that the right cleanup occurs.
    #
    # Side Effects:
    # Cleans up any after event associated with the connection.
    # Closes the socket.
    # Makes the callback to the URL domain implementation.

    proc HttpdCloseFinal {sock {errmsg {}}} {
        upvar #0 ::ahttpd::Httpd$sock data
        stats count sockets -1

        if {[info exists data(cancel)]} {
            after cancel $data(cancel)
        }

        if {[catch {close $sock} err]} {
            ::ahttpd::log add $sock CloseError $err
            if {[string length $errmsg] == 0} {
                set errmsg $err
            }
        }

        HttpdDoCallback $sock $errmsg

        if {[info exist data]} {
            unset data
        }
    }

    # requestComplete sock
    #
    # sock    - Socket connection
    #
    # Detect if a request has been sent.  The holder of a socket
    # might need to know of the URL request was completed with
    # one of the return-data commands, or is still lingering open.
    #
    # Returns 1 if the request was completed, 0 otherwise.

    typemethod requestComplete {sock} {
        upvar #0 ::ahttpd::Httpd$sock data

        if {![info exist data(state)] || $data(state) == "start"} {
            # The connection was closed or reset in a keep-alive situation.
            return 1
        } else {
            return 0
        }
    }

    # suspend sock ?timeout?
    #
    # sock    - Socket connection
    # timeout - Timeout period.  After this the request is aborted.
    #
    # Suspend Wire Callback - for async transactions
    # Use resume once you are back in business
    # Note: global page array is not preserved over suspend
    #
    # Disables fileevents and sets up a timer.

    typemethod suspend {sock {timeout ""}} {
        upvar #0 ::ahttpd::Httpd$sock data

        fileevent $sock readable {}
        fileevent $sock writable {}

        if {[info exists data(cancel)]} {
            after cancel $data(cancel)
            unset data(cancel)
        }

        if {[info exists Httpd(currentSocket)]} {
            unset Httpd(currentSocket)
        }

        if {$timeout == ""} {
            set timeout $Httpd(timeout2)
        }

        if {$timeout != 0} {
            set data(cancel) [after $timeout [myproc HttpdCancel $sock]]
        }
    }

    # resume sock ?timeout?
    #
    # sock    - Socket connection
    # timeout - Timeout period.  After this the request is aborted.
    #
    # Resume processing of a request.  Sets up a bit of global state that
    # has been cleared by suspend.
    #
    # Restores the Httpd(currentSocket) setting.

    typemethod resume {sock {timeout ""}} {
        upvar #0 ::ahttpd::Httpd$sock data
        
        set Httpd(currentSocket) $sock

        if {[info exists data(cancel)]} {
            after cancel $data(cancel)
        }

        if {$timeout == ""} {
            set timeout $Httpd(timeout1)
        }
        set data(cancel) [after $timeout \
            [mytypemethod sockclose $sock 1 "timeout"]]
    }

    # currentSocket ?sock?
    #
    # sock    - if specified, set the current socket.
    #
    # Return (or set) the handle to the current socket.

    typemethod currentSocket {{sock {}}} {
        if {[string length $sock]} {
            set Httpd(currentSocket) $sock
        }
        return $Httpd(currentSocket)
    }

    # pair sock fd
    #
    # sock  - Socket connection
    # fd    - Any other I/O connection
    #
    # Pair two fd's - typically for tunnelling
    # Close both if either one closes (or gets an error)
    # Sets up fileevents for proxy'ing data.

    typemethod pair {sock fd} {
        upvar #0 ::ahttpd::Httpd$sock data

        syslog debug "HTTP: Pairing $sock and $fd"

        httpd suspend $sock 0

        fconfigure $sock -translation binary -blocking 0
        fconfigure $fd -translation binary -blocking 0

        fileevent $sock readable [myproc HttpdReflect $sock $fd]
        fileevent $fd readable [myproc HttpdReflect $fd $sock]
    }

    # HttpdReflect in out
    #
    # in    - Input channel
    # out   - Output channel
    #
    # This is logically fcopy in both directions, but the core
    # prevents us from doing that so we do it by hand.
    # Copy data between channels.

    proc HttpdReflect {in out} {
        if {[catch {
            set buf [read $in $Httpd(bufsize)]
            puts -nonewline $out $buf
            flush $out
            set buflen [string length $buf]
            if {$buflen > 0} {
                syslog debug "Tunnel: $in -> $out ($buflen bytes)" 
            }
        } oops]} {
            ::ahttpd::log add $in Tunnel "Error: $oops"
        } elseif {![eof $in]} {
            return 1
        } else {
            syslog debug "Tunnel: $in EOF"
        }

        fileevent $in readable {}
        fileevent $out readable {}
        catch {flush $in}
        catch {flush $out}
        catch {close $in}
        catch {close $out}
        return 0
    }

    # dumpHeaders sock
    #
    # sock   - Client connection
    #
    # Dump out the protocol headers so they can be saved for later.
    #
    # A list structure that alternates between names and values.
    # The names are header names without the trailing colon and
    # mapped to lower case (e.g., content-type).  Two pseudo-headers
    # added: One that contains the original request URL; its name is "url"
    # Another that contains the request protocol; its name is "method"
    # There are no duplications in the header keys.  If any headers
    # were repeated, their values were combined by separating them
    # with commas.

    typemethod dumpHeaders {sock} {
        upvar #0 ::ahttpd::Httpd$sock data

        set result [list url $data(uri) method $data(proto) version $data(version)]
        if {[info exist data(mimeorder)]} {
            foreach key $data(mimeorder) {
                lappend result $key $data(mime,$key)
            }
        }
        return $result
    }

    # webmaster ?email?
    #
    # email  - The email of the webmaster.  If empty, the
    #          current value is returned, which is handy in
    #          web pages.
    #
    # Sets and queries an email address for the webmaster.
    # TBD: This should probably go somewhere else.

    typemethod webmaster {{email {}}} {
        if {[string length $email] == 0} {
            if {![info exists Httpd(webmaster)]} {
                set Httpd(webmaster) webmaster
            }
            return $Httpd(webmaster)
        } else {
            set Httpd(webmaster) $email
        }
    }

}


