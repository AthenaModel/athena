#-----------------------------------------------------------------------
# TITLE:
#    smartdomain.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    projectlib(n): smart URL domain handler
#
#    Instances of smartdomain(n) provide domain handlers that can be
#    used with ahttpd(n) or myserver(n).
#
#    TBD: If a folder is queried, redirect to index.html.
#
#-----------------------------------------------------------------------

oo::class create ::projectlib::smartdomain {
    #-------------------------------------------------------------------
    # Instance Variables

    # info array
    #
    # domain            - The URL prefix for this domain, e.g., /foo/bar
    # handler-$suffix   - The handler command for the suffix
    # docstring-$suffix - The documentation string for the suffix
    # sock              - The connection currently being handled.

    variable info

    # patterns dictionary: URL suffix by matching regexp

    variable patterns

    # schemaForm - array of values
    variable schemaForm

    #-------------------------------------------------------------------
    # Constructor

    # constructor domain
    #
    # domain   - The domain prefix, e.g., /foo/bar

    constructor {domain} {
        namespace import ::ahttpd::ahttpd
        set info(domain) $domain
        set patterns [dict create]

        my url /urlschema.html [mymethod UrlSchema] {This description.}

        set schemaForm(order) alpha
    }

    #-------------------------------------------------------------------
    # Server Registrations

    # ahttpd
    #
    # Registers this domain with ahttpd(n), which should already be
    # initialized.

    method ahttpd {} {
        ahttpd domain install $info(domain) [mymethod ahttpdDomain]
    }

    # myserver name
    #
    # Registers this domain with a myserver(n) called $name.

    method myserver {name} {
        error "Not implemented yet"
        $name install $info(domain) [mymethod myHandler]
    }
    
    
    #-------------------------------------------------------------------
    # URL Registration

    # url suffix handler docstring
    #
    # suffix     - The URL suffix with filename and extension, e.g.,
    #              /this/that/index.html
    # handler    - The handler command prefix; see below.
    # docstring  - A brief documentary string for the URL.
    #
    # Registers a URL with the domain.  The suffix must begin with a "/",
    # end with a filename and extension, and may include zero or
    # more variables, e.g., "/actor/{a}/index.html".  The variable name 
    # must be the entire path component, and must be contained in {} as 
    # shown.
    #
    # The suffix will be matched by replacing the variables with 
    # regexp's, e.g., /actor/(\w+)/index.html.
    #
    # The handler must be a command prefix, to which will be added
    # one argument for each matched variable; the name of the request
    # data array; and a dictionary of query data as parsed by ncgi.
    # The full query string is also contained in the data array, in
    # case the handler wants to handle it by itself.

    method url {suffix handler docstring} {
        # FIRST, turn it into a matching pattern; this will throw
        # an error if there's a problem.
        set pattern [my GetUrlPattern $suffix]

        if {$pattern eq ""} {
            error "Invalid suffix: \"$suffix\""
        }

        # NEXT, save it all.
        set info(handler-$suffix) $handler
        set info(docstring-$suffix) [outdent $docstring]
        dict set patterns $pattern $suffix
    }

    # urltree root handler docstring
    #
    # root       - The domain suffix that is the root of the tree, e.g.,
    #              /this/that
    # handler    - The handler command prefix; see below.
    # docstring  - A brief documentary string for the URL tree
    #
    # Registers a URL tree with the domain.  The root must begin with 
    # a "/", must end with a directory name, and may include
    # zero or more variables, e.g., "/rdb/{name}".  The variable name 
    # must be the entire path component, and must be contained in {} as 
    # shown.
    #
    # The root will be matched by replacing the variables with 
    # regexp's and adding a regexp for the URL suffix, e.g., 
    # "/rdb/(\w+)/(.+..)".
    #
    # The handler must be a command prefix, to which will be added
    # one argument for each matched variable; the URL suffix; the name of 
    # the request data array; and a dictionary of query data as parsed by 
    # ncgi. The full query string is also contained in the data array, in
    # case the handler wants to handle it by itself.

    method urltree {root handler docstring} {
        # FIRST, turn it into a matching pattern.
        set pattern [my GetUrlTreePattern $root]

        if {$pattern eq ""} {
            error "Invalid root: \"$root\""
        }

        # NEXT, save it all.
        set info(handler-$root) $handler
        set info(docstring-$root) [outdent $docstring]
        dict set patterns $pattern $root
    }

    # GetUrlPattern suffix
    #
    # suffix  - A URL suffix, possibly containing variables.
    #
    # Returns the matching regexp pattern, or "" if the suffix
    # is invalid.

    method GetUrlPattern {suffix} {
        if {[string index $suffix 0] ne "/"} {
            return ""
        }

        set folders  [split [string range $suffix 1 end] /]
        set filename [lpop folders]

        set pattern "^"

        foreach f $folders {
            if {[regexp {^{\w+}$} $f]} {
                append pattern {/(\w+)}
            } elseif [regexp {^\w+$} $f] {
                append pattern / $f
            } else {
                return ""
            }
        }

        if {[regexp {^\w+\.\w+$} $filename]} {
            append pattern / $filename
        } else {
            return ""
        }

        append pattern "\$"

        return $pattern
    }

    # GetUrlTreePattern suffix
    #
    # suffix  - An URL tree root, possibly containing variables.
    #
    # Returns the matching regexp pattern, or "" if the suffix
    # is invalid.

    method GetUrlTreePattern {suffix} {
        if {[string index $suffix 0] ne "/"} {
            return ""
        }

        set folders  [split [string range $suffix 1 end] /]

        set pattern "^"
        foreach f $folders {
            if {[regexp {^{\w+}$} $f]} {
                append pattern {/(\w+)}
            } elseif [regexp {^\w+$} $f] {
                append pattern / $f
            } else {
                return ""
            }
        }

        append pattern "/(.*)\$"

        return $pattern
    }

    # GetHandler suffix
    #
    # suffix   - The URL's suffix in this domain.
    #
    # Finds the matching handler, and returns the command prefix.  
    # If there's no match, returns "".

    method GetHandler {suffix} {
        # FIRST, find the matching handler.
        dict for {pattern id} $patterns {
            set result [regexp -inline $pattern $suffix]
            if {[llength $result] == 0} {
                continue
            }

            return [list {*}$info(handler-$id) {*}[lrange $result 1 end]]
        }

        # NEXT, it hasn't matched anything; see if it's a directory
        # and if so add index.html and try again.
        if {[file extension $suffix] eq ""} {
            if {$suffix eq ""} {
                set newsuffix "/index.html"
            } else {
                set newsuffix [file join $suffix index.html]
            }

            if {[my GetHandler $newsuffix] ne ""} {
                set newurl $info(domain)$newsuffix
                throw [list HTTPD_REDIRECT $newurl] "Redirect to index.html"
            }
        }

        return ""
    }


    #-------------------------------------------------------------------
    # ahttpd(n) support

    # ahttpdDomain sock suffix
    #
    # sock    - The socket back to the client
    # suffix  - The part of the URL after the domain prefix
    #
    # Main ahttpd(n) handler for smart domains.  The content-type
    # is determined by the file extension on the URL.
    #
    #  The default type is text/html
    #
    # TBD: provide ahttpd subcommands, as needed, so that it isn't
    # necessary to call internal modules.
    #
    # TBD: What should go in the data array?

    method ahttpdDomain {sock suffix} {
        # FIRST, get the handler for this suffix.  Return "not found"
        # if there's no matching handler.  The handler will include
        # values of any place-holder arguments as normal arguments.

        set handler [my GetHandler $suffix]

        if {$handler eq ""} {
            ahttpd notfound  $sock            
            return
        }

        # NEXT, get the request data.  TBD: Possibly, data should be
        # sanitized for the handler.  Be nice to have a better way to
        # do this, as well.
        upvar #0 ::ahttpd::Httpd$sock data

        # NEXT, parse the query data into a dictionary.
        # TBD: This will need to be generalized for myserver use.
        if {$data(proto) ne "POST" ||
            $data(mime,content-type) eq "application/x-www-form-urlencoded"
        } {
            set qdict [ahttpd querydict $sock]
        } else {
            set qdict {}
        }


        set pdict [::projectlib::parmdict new $qdict]

        try {
            set info(sock) $sock
            set result [{*}$handler [self] $pdict]
        } trap NOTFOUND {result} {
            ahttpd notfound $sock $result
            return
        } finally {
            $pdict destroy
        }

        set ctype [ahttpd mimetype frompath $suffix]

        ahttpd return $sock $ctype $result

        return
    }

    #-------------------------------------------------------------------
    # Automatically generated content

    # UrlSchema sd datavar qdict
    #
    # sd       - The smartdomain object name
    # datavar  - name of the ahttpd(n) state array
    # qdict    - Dictionary of query data
    #
    # Returns an HTML description of the URLs in the domain.

    method UrlSchema {sd datavar qdict} {
        upvar 1 $datavar data
        set ht [htools create %AUTO%]

        if {[dict exist $qdict sort]} {
            set sort [dict get $qdict sort]
        } else {
            set sort url
        }

        set urlcheck ""
        set defcheck ""

        switch -- $sort {
            url     { set urlcheck checked }
            def     { set defcheck checked }
            default { 
                set urlcheck checked 
                set sort url
            }
        }

        set trans [list \{ <i> \} </i>]

        set title "URL Schema Help: $info(domain)" 
        $ht page $title
        $ht h1 $title

        $ht putln "The following URLs are defined within this domain."
        $ht para
        $ht hr
        $ht form -action $data(url)
        $ht putln "Sort by URL <input type=radio name=sort value=url $urlcheck>"
        $ht putln "or Match Order <input type=radio name=sort value=def $defcheck>"
        $ht putln "<input type=submit name=submit value=\"Refresh\">"
        $ht /form
        $ht hr
        $ht para

        set suffixes [dict values $patterns]

        if {$sort eq "url"} {
            set suffixes [lsort $suffixes]
        }

        $ht dl

        foreach suffix $suffixes {
            set url "$info(domain)[string map $trans $suffix]"
            set doc [string map $trans $info(docstring-$suffix)]

            $ht dlitem  "<tt>$url</tt>" $doc       
        }

        $ht /dl
        $ht /page

        set result [$ht get]

        $ht destroy
        return $result
    }
    
    #-------------------------------------------------------------------
    # Tools for use in domain handlers 

    # redirect url
    #
    # url   - A server-relative URL
    #
    # Redirects to the URL.

    method redirect {url} {
        throw [list HTTPD_REDIRECT $url] "Redirect to $url"
    }

    # query
    #
    # Returns the raw query string.
    
    method query {} {
        upvar #0 ::ahttpd::Httpd$info(sock) data
        return $data(query) 
    }

}

