#-----------------------------------------------------------------------
# TITLE:
#    utils.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    ahttpd(n): Utility Commands
#
#    This is much trimmed from the TclHTTPD set of commands.
#
#    Brent Welch (c) 1998-2000 Ajuba Solutions
#    Will Duquette (c) 2015 California Institute of Technology
#
#    See the file "license.terms" for information on usage and 
#    redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
#-----------------------------------------------------------------------

namespace eval ::ahttpd:: {}

# errputs string
#
# string - An error message
#
# Safely outputs the message to stderr.

proc ::ahttpd::errputs {string} {
    catch {puts stderr $string}
}

# iscommand name 
#
# name -  Possibly, a command name.
#
# Returns true if the command is defined.

proc ::ahttpd::iscommand {name} {
    expr {([string length [info command $name]] > 0)}
}

# escape html characters (simple version)

proc ::ahttpd::protect_text {text} {
    array set Map { < lt   > gt   & amp   \" quot}
    regsub -all {[\\$]} $text {\\&} text
    regsub -all {[><&"]} $text {\&$Map(&);} text
    subst -nocommands $text
}

# File_Reset - hack to close files after a leak has sprung
# TBD: Doesn't belong here.

proc ::ahttpd::File_Reset {} {
    for {set i 5} {$i <= 1025} {incr i} {
        if {! [catch {close file$i}]} {
            append result file$i\n
        }
    }
    for {set i 10} {$i <= 1025} {incr i} {
        if {! [catch {close sock$i}]} {
            append result sock$i\n
        }
    }
    ::ahttpd::log setfile
    return $result
}

# File_List - report which files are open.
# TBD: Doesn't belong here.
proc ::ahttpd::File_List {} {
    global OpenFiles
    for {set i 1} {$i <= 1025} {incr i} {
        if {! [catch {fconfigure file$i} conf]} {
            append result "file$i $conf\n"
            if {[info exist OpenFiles(file$i)]} {
                append result "file$i: $OpenFiles(file$i)\n"
            }
        }
        if {! [catch {fconfigure sock$i} conf]} {
            array set c {-peername {} -sockname {}}
            array set c $conf
            append result "sock$i $c(-peername) $c(-sockname)\n"
        }
    }
    return $result
}

# parray - version of parray that returns the result instead
# of printing it out.
# TBD: Rename

proc ::ahttpd::parray {aname {pat *}} {
    upvar $aname a
    set max 0
    foreach name [array names a $pat] {
        set max [expr {max($max,[string length $name])}]
    }

    if {$max == 0} {
        return {}
    }
    incr max [string length $aname]
    incr max 2
    set result {}
    foreach name [lsort [array names a $pat]] {
        append result [list ${aname}($name) = $a($name)]
        append result \n
    }
    return $result
}


# file_latest --
#
#   Return the newest file from the list.
#
# Arguments:
#   files   A list of filenames.
#
# Results:
#   None
#
# Side Effects:
#   The name of the newest file.

proc ::ahttpd::file_latest {files} {
    set newest {}
    foreach file $files {
        if {[file readable $file]} {
            set m [file mtime $file]
            if {![info exist mtime] || ($m > $mtime)} {
                set mtime $m
                set newest $file
            }
        }
    }
    return $newest
}



# Tcllib 1.6 has inconsistencies with md5 1.4.3 and 2.0.0,
# and requiring 1.0 cures later conflicts with 2.0
# we run with whatever version is available
# by making an aliased wrapper

if {[package vcompare [package present md5] 2.0] > -1} {
    # we have md5 v2 - it needs to be told to return hex
    interp alias {} ::ahttpd::md5hex {} ::md5::md5 --hex --
} else {
    # we have md5 v1 - it returns hex anyway
    interp alias {} ::ahttpd::md5hex {} ::md5::md5
}
