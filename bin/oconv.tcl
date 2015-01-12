#!/bin/sh
# -*-tcl-*-
# The next line restarts using tclsh \
exec tclsh "$0" "$@"

# oconv.tcl

package require kiteutils
namespace import kiteutils::*

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
    "    validate "       "    my checkon "
    {[sender]}            {[my mode]}     
}

set valText "

    method _validate {} \{
"

set exeText "
    }

    method _execute {{flunky \"\"}} {
"

proc main {argv} {
    variable swaps
    variable valText
    variable exeText

    set file [lindex $argv 0]

    if {$file eq ""} {
        puts "Usage: oconv.tcl orderx_file.tcl"
        exit 1
    }

    if {![file exists $file]} {
        puts "File doesn't exist: $file"
        exit 1
    }

    set inOrders no
    set outlines [list]


    foreach line [split [readfile $file] \n] {
        if {!$inOrders} {
            if {![string match "order define*" $line]} {
                lappend outlines $line
                continue
            }

            set inOrders 1
        }

        if {[string first "\} \{" $line] == 0} {
            lappend outlines $valText
            continue
        }

        if {[string match "*returnOnError -final*" $line]} {
            lappend outlines $exeText
            continue
        }

        lappend outlines [string map $swaps $line]
    }

    writefile new_$file [join $outlines \n]
}

main $argv