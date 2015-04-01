#-----------------------------------------------------------------------
# TITLE:
#   ahttpd.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#   ahttpd(n) Package: Application Web Server
#
# TBD:
#
#   * Replace the ahttpd::log with a -logcmd that can work with logger(n).
#   * Delegate from server to url, direct, etc., for adding content 
#     URLs and domains.
#   * Define an appserver-like domain handler
#     for defining URLs with place-holders.
#   * Add a "help" domain, displaying the Athena help.\
#   * Clean up the mime.types file and add the new mime-types we need.
#
#-----------------------------------------------------------------------

namespace eval ::ahttpd:: {
    namespace export ahttpd
}

snit::type ::ahttpd::ahttpd {
    # Make it an ensemble
    pragma -hasinstances 0 -hastypedestroy 0

    #------------------------------------------------------------------
    # Typevariables
    
    # info
    #
    # The info array carries around configuration data used to set up
    # the webserver. This array contains the following data:
    #
    # -allowtml   - 1 to allow .tml templates, and 0 otherwise.
    # -allowsubst - 1 to allow .subst templates, and 0 otherwise.
    # -debug      - 1 to enable ahttpd debugging, and 0 otherwise.
    # -docroot    - The location of the root of the html document tree
    # -host       - hostname of the server. Defaulted to the current host
    # -port       - The port the server is running on, or ""
    # -secureport - The port the https server is running on, or ""
    # -ipaddr     - IP address of the server.
    # -webmaster  - email address of contact person should server have
    #               problems

    typevariable info -array {
        -allowtml     0
        -allowsubst   0
        -debug        0
        -docroot      {}
        -errorpage    "/error.html"
        -host         {}
        -ipaddr       127.0.0.1
        -logcmd       ""
        -notfoundpage "/notfound.html"
        -port         8080
        -secureport   8081
        -webmaster    "Brian.J.Kahovec@jpl.nasa.gov"
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
            -allowtml   -
            -allowsubst -
            -debug      {
                set info($opt) 1
            }
            -docroot {
                set info($opt) [file normalize [lshift args]]
            }
            -errorpage    -
            -host         -
            -ipaddr       -
            -logcmd       -
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
        doc root $info(-docroot)                ;# Document tree
        doc errorpage $info(-errorpage)         ;# Error template
        doc notfoundpage $info(-notfoundpage)   ;# Page not found template

        if {$info(-allowtml)} {
            template init
        }

        if {$info(-allowsubst)} {
            docsubst init
        }

        httpd webmaster $info(-webmaster)       ;# Webmaster e-mail

        if {$info(-debug)} {
            status init                         ;# Status Pages
            debug init /debug                   ;# Debugging tools
            redirect init /redirect             ;# Redirect management
        } else {
            # Do not provide UI unless debugging.
            redirect init                       ;# Redirect management
        }

        # NEXT, start the server.
        if {$info(-port) ne ""} {
            $type log normal ahttpd "Starting http server on $info(-port)"
            httpd server $info(-port) $info(-host) $info(-ipaddr)
        }

        if {$info(-secureport) ne ""} {
            $type log normal ahttpd "Starting https server on $info(-secureport)"
            tls::init -tls1 1 -ssl2 0 -ssl3 0 -tls1.1 0 -tls1.2 0
            httpd secureserver $info(-secureport) $info(-host) $info(-ipaddr)           
        }
    }

    # log level comp message
    #
    # Writes to the log.

    typemethod log {level comp message} {
        callwith $info(-logcmd) $level $comp $message
    }
        
    # version
    #
    # Returns the package version.

    typemethod version {} {
        return [package present ahttpd]
    }

    # domain install domain handler
    #
    # domain   - The URL prefix for the domain, e.g., /mydomain
    # handler  - The domain handler
    #
    # Installs a domain handler with the server.  The handler
    # is a command prefix to which will be added the connection
    # socket name and the URL suffix.

    typemethod {domain install} {domain handler} {
        url prefix install $domain $handler
    }

    #-------------------------------------------------------------------
    # Delegated Methods

    delegate typemethod port       using {::ahttpd::httpd %m}
    delegate typemethod secureport using {::ahttpd::httpd %m}
    

}
