#-----------------------------------------------------------------------
# TITLE:
#    cgi.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    ahttpd(n): CGI Environment Support
#
#    ahttpd(n) does not support "cgi-bin" directories or external
#    CGI scripts.  However, several of the modules in ahttpd(n) (e.g.,
#    direct.tcl) make use of a CGI-like environment.  We have retained
#    only the required code from the TclHTTPD CGI module.
#
#    Stephen Uhler / Brent Welch (c) 1997 Sun Microsystems
#    Brent Welch (c) 1998-2000 Ajuba Solutions
#    Will Duquette (c) 2015 California Institute of Technology
#
#    See the file "license.terms" for information on usage and 
#    redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
#-----------------------------------------------------------------------

snit::type ::ahttpd::cgi {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # envmap
    #
    # Environment variables that are extracted from the mime header
    # SetEnvAll.  The values are keys into the per-connection state 
    # array (i.e. "data")

    typevariable envmap -array {
        CONTENT_LENGTH          mime,content-length
        CONTENT_TYPE            mime,content-type
        HTTP_ACCEPT             mime,accept
        HTTP_AUTHORIZATION      mime,authorization
        HTTP_FROM               mime,from
        HTTP_REFERER            mime,referer
        HTTP_USER_AGENT         mime,user-agent
        QUERY_STRING            query
        REQUEST_METHOD          proto
        HTTP_COOKIE             mime,cookie
        HTTP_FORWARDED          mime,forwarded
        HTTP_HOST               mime,host
        HTTP_PROXY_CONNECTION   mime,proxy-connection
        REMOTE_USER             remote_user
        AUTH_TYPE               auth_type
    }


    # info array:
    #
    # env-pass   - List of environment variables to preserve when setting
    #              up the environment.  The rest are deleted and then 
    #              recreated from information in the CGI request.

    typevariable info -array {
        env-pass {TZ}
    }

    #-------------------------------------------------------------------
    # Public Type Methods

    # setenv sock path ?var?
    #
    # sock    - The client socket
    # path    - ???? (Server-specific URL?)
    # var     - Name of the environment array; defaults to ::ahttpd::cgienv
    #
    # Set up a CGI-like environment array in the caller's environment.

    typemethod setenv {sock path {var ::ahttpd::cgienv}} {
        upvar 1 $var cgienv
        upvar #0 ::ahttpd::Httpd$sock data
        SetEnvAll $sock $path {} $data(url) cgienv
    }
    
    # setenvfor sock path interp
    #
    # sock    - The client socket
    # path    - ???? (Server-specific URL?)
    # interp  - Name of a slave interpreter
    #
    # Set up a CGI-like environment array in the interpreter.

    typemethod setenvfor {sock path interp} {
        upvar #0 ::ahttpd::Httpd$sock data
        SetEnvAll $sock $path {} $data(url) cgienv
        interp eval $interp \
            [list uplevel #0 [list array set ::ahttpd::cgienv [array get cgienv]]]
    }

    #-------------------------------------------------------------------
    # Helper Procs
    
    # SetEnvAll sock path extra url var
    #
    # sock    - The client socket
    # path    - ???? (Server-specific URL?)
    # url     - The requested URL from the header
    # var     - The name of the environment variable
    #
    # Sets up an environment array with the necessary data.

    proc SetEnvAll {sock path extra url var} {
        upvar #0 ::ahttpd::Httpd$sock data
        upvar #0 ::ahttpd::httpd::Httpd Httpd
        upvar 1 $var env

        # Clear the environment
        array set env [array get ::env]
        foreach i [array names env] {
            if {$i ni $info(env-pass)} {
                unset env($i)
            } 
        }

        foreach name [array names envmap] {
            set env($name) ""
            catch {
                set env($name) $data($envmap($name))
            }
        }

        set env(REQUEST_URI) [httpd selfUrl $data(uri) $sock]
        set env(GATEWAY_INTERFACE) "CGI/1.1"
        set env(SERVER_PORT) [httpd port $sock]
        if {[info exist Httpd(https_port)]} {
            set env(SERVER_HTTPS_PORT) $Httpd(https_port)
        }
        set env(SERVER_NAME) $Httpd(name)
        set env(SERVER_SOFTWARE) $Httpd(server)
        set env(SERVER_PROTOCOL) HTTP/1.0
        set env(REMOTE_ADDR) $data(ipaddr)
        set env(SCRIPT_NAME) $url
        set env(PATH_INFO) $extra
        set env(PATH_TRANSLATED) [string trimright [doc root] /]/[string trimleft $data(url) /]
        set env(DOCUMENT_ROOT) [doc root]
        set env(HOME) [doc root]

        if {$data(proto) == "POST"} {
            set env(QUERY_STRING) ""
        }
    }
}

