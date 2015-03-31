#-----------------------------------------------------------------------
# TITLE:
#    direct.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    ahttpd(n): Application-direct URLs
#
#    Support for application-direct URLs that result in Tcl procedures
#    being invoked inside the server.
#
#    Brent Welch (c) 1997 Sun Microsystems
#    Brent Welch (c) 1998-2000 Ajuba Solutions
#    Will Duquette (c) 2015 California Institute of Technology
#
#    See the file "license.terms" for information on usage and 
#    redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# TBD: 
#    The naming scheme and content type handling is ghastly.
#
#-----------------------------------------------------------------------

snit::type ::ahttpd::direct {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # info array 
    #
    # $prefix  - virtual URL

    typevariable info -array {}
    
    #-------------------------------------------------------------------
    # Public Type Methods
    
    # url virtual prefix
    # 
    # virtual - The name of the subtree of the hierarchy, e.g., /device
    # prefix  - The Tcl command prefix to use when constructing calls,
    #           e.g. Device
    # 
    # Define a subtree of the URL hierarchy that is implemented by
    # direct Tcl calls.

    typemethod url {virtual prefix} {
        set info($prefix) $virtual    ;# So we can reconstruct URLs
        url prefix install $virtual [myproc DirectDomain $prefix]
    }

    # remove prefix
    #
    # prefix  - The Tcl command prefix used when constructing calls
    #
    # Remove a subtree of the URL hierarchy that is implemented by
    # direct Tcl calls.
           
    typemethod remove {prefix} {
        catch { url prefix uninstall $info($prefix) }
        unset -nocomplain info($prefix)
    }

    #-------------------------------------------------------------------
    # Private Type Methods

    # DirectDomain prefix sock suffix
    #
    # prefix  - The Tcl command prefix registered for the URL
    # sock    - The socket back to the client
    # suffix  - The part of the URL after the domain prefix
    #
    # Main handler for Direct domains (i.e. tcl commands)
    #
    # This calls out to the Tcl procedure named "$prefix$suffix",
    # with arguments taken from the form parameters.
    #
    # Example: ::ahttpd::direct url /device Device
    #
    # If the URL is /device/a/b/c, then the Tcl command to handle it
    # should be
    #
    #   proc Device/a/b/c
    #
    # You can define the content type for the results of your procedure by
    # defining a global variable with the same name as the procedure:
    # set Device/a/b/c text/plain
    #
    #  The default type is text/html

    proc DirectDomain {prefix sock suffix} {
        upvar #0 ::ahttpd::Httpd$sock data

        # Set up the environment a-la CGI, into ::ahttpd::cgienv
        cgi setenv $sock $prefix$suffix

        # Prepare an argument data from the query data.
        url querysetup $sock

        set cmd [MarshallArguments $prefix $suffix]
        if {$cmd eq ""} {
            doc notfound $sock
            return
        }

        # Eval the command.  Errors can be used to trigger redirects.

        set code [catch $cmd result]

        set ctype text/html
        # TBD: This is ghastly
        upvar #0 $prefix$suffix aType
        if {[info exist aType]} {
            set ctype $aType
        }

        DirectRespond $sock $code $result $ctype
    }

    # MarshallArguments prefix suffix
    #
    # prefix  - The Tcl command prefix of the domain registered 
    #           with [direct url].
    # suffix  - The part of the url after the domain prefix.
    #
    # Use the url prefix, suffix, and cgi values (set with the
    # ncgi package) to create a Tcl command line to invoke.
    #
    # Returns a Tcl command line.
    #
    # If the prefix and suffix do not map to a Tcl procedure,
    # returns empty string.

    proc MarshallArguments {prefix suffix} {
        set cmd $prefix$suffix
    
        if {![iscommand $cmd]} {
            return
        }

        # Compare built-in command's parameters with the form data.
        # Form fields with names that match arguments have that value
        # passed for the corresponding argument.
        # Form fields with no corresponding parameter are collected into args.

        set cmdOrig $cmd
        set params [info args $cmdOrig]
        foreach arg $params {
            if {[ncgi::empty $arg]} {
                if [info default $cmdOrig $arg value] {
                    lappend cmd $value
                } elseif {[string compare $arg "args"] == 0} {
                    set needargs yes
                } else {
                    lappend cmd {}
                }
            } else {
                # The original semantics for Direct URLS is that if there
                # is only a single value for a parameter, then no list
                # structure is added.  Otherwise the parameter gets a list
                # of all values.

                set vlist [ncgi::valueList $arg]
                if {[llength $vlist] == 1} {
                    lappend cmd [ncgi::value $arg]
                } else {
                    lappend cmd $vlist
                }
            }
        }

        if {[info exists needargs]} {
            foreach {name value} [ncgi::nvlist] {
                if {[lsearch $params $name] < 0} {
                    lappend cmd $name $value
                }
            }
        }
        return $cmd
    }

    # DirectRespond sock code result ?type?
    #
    # sock    - The socket back to the client.
    # code    - The return code from evaluating the direct url.
    # result  - The return string from evaluating the direct url.
    # type    - The mime type to use for the result.  (Defaults to text/html).
    #
    # This function returns the result of evaluating the direct
    # url.  Usually, this involves returning a page, but a redirect
    # could also occur.
    #
    # Side effects:
    #   If code 302 (redirect) is passed, calls httpd redirect to 
    #   redirect the current request to the url in result.
    #   If code 0 is passed, the result is returned to the client.
    #   If any other code is passed, an exception is raised, which
    #   will cause a stack trace to be returned to the client.

    proc DirectRespond {sock code result {type text/html}} {
        switch $code {
            0 {
                # Fall through to httpd returnData.
            }
            302 {
                # Redirect.
                httpd redirect $result $sock
                return ""
            }
            default {
                # Exception will cause error page to be returned.

                global errorInfo errorCode
                return -code $code -errorinfo $errorInfo -errorcode $errorCode \
                    $result
            }
        }

        # See if a content type has been registered for the URL.

        # Save any return cookies which have been set.
        # This works with the [cookie set] command that populates
        # the global cookie array.
        cookie save $sock

        httpd returnData $sock $type $result
        return ""
    }
}

