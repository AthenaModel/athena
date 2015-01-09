#!/bin/sh
# -*-tcl-*-
# The next line restarts using tclsh \
exec tclsh "$0" "$@"

# oconv.tcl

package require kiteutils

set swaps {
    "order define"        "myorders define"
    "options -sendstates" "meta sendstates"
    "    title"           "    meta title"
    "    form"            "    meta form"
    "    prepare"         "    my prepare"
    "    reject"          "    my reject"
    "    setundo"         "    my setundo"
    "    returnOnError"   "    my returnOnError"
    "    cancel"          "    my cancel"
    "    validate "       "    checkon "
    {[sender]}            {[my mode]}     
}

set methods {

    method _validate {} {

    }

    method _execute {{flunky ""}} {

    }

}

proc main {argv} {
    variable swaps
    variable methods

    set file [lindex $argv 0]

    if {$file eq ""} {
        puts "Usage: oconv.tcl orderx_file.tcl"
        exit 1
    }

    if {![file exists $file]} {
        puts "File doesn't exist: $file"
        exit 1
    }

    foreach {this that} $swaps {
        puts "$file: '$this' -> '$that'"
        exec kite replace $this $that $file
    }

    set lines [split [readfile $file] \n]

    set outlines [list]

    foreach line [split [readfile $file] \n] {
        if {[string first "} {" $line] == 0} {
            lappend outlines $methods
        } else {
            lappend outlines $line
        }
    }

    writefile $file [join $outlines \n]

}

main $argv