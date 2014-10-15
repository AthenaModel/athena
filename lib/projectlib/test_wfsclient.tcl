#-----------------------------------------------------------------------
# TITLE:
#   test_wfsclient.tcl
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   Test program for wfsclient(n). 
#
#   There is a WFS server at 
#
#       http://demo.cubewerx.com/demo/cubeserv/haiti?DATASTORE=MINUSTAH
#
#   It contains geographic features for the country of Haiti.
#
#-----------------------------------------------------------------------
lappend auto_path ~/athena/mars/lib ~/athena/lib

package require marsutil
package require marsgui
package require projectlib

namespace import marsutil::* marsgui::* projectlib::*

proc main {argv} {
    # FIRST, create wfsclient
    wfsclient wfs -servercmd HandleResponse

    # NEXT, create GUI

    # tabbed notebook
    ttk::notebook .content

    # debug frame
    ttk::frame .debugf

    # debug text tab
    text .debugf.debug \
        -width 80 \
        -height 40 \
        -yscrollcommand [list .debugf.yscroll set]

    scrollbar .debugf.yscroll \
        -command [list .debugf.debug yview]

    grid .debugf.debug   -row 0 -column 0 -sticky nsew
    grid .debugf.yscroll -row 0 -column 1 -sticky ns

    grid rowconfigure    .debugf 0 -weight 1
    grid columnconfigure .debugf 0 -weight 1

    .content add .debugf -text "Debug"

    # grid components

    grid .content -row 0 -column 0 -sticky nsew

    grid rowconfigure    . 0 -weight 1
    grid columnconfigure . 0 -weight 1

    if {[llength $argv] > 0} {
        set url [lindex $argv 0]
    } else {
        set url "http://demo.cubewerx.com/demo/cubeserv/haiti?DATASTORE=MINUSTAH&"
    }

    DebugClear
    puts "trying initial connect to: $url"
    wfs server connect $url
}

# HandleResponse rtype
#
# rtype - response type; one of WFSCAP
#
# handles responses from the connected server

proc HandleResponse {rtype} {
    # FIRST, debug information
    DebugValue "Server:" [wfs server url]
    DebugValue "URL:"    [wfs agent url]
    DebugPuts "\n"

    if {[wfs server state] ne "OK"} {
        DebugPuts "Connection Error:\n"
        DebugPuts "WFS [wfs server state]: [wfs server status]\n"
        DebugPuts "=> [wfs server error]\n"
        return
    }

    DebugPuts "WFS [wfs server state]: [wfs server status]\n\n"

    # NEXT, if the response is from a GetCapabilities request
    puts "rtype= $rtype"
    if {$rtype eq "WFSCAP"} {
        set caps [wfs server wfscap]

        DebugValue "WFS Version:" [dict get $caps Version]
        DebugPuts "\n"

        DebugPuts "-------------------\n\n"

        if {[wfs server state] eq "OK"} {
            DebugPuts \
                "================= Operations Supported ==================\n"
            dict for {op odata} [dict get $caps Operation] {
                DebugDict $op $odata
            }

            DebugPuts \
                "================== Features Available ===================\n"
            dict for {ft ftdata} [dict get $caps FeatureType] {
                DebugDict $ft $ftdata
            }

            DebugPuts \
                "====================== Constraints ======================\n"
            dict for {cname cvalue} [dict get $caps Constraints] {
                DebugValue $cname $cvalue
            }
        }


    } else {
        DebugPuts "Unknown response from WFS Client: $rtype \n\n"
    }
}


proc DebugClear {} {
    .debugf.debug delete 1.0 end
}

proc DebugPuts {text} {
    .debugf.debug insert end $text
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
