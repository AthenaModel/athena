#-----------------------------------------------------------------------
# TITLE:
#    dirlist.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    ahttpd(n): HTML-formatted directory listing
#
#    Steve Ball (c) 1997 Sun Microsystems
#    Brent Welch (c) 1998-2000 Ajuba Solutions
#    Will Duquette (c) 2015 California Institute of Technology
#
#    See the file "license.terms" for information on usage and 
#    redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
#-----------------------------------------------------------------------

snit::type ::ahttpd::dirlist {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # info array
    # 
    # hide       - If true, directory listings cannot be seen.
    # indexpat   - A glob pattern for index files in a directory.

    typevariable info -array {
        hide     0
        indexpat index.{tml,html,thtml,htm}
    }
    

    #-------------------------------------------------------------------
    # Public Type Methods
    
    # indexfile ?pattern?
    #
    # pattern - A glob pattern for index files in a directory.
    #
    # Queries and sets the index pattern for a directory.

    typemethod indexfile {{pattern ""}} {
        if {$pattern ne ""} {
            set info(indexpat) $pattern            
        }

        return $info(indexpat)
    }

    # handle prefix path suffix sock
    #
    # prefix  - The URL domain prefix.
    # path    - The file system pathname of the directory.
    # suffix  - The URL suffix.
    # sock    - The socket connection.
    #
    # Handle a directory.  Look for the index file, falling back to
    # the Directory Listing module, if necessary.  If the Directory
    # Listing is hidden, then give the not-found page.
    #

    typemethod handle {prefix path suffix sock} {
        upvar #0 ::ahttpd::Httpd$sock data
        global tcl_platform

        # Special case because glob doesn't work in wrapped files
        # Just set indexpat to "index.tml" or "index.html"

        set npath [file join $path $info(indexpat)]

        if {[info exist tcl_platform(isWrapped)] && $tcl_platform(isWrapped)} {
            set newest $npath
        } else {
            set newest [file_latest [glob -nocomplain $npath]]
        }

        if {[string length $newest]} {
            # Template hack.  Ask for the corresponding .html file in
            # case that file should be cached when running the template.
            # If we ask for the .tml directly then its result is never 
            # cached.

            set tmlext [template tmlext]

            if {$tmlext eq [file extension $newest]} {
                puts "Looking for newest"
                set newest [file root $newest]$tmlext
            }
            return [doc handle $prefix $newest $suffix $sock]
        }

        if {[$type hide]} {
            # Directory listings are hidden, so give the not-found page.
            return [doc notfound $sock]
        }
        # Listings are not hidden, so show it.
        httpd returnData $sock text/html [DirList $sock $path $data(url)]
    }


    # hide ?flag?
    #
    # flag - 1 to hide directory listings, and 0 otherwise.
    #
    # Sets and queries the directory listing flag.

    typemethod hide {{flag ""}} {
        if {$flag ne ""} {
            set info(hide) $flag
        }

        return $info(hide)
    }

    #-------------------------------------------------------------------
    # Directory List Formatting Commands
    

    proc DirListForm {dir urlpath {sort name} {pattern *}} {
        set what [DirListTerm]
        set namecheck ""
        set sizecheck ""
        set numcheck ""
        switch -- $sort {
            number {
                set numcheck checked
            }
            size {
                set sizecheck checked
            }
            default {
                set namecheck checked
            }
        }
        set listing "
    <H1>Listing of $what $urlpath</H1>

    <form action=$urlpath>
    Pattern <input type=text name=pattern value=$pattern><br>
    Sort by Modify Date <input type=radio name=sort value=number $numcheck>
    or Name <input type=radio name=sort value=name $namecheck>
    or Size <input type=radio name=sort value=size $sizecheck><br>
    <input type=submit name=submit value='Again'><p>
    "
        append listing [DirListInner $dir $urlpath $sort $pattern]
        append listing "</form>\n"
        return $listing
    }

    proc DirListInner {dir urlpath sort pattern} {
        set listing "<PRE>\n"
        set path [file split $dir]

        # Filter pattern to avoid leaking path information
        regsub -all {\.+/} $pattern {} pattern
        set pattern [string trimleft $pattern /]

        set list [glob -nocomplain -- [file join $dir $pattern]]
        if {[llength $path] > 1} {
            append listing \
                "<A HREF=\"..\">Up to parent [string tolower [DirListTerm]]</A>\n"
        }

        set timeformat "%b %e, %Y %X"
        if {[llength $list] > 0} {
            set max 0
            foreach entry $list {
                setmax max [string length [file tail $entry]]
            }
            incr max [string length </a>]

            # Resort the list into list2

            switch -- $sort {
                number {
                    set mlist {}
                    foreach entry $list {
                        lappend mlist [list $entry [file mtime $entry]]
                    }
                    if {[catch {lsort -decreasing -integer -index 1 $mlist} list2]} {
                        set list2 [lsort -command DateCompare $mlist]
                    }
                    set extra 1
                }
                size {
                    set slist {}
                    foreach entry $list {
                        lappend slist [list $entry [file size $entry]]
                    }
                    if {[catch {lsort -decreasing -integer -index 1 $slist} list2]} {
                        set list2 [lsort -command SizeCompare $slist]
                    }
                    set extra 1
                }
                default {
                    if {[catch {lsort -dict $list} list2]} {
                        set list2 [lsort -command DirlistCompare $list]
                    }
                    set extra 0
                }
            }

            # Loop through list2, which may have an extra sorting field we ignore

            foreach entry $list2 {
                if {$extra} {
                    set entry [lindex $entry 0]
                }
                file lstat $entry lst
                switch $lst(type) {
                    file {
                        # Should determine dingbat from file type
                        append listing "<A HREF=\"[DirHref $entry]\">[format %-*s $max [file tail $entry]</a>] [format %8d $lst(size)] [format %-5s bytes]  [clock format $lst(mtime) -format $timeformat]\n"
                    }
                    directory {
                        append listing "<A HREF=\"[DirHref $entry]/\">[format %-*s $max [file tail $entry]/</a>] [format %8s {}] [format %-5s dir]  [clock format $lst(mtime) -format $timeformat]\n"
                    }
                    link {
                        append listing "<A HREF=\"[DirHref $entry]\">[format %-*s $max [file tail $entry]</a>] [format %8s {}] [format %-5s link]  [clock format $lst(mtime) -format $timeformat] -> [file readlink $entry]\n"
                    }
                    characterSpecial -
                    blockSpecial -
                    fifo -
                    socket {
                        append listing "<A HREF=\"${urlpath}[file tail $entry]\">[format %-20s [file tail $entry]</a>] $lst(type)\n"
                    }
                }
            }
        } else {
            append listing "[DirListTerm] is empty\n"
        }
     
        append listing "
    </PRE>
    "
        return $listing
    }

    proc DirHref {entry} {
        set entry [url encode [file tail $entry]]
        # Decode ".",
        regsub -all -nocase {%2e} $entry . entry
        regsub -all -nocase {%5f} $entry _ entry
        return $entry
    }

    proc DirList {sock dir urlpath} {
        upvar #0 ::ahttpd::Httpd$sock data

        set sort name
        set pattern *
        if {[info exists data(query)]} {
            foreach {name value} [url decodequery $data(query)] {
                switch $name {
                    sort    {set sort $value}
                    pattern {set pattern $value}
                }
            }
        }

        return "
    <HTML>
    <HEAD>
        <TITLE>Listing of [DirListTerm] $urlpath</TITLE>
    </HEAD>
    <BODY>
        [DirListForm $dir $urlpath $sort $pattern]
    </BODY>
    </HTML>"
    }

    # DirlistCompare --
    #
    # Utility procedure for case-insensitive filename comparison.
    # Suitable for use with lsort
     
    proc DirlistCompare {a b} {
        string compare [string tolower $a] [string tolower $b]
    }
     

    proc DateCompare {a b} {
        set a [lindex $a 1]
        set b [lindex $b 1]
        if {$a > $b} {
            return -1
        } elseif {$a < $b} {
            return 1
        } else {
            return 0
        }
    }
     
    proc SizeCompare {a b} {
        set aa [lindex $a 1]
        set bb [lindex $b 1]
        set res [string compare $aa $bb]
        if { $res != 0 } {
            return $res
        } else {
            return [string compare $a $b]
        }
    }

    # DirListTerm --
    #
    # Return "Folder" or "Directory" as appropriate

    proc DirListTerm {} {
        global tcl_platform
     
        if [string compare macintosh $tcl_platform(platform)] {
            set what Directory
        } else {
            set what Folder
        }
        return $what
    }
}
 
    