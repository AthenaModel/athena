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
#-----------------------------------------------------------------------

snit::type ::ahttpd::server {
    # Make it an ensemble
    pragma -hasinstances 0 -hastypedestroy 0

    #------------------------------------------------------------------
    # Type Components

    # none
    #
    #------------------------------------------------------------------
    # Typevariables
    
    # info
    #
    # The info array carries around configuration data used to set up
    # the webserver. This array contains the following data:
    #
    # host      - hostname of the server. Defaulted to the current host
    # port      - The port the server is running on. Default 8080
    # ipaddr    - IP address of the server. Defaulted to ""
    # docroot   - The location of the root of the html document tree
    # webmaster - email address of contact person should server have
    #             problems
    # limit     - The file descriptor limit, currently set to the OS default

    typevariable info -array {
        host        {}
        port        8080
        ipaddr      127.0.0.1
        uid         50
        gid         50
        docroot     {}
        webmaster   "David.R.Hanks@jpl.nasa.gov"
        limit       default
    }

    # pageCache
    #
    # Cached HTML pages. The code returns this for a particular time
    # if it already exists.

    typevariable pageCache -array {}

    #------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # Nothing yet
    }

    #------------------------------------------------------------------
    # Public Type methods

    
    # init
    #
    # Initializes and starts the webserver

    typemethod init {args} {
        # FIRST, default the host name 
        set info(host) [info host]

        # NEXT, parse the configuration args
        while {[llength $args] > 0} {
            set opt [lshift args]

            switch -exact -- $opt {
                -host {
                    set info(host) [lshift args]
                }

                -port {
                    set info(port) [lshift args]
                }

                -docroot {
                    set info(docroot) [file normalize [lshift args]]
                }

                default {
                    error "Unknown option \"$opt\""
                }
            }
        }

        # NEXT, start the server running
        Httpd_Init
        
        # NEXT, Open the listening sockets
        Httpd_Server $info(port) $info(host) $info(ipaddr)
                        
        # NEXT, start the server running
        $type StartMainThread

        # NEXT, some logging parameters
        # TBD: Need -logroot parameter
        ::ahttpd::log setfile ~/github/athena/log/httpd$info(port)

        # TBD: Need application log.  ahttpd::log should be combined
        # with it.
        puts "httpd started on port $info(port)"
    }
    
    # flush
    #
    # Empties the pageCache of all history

    typemethod flush {} {
        array unset pageCache
    }
    
    # version
    #
    # Returns the package version.

    typemethod version {} {
        return [package present ahttpd]
    }

    #------------------------------------------------------------------
    # Private Type methods

    #------------------------------------------------------------------
    # Type method: StartMainThread
    #
    # This method does all the heavy lifting for starting up and setting
    # all the configuration parameters for the webserver

    typemethod StartMainThread {} {
        # FIRST, initialize the statistics counter
        ::ahttpd::stats init 
        
        # NEXT, Define the top-level directory, or folder, for
        # the web-visible file structure.
        ::ahttpd::doc root $info(docroot)

        # NOTE: the following package require must have Doc_Root set first 
        # otherwise it fails -- YUK!
        # Session state module 
        package require httpd::session
                
        # Template_Interp determines which interpreter to use when
        # interpreting templates.
        
        Template_Interp {}
        
        # DirList_IndexFile defines the name of the default index file
        # in each directory.  Its value is a glob pattern.
        
        DirList_IndexFile index.{tml,html,shtml,thtml,htm,subst}
        
        
        # Template_Check causes the processing of text/html files to
        # first look aside at the corresponding .tml file and check if it is
        # up-to-date.  If the .tml (or its dependent files) are newer than
        # the HTML file, the HTML file is regenerated from the template.
        
        Template_Check 1
        
        # Doc_ErrorPage registers a template to be used when a page raises an
        # uncaught Tcl error.  This is a crude template that is simply passed 
        # through subst at the global level.  In particular,  
        # it does not have the full semantics of a .tml template.
        
        ::ahttpd::doc errorpage /error.html
        
        # Doc_NotFoundPage registers a template to be used when a 404 not found
        # error occurs.  Like Doc_ErrorPage, this page is simply subst'ed.
        
        ::ahttpd::doc notfoundpage /notfound.html
        
        # Doc_Webmaster returns the value last passed into it.
        # Designed to be used in page templates where contact email is needed.
        
        Httpd_Webmaster  $info(webmaster)
        
        Status_Url /status /images
                
        Debug_Url /debug
        
        Redirect_Init /redirect
        
        if {[catch {
            Auth_InitCrypt ;# Probe for crypt module
        } err]} {
            catch {puts "No .htaccess support: $err"}
        }
    }
}
                
# These stubs tell the httpd server that there are no worker threads
# TBD: These should not be necessary; just need to configure 
# Httpd to not use threads.
proc Thread_Respond {args} {return 0}
proc Thread_Enabled {}     {return 0}
