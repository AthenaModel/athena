#-----------------------------------------------------------------------
# TITLE:
#    debug.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    ahttpd(n): Server Debugging
#
#    Application-direct URLs to help debug the server.
#    Tcl procedures of the form Debug/hello implement URLS
#    of the form /debug/hello
#
#    Copyright (c) 1998-2000 by Ajuba Solutions.
#    Will Duquette (c) 2015 California Institute of Technology
#
#    See the file "license.terms" for information on usage and 
#    redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
#-----------------------------------------------------------------------

snit::type ::ahttpd::debug {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Public Type Methods
    
    # init url
    #
    # url   - The URL prefix
    #
    # Use this to register the URL prefix that corresponds to
    # the debug URLs implemented by this module.

    typemethod init {url} {
        direct url $url ::ahttpd::debug::Debug
    }

    #-------------------------------------------------------------------
    # Debug URL handlers
    


    # Debug/source source=<file.tcl>
    #
    # source - The file to source
    #
    # Source the file into a server thread.  First look for the file to
    # source in the dir specified by Httpd(library).  If not found, use the
    # dir in Config(lib).
    #
    # Returns HTML code that displays result of loading the file.

    proc Debug/source {source} {
        global Httpd Config
        set source [file tail $source]

        set dirlist $Httpd(library)

        if {[info exists Config(library)]} {
            lappend dirlist $Config(library)
        }
        if {[info exists Config(lib)]} {
            lappend dirlist $Config(lib)
        }
        foreach dir $dirlist {
            set file [file join $dir $source]
            if {[file exists $file]} {
                break
            }
        }

        if {![file exists $file]} {
            set html "<h1>Error sourcing $source</h1>"
            append html "Cannot find it in <br>[join $dirlist <br>]"
            return $html
        }
          
        set html "<title>Source $source</title>\n"

        try {
            set result [uplevel #0 [list source $file]]
        } on error {error} {
            global errorInfo
            append html "<H1>Error in $source</H1>\n"
            append html "<pre>$result<p>$errorInfo</pre>"
            return $html
        }

        append html "<H1>Reloaded $source</H1>\n"
        append html "<pre>$result</pre>"
        return $html
    }

    # Debug/package name=<name>
    #
    # name  - the package to reload.
    #
    # Forget, delete, and the reload a package into the server.
    # Returns HTML code that displays the result of reloading the package.

    proc Debug/package {name} {
        try {
            package forget $name
            catch {namespace delete $name}
            set result [package require $name]
        } on error {result} {
            return "<title>Error</title>
            <H1>Error Reloading Package $name</H1>

            Unable to reload package \"$name\" due to:
            <PRE>
            $result
            </PRE>
        "
        }

        return "<title>Package reloaded</title>
            <H1>Reloaded Package $name</H1>
            Version $result of package \"$name\" has been (re)loaded.
        "
    }
     
    # Debug/pvalue aname=<pattern>
    #
    # aname   - the (fully qualified) glob pattern to match against existing
    #           arrays and variables.
    #
    # Generate HTML code that displays the contents of all existing arrays
    # and variables that match the glob pattern.

    proc Debug/pvalue {aname} {
        set html "<title>$aname</title>\n"
        append html [DebugValue $aname]
        return $html
    }

    proc DebugValue {aname} {
        upvar #0 $aname var
        append html "<p><b><font size=+=>$aname</font></b><br>\n"
        if {[array exists var]} {
            global $aname
            append html "<pre>[parray $aname]</pre>"
        } elseif {[info exists var]} {
            append html "<pre>[list set $aname $var]</pre>"
        } else {
            # Undefined variable - see if it is a pattern.
            # Be careful about declared but undefined procedures
            # that used to blow the recursion stack here...

            set list [lsort [uplevel #0 [list info vars $aname]]]
            if {[llength $list] == 1 &&
                [string compare [lindex $list 0] $aname] == 0
            } {
                append html "<pre># $aname undefined</pre>"
            } else {
                append html "<ul>"
                foreach n $list {
                    append html [DebugValue $n]
                }
                append html "</ul>"
            }
        }
        return $html
    }

    # Debug/parray aname=<arrayvar>
    #
    # aname   - the name of the array whose contents will appear.
    #
    # Generate HTML code that displays the content of a specific array
    # variable. 

    proc Debug/parray {aname} {
        global $aname
        set html "<title>Array $aname</title>\n"
        append html "<H1>Array $aname</H1>\n"
        append html "<pre>[parray $aname]</pre>"
        return $html
    }

    # Debug/raise ?args?
    #
    # args   - (optional) the error string to throw.
    #
    # Throw the Tcl error specified by args to be thrown.

    proc Debug/raise {args} {
        error $args
    }

    # Debug/goof
    #
    # Throw the Tcl error: "can't read "goof": no
    # such variable".

    proc Debug/goof {} {
        set goof
        return
    }

    # Debug/after
    #
    # Generate HTML code that displays info regarding after events existing
    # on the server.

    proc Debug/after {} {
        global tcl_version
        set html "<title>After Queue</title>\n"
        append html "<H1>After Queue</H1>\n"
        append html "<pre>"

        foreach a [after info] {
            append html "$a [after info $a]\n"
        }
        append html </pre>
        return $html
    }

    # Debug/echo title=<title> args...
    #
    # title  - (optional) title to display
    # args   - an even number of attrbutes and values to be displayed.
    #
    # Generate HTML code that displays the attributes and values posted to
    # the URL.

    proc Debug/echo {title args} {
        set html "<title>$title</title>\n"
        append html "<H1>$title</H1>\n"
        append html "<table border=1>\n"
        foreach {name value} $args {
            append html "<tr><td>$name</td><td>$value</td></tr>\n"
        }
        append html </table>
        return $html
    }

    # Debug/showproc proc=<proc>
    #
    # proc   - the name of the procedure.
    #
    # Generate HTML code that displays the args and body of a proc.
    #
    # TBD: Should use "getcode" (or whatever it's called these days)

    proc Debug/showproc {proc} {
        global Debug/showproc
        set Debug/showproc text/plain

        set alist ""
        foreach arg [info args $proc] {
            if {[info default $proc $arg default]} {
                set arg [list $arg $default]
            }
            lappend alist $arg
        }
        return [list proc $proc $alist [info body $proc]]
    }

    # Debug/disable
    #
    # Disable debugging in tclhttpd.  Removes the /debug URL.

    proc Debug/disable {} {
        direct remove Debug
        return "<title>Debugging disabled</title>\n
                        <h1> Debugging disabled</h1>"
    }  

}

