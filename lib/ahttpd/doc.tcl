#-----------------------------------------------------------------------
# TITLE:
#    doc.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    ahttpd(n): File-system based URL support.
#
#    This calls out to the Auth module to check for access files.
#    Once a file is found, it checks for content-type handlers defined
#    by "doc handler".  If one is present then it is responsible for 
#    processing the file and returning it.  Otherwise the file is 
#    returned by "doc handle".
#
#    If a file is not found then a limited form of content negotiation is
#    done based on the browser's Accept header.  For example, this makes
#    it easy to transition between foo.shtml and foo.html.  Just rename
#    the file and content negotiation will find it from old links.
#
#    Stephen Uhler / Brent Welch (c) 1997-1998 Sun Microsystems
#    Brent Welch (c) 1998-2000 Ajuba Solutions
#    Will Duquette (c) 2015 California Institute of Technology
#
#    See the file "license.terms" for information on usage and 
#    redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
#-----------------------------------------------------------------------

snit::type ::ahttpd::doc {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # info - module info array
    #
    # root - The directory corresponding to "/" on this server.
    typevariable info -array {
        root {}
    }

    # handler - Content Type handlers by mime type   
    typevariable handler -array {}

    #-------------------------------------------------------------------
    # Public Type Methods

    # handler mtype ?command?
    #
    # mtype   - A mime type
    # command - A command prefix
    #
    # Sets and queries a mimetype handler that will be used to process
    # specific content types.  The command will be called with
    # three additional arguments, the path, the URL suffix, and the
    # socket connection.

    typemethod handler {mtype {command ""}} {
        if {$command ne ""} {
            set handler($mtype) $command
        }

        return $handler($mtype)
    }

    # root ?real? args
    #
    # real - The name of the file system directory containing the root of 
    #        the URL tree.  If this is empty, then the current document 
    #        root is returned instead.
    # args - With "real", arguments for [url prefix install]
    #
    # Sets or queries the root of the document tree.

    typemethod root {args} {
        if {[llength $args] > 0} {
            set info(root) [lindex $args 0]
            $type addroot / {*}$args
            return
        }

        return $info(root)
    }

    # addroot virtual directory args
    #
    # virtual    - The URL prefix of the document tree to add.
    # directory  - The file system directory containing the doc tree.
    # args       - Same as args for [url prefix install]
    #
    # Add a file system to the virtual document hierarchy.
    # Sets up a document URL domain and the document-based access hook.

    typemethod addroot {virtual directory args} {
        $type registerroot $virtual $directory
        url prefix install $virtual [myproc DocDomain $virtual $directory] {*}$args
        url access install [myproc DocAccessHook]
        return
    }

    # registerroot virtual directory
    #
    # virtual   - The prefix of the URL
    # directory - The directory that corresponds to $virtual
    # 
    # Add a file system managed by any Domain Handler (e.g. CGI)
    # This is necessary for Doc_AccessControl to search directories right.

    typemethod registerroot {virtual directory} {
        if {[info exist info(root,$virtual)] &&
            [string compare $info(root,$virtual) $directory] != 0
        } {
            return -code error \
                "cannot change an existing url-to-directory mapping"
        }
        set info(root,$virtual) $directory
    }


    # virtual sock curfile virtual
    #
    # sock     - The client connection.
    # curfile  - The pathname of the file that contains the
    #            "virtual" URL spec.  This is used to resolve
    #            relative URLs.
    # virtual  - The URL we need the file name of.
    # 
    # Return a real pathname corresponding to a "virtual" path in an 
    # include.  If "" is returned, then the URL is invalid.

    typemethod virtual {sock curfile virtual} {
        if {[regexp ^~ $virtual]} {
            # Home directory syntax is not supported.
            return {} 
        }

        # Try to hook up the pathname under the appropriate document root
        if {[regexp ^/ $virtual]} {
            url prefix match  $virtual prefix suffix

            if {[info exist info(root,$prefix)]} {
                return [file join $info(root,$prefix) [string trimleft $suffix /]]
            } else {
                # Not a document domain, so there cannot be a file behind this url.
                return {}
            }
        }

        # Non-absolute URL
        return [file join [file dirname $curfile] $virtual]
    }

    # handle prefix path suffix sock
    #
    # prefix  - The URL prefix of the domain.
    # path    - The file system pathname of the file.
    # suffix  - The URL suffix.
    # sock    - The socket connection.
    #
    # Handle a document URL.  Dispatch to the mime type handler, if defined.

    typemethod handle {prefix path suffix sock} {
        upvar #0 ::ahttpd::Httpd$sock data

        if {[file isdirectory $path]} {
            if {[string length $data(url)] && ![regexp /$ $data(url)]} {

                # Insist on the trailing slash
                httpd redirectDir $sock
                return
            }

            dirlist handle $prefix $path $suffix $sock
        } elseif {[file readable $path]} {
            # Is there a content handler for this type?
            set mtype [mimetype frompath $path]

            if {![info exists handler($mtype)]} {
                httpd returnFile $sock $mtype $path
            } else {
                {*}$handler($mtype) $path $suffix $sock
            }
        } else {
            # Either not found, or we can find an alternate (e.g. a template).
            if {![fallback try $prefix $path $suffix $sock]} {
                $type notfound $sock
            }
        }
    }

    # getpath sock ?file?
    #
    # sock  - The client connection
    # file  - The file endpoint of the path
    #   
    # Return a list of unique directories from domain root to a given path
    # Adjusts for Document roots and user directories

    typemethod getpath {sock {file ""}} {
        upvar #0 ::ahttpd::Httpd$sock data

        if {$file == ""} {
            set file $data(path)
        }

        # Start at the virtual root
        if {[info exist info(root,$data(prefix))]} {
            set root $info(root,$data(prefix))

            # always start in the rootdir
            set dirs $info(root)
        } else {
            set root $info(root,/)
            set dirs {}
        }

        set dirsplit [file split [file dirname $file]]

        if {[string match ${root}* $file]} {
            # Normal case of pathname under domain prefix
            set path $root
            set extra [lrange $dirsplit [llength [file split $root]] end]
        } else {
            # Don't know where we are - just use the current directory
            set path [file dirname $file] 
            set extra {}
        }

        foreach dir [concat [list {}] $extra] {
            set path [file join $path $dir]

            # Don't add duplicates to the list.
            if {[lsearch $dirs $path] == -1} {
                lappend dirs $path
            }
        }

        return $dirs
    }


    # notfoundpage virtual
    #
    # virtual - The URL of the not-found page, e.g., /notfound.html
    #
    # Register a file-not-found error page. This page always gets 
    # "subst'ed, but without the fancy context of the ".tml" pages.

    typemethod notfoundpage {virtual} {
        set info(page,notfound) [$type virtual {} {} $virtual]
    }

    # errorpage virtual
    # 
    # virtual - The URL of the error page, e.g., /error.html
    #
    # Register a server error page.  This page always gets "subst'ed".

    typemethod errorpage {virtual} {
        set info(page,error) [$type virtual {} {} $virtual]
    }

    # notfound sock
    #
    # sock - The socket connection.
    #
    # Called when a page is missing.  This looks for a handler page
    # and sets up a small amount of context for it.  Returns the page.

    typemethod notfound {sock} {
        # TBD: Referer -- where does this come from?
        global Referer
        upvar #0 ::ahttpd::Httpd$sock data

        stats countname $data(url) notfound
        set info(url,notfound) $data(url)    ;# For subst

        if {[info exists data(mime,referer)]} {
            # Record the referring URL so we can track down
            # bad links
            ladd Referer($data(url)) $data(mime,referer)
        }
        DocSubstSystemFile $sock notfound 404 [protect_text $info(url,notfound)]
    }

    # error sock ei
    #
    # sock  - The socket connection.
    # ei    - errorInfo
    #
    # Called when an error has occurred processing the page.
    # Returns a page.

    typemethod error {sock ei} {
        upvar #0 ::ahttpd::Httpd$sock data

        # Could have been reset!!!
        catch {
            set info(errorUrl)  $data(url)
            set info(errorInfo) $ei  ;# For subst
            stats countname $info(errorUrl) errors
        }

        if {![info exists data(error_hook)] || 
            [catch {$data(error_hook) $sock}]
        } {
            DocSubstSystemFile $sock error 500 [protect_text $ei]
        }
    }


    # errorinfo
    #
    # Return the error information raised by this page
    
    typemethod errorinfo {} {
        return $info(errorInfo)
    }

    # urlnotfound
    #
    # Return the url which was not found (in notfound handler)

    typemethod urlnotfound {} {
        return $info(url,notfound)
    }

    # webmaster
    #
    # Returns the webmaster's e-mail address.

    typemethod webmaster {} {
        return [httpd webmaster]
    }

    #-------------------------------------------------------------------
    # Private Helper Procs

    # DocDomain prefix directory sock suffix
    #
    # prefix     - The URL prefix of the domain.
    # directory  - The directory containing teh domain.
    # sock       - The socket connection.
    # suffix     - The URL after the prefix.
    #
    #
    # Main handler for Doc domains (i.e. file systems)
    # This looks around for a file and, if found, uses "handle"
    # to return the contents.

    proc DocDomain {prefix directory sock suffix} {
        # TBD: Need a better way to do this.
        upvar #0 ::ahttpd::Httpd$sock data

        # The pathlist has been checked and URL decoded by
        # DocAccess, so we ignore the suffix and recompute it.

        set pathlist $data(pathlist)
        set suffix [join $pathlist /]

        # Handle existing files

        # The file join here is subject to attacks that create absolute
        # pathnames outside the URL tree.  We trim left the / and ~
        # to prevent those attacks.

        set path [file join $directory [string trimleft $suffix /~]]
        set path [file normalize $path]
        set data(path) $path    ;# record this path for not found handling

        if {[file exists $path]} {
            stats countname $data(url) hit
            doc handle $prefix $path $suffix $sock
            return
        }

        # Try to find an alternate.

        if {![fallback try $prefix $path $suffix $sock]} {
            # Couldn't find anything.
            doc notfound $sock
        }
    }

    # DocAccessHook sock url
    #
    # sock  - Client connection
    # url   - The full URL. We really need the prefix/suffix, which
    #         is stored for us in the connection state
    #
    # Access handle for Doc domains.  This looks for special files in the 
    # file system that determine access control.  This is registered via
    # [url access install]
    #
    # Returns "denied", in which case an authorization challenge or
    # not found error has been returned.  Otherwise "skip"
    # which means other access checkers could be run, but
    # most likely access will be granted.

    proc DocAccessHook {sock url} {
        upvar #0 ::ahttpd::Httpd$sock data

        # Make sure the path doesn't sneak out via ..
        # This turns the URL suffix into a list of pathname components

        if {[catch {url pathcheck $data(suffix)} data(pathlist)]} {
            doc notfound $sock
            return denied
        }

        # Figure out the directory corresponding to the domain, taking
        # into account other document roots.

        if {[info exist info(root,$data(prefix))]} {
            set directory $info(root,$data(prefix))
        } else {
            set directory [file join $info(root,/) [string trimleft $data(prefix) /]]
        }

        # Look for .htaccess and .tclaccess files along the path
        # If you wanted to have a time-limited cache of these
        # cookies you could save the cost of probing the file system
        # for these files on each URL.

        set cookie [auth check $sock $directory $data(pathlist)]

        # Finally, check access

        if {![auth verify $sock $cookie]} {
            return denied
        } else {
            return skip
        }
    }

    # DocSubstSystemFile sock key code ?extra? ?interp?
    #
    # sock    - The socket connection
    # key     - Either "notfound" or "error"
    # code    - HTTP code
    # extra   - Optional string to include in return page.
    # interp  - Interp to use for subst.
    #
    # Simple template processor for notfound and error pages.  Returns
    # the page.

    proc DocSubstSystemFile {sock key code {extra {}} {interp {}}} {
        if {![info exists info(page,$key)]} {
            set path [$type virtual {} {} /$key.html]
            if {[file exists $path]} {
                set info(page,$key) $path
            }
        }

        if {![info exists info(page,$key)] || 
            [catch {docsubst returnfile $sock $info(page,$key) $interp} err]
        } {
            if {[info exists err]} {
                ::ahttpd::log add $sock DocSubstSystemFile $err
            }
            httpd error $sock $code $extra
        }
    }

}
