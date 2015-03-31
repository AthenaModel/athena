#-----------------------------------------------------------------------
# TITLE:
#   server.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#   ahttpd(n) Package: Application Web Server
#
# TBD:
#
#   * Determine required server options, and implement, initializing
#     the ahttpd modules as required.
#   * Replace the ahttpd::log with a -logcmd that can work with logger(n).
#   * Simplify remaining CGI-related code; get rid of env() fixups if
#     possible.
#     * Use same variables, but pass array explicitly, or access via
#       "sock".
#   * Scan mime.types, and remove tcl-* handlers that we don't use.
#   * Consider removing templates.  If not, simplify.
#       * Always use safe interp.
#       * Provide clean API for use by templates.
#
#-----------------------------------------------------------------------

snit::type ::ahttpd::server {
    # Make it an ensemble
    pragma -hasinstances 0 -hastypedestroy 0

    #------------------------------------------------------------------
    # Typevariables
    
    # info
    #
    # The info array carries around configuration data used to set up
    # the webserver. This array contains the following data:
    #
    # debug     - 1 to enable ahttpd debugging, and 0 otherwise.
    # docroot   - The location of the root of the html document tree
    # host      - hostname of the server. Defaulted to the current host
    # port      - The port the server is running on. Default 8080
    # ipaddr    - IP address of the server. Defaulted to ""
    # webmaster - email address of contact person should server have
    #             problems

    typevariable info -array {
        debug        0
        docroot      {}
        errorpage    "/error.html"
        host         {}
        ipaddr       127.0.0.1
        notfoundpage "/notfound.html"
        port         8080
        secureport   8081
        webmaster    "David.R.Hanks@jpl.nasa.gov"
    }

    #------------------------------------------------------------------
    # Public Type methods

    
    # init
    #
    # Initializes and starts the webserver

    typemethod init {args} {
        # FIRST, default the host name 
        set info(host) [info host]

        # NEXT, parse the options.
        # TBD: Add error checking
        foroption opt args -all {
            -debug {
                set info(debug) 1
            }
            -docroot {
                set info(docroot) [file normalize [lshift args]]
            }
            -errorpage    -
            -host         -
            -ipaddr       -
            -notfoundpage -
            -port         -
            -secureport   -
            -webmaster    {
                set info($opt) [lshift args]
            }
        }

        # NEXT, initialize the package.
        httpd init                              ;# Server data structures      
        stats init                              ;# Statistics gathering
        auth init                               ;# Authentication
        doc root $info(docroot)                 ;# Document tree
        doc errorpage $info(errorpage)          ;# Error template
        doc notfoundpage $info(notfoundpage)    ;# Page not found template
        httpd webmaster $info(webmaster)        ;# Webmaster e-mail

        if {$info(debug)} {
            status init                         ;# Status Pages
            debug init /debug                   ;# Debugging tools
            redirect init /redirect             ;# Redirect management
        } else {
            # Do not provide UI unless debugging.
            redirect init                       ;# Redirect management
        }


        # TBD: Need -logroot parameter
        # TBD: Need application log.  ahttpd::log should be combined
        # with it.
        ::ahttpd::log setfile ~/github/athena/log/httpd$info(port)

        # NEXT, start the server.
        if {$info(port) ne ""} {
            httpd server $info(port) $info(host) $info(ipaddr)
        }

        if {$info(secureport) ne ""} {
            tls::init -tls1 1 -ssl2 0 -ssl3 0 -tls1.1 0 -tls1.2 0
            httpd secureserver $info(secureport) $info(host) $info(ipaddr)           
        }
    }
        
    # version
    #
    # Returns the package version.

    typemethod version {} {
        return [package present ahttpd]
    }

    #-------------------------------------------------------------------
    # Delegated Methods

    delegate typemethod port       using {::ahttpd::httpd %m}
    delegate typemethod secureport using {::ahttpd::httpd %m}
    

}
