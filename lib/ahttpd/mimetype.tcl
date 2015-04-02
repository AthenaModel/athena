#-----------------------------------------------------------------------
# TITLE:
#    mimetype.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    ahttpd(n): MIME Types
#
#    Brent Welch (c) 1997 Sun Microsystems
#    Brent Welch (c) 1998-2000 Ajuba Solutions
#    Will Duquette (c) 2015 California Institute of Technology
#
#    See the file "license.terms" for information on usage and 
#    redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#-----------------------------------------------------------------------

snit::type ::ahttpd::mimetype {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    typevariable mimeTypes -array {}

    #-------------------------------------------------------------------
    # Type Constructor
    
    typeconstructor {
        $type readtypes [file join $::ahttpd::library mime.types]
    }

    #-------------------------------------------------------------------
    # Public Type Methods
    
    # frompath path
    #
    # path   - A file path
    #
    # Returns the mime type for the file, given its file extension.

    typemethod frompath {path} {
        set ext [string tolower [file extension $path]]
        if {[info exist mimeTypes($ext)]} {
            return $mimeTypes($ext)
        } else {
            return text/plain
        }
    }

    # add mtype extlist ?mtype extlist...?
    # add mappings
    #
    # mtype    - A MIME content-type
    # extlist  - A list of file extensions that map to it.
    #
    # Adds the mappings to the database.

    typemethod add {args} {
        if {[llength $args] eq 1} {
            set args [lindex $args 0]
        }

        foreach {mtype extlist} $args {
            foreach ext $extlist {
                set mimeTypes([string tolower $ext]) $mtype
            }
        }
    }

    # readtypes file
    #
    # file  - A mime.types file
    #
    # Initializes the lookup table with some defaults, and then loads
    # the file if possible.

    typemethod readtypes {file} {
        array set mimeTypes {
            {}  text/plain
            .txt    text/plain
            .htm    text/html
            .html   text/html
            .tml    application/x-tcl-template
            .gif    image/gif
            .thtml  application/x-safetcl
            .shtml  application/x-server-include
            .cgi    application/x-cgi
            .map    application/x-imagemap
            .subst  application/x-tcl-subst
        }

        if {[catch {open $file} in]} {
            return
        }

        while {[gets $in line] >= 0} {
            if {[regexp {^(  )*$} $line]} {
                continue
            }
            if {[regexp {^(  )*#} $line]} {
                continue
            }
            if {[regexp {([^     ]+)[    ]+(.+)$} $line match mtype rest]} {
                foreach item [split $rest] {
                    if {[string length $item]} {
                        set mimeTypes([string tolower .$item]) $mtype
                    }
                }
            }
        }
        close $in
    }

    # accept sock
    #
    # sock   - The socket connection
    #
    # Returns the Accept specification from the HTTP headers.
    # These are a list of MIME types that the browser favors.
    #
    # TBD: Is there any reason why this needs to be in this module?

    typemethod accept {sock} {
        # TBD: Need a better interface to Httpd data.
        upvar #0 ::ahttpd::Httpd$sock data
        if {![info exist data(mime,accept)]} {
            return */*
        } else {
            return $data(mime,accept)
        }
    }
}

