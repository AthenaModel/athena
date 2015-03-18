# utils.tcl
#
# Brent Welch (c) 1998-2000 Ajuba Solutions
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: utils.tcl,v 1.10 2004/05/27 01:25:19 coldstore Exp $

package provide httpd::utils 1.0

# Stderr - print to standard error

proc Stderr {string} {
    catch {puts stderr $string}
}

# iscommand - returns true if the command is defined  or lives in auto_index.

proc iscommand {name} {
    expr {([string length [info command $name]] > 0) || [auto_load $name]}
}

# lappendOnce - add to a list if not already there
# TBD: replace with ladd

proc lappendOnce {listName value} {
    upvar $listName list
    if ![info exists list] {
    lappend list $value
    } else {
    set ix [lsearch $list $value]
    if {$ix < 0} {
        lappend list $value
    }
    }
}

# setmax - set the variable to the maximum of its current value
# or the value of the second argument
# return 1 if the variable's value was changed.
# TBD: Refactor out
proc setmax {varName value} {
    upvar $varName var
    if {![info exists var] || ($value > $var)} {
    set var $value
    return 1
    } 
    return 0
}


# Delete a list item by value.  Returns 1 if the item was present, else 0
# TBD: refactor out of thread.tcl

proc ldelete {varList value} {
    upvar $varList list
    if ![info exist list] {
    return 0
    }
    set ix [lsearch $list $value]
    if {$ix >= 0} {
    set list [lreplace $list $ix $ix]
    return 1
    } else {
    return 0
    }
}


# simple random number generator snagged from the net
# TBD: Refactor out
set RNseed [pid]
proc randomx {} {
    global RNseed
    set RNseed [expr 30903*($RNseed&65535)+($RNseed>>16)]
    return [format %.4x [expr int(32767*($RNseed & 65535)/65535.0)]]
} 

# escape html characters (simple version)

proc protect_text {text} {
    array set Map { < lt   > gt   & amp   \" quot}
    regsub -all {[\\$]} $text {\\&} text
    regsub -all {[><&"]} $text {\&$Map(&);} text
    subst -nocommands $text
}

# File_Reset - hack to close files after a leak has sprung
# TBD: Doesn't belong here.

proc File_Reset {} {
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
proc File_List {} {
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

proc parray {aname {pat *}} {
    upvar $aname a
    foreach name [array names a $pat] {
    setmax max [string length $name]
    }
    if ![info exists max] {
    return {}
    }
    incr max [string length $aname]
    incr max 2
    set result {}
    foreach name [lsort [array names a $pat]] {
    append result [list set ${aname}($name) $a($name)]
    append result \n
    }
    return $result
}


# boolnum value
#
# value  - A boolean value: true/false, on/off, yes/no, etc
#
# Returns 1 if value is true and 0 otherwise.

proc boolnum {value} {
    if {!([regsub -nocase {^(1|yes|true|on)$} $value 1 value] ||
        [regsub -nocase {^(0|no|false|off)$} $value 0 value])
    } {
       error "boolean value expected"
    }
    return $value
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

proc file_latest {files} {
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



# see http://mini.net/tcl/lambda
proc K {a b} {set a}
proc lambda {argl body} {K [info level 0] [proc [info level 0] $argl $body]}

# Tcllib 1.6 has inconsistencies with md5 1.4.3 and 2.0.0,
# and requiring 1.0 cures later conflicts with 2.0
# we run with whatever version is available
# by making an aliased wrapper
# TBD: Just use "mdg --hex" explicitly.
if {[package vcompare [package present md5] 2.0] > -1} {
    # we have md5 v2 - it needs to be told to return hex
    interp alias {} md5hex {} ::md5::md5 --hex --
} else {
    # we have md5 v1 - it returns hex anyway
    interp alias {} md5hex {} ::md5::md5
}
