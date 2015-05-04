#-----------------------------------------------------------------------
# TITLE:
#    myagent.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    my: URL user agent.
#
#    This module defines the myagent type, which is a user agent
#    for retrieving "my:" URLs from the application.
#
# URL SYNTAX:
#    The URL syntax for "my:" URLs is the same as for http, except that 
#    many fields (host, username, port, etc.) are ignored.
#
# MY DOMAINS:
#    mydomain(n) defines handlers for domains, where a domain is a
#    top-level "folder" on the application's "my:" file system.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export myagent
}

#-----------------------------------------------------------------------
# scenario

snit::type ::projectlib::myagent {
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        namespace import ::marsutil::*

        # Register the "my" scheme with uri(n).  It simply copies
        # the HTTP code.

        uri::register my {
            # FIRST, copy the http regex variables
            foreach var [info vars ::uri::http::*] {
                set [namespace tail $var] [set $var]
            }

            # NEXT, define the join and split routines.
            proc ::uri::JoinMy {args} {
                ::uri::JoinHttpInner my {} {*}$args
            }

            proc ::uri::SplitMy {url} {
                ::uri::SplitHttp $url
            }
        }

        # NEXT, register the gui: scheme with uri(n).
        # TBD: This doesn't really belong here, but I'm not sure
        # where else to put it.
        uri::register gui {
            # FIRST, copy the http regex variables
            foreach var [info vars ::uri::http::*] {
                set [namespace tail $var] [set $var]
            }

            # NEXT, define the join and split routines.
            proc ::uri::JoinGui {args} {
                ::uri::JoinHttpInner gui {} {*}$args
            }

            proc ::uri::SplitGui {url} {
                ::uri::SplitHttp $url
            }
        }
    }

    #-------------------------------------------------------------------
    # Type Variables

    # servers: array of mydomain domain handler objects by domain name
    typevariable domains -array {}

    #-------------------------------------------------------------------
    # Type Methods

    # register handler
    #
    # handler  - A mydomain(i) object, e.g., "::appdomain"
    #
    # Registers a handler so that myagent knows how to query it.

    typemethod register {handler} {
        set domains([$handler domain]) $handler
    }

    # resolve base url
    #
    # base   - A base url, e.g., /app/foo
    # url    - A relative url, e.g., bar/baz or #subsection
    #
    # Resolves the base and url into a single URL and returns it.

    typemethod resolve {base url} {
        # FIRST, if there's no URL given, just return the base.
        if {$url eq ""} {
            return [file join $base]
        }

        # NEXT, if the url has a scheme or begins with "/", just return
        # it.
        if {[regexp {^([a-z]+:)|(^/)} $url]} {
            return [file join $url]
        }

        # NEXT, if the url begins with "#" or "?" it can just be appended
        # to the base.
        if {[string index $url 0] in {"#" "?"}} {
            return "$base$url"
        }

        # NEXT, we can just join them using file join.
        return [file join $base $url]
    }

    #-------------------------------------------------------------------
    # Options

    # -contenttypes
    #
    # List of content types accepted by this client.  Defaults to
    # */*.

    option -contenttypes \
        -default {*/*}

    #-------------------------------------------------------------------
    # Constructor
    
    constructor {args} {
        $self configurelist $args
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method resolve using {::projectlib::myagent %m}

    # find url
    #
    # url   - A URL
    #
    # Validates and canonicalizes the URL.  Returns a pair, 
    # {domain url}.

    method find {url} {
        # FIRST, parse the URL and validate.
        try {
            array set fields [uri::split $url my]           
        } on error {result} {
            throw NOTFOUND \
                "Error in URL: $result"
        }

        if {$fields(scheme) ne "my"} {
            throw NOTFOUND \
                "Error in URL: unsupported scheme '$fields(scheme)' in '$url'"
        }

        if {$fields(host) ne ""} {
            throw NOTFOUND \
                "Error in URL: unsupported host '$fields(host)' in '$url'"
        }

        # NEXT, get rid of other irrelevant bits, should they happen
        # to be set.
        unset -nocomplain fields(port)
        unset -nocomplain fields(user)
        unset -nocomplain fields(pwd)
        unset -nocomplain fields(fragment)

        # NEXT, extract the domain, which is the first component of the
        # path.
        set domain /[lindex [split $fields(path) /] 0]

        if {![info exists domains($domain)]} {
            throw NOTFOUND \
                "Error in URL: unsupported domain '$domain' in '$url'"
        }

        # NEXT, canonicalize
        set finalURL [uri::canonicalize [uri::join {*}[array get fields]]]

        return [list $domain $finalURL]
    }

    # get url ?contentTypes?
    #
    # url          - The URL to retrieve
    # contentTypes - Desired content types; defaults to -contenttypes.
    #
    # Attempts to retrieve the URL, which must have scheme "my" or no
    # scheme at all.  We use uri::split for convenience, but we don't
    # really mean it.

    method get {url {contentTypes ""}} {
        # FIRST, parse the URL and validate.
        lassign [$self find $url] domain url

        # NEXT, get the list of desired content types.
        if {[llength $contentTypes] == 0} {
            set contentTypes $options(-contenttypes)
        }

        # NEXT, do the query

        return [{*}$domains($domain) get $url $contentTypes]
    }
}
