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
#    used with ahttpd(n) or mydomain(n).
#
#    TBD: If a folder is queried, redirect to index.html.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export smarturl
}


oo::class create ::projectlib::smartdomain {
    #-------------------------------------------------------------------
    # Instance Variables

    # info array
    #
    # domain            - The URL prefix for this domain, e.g., /foo/bar
    # handler-$suffix   - The handler command for the suffix
    # docstring-$suffix - The documentation string for the suffix

    variable info

    # patterns dictionary: URL suffix by matching regexp

    variable patterns

    # trans array
    #
    # Transient data during a request.
    #
    # query   - The full query string

    variable trans

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

        my url /urlschema.html {This description.}

        set trans(query) ""

        set schemaForm(order) alpha

        # Create components in the instance namespace for use
        # in URL handlers.

        ::projectlib::htmlbuffer create hb \
            -domain $domain

        ::projectlib::parmdict create qdict
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

    # mydomain name
    #
    # Registers this domain with a mydomain(n) called $name.

    method mydomain {name} {
        error "Not implemented yet"
        $name install $info(domain) [mymethod myHandler]
    }
    
    
    #-------------------------------------------------------------------
    # URL Registration

    # url suffix docstring
    #
    # suffix     - The URL suffix with filename and extension, e.g.,
    #              /this/that/index.html
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
    # The suffix will be handled by the method of the same name, which
    # will be called with one argument for each matched variable and
    # a dictionary of query data as parsed by ncgi.

    method url {suffix docstring} {
        # FIRST, turn it into a matching pattern; this will throw
        # an error if there's a problem.
        set result [::projectlib::smartdomain::GetUrlPattern $suffix]

        if {[llength $result] == 0} {
            error "Invalid suffix: \"$suffix\""
        }

        set pattern [lindex $result 0]

        # NEXT, save it all.
        set info(handler-$suffix) [list my $suffix]
        set info(docstring-$suffix) [outdent $docstring]
        dict set patterns $pattern $suffix
    }

    # urltree root docstring
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
    # URLs with this root will be handled by the method of the same name, 
    # which will be called with one argument for each matched variable, 
    # the URL suffix (following the root) and a dictionary of query data 
    # as parsed by ncgi.

    method urltree {root docstring} {
        # FIRST, turn it into a matching pattern.
        set pattern [my GetUrlTreePattern $root]

        if {$pattern eq ""} {
            error "Invalid root: \"$root\""
        }

        # NEXT, save it all.
        set info(handler-$root) [list my $root]
        set info(docstring-$root) [outdent $docstring]
        dict set patterns $pattern $root
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

        append pattern "(/.*)\$"

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
        set trans(query)   $data(query)
        set trans(hmethod) $data(proto)
        set trans(url)     $data(url)

        # NEXT, parse the query data into a dictionary.
        # TBD: This will need to be generalized for mydomain use.
        if {$data(proto) ne "POST" ||
            $data(mime,content-type) eq "application/x-www-form-urlencoded"
        } {
            qdict setdict [ahttpd querydict $sock]
        } else {
            qdict setdict {}
        }

        try {
            set info(sock) $sock
            set result [{*}$handler]
        } trap NOTFOUND {result} {
            ahttpd notfound $sock $result
            return
        }

        set ctype [ahttpd mimetype frompath $suffix]

        ahttpd return $sock $ctype $result

        return
    }

    #-------------------------------------------------------------------
    # Direct Access

    # request op suffix ?query?
    #
    # op      - GET or POST
    # suffix  - The part of the URL after the domain prefix
    # query   - The query data
    #
    # Calls the handler for the suffix, returning the desired value,
    # or throws NOTFOUND.  On GET, the query data is parsed as 
    # a query dictionary; on POST it is not. 

    method request {op suffix {query ""}} {
        # FIRST, get the handler for this suffix.  Return "not found"
        # if there's no matching handler.  The handler will include
        # values of any place-holder arguments as normal arguments.

        set handler [my GetHandler $suffix]

        if {$handler eq ""} {
            throw NOTFOUND "Not found: $suffix"
        }

        # NEXT, get the query data.
        set trans(query) $query

        if {$op ne "POST"} {
            qdict setdict $query
        }

        return [{*}$handler]
    }

    #-------------------------------------------------------------------
    # Tools for use in domain handlers 

    # domain ?components?
    #
    # Returns the domain URL

    method domain {args} {
        if {[llength $args] > 0} {
            return $info(domain)/[join $args /]
        } else {
            return $info(domain)
        }
    }

    # redirect url
    #
    # url   - A server-relative URL
    #
    # Redirects to the URL.
    #
    # TBD: Should really be 'throw REDIRECT $url'

    method redirect {url} {
        throw [list HTTPD_REDIRECT $url] "Redirect to $url"
    }

    # query
    #
    # Returns the raw query string.
    
    method query {} {
        return $trans(query) 
    }

    # hmethod
    #
    # Returns the HTTP method, GET or POST.
    
    method hmethod {} {
        return $trans(hmethod)
    }

    # hurl 
    #
    # Returns the server-relative URL, minus query, for this request.

    method hurl {} {
        return $trans(url)
    }

    #-------------------------------------------------------------------
    # Automatically generated content

    # /urlschema.html
    #
    # Returns an HTML description of the URLs in the domain.

    method /urlschema.html {} {
        qdict prepare sort -default url
        qdict assign sort

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

        set title "URL Schema Help: $info(domain)" 
        hb page $title
        hb h1 $title

        hb putln "The following URLs are defined within this domain."
        hb para
        hb hr
        hb form
        hb label sort "Sort by URL"
        # TBD: Need to support radio buttons, or perhaps a pulldown.
        hb putln "<input type=radio name=sort value=url $urlcheck>"
        hb putln "or Match Order"
        hb putln "<input type=radio name=sort value=def $defcheck>"
        hb submit "Refresh"
        hb /form
        hb hr
        hb para

        set suffixes [dict values $patterns]

        if {$sort eq "url"} {
            set suffixes [lsort $suffixes]
        }

        set mapping [list \{ <i> \} </i>]

        hb dl {
            foreach suffix $suffixes {
                set url "$info(domain)[string map $mapping $suffix]"
                set doc [string map $mapping $info(docstring-$suffix)]

                hb dt "<tt>$url</tt>"
                hb dd-with {
                    hb putln $doc
                    hb para
                }       
            }
        }

        return [hb /page]
    }
    
}

