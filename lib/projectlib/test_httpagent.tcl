#-----------------------------------------------------------------------
# TITLE:
#   test_httpagent.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Test script for exercising httpagent(n).
#
#-----------------------------------------------------------------------

lappend auto_path ~/athena/mars/lib ~/athena/lib

package require marsutil
package require marsgui
package require projectlib

namespace import marsutil::* marsgui::* projectlib::*

proc main {argv} {
    # FIRST, create the httpagent.
    httpagent agent \
        -command RequestComplete

    # NEXT, create GUI

    # address entry
    commandentry .address \
        -clearbtn 1 \
        -returncmd GotAddress

    ttk::separator .sep1 

    # debug text pane
    text .debug \
        -width 80 \
        -height 40 \
        -yscrollcommand [list .yscroll set]

    scrollbar .yscroll \
        -command [list .debug yview]

    # grid components

    grid .address -row 0 -column 0 -columnspan 2 -sticky ew
    grid .sep1    -row 1 -column 0 -columnspan 2 -sticky ew
    grid .debug   -row 2 -column 0 -sticky nsew
    grid .yscroll -row 2 -column 1 -sticky ns

    grid rowconfigure    . 2 -weight 1
    grid columnconfigure . 0 -weight 1

    if {[llength $argv] > 0} {
        .address set [lindex $argv 0]
        .address execute
    }

    bind all <F10> {debugger new}
}


# GotAddress addr 
#
# addr - The address they entered
#
# Called when the user enters an address.

proc GotAddress {addr} {
    DebugClear
    agent get $addr
}


# RequestComplete 
#
# Called when the request has completed.

proc RequestComplete {} {
    DebugClear
    DebugPuts "Address: [agent url]\n\n"

    switch -exact -- [agent state] {
        IDLE    -
        WAITING {
            DebugPuts "BUG: Agent state is [agent state].\n"
            DebugPuts "There is a bug somewhere; this should never happen.\n"
            return
        }
        TIMEOUT - 
        ERROR   {
            DebugValue "State:"  [agent state]
            DebugValue "Status:" [agent status]
            DebugValue "Error:"  [agent error]
            DebugPuts "\n"

            DebugDict "http(n) status---:" [agent httpinfo]

            return
        }
        default {
            # Everything's fine; we go on.
        }
    }

    DebugPuts "httpagent(n) status:\n"
    DebugValue "State:" [agent state]
    DebugValue "Status:" [agent status]
    DebugPuts "\n"

    set token [agent token]

    DebugDict "http(n) status---:" [agent httpinfo]

    DebugDict "Meta-------------:" [agent meta]

    DebugPuts "Data-------------:\n"
    DebugPuts [agent data]
}

proc DebugClear {} {
    .debug delete 1.0 end
}

proc DebugPuts {text} {
    .debug insert end $text
}

proc DebugValue {label value} {
    DebugPuts [format "%-20s <%s>\n" $label $value]
}

proc DebugDict {label dict} {
    DebugPuts "$label\n"
    foreach {label value} $dict {
        DebugValue $label $value
    }
    DebugPuts  "------------------\n\n"
}


main $argv
