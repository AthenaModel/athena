#-----------------------------------------------------------------------
# TITLE:
#    cookie.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    ahttpd(n): Cookie Support.
#
#    Stephen Uhler / Brent Welch (c) 1997-1998 Sun Microsystems
#    Brent Welch (c) 1998-2000 Ajuba Solutions
#    Will Duquette (c) 2015 California Institute of Technology
#
#    See the file "license.terms" for information on usage and 
#    redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# TBD:
#    Cookies are currently stored in a global "Cookie" array.  I've
#    retained this because the "save" call will retrieve data from
#    the Cookie array in a specific interpreter.  Until I understand
#    how the Cookie array is propagated I can't clean it up.
#
#    It appears that the Cookie array is NEVER populated in the 
#    alternate interpreters, unless client domain code populates it
#    directly.  The only code that uses [cookie save] with an interp
#    is in the template module; conceivably a template could populate
#    the Cookie array.
#
#-----------------------------------------------------------------------

snit::type ::ahttpd::cookie {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Public Type Methods

    # save sock ?interp?
    #
    # sock    - The request socket
    # interp  - The interp in which to subst
    #
    # instruct httpd to return cookies, if any, to the browser

    typemethod save {sock {interp {}}} {
        global Cookie ;# TBD: This should have no effect.

        if {![catch {
            interp eval $interp {uplevel #0 {set Cookie(set-cookie)}}
        } cookie]} {
            foreach c $cookie {
                httpd setCookie $sock $c
            }
            interp eval $interp {uplevel #0 {unset Cookie(set-cookie)}}
        }
    }

    # getsock sock cookie
    #
    # sock    - A handle on the socket connection
    # cookie  - The name of the cookie (the key)
    #
    # Return a list of cookie values, if present, else "".
    # It is possible for multiple cookies with the same key
    # to be present, so we return a list.

    typemethod getsock {sock cookie} {
        upvar #0 ::ahttpd::Httpd$sock data
        set result ""
        set rawcookie ""

        if {[info exist data(mime,cookie)]} {
            set rawcookie $data(mime,cookie)
        }

        foreach pair [split $rawcookie \;] {
            lassign [split [string trim $pair] =] key value
            if {[string compare $cookie $key] == 0} {
                lappend result $value
            }
        }

        return $result
    }

    # make options...
    #
    # Make and return a formatted cookie from option/value pairs:
    #
    # Options:
    #   -name     - Cookie name
    #   -value    - Cookie value
    #   -path     - Path restriction
    #   -domain   - domain restriction
    #   -expires  - Time restriction
    #   -secure   - Security flag

    typemethod make {args} {
        array set opt $args
        set line "$opt(-name)=$opt(-value) ;"

        foreach extra {path domain} {
            if {[info exist opt(-$extra)]} {
                append line " $extra=$opt(-$extra) ;"
            }
        }

        if {[info exist opt(-expires)]} {
            switch -glob -- $opt(-expires) {
                *GMT {
                    set expires $opt(-expires)
                }
                default {
                    set expires [clock format [clock scan $opt(-expires)] \
                        -format "%A, %d-%b-%Y %H:%M:%S GMT" -gmt 1]
                }
            }
            append line " expires=$expires ;"
        }

        if {[info exist opt(-secure)]} {
            append line " secure "
        }

        return $line
    }


    # set ?options...?
    #
    # Set a return cookie.  The options are as for "make".

    typemethod set {args} {
        global Cookie
        lappend Cookie(set-cookie) [$type make {*}$args]
    }


    # unset name args
    #
    # name - The cookie name
    # args - Unused.
    #
    # Unset a return cookie

    typemethod unset {name args} {
        # TBD: previously passed "name" rather than "$name", which
        # looks like a mistake.
        httpd RemoveCookies [httpd currentSocket] $name
        $type set -name $name -value "" \
            -expires [clock format [clock scan "last year"] -format "%A, %d-%b-%Y %H:%M:%S GMT" -gmt 1]
    }
}

