#-----------------------------------------------------------------------
# TITLE:
#    redirect.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    ahttpd(n): Support for redirecting URLs.
#
#    You can either do a single redirect (Redirect_Url)
#    or you can redirect a whole subtree elsewhere (Redirect_UrlTree)
#
#    Brent Welch (c) 1998-2000 Ajuba Solutions
#    Will Duquette (c) 2015 California Institute of Technology
#
#    See the file "license.terms" for information on usage and 
#    redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
#-----------------------------------------------------------------------

snit::type ::ahttpd::redirect {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    typevariable toDict     {}  ;# Registry for [redirect to]
    typevariable toselfDict {}  ;# Registry for [redirect toself]
    typevariable treeDict   {}  ;# Registry for [redirect urltree]
    

    #-------------------------------------------------------------------
    # Immediate Redirection
    #
    # These commands can be used in other domain handlers to trigger
    # an immediate redirect to another page.
    
    # goto newurl
    #
    # newurl - The new URL
    #
    # Trigger a page redirect.  Raises a special error that is caught 
    # by ::ahttpd::url::Unwind

    typemethod goto {newurl} {
        throw [list HTTPD_REDIRECT $newurl] "Redirect to $newurl"
    }

    # gotoself newurl
    #
    # newurl  - A URL relative to this server
    #
    # Like [redirect to], but to a URL that is relative to this server.

    typemethod gotoself {newurl} {
        set thispage [ncgi::urlStub]
        set thisurl [httpd selfUrl $thispage]
        set newurl [uri::resolve $thisurl $newurl]
        $type to $newurl
    }

    #-------------------------------------------------------------------
    # Registered Redirection
    #
    # These commands allow redirection based on configuration files in 
    # the server's document tree.
    

    # init ?url?
    #
    # url   - (optional) Direct URL for redirect control.
    #
    # Initialize the redirect module.  Registers access hook to 
    # implement redirects.  May register direct domain.

    typemethod init {{url {}}} {
        # FIRST, all administration of redirections, if desired.
        if {[string length $url]} {
            ::ahttpd::direct url $url [list ::ahttpd::redirect::Redirect]
        }

        # NEXT, allow redirection by individual URL.
        ::ahttpd::url access install ::ahttpd::redirect::RedirectAccess

        # NEXT, load the "redirect" file from the toplevel Doc 
        # directory; it is a Tcl file and can define redirections using
        # the commands in this module.
        Redirect/reload
    }

    #-------------------------------------------------------------------
    # Redirecting entire subtrees.
    #
    # Note that this will work whether [redirect init] is called or 
    # not.

    # subtree
    #
    # old  - Old location, (e.g., /olddir)
    # new  - New location, (e.g., /newdir)
    #
    # Map a whole URL hierarchy to a new place.
    # Future requests to old/a/b/c will redirect to new/a/b/c

    typemethod subtree {old new} {
        # FIRST, do the redirection
        ::ahttpd::url prefix install $old \
            [list ::ahttpd::redirect::RedirectDomain $new]

        # NEXT, save the details, for introspection.
        dict set treeDict $old $new
    }

    # RedirectDomain
    #
    # prefix  - The Prefix of the domain
    # url     - The other URL to which to redirect
    #
    # Set up a domain that redirects requests elsewhere
    # To use, make a call like this:
    #
    # ::ahttpd::url prefix install /olddir \
    #     [list ::ahttpd::redirect::RedirectDomain /newdir]
    #
    #   This always raises a redirect error

    proc RedirectDomain {url sock suffix} {
        set newurl $url$suffix
        httpd redirect $newurl $sock
    }

    #-------------------------------------------------------------------
    # Redirection of Individual URLs.
    #
    # These calls depend on the access control hook set by 
    # [redirect init].
    

    # to old new
    #
    # old    - Old location, (e.g., /olddir/file.html)
    # new    - New location, (e.g., http://www.foo.bar/newdir/newfile.html)
    #
    # Redirect a single URL to another, fully-qualified URL.
    # Future requests to $old will redirect to $new

    typemethod to {old new} {
        dict set toDict $old $new
    }

    # toself old new
    #
    # old   - Old location, (e.g., /olddir/file.html)
    # new   - New location, (e.g., /newdir/newfile.html)
    #
    # Redirect a single URL to another location on the same server.
    # Future requests to $old will redirect to $new

    typemethod toself {old new} {
        # Cannot make the "self" computation until we have
        # a socket and know the protocol and server name for sure

        dict set toselfDict $old $new
    }

    # RedirectAccess sock url
    #
    # sock  - Current connection
    # url   - The url of the connection
    #
    # This is invoked as an "access checker" that will simply
    # redirect a URL to another location.
    #
    # Returns "denied" if it triggered a redirect.  This stops URL processing.
    # Returns "skip" otherwise, so other access control checks can be made.

    proc RedirectAccess {sock url} {
        # FIRST, check for redirection to another URL on this server.
        if {[dict exists $toselfDict $url]} {
            # Note - this is not an "internal" redirect, but in this case
            # the server simply qualifies the url with its own name
            httpd redirectSelf [dict get $toselfDict $url] $sock
            return denied
        }

        # NEXT, check for redirection to an external URL.
        if {[dict exists $toDict $url]} {
            httpd redirect [dict get $toDict $url] $sock
            return denied
        }

        # NEXT, no redirection was found.
        return skip
    }

    #-------------------------------------------------------------------
    # Control URL Handlers

    # Redirect/reload
    #
    # When a client requests the "$url/reload", where $url is the
    # [redirect init] $url, this handler reloads the /redirect 
    # configuration file and displays status.  The file is sourced
    # into the current namespace.

    proc Redirect/reload {} {
        # Find the configuration file, if any
        set path [file join [doc root] redirect]

        if { ! [file exists $path]} {
            return
        }

        # Load the configuration file.
        source $path

        # Display status.
        set html "<h3>Reloaded redirect file</h3>"
        append html [Redirect/status]
        return $html
    }

    # Redirect/status
    #
    # Display the Redirection tables when $url/status is requested.
    # Returns the HTML text.

    proc Redirect/status {} {
        global Url  ;# hack alert

        append html "<h3>Redirect Table</h3>\n"
        append html "<table>\n"
        append html "<tr><th colspan=2>Single URLs</th></tr>\n"

        foreach old [lsort [dict keys $toselfDict]] {
            set new [dict get $toselfDict $old]
            append html "<tr><td>$old</td><td>$new</td></tr>\n"
        }

        foreach old [lsort [dict keys $toDict]] {
            set new [dict get $toDict $old]
            append html "<tr><td>$old</td><td>$new</td></tr>\n"
        }

        append html "<tr><th colspan=2>URL Subtrees</th></tr>\n"

        foreach old [lsort [dict keys $treeDict]] {
            set new [dict get $treeDict $old]
            append html "<tr><td>$old</td><td>$new</td></tr>\n"
        }
        append html </table>\n

        return $html
    }
}


