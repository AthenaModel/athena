#-----------------------------------------------------------------------
# TITLE:
#    webserver.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    jnem_console(1) webserver module. This module is a refactoring of
#    the main script from the Tclhttpd package. It uses the tclhttpd 
#    library to load all of its needed submodules.
#
#  Libs needed:
#      counter 2.0
#      html    1.4.4
#      ncgi    1.4.3
#
#  Needs:
#      -tempdir
#      -logdir
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Required Packages
package require httpd 1.7
package require md5
# package require cmdline
# package require html
# package require ncgi

# httpd sub-packages
package require httpd::version  ;# For Version proc
package require httpd::utils    ;# For Stderr
package require httpd::counter  ;# For Count

package require httpd::url	    ;# URL dispatching
package require httpd::mtype	;# Mime types
package require httpd::redirect	;# URL redirection

set ::Config(AuthDefaultFile) [pwd]/tmp/tclhttpd.default

package require httpd::auth	    ;# Basic authentication
package require httpd::log	    ;# Standard logging
package require httpd::digest	;# Digest authentication
package require httpd::doc
package require httpd::dirlist  ;# Directory listings
package require httpd::include  ;# Server side includes
# package require httpd::cgi      ;# Standard CGI
# package require httpd::ismaptk
package require httpd::direct   ;# Application Direct URLs
package require httpd::status   ;# Built in status counters
# package require httpd::mail     ;# Crude email form handlers
# package require httpd::admin    ;# Url-based administration
package require httpd::debug    ;# Debug utilites
# package require httpd::doctools ;# doctool type conversions
# package require httpd::compat   ;# doctool type conversions
 
#----------------------------------------------------------------------
# webserver singleton

proc log {level comp text} {
    puts "$level $comp $text"
}

snit::type webserver {
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
    # uid       - User ID of the server process. Not used.
    # gid       - Group ID of the server process. Not used.
    # docroot   - The location of the root of the html document tree
    # webmaster - email address of contact person should server have
    #             problems
    # limit     - The file descriptor limit, currently set to the OS default
    # comp      - Compression program used to compress log files

    typevariable info -array {
        host        {}
        port        8080
        ipaddr      127.0.0.1
        uid         50
        gid         50
        docroot     {}
        webmaster   "David.R.Hanks@jpl.nasa.gov"
        limit       default
        comp        gzip
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
    #------------------------------------------------------------------
    # Type Method: init
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
                    set info(docroot) [lshift args]
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
        Log_SetFile		    [pwd]/log/httpd$info(port)_
        Log_FlushMinutes	0
        Log_Flush
        
        log normal httpd "httpd started on port $info(port)\n"

        puts "httpd started on port $info(port)"
    }
    
    # flush
    #
    # Empties the pageCache of all history

    typemethod flush {} {
        array unset pageCache
    }
    

    #------------------------------------------------------------------
    # Private Type methods
    #------------------------------------------------------------------
    # Type method: StartMainThread
    #
    # This method does all the heavy lifting for starting up and setting
    # all the configuration parameters for the webserver

    typemethod StartMainThread {} {
        # FIRST, read the MIME types
        Mtype_ReadTypes [file join $::Httpd(library) mime.types]

        # NEXT, initial the counter, this is for gathering statistics about
        # the server.
        # Note: This could be made an option to be passed to the server
        Counter_Init 60
        
        # NEXT, Doc_Root defines the top-level directory, or folder, for
        # your web-visible file structure.
        Doc_Root $info(docroot)

        # NOTE: the following package require must have Doc_Root set first 
        # otherwise it fails -- YUK!
        # Session state module 
        package require httpd::session
        
        # Merge in a second file system into the URL tree.
        set htdocs_2 [file join [file dirname [info script]] ../htdocs_2]
        if {[file isdirectory $htdocs_2]} {
            Doc_AddRoot /addroot	$htdocs_2
        }
        
        # Template_Interp determines which interpreter to use when
        # interpreting templates.
        
        Template_Interp {}
        
        # Doc_IndexFile defines the name of the default index file
        # in each directory.  Its value is a glob pattern.
        
        DirList_IndexFile index.{tml,html,shtml,thtml,htm,subst}
        
        # Doc_PublicHtml turns on the mapping from ~user to the
        # specified directory under their home directory.
        
        # Doc_PublicHtml public_html
        
        # Doc_CheckTemplates causes the processing of text/html files to
        # first look aside at the corresponding .tml file and check if it is
        # up-to-date.  If the .tml (or its dependent files) are newer than
        # the HTML file, the HTML file is regenerated from the template.
        
        Template_Check 1
        
        # Doc_ErrorPage registers a template to be used when a page raises an
        # uncaught Tcl error.  This is a crude template that is simply passed 
        # through subst at the global level.  In particular,  
        # it does not have the full semantics of a .tml template.
        
        Doc_ErrorPage /error.html
        
        # Doc_NotFoundPage registers a template to be used when a 404 not found
        # error occurs.  Like Doc_ErrorPage, this page is simply subst'ed.
        
        Doc_NotFoundPage /notfound.html
        
        # Doc_Webmaster returns the value last passed into it.
        # Designed to be used in page templates where contact email is needed.
        
        Httpd_Webmaster  $info(webmaster)
        
        # Cgi_Directory /cgi-bin
        
        Status_Url /status /images
        
        # Mail_Url /mail
        
        # Admin_Url /admin
        
        Debug_Url /debug
        
        Redirect_Init /redirect
        
        if {[catch {
            Auth_InitCrypt ;# Probe for crypt module
        } err]} {
            catch {puts "No .htaccess support: $err"}
        }
        
        # NEXT, define URLs recognized by this webserver
        $type DefineURLs
    }


    # Type method: DefineURLs
    #
    # This typemethod calls the tclhttpd proc to create all the URLs 
    # recognized by the JNEM webserver. When a client requests a document
    # from the server the corresponding proc is called to build and 
    # deliver the requested page. 

    typemethod DefineURLs {} {
        Direct_Url /getReport.html [myproc getReport]
    }
}
                
# These stubs tell the httpd server that there are no worker threads
proc Thread_Respond {args} {return 0}
proc Thread_Enabled {}     {return 0}