#-------------------------------------------------------------------
# Helper Procs

namespace eval ::projectlib::smartdomain {
    # GetUrlPattern suffix
    #
    # suffix  - A URL suffix, possibly containing variables.
    #
    # Returns a pair, consisting of the matching regexp pattern
    # and a list of the placeholder names, or "" if the suffix
    # is invalid.

    proc ::projectlib::smartdomain::GetUrlPattern {suffix} {
        if {[string index $suffix 0] ne "/"} {
            return ""
        }

        set folders  [split [string range $suffix 1 end] /]
        set filename [lpop folders]

        set pattern "^"
        set pnames [list]

        foreach f $folders {
            if {[regexp {^{(\w+)}$} $f dummy pname]} {
                append pattern {/(\w+)}
                lappend pnames $pname
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

        return [list $pattern $pnames]
    }
}

proc ::projectlib::smarturl {cls suffix docstring body} {
    # FIRST, extract the placeholders out of the suffix.
    set result [::projectlib::smartdomain::GetUrlPattern $suffix]

    if {$result eq ""} {
        error "Invalid smarturl suffix: \"$suffix\""
    }

    lassign $result pattern arglist

    # NEXT define the handler method
    oo::define $cls method $suffix $arglist $body

    # NEXT, make the constructor register the URL.
    lassign [info class constructor $cls] carglist cbody

    set cmd [list my url $suffix $docstring]

    append cbody \n $cmd

    oo::define $cls constructor $carglist $cbody
}

