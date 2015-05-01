#-----------------------------------------------------------------------
# TITLE:
#    mydomain.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectlib(n): Generic mydomain(i) Server
#
#    This is an object that presents a unified view of the data resources
#    in an application domain, and consequently abstracts away the details of
#    the RDB.  The intent is to provide a RESTful interface to the 
#    application data to support browsing (and, possibly,
#    editing as well).
#
# URLs:
#
#    Resources are identified by URLs, as in a web server.  The ostensible
#    scheme is "my:", but that usage is obsolescent.  The mydomains in the
#    application provide a single file system view rooted at "/".  Each
#    mydomain provides one domain, e.g., "/app", "/help".
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export mydomain
}

#-----------------------------------------------------------------------
# mydomain type

snit::type ::projectlib::mydomain {
    #-------------------------------------------------------------------
    # Components

    component ht   ;# htools instance

    #-------------------------------------------------------------------
    # Options

    # -domain: the server's domain, e.g., /app, /help, /rdb.
    option -domain \
        -readonly yes \
        -type     {snit::stringtype -regexp "/[a-z]+"}

    # -logcmd: Command called to log activity

    option -logcmd

    #-------------------------------------------------------------------
    # Instance Variables

    # URL Schema dictionary
    #
    # This is a dictionary of resource data by resource type.
    # The resource types are arbitrary strings; however, they usually
    # mimic the related URL, with placeholders shown in curly brackets,
    # e.g., /myresource/{id}.
    #
    # For each resource type, we save the following data:
    #
    # pattern - A regexp that recognizes the resource.  It is matched
    #           against the "path" component, and so does not begin
    #           with a "/".
    # ctypes  - A dictionary of content types and handlers.  The
    #           first content type is the preferred type used when no
    #           type is requested.  The handler is a command that takes
    #           two additional arguments, the components of the URL 
    #           given to the server, and an array to received pattern 
    #           matches from the regexp into values "0" through "9"
    # doc     - A documentation string for the resource type.  Note
    #           that "{" and "}" in resource types and doc strings
    #           are converted to "<i>" and "</i>" when displayed as
    #           HTML.

    variable rinfo {}

    # Resource Type Cache
    #
    # Looking up a URL requires matching it against a variety of 
    # resource types.  In general, the resource type matched by 
    # a URL will never change; and many we'll look up over and over
    # again.  So cache the results of the lookup in an array.
    #
    # This might be an unnecessary optimization (I dunno) but it will
    # make me feel better.
    #
    # The key is a URL; the value is a pair, resourceType/matchDict

    variable rtypeCache -array {}

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, save options
        $self configurelist $args

        if {$options(-domain) eq ""} {
            error "-domain not specified"
        }

        # NEXT, create the htools buffer.
        install ht using htools ${selfns}::ht \
            -footercmd [mymethod FooterCmd]

        # NEXT, register the default handlers
        $self register /urlhelp {urlhelp/?} \
            text/html [mymethod html_UrlHelp] \
            "Complete URL schema for this server."

        $self register /urlhelp/{path} {urlhelp/(.+)} \
            text/html [mymethod html_UrlHelp]        \
            "Help for resource {path}."
    }

    # FooterCmd
    #
    # Formats footer text for generated pages.

    method FooterCmd {} {
        $ht putln <p>
        $ht putln <hr>
        $ht putln "<font size=2><i>"

        $ht put [format "Page generated at %s" [clock format [clock seconds]]]

        $ht put "</i></font>"
    }

    #-------------------------------------------------------------------
    # Public methods

    # domain
    #
    # Returns the object's domain

    method domain {} {
        return $options(-domain)
    }

    # register rtype pattern ctype handler ?ctype handler...? doc
    #
    # rtype     - The resource type name.
    # pattern   - The resource regexp pattern
    # ctype     - A content type, e.g., text/html
    # handler   - A content handler command
    # doc       - A doc string.
    #
    # Registers a resource type and its content handlers with the
    # server, so that it can be served.
    #
    # The rtype is an arbitrary string, but should mimic the url,
    # with placeholder names shown in curly brackets, e.g., "/data/{id}".
    #
    # The pattern is a regex that matches the path component of the
    # resource's URL.  It will be used as "^$pattern$" so that it matches 
    # the entire URL's path.  It should not begin with a "/".
    #
    # The doc string should describe the resource, and especially any
    # placeholders.  It will be used in the automatically generated
    # /urlhelp.
    #
    # The ctype is the content type.  Use standard content types
    # (e.g., text/html, text/plain) where possible; for Tcl formatted
    # data use "tcl/<name>" or "tk/<name>" where appropriate.
    #
    # The handler is a Tcl command that generates the content of the
    # give content type.  It will be called with two additional arguments,
    # the URL, and the name of an array of match parameters from the 
    # regex match.  Array values 0 contains the entire match; array
    # values 1 through 9 contain the first 9 submatches.
    #
    # The handler must either return the desired content, or throw a
    # NOTFOUND error.

    method register {rtype pattern args} {
        set doc  [lindex $args end]
        set args [lrange $args 0 end-1]

        if {$doc eq ""} {
            error "Missing doc string"
        }

        if {[llength $args] == 0} {
            error "No content types defined."
        }

        foreach {ctype handler} $args {
            if {[llength $handler] == 0} {
                error "Missing handler for content type \"$ctype\""
            }
        }

        dict set rinfo $rtype pattern $pattern
        dict set rinfo $rtype doc     $doc
        dict set rinfo $rtype ctypes  $args
    }
    

    # resources
    #
    # Returns a list of the resource types accepted by the server.

    method resources {} {
        return [dict keys $rinfo]
    }

    # ctypes rtype
    #
    # rtype   - A resource type
    #
    # Returns a list of the content types for each resource type.

    method ctypes {rtype} {
        return [dict keys [dict get $rinfo $rtype ctypes]]
    }

    # get url ?contentTypes?
    #
    # url         - The URL of the resource to get.
    # contentType - The list of accepted content types.  Wildcards are
    #               allowed, e.g., text/*, */*
    #
    # Retrieves the given resource, or throws an error.  If the 
    # contentTypes list is omitted, returns the resource's 
    # preferred content type (usually text/html); otherwise it returns
    # the first content type in contentTypes that matches an available
    # content type.  If there is none, throws NOTFOUND.
    #
    # Returns a dictionary:
    #
    #    url          - The URL
    #    contentType  - The returned content type
    #    content      - The returned content
    #
    # If the requested resource is not found, throws NOTFOUND.

    method get {url {contentTypes ""}} {
        # Gets the content for the URL, timing the result.
        set msec [lindex [time {
            set result [$self GetContent $url $contentTypes]
        } 1] 0]

        set ctype [dict get $result contentType]
        callwith $options(-logcmd) detail $self "msec $msec: $ctype $url"

        return $result
    }

    # GetContent url contentTypes
    #
    # url         - The URL of the resource to get.
    # contentType - The list of accepted content types.  Wildcards are
    #               allowed, e.g., text/*, */*
    #
    # Retrieves the given resource, or throws an error.  If the 
    # contentTypes list is omitted, returns the resource's 
    # preferred content type (usually text/html); otherwise it returns
    # the first content type in contentTypes that matches an available
    # content type.  If there is none, throws NOTFOUND.
    #
    # Returns a dictionary:
    #
    #    url          - The URL
    #    contentType  - The returned content type
    #    content      - The returned content
    #
    # If the requested resource is not found, throws NOTFOUND.

    method GetContent {url contentTypes} {
        # FIRST, parse the URL.  We will ignore the scheme and host.
        set u [uri::split $url]

        # NEXT, if the path isn't in this domain, NOTFOUND.  This shouldn't
        # happen, but might during transition.
        set path [dict get $u path]

        if {[string first $options(-domain) /$path] == -1} {
            throw NOTFOUND "URL incorrectly sent to this domain."
        }
        set suffix [string range $path [string length $options(-domain)] end]

        # NEXT, save the entire URL back in.
        dict set u suffix $suffix
        dict set u url    $url

        # NEXT, determine the resource type
        set rtype [$self GetResourceType $suffix match]

        # NEXT, strip any trailing "/" from the URL
        set url [string trimright $url "/"]

        # NEXT, get the content handler
        lassign [$self GetHandler $rtype $contentTypes] contentType handler

        if {$contentType eq ""} {
            return -code error -errorcode NOTFOUND \
                "Content-type unavailable: $contentTypes"
        }

        return [dict create \
                    url         $url                     \
                    content     [{*}$handler $u match] \
                    contentType $contentType]
    }

    # GetResourceType suffix matchArray
    #
    # suffix      - A resource suffix
    # matchArray  - An array of matches from the pattern.  Up to 3
    #               substrings can be matched.
    #
    # Returns the resource type key from $rinfo, or throws NOTFOUND.

    method GetResourceType {suffix matchArray} {
        upvar 1 $matchArray match

        # FIRST, is it cached?
        if {[info exists rtypeCache($suffix)]} {
            lassign $rtypeCache($suffix) rtype matchDict
            array set match $matchDict
            return $rtype
        }

        # NEXT, look it up and cache it.
        dict for {rtype rdict} $rinfo {
            # FIRST, does it match?
            set pattern [dict get $rdict pattern]

            set matched [regexp ^$pattern\$ $suffix \
                             match(0) match(1) match(2) match(3) match(4)  \
                             match(5) match(6) match(7) match(8) match(9)]

            if {$matched} {
                set rtypeCache($suffix) [list $rtype [array get match]]

                return $rtype
            }
        }

        return -code error -errorcode NOTFOUND \
            "Resource not found or not compatible with this application."
    }

    # GetHandler rtype contentTypes
    #
    # rtype        - The resource type
    # contentTypes - The accepted content types
    #
    # Returns a pair, the content type and the handler; or the empty
    # string if no matching handler is found.

    method GetHandler {rtype contentTypes} {
        dict with rinfo $rtype {
            if {[llength $contentTypes] == 0} {
                set contentType [lindex [dict keys $ctypes] 0]
                set handler [dict get $ctypes $contentType]

                return [list $contentType $handler]
            } else {
                foreach cpat $contentTypes {
                    dict for {ctype handler} $ctypes {
                        if {[string match $cpat $ctype]} {
                            return [list $ctype $handler]
                        }
                    }
                }
            }
        }
    }


    #===================================================================
    # Content Routines
    #
    # The following code relates to particular resources or kinds
    # of content.

    #-------------------------------------------------------------------
    # Server Introspection

    # html_UrlHelp udict matchArray
    #
    # udict      - The /urlhelp URL dictionary
    # matchArray - Array of pattern matches
    # 
    # Produces an HTML page detailing one or all of the URLs
    # understood by this server.  Match parm (1) is either empty
    # or a URL for which help is requested.

    method html_UrlHelp {udict matchArray} {
        upvar 1 $matchArray ""

        # FIRST, get the list of rtypes to document.
        if {$(1) eq ""} {
            set rtypes [dict keys $rinfo]
            set title "URL Schema Help"
        } else {
            set rtypes [list [$self GetResourceType $(1) dummy]]
            set title "URL Schema Help: /$(1)"
        }

        # NEXT, format the output.
        set trans [list \{ <i> \} </i>]

        $ht page $title
        $ht h1 $title
        $ht putln <dl>

        foreach rtype $rtypes {
            set doc [string map $trans [dict get $rinfo $rtype doc]]
            set ctypes [dict keys [dict get $rinfo $rtype ctypes]]
            set rtype [string map $trans $rtype]

            $ht putln <dt><b>$rtype</b></dt>
            $ht putln <dd>$doc ([join $ctypes {, }])<p>
        }

        $ht putln </dl>
        $ht /page

        return [$ht get]
    }
}

