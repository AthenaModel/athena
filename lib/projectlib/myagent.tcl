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
#    many fields (username, port, etc.) are ignored.
#
# MY SERVERS:
#    A "my:" server is a server name registered with a Tcl command that
#    adheres to the myserver(i) interface.  The -defaultserver option
#    gives the name of the default server to use when no server is given
#    in the URL.
#
# RESOLUTION:
#    The myagent instance will automatically resolve relative addresses.
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

    # servers: array of server commands by server name
    typevariable servers -array {}

    #-------------------------------------------------------------------
    # Type Methods

    # register server command
    #
    # server   - A server name, e.g., "app"
    # command  - A myserver(i) object, e.g., "::appserver"
    #
    # Registers a server so that myagent knows how to query it.

    typemethod register {server command} {
        set servers($server) $command
    }

    # resolve base url
    #
    # base   - A base url, e.g., my://app/foo
    # url    - A relative url, e.g., bar/baz or /bar/baz
    #
    # Resolves the base and url into a single URL and returns it.
    #
    # This code is based on uri::resolve, but handles only my:// URLs.

    typemethod resolve {base url} {
        if {$url eq ""} {
            return $base
        }

        if {![uri::isrelative $url]} {
            return $url
        }

        array set baseparts [uri::split $base my]

        array set relparts [uri::split $url]

        if {[string match /* $url]} {
            catch { set baseparts(path) $relparts(path) }
        } elseif {[string match */ $baseparts(path)]} {
            set baseparts(path) "$baseparts(path)$relparts(path)"
        } else {
            if {[string length $relparts(path)] > 0} {
                set path [lreplace [::split $baseparts(path) /] end end]
                set baseparts(path) "[::join $path /]/$relparts(path)"
            }
        }
        catch { set baseparts(query) $relparts(query) }
        catch { set baseparts(fragment) $relparts(fragment) }
        return [uri::join {*}[array get baseparts]]
    }

    #-------------------------------------------------------------------
    # Options

    # -defaultserver
    #
    # The name of the default server; defaults to "app".  The default
    # server must be registered with "myagent register".

    option -defaultserver \
        -default app

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

    # Delegated methods
    delegate method join         using ::uri::join
    delegate method split        using ::uri::split
    delegate method canonicalize using ::uri::resolve
    delegate method isrelative   using ::uri::isrelative
    delegate method resolve      using {::projectlib::myagent %m}

    # get url ?contentTypes?
    #
    # url          - The URL to retrieve
    # contentTypes - Desired content types; defaults to -contenttypes.
    #
    # Attempts to retrieve the URL, which must have scheme "my".

    method get {url {contentTypes ""}} {
        # FIRST, parse the URL
        if {[catch {
            array set fields [uri::split $url my]
        } result]} {
            return -code error -errorcode NOTFOUND \
                "Error in URL: $result"
        }

        unset -nocomplain fields(port)
        unset -nocomplain fields(user)
        unset -nocomplain fields(pwd)
        unset -nocomplain fields(fragment)

        if {$fields(scheme) ne "my"} {
            return -code error -errorcode NOTFOUND \
                "Error in URL: unsupported scheme '$fields(scheme)' in '$url'"
        }

        # NEXT, get the server
        if {$fields(host) eq ""} {
            set fields(host) $options(-defaultserver)
        }

        if {![info exists servers($fields(host))]} {
            return -code error -errorcode NOTFOUND \
                "Server \"$fields(host)\" not found."
        }

        # NEXT, get the list of desired content types.
        if {[llength $contentTypes] == 0} {
            set contentTypes $options(-contenttypes)
        }

        # NEXT, do the query
        set finalURL [uri::canonicalize [uri::join {*}[array get fields]]]

        return [{*}$servers($fields(host)) get $finalURL $contentTypes]

        return $result
    }
}
