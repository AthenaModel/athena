#-----------------------------------------------------------------------
# TITLE:
#    fallback.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    ahttpd(n): Fallback content negotation
#
#    Fallback does "content negotation" if a file isn't found,
#    looking around for files with different suffixes but the same root.
#
#    NOTE: This feature is probably more trouble than it is worth.
#    It was originally used to be able to choose between different
#    image types (e.g., .gif and .jpg), but is now also used to
#    find templates (.tml files) that correspond to .html files.
#
#    Stephen Uhler / Brent Welch (c) 1997-1998 Sun Microsystems
#    Brent Welch (c) 1998-2000 Ajuba Solutions
#    Will Duquette (c) 2015 California Institute of Technology
#
#    See the file "license.terms" for information on usage and 
#    redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
#-----------------------------------------------------------------------

snit::type ::ahttpd::fallback {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # info - Module info array
    #
    # excludePat - List of patterns for files to exclude when doing
    #              fallback matching.

    typevariable info -array {
        excludePat {*.bak *.swp *~}
    }
    
    #-------------------------------------------------------------------
    # Public Type Methods
    
    # exclude patlist
    #
    # patlist - A list of glob patterns of files to avoid when trying
    #           to find an alternative file.
    #
    # Set the file exclusion pattern list.

    typemethod exclude {patlist} {
        set info(excludePat) $patlist
    }

    # try prefix path suffix sock
    #
    # prefix  - The URL prefix of the domain.
    # path    - The pathname we were trying to find.
    # suffix  - The URL suffix.
    # sock    - The socket connection.
    #
    # This either triggers an HTTP redirect to switch the user
    # to the correct file name, or it calls out to the template-aware
    # text/html processor.
    #
    # Returns 0 on no fallback, 1 if a template is used, and "" otherwise.
    # TBD: Does this return value matter?

    typemethod try {prefix path suffix sock} {
        set root [file root $path]
        if {[string match */ $root]} {
            # Input is something like /a/b/.xyz
            return 0
        }

        # Here we look for files indicated by any Accept headers.
        # Most browsers say */*, but they may provide some ordering info, 
        # too.

        # First generate a list of candidate files by ignoring extension
        set ok {}
        foreach choice [glob -nocomplain $root.*] {
            # Filter on the exclude patterns, and make sure that we
            # don't let "foo.html.old" match for "foo.html"

            if {[string compare [file root $choice] $root] == 0 &&
                ![Exclude $choice]
            } {
                lappend ok $choice
            }
        }

        # Now we pick the best file from the ones that matched.
        set npath [Choose [mimetype accept $sock] $ok]
        if {[string length $npath] == 0 || [string compare $path $npath] == 0} {
            # not found or still trying one we cannot use
            return 0
        } else {
            # A file matched, but has a different extension to that requested

            # Another hack for templates.  If the requested .html is not found,
            # and the .tml exists, ask for .html so the template is
            # processed and cached as the .html file.
            if {[template tmlext] eq [file extension $npath]} {
                {*}[doc handler text/html] \
                    [file root $npath][template htmlext] $suffix $sock
                return 1
            }

            # No template matched the request, so redirect_to/offer our best match.
            # Redirect so we don't mask spelling errors like john.osterhoot

            set new [file extension $npath]
            set old [file extension $suffix]

            if {[string length $old] == 0} { 
                append suffix $new
            } else {
                # Watch out for specials in $old, like .html)

                regsub -all {[][$^|().*+?\\]} $old {\\&} old
                regsub $old\$ $suffix $new suffix
            }

            # Preserve query data when bouncing among pages.
            # TBD: Need better interface to Httpd$sock
            upvar #0 ::ahttpd::Httpd$sock data
            if {$prefix eq "/"} {
                set url $prefix[string trimleft $suffix /~]
            } else {
                set url $prefix/[string trimleft $suffix /~]
            }

            if {[info exist data(query)] && [string length $data(query)]} {
                append url ? $data(query)
            }

            redirect gotoself $url  ;# offer what we have to the client
        }
    }

    # Exclude filename
    #
    # name - The filename to filter.
    #
    # This is used to filter out files like "foo.bak"  and foo~
    # from the Fallback failover code.  Returns 1 if the file 
    # should be excluded, and 0 otherwise.

    proc Exclude {name} {
        foreach pat $info(excludePat) {
            if {[string match $pat $name]} {
                return 1
            }
        }
        return 0
    }

    # Choose accept choices
    #
    # accept   - The results of [mimetype accept]
    # choices  - The list of matching file names.
    #
    # Choose based first on the order of things in the Accept type list,
    # then on the newest file that matches a given accept pattern.
    #
    # Returns the name of the newest file whose mime type is most 
    # acceptable to the client browser.

    proc Choose {accept choices} {
        foreach t [split $accept ,] {
            regsub {;.*} $t {} t    ;# Nuke quality parameters
            set t [string trim [string tolower $t]]
            set hits {}
        
            foreach f $choices {
                set type [mimetype frompath $f]
                if {[string match $t $type]} {
                    lappend hits $f ;# this file provides a matching mime type
                }
            }
        
            set result [file_latest $hits]  ;# latest file matching mime type $t
        
            if {[string length $result]} {
                return $result
            }
        }
        return {}
    }
}


