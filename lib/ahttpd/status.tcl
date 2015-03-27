#-----------------------------------------------------------------------
# TITLE:
#    status.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    ahttpd(n): Server Status
#
#    Application-direct URLs to give out status of the server.
#    Tcl procedures of the form Status/hello implement URLS
#    of the form /status/hello
#
#    Brent Welch (c) Copyright 1997 Sun Microsystems, Inc.
#    Brent Welch (c) 1998-2000 Ajuba Solutions
#    Will Duquette (c) 2015 California Institute of Technology
#
#    See the file "license.terms" for information on usage and 
#    redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
#-----------------------------------------------------------------------

snit::type ::ahttpd::status {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # info array
    #
    # server  - The server name, i.e., ahttpd(n)
    # url     - URL prefix for status pages
    # images  - URL prefix for images

    typevariable info -array {
        server ahttpd(n)
        url    /status
        images /images
    }

    #-------------------------------------------------------------------
    # Public Typemethods

    # init ?options?
    #
    # -url dir      - The prefix URL for the status pages.  Defaults to
    #                 "/status".
    # -images dir   - The prefix URL for the images used by the status
    #                 pages.  Defaults to "/images".
    # -server name  - The server software name.  Defaults to ahttpd(n).

    typemethod init {args} {
        foroption opt args -all {
            -url    { set info(url)    [lshift args] }
            -images { set info(images) [lshift args] }
            -server { set info(server) [lshift args] }
        }

        ::ahttpd::direct url $info(url) ::ahttpd::status::Status
    }


    #===================================================================
    # Direct URL handlers


    #-------------------------------------------------------------------
    # Main Page
    
    # Status
    #
    # Same as Status/all; returns main status page.

    proc Status {args} {
        Status/all {*}$args
    }

    # Status/
    #
    # Same as Status/all; returns main status page.

    proc Status/ {args} {
        Status/all {*}$args
    }

    # Status/all
    #
    # Show the page hist per minute, hour, and day using images.
    #
    # TBD: Should be able to configure some of the boilerplate.
    # Ultimately, revise to use htools.

    proc Status/all {args} {
        set html    [StatusHeader "$info(server) Status"]
        append html [StatusMenu]
        append html [AthenaLogo left]
        append html [StatusMainTable]
        append html "<br><a href=/status/text>Text only view.</a>\n"

        append html "<p>\n<table border=0 cellpadding=0 cellspacing=0>\n"
        append html [counter::histHtmlDisplayRow serviceTime \
            -title "Service Time" -unit seconds \
            -width 1 -skip 10 -min 0 -max 400 \
            -images $info(images)]

        append html [counter::histHtmlDisplayRow urlhits \
            -title "Url Hits" -unit minutes \
            -min 0 -max 60 \
            -images $info(images)]

        append html [counter::histHtmlDisplayRow urlhits \
            -title "Url Hits" -unit hours \
            -min 0 -max 24 \
            -images $info(images)]

        append html [counter::histHtmlDisplayRow urlhits \
            -title "Url Hits" -unit days \
            -images $info(images)]
        
        append html </table>
        return $html
    }

    # Status/text
    #
    # Show the page hist per minute, hour, and day in text format.

    proc Status/text {args} {
        set html    [StatusHeader "$info(server) Status"]
        append html [StatusMenu]
        append html [AthenaLogo left]
        append html [StatusMainTable]
        append html "<p><a href=$info(url)/all>Bar Chart View.</a>"
        catch {
        append html [counter::histHtmlDisplay serviceTime \
            -title "Service Time" -unit seconds -max 100 -text 1]
        }
        catch {
        append html [counter::histHtmlDisplay urlhits \
            -title "Per Minute Url Hits" -unit minutes -text 1]
        append html [counter::histHtmlDisplay urlhits \
            -title "Hourly Url Hits" -unit hours -text 1]
        append html [counter::histHtmlDisplay urlhits \
            -title "Daily Url Hits" -unit days -text 1]
        }
        return $html
    }


    # StatusHeader title
    #
    # title - also used as <h1>
    # 
    # Returns standard HTML header for status pages.

    proc StatusHeader {title} {
        return "<html><head>
            <title>$title</title>
            </head>
            <body bgcolor=white text=black>
            <h1>$title</h1>
        "
    }

    # StatusMenu
    #
    # Returns menu "link bar" across the top of the page.
    proc StatusMenu {} {
        set sep ""
        set html "<p>\n"
        foreach {url label} [list \
            /                    "Home" \
            $info(url)/          "Graphical Status" \
            $info(url)/text      "Text Status" \
            $info(url)/domain    "Domains" \
            $info(url)/doc       "Documents" \
            $info(url)/notfound  "Not Found"
        ] {
            append html "$sep<a href=$url>$label</a>\n"
            set sep " | "
        }
        append html "</p>\n"
        return $html
    }

   proc AthenaLogo {{align left}} {
        global _status
        set html "<img src=$info(images)/Athena_logo_small.png align=$align>\n"
    }

    # StatusMainTable
    #
    # Display the main status counters.

    proc StatusMainTable {} {
        global Httpd Doc status tcl_patchLevel tcl_platform

        set html "<H1>$Httpd(name):$Httpd(port)</h1>\n"
        append html "<H2>Server Info</h2>"
        append html "<table border=0>"
        append html "<tr><td>Start Time:</td><td>[clock format [stats starttime]]</td></tr>\n"
        append html "<tr><td>Current Time:</td><td>[clock format [clock seconds]]</td></tr>\n"
        append html "<tr><td>Server:</td><td>$Httpd(server)</td></tr>\n"
        append html "<tr><td>Tcl Version:</td><td>$tcl_patchLevel</td></tr>"

        switch $tcl_platform(platform) {
            unix {
                append html "<tr><td>Platform:</td><td>[exec uname -a]</td></tr>"
            }
            macintosh -
            windows  {
                append html "<tr><td>Platform:</td><td>$tcl_platform(os) $tcl_platform(osVersion)</td></tr>"
            }
        }

        append html </table>

        append html "<br><br><br>\n"

        append html "<p>[StatusTable]<p>\n"

        return $html
    }

    proc StatusTable {} {
        append html "<table bgcolor=#eeeeee>\n"

        set hit 0

        foreach {c label} {
            / "Home Page Hits"
        } {
            set N [counter::get hit -hist $c]
            if {$N > 0} {
                append html "<tr><td>$label</td><td>$N</td>\n"
                set hit 1
                append html </tr>\n
            }
        }

        foreach {c label} {
            urlhits      "URL Requests"
            UrlDispatch  "URL Dispatch"
            UrlToThread  "Thread Dispatch"
            UrlEval      "Direct Dispatch"
            UrlCacheHit  "UrlCache eval"
            urlreply     "URL Replies"
            accepts      "Total Connections"
            accept_https "HTTPS Connections"
            keepalive    "KeepAlive Requests"
            http1.0      "OneShot Connections"
            http1.1      "Http1.1 Connections"
            threads      "Worker Threads"
            sockets      "Open Sockets"
            cgihits      "CGI Hits"
            tclhits      "Tcl Safe-CGIO Hits"
            maphits      "Image Map Hits"
            cancel       "Timeouts"
            notfound     "Not Found"
            errors       "Errors"
            Status       "Status"
        } {
            if {[counter::exists $c]} {
                set t [counter::get $c -total]
                if {$t > 0} {
                    append html "<tr><td>$label</td><td>$t</td>\n"
                    set hit 1
                    set resetDate [counter::get $c -resetDate]
                    if {[string length $resetDate]} {
                        append html "<td>[clock format $resetDate -format "%B %d, %Y"]</td>"
                    }
                    append html </tr>\n
                }
            }
        }

        if {!$hit} {
            foreach c [counter::get "" -allTagNames] {
                append html "<tr><td>$name</td><td>[counter::get $c -total]</td>\n"
                set resetDate [counter::get $c -resetDate]
                if {[string length $resetDate]} {
                    append html "<td>[clock format $resetDate -format "%B %d, %Y"]</td>"
                }
                append html </tr>\n
            }
        }
        append html </table>\n

        return $html
    }


    #-------------------------------------------------------------------
    # Domain status
    
    # Status/domain pattern=<pattern> sort=???
    #
    # pattern - (optional) the glob pattern of the domain to report on.
    # sort    - (optional) how to sort the output.  If the default "number" is
    #           not given, output is sorted by url alphabetically.
    #
    # Show the number of hits for documents in different domains.

    proc Status/domain {{pattern *} {sort number}} {
        set result ""
        append result [StatusHeader "Domain Hits"]
        append result [StatusMenu]
        append result [StatusSortForm $info(url)/domain "Hit Count" $pattern $sort]
        append result [StatusPrintArray [counter::get domainHit -histVar] * $sort Hits Domain]
    }

    # StatusSortForm action label ?pattern? ?sort?
    #
    # action  - The form action (i.e., a URL to go to)
    # pattern - The pattern to filter by
    # sort    - number|name

    proc StatusSortForm {action label {pattern *} {sort number}} {
        if {[string compare $sort "number"] == 0} {
            set numcheck checked
            set namecheck ""
        } else {
            set numcheck ""
            set namecheck checked
        }
        append result "<form action=$action>"
        append result "Pattern <input type=text name=pattern value=$pattern><br>"
        append result "Sort by $label <input type=radio name=sort value=number $numcheck> or Name <input type=radio name=sort value=name $namecheck><br>"
        append result "<input type=submit name=submit value=\"Again\">"
        append result "</form>"
    }

    # StatusPrintArray
    #
    # Print an array of sorted stuff.

    proc StatusPrintArray {aname pattern sort col1 col2} {
        upvar #0 $aname a
        set result ""
        append result <pre>\n
        append result [format "%6s %s\n" $col1 $col2]
        set list {}
        set total 0

        foreach name [lsort [array names a $pattern]] {
            set value $a($name)
            lappend list [list $value $name]
            incr total $value
        }

        if {[string compare $sort "number"] == 0} {
            if [catch {lsort -index 0 -integer -decreasing $list} newlist] {
                set newlist [lsort -command [myproc StatusSort] $list]
            }
        } else {
            if [catch {lsort -index 1 -integer -decreasing $list} newlist] {
                set newlist [lsort -command [myproc StatusSortName] $list]
            }
        }

        append result [format "%6d %s\n" $total Total]
        
        foreach k $newlist {
            set url [lindex $k 1]
            append result [format "%6d %s\n" [lindex $k 0] $url]
        }
        append result </pre>\n
        return $result
    }

    proc StatusSort {a b} {
        set 1 [lindex $a 0]
        set 2 [lindex $b 0]

        if {$1 == $2} {
            return [string compare $a $b]
        } elseif {$1 < $2} {
            return 1
        } else {
            return -1
        }
    }

    proc StatusSortName {a b} {
        set 1 [lindex $a 1]
        set 2 [lindex $b 1]
        return [string compare $1 $2]
    }

    #-------------------------------------------------------------------
    # Hits on Documents.
    

    # Status/doc pattern=<pattern> sort=???
    #
    # pattern - (optional) the glob pattern of the domain to report on.
    # sort    - (optional) how to sort the output.  If the default "number" is
    #           not given, output is sorted by url alphabetically.
    #
    # Show the number of hits for documents matching the pattern.

    proc Status/doc {{pattern *} {sort number}} {
        set result ""
        append result [StatusHeader "Document Hits"]
        append result [StatusMenu]
        append result [StatusSortForm $info(url)/doc "Hit Count" $pattern $sort]
        append result [StatusPrintArray [counter::get hit -histVar] * $sort Hits Url]
    }

    #-------------------------------------------------------------------
    # Documents not found
    

    # Status/notfound pattern=<pattern> sort=???
    #
    # pattern - (optional) the glob pattern of the domain to report on.
    # sort    - (optional) how to sort the output.  If the default "number" is
    #           not given, output is sorted by url alphabetically.
    #
    # Show the number of hits for nonexistent documents matching the pattern.

    proc Status/notfound {{pattern *} {sort number}} {
        set result ""
        append result [StatusHeader "Documents Not Found"]
        append result [StatusMenu]
        append result [StatusSortForm $info(url)/notfound "Hit Count" $pattern $sort]
        append result [StatusPrintNotFound $pattern $sort]
    }

    # TBD: This output is ugly; clean it up.
    proc StatusPrintNotFound {{pattern *} {sort number}} {
        # TBD: Clean up Referer
        global Referer

        upvar #0 [counter::get notfound -histVar] histogram
        append result <pre>\n
        append result [format "%6s %s\n" Miss Url]
        set list {}
        foreach i [lsort [array names histogram $pattern]] {
            lappend list [list $histogram($i) $i]
        }

        if [catch {lsort -index 0 -integer -decreasing $list} newlist] {
            set newlist [lsort -command [myproc StatusSort] $list]
        }

        foreach k $newlist {
            set url [lindex $k 1]
            append result [format "%6d <a href=%s>%s</a>\n" \
                [lindex $k 0] [lindex $k 1] [lindex $k 1]]
            if {[info exists Referer($url)]} {
                set i 0
                append result <ul>
                foreach r $Referer($url) {
                    append result "<li> <a href=\"$r\">$r</a>\n"
                }
                append result </ul>\n
            }
        }
        append result </pre>\n
        append result "<a href=$info(url)/notfound/reset>Reset counters</a>"
        return $result
    }

    # Status/notfound/reset
    #
    # Reset the number of hits for nonexistent documents to 0.
    # Returns HTML code that confirms that the reset occurred.

    proc Status/notfound/reset {args} {
        # TBD: Cleanup Referer
        global Referer
        counter::reset notfound
        catch {unset Referer}
        return [StatusHeader "Reset Notfound Counters"]
    }


 
    
}
