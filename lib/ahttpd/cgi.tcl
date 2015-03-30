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

    # info array:
    #
    # env-pass   - List of environment variables to preserve when setting
    #              up the environment.  The rest are deleted and then 
    #              recreated from information in the CGI request.

    typevariable info -array {
        env-pass {PATH LD_LIBRARY_PATH TZ}
    }

    #-------------------------------------------------------------------
    # Public Type Methods

    # setenv sock path ?var?
    #
    # sock    - The client socket
    # path    - ???? (Server-specific URL?)
    # var     - Name of the environment array
    #
    # Set up a CGI-like environment array in the caller's environment.

    typemethod setenv {sock path {var env}} {
        upvar 1 $var env
        upvar #0 Httpd$sock data
        SetEnvAll $sock $path {} $data(url) env
    }
    
    # setenvfor sock path interp
    #
    # sock    - The client socket
    # path    - ???? (Server-specific URL?)
    # interp  - Name of a slave interpreter
    #
    # Set up a CGI-like environment array in the interpreter.

    typemethod setenvfor {sock path interp} {
        upvar #0 Httpd$sock data
        SetEnvAll $sock $path {} $data(url) env
        interp eval $interp \
            [list uplevel #0 [list array set env [array get env]]]
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
        upvar #0 Httpd$sock data
        upvar 1 $var env
        global Httpd Httpd_EnvMap

        # Clear the environment
        foreach i [array names env] {
            if {$i ni $info(env-pass)} {
                unset env($i)
            } 
        }

        foreach name [array names Httpd_EnvMap] {
            set env($name) ""
            catch {
                set env($name) $data($Httpd_EnvMap($name))
            }
        }

        set env(REQUEST_URI) [Httpd_SelfUrl $data(uri) $sock]
        set env(GATEWAY_INTERFACE) "CGI/1.1"
        set env(SERVER_PORT) [Httpd_Port $sock]
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

