#-----------------------------------------------------------------------
# TITLE:
#   test_wmsclient.tcl
#
# AUTHOR:
#   Will Duquette
#   Dave Hanks
#
# DESCRIPTION:
#   Test program for wmsclient(n). 
#
#   There is a WMS server at 
#
#       http://demo.cubewerx.com/demo/cubeserv/simple
#
#-----------------------------------------------------------------------
lappend auto_path ~/athena/mars/lib ~/athena/lib

package require marsutil
package require marsgui
package require projectlib

namespace import marsutil::* marsgui::* projectlib::*

proc main {argv} {
    # FIRST, create wmsclient
    wmsclient wms -servercmd HandleResponse

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

    ttk::frame .mapf

    ttk::frame .mapf.toolbar

    ttk::button .mapf.toolbar.layers \
        -style Toolbutton       \
        -text "Select Layers"   \
        -command SelectLayers

    ttk::button .mapf.toolbar.getmap \
        -style Toolbutton \
        -text  "Get Map"  \
        -command GetMap

    ttk::label .mapf.toolbar.loc \
        -textvariable ::maploc   \
        -justify right           \
        -anchor e                \
        -width 60             

    pack .mapf.toolbar.layers -side left
    pack .mapf.toolbar.getmap -side left -padx {5 0}
    pack .mapf.toolbar.loc    -side right

    # map tab
    mapcanvas .mapf.map -locvariable ::maploc -width 1000 -height 650

    # bounding box events
    bind .mapf.map <ButtonPress-1>   {BboxSet  %x %y}
    bind .mapf.map <B1-Motion>       {BboxDraw %x %y}
    bind .mapf.map <ButtonRelease-1> {BboxDone %x %y}    
    bind .mapf.map <ButtonPress-3>   {HandleRightClick}

    # Button 2 is for OSX
    bind .mapf.map <ButtonPress-2>   {HandleRightClick}

    pack .mapf.toolbar -side top -anchor w
    pack .mapf.map     -side bottom -expand yes -fill both

    .content add .debugf -text "Debug"
    .content add .mapf   -text "Map"

    # grid components

    grid .content -row 0 -column 0 -sticky nsew

    grid rowconfigure    . 0 -weight 1
    grid columnconfigure . 0 -weight 1

    if {[llength $argv] > 0} {
        set url [lindex $argv 0]
    } else {
        set url "http://demo.cubewerx.com/demo/cubeserv/simple?"
    }

    # initialize layers
    set ::layers [dict create]
    set ::clayers [list]

    # initialize canvas size
    set ::cwidth 1000
    set ::cheight 650

    # initialize zoom stack
    set ::zoomstack [list]

    set ::lchanged 0
    set ::boxchanged 0

    DebugClear
    wms server connect $url
}

# GetDefaultMap
#
# This proc gets the default map once the client has successfully connected
# to the server.

proc GetDefaultMap {} {
    # NEXT set the URL with user parms
    set baseURL [dict get [wms server wmscap] Request GetMap Xref]
    set qparms [dict create]
    dict set qparms LAYERS [lindex $::clayers 0]
    dict set qparms WIDTH $::cwidth
    dict set qparms HEIGHT $::cheight

    DebugClear

    # NEXT, make the request
    wms server getmap $baseURL $qparms
}

proc BboxSet  {x y} {
    BboxClear

    set ::x0 $x
    set ::y0 $y
    .mapf.map create rectangle $::x0 $::y0 $::x0 $::y0 \
        -outline red -tags Bbox
    bind .mapf.map <B1-Motion> {BboxDraw %x %y}
}

proc BboxDraw {x y} {
    # dragging down and to the right is what's allowed
    if {$x < $::x0} {
        set x $::x0
    } 

    if {$y < $::y0} {
        set y $::y0
    }

    # the user is dragging the mouse draw the box
    .mapf.map delete Bbox

    .mapf.map create rectangle $::x0 $::y0 $x $y \
        -outline red -tags Bbox
}

proc BboxDone {x y} {
    # the user has released the mouse
    set ::x1 $x
    set ::y1 $y

    set ::boxchanged 1
}

# HandleRightClick
#
# Depending on the presence or absence of a bounding box deal with
# right click

proc HandleRightClick {} {
    # FIRST, if there's a bounding box clear it
    if {[llength [.mapf.map find withtag Bbox]] > 0} {
        BboxClear
        return
    }

    # NEXT, no zoom stack, nothing to do
    if {[llength $::zoomstack] == 0} {
        return
    }

    # NEXT, no bounding box, zoom out if there's an image to zoom out
    # to
    if {[llength $::zoomstack] > 2} {
        # Pop image and projection off zoomstack
        set ::zoomstack [lrange $::zoomstack 0 end-2]
    }

    # NEXT, set image and projection for zoomed out image
    set img [lindex $::zoomstack end-1]
    set proj [lindex $::zoomstack end]

    # NEXT, zoom out
    .mapf.map clear
    .mapf.map configure -map $img -projection $proj
    .mapf.map refresh
}

# BboxClear
#
# Deletes the bounding box from the map and resets the origin
#
proc BboxClear {} {
    if {[llength [.mapf.map find withtag Bbox]] > 0} {
        .mapf.map delete Bbox
        set ::x0 0
        set ::y0 0
    }
}

# HandleResponse rtype
#
# rtype - response type; one of WMSCAP or WMSMAP
#
# handles responses from the connected server

proc HandleResponse {rtype} {
    puts "handling response"
    # FIRST, debug information
    DebugValue "Server:" [wms server url]
    DebugValue "URL:"    [wms agent url]
    DebugPuts "\n"

    if {[wms server state] ne "OK"} {
        DebugPuts "Connection Error:\n"
        DebugPuts "WMS [wms server state]: [wms server status]\n"
        DebugPuts "=> [wms server error]\n"
        return
    }

    DebugPuts "WMS [wms server state]: [wms server status]\n\n"

    # NEXT, if the response is from a GetCapabilities request
    if {$rtype eq "WMSCAP"} {
        set caps [wms server wmscap]

        DebugValue "WMS Version:" [dict get $caps Version]
        DebugPuts "\n"

        DebugDict "Service------------:" [dict get $caps Service]


        DebugPuts "GetMap-------------:\n" 

        DebugValue "Xref:" [dict get $caps Request GetMap Xref]

        foreach fmt [dict get $caps Request GetMap Format] {
            DebugValue "Format:" "$fmt"
        }
        DebugPuts "-------------------\n\n"

        if {[wms server state] eq "OK"} {
            # extract layers from WMS capabilities
            set lns [dict get $caps Layer Name]
            set lts [dict get $caps Layer Title]
            set ::layers [dict create]
            foreach ln $lns lt $lts {
                dict set ::layers $ln $lt
            }
            set ::clayers [lindex $lns 0]

            puts "get default map"
            GetDefaultMap
        }
    } elseif {$rtype eq "WMSMAP"} {
        # NEXT, response is from a GetMap request
        if {[wms server state] eq "OK"} {
            .mapf.map clear
            .mapf.map configure -map [wms map image]
            lassign [wms map bbox] minlat minlon maxlat maxlon
            set proj [::marsutil::maprect %AUTO% \
                                      -minlon $minlon -minlat $minlat \
                                      -maxlon $maxlon -maxlat $maxlat \
                                      -width [wms map width] \
                                      -height [wms map height]]
            .mapf.map configure -projection $proj
            .mapf.map refresh

            # Push retrieved image and projection onto the zoom stack
            lappend ::zoomstack [wms map image] $proj
            set ::boxchanged 0
            set ::lchanged 0
        } else {
            tk_messageBox -default "ok" \
                          -icon error   \
                          -message "Error in map request, see debug tab." \
                          -parent . \
                          -title "Error" \
                          -type ok
        }
    } else {
        DebugPuts "Unknown response from WMS Client: $rtype \n\n"
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

# GetMap
#
# User has requested a map from the WMS

proc GetMap {} {
    # FIRST, gather requested layers
    if {[llength $::clayers] == 0} {
        tk_messageBox -default ok \
                      -icon error \
                      -title "Layers not selected" \
                      -message "Select one or more layers" \
                      -type ok
        return
    }

    if {!$::lchanged && !$::boxchanged} {
        return
    }

    # NEXT set the URL with user parms
    set baseURL [dict get [wms server wmscap] Request GetMap Xref]
    set qparms [dict create]
    dict set qparms LAYERS [join $::clayers ","]
    computeCanvasDim
    dict set qparms WIDTH $::cwidth
    dict set qparms HEIGHT $::cheight

    # NEXT, if theres a bounding box, convert it to lat/lon coords and set
    # the BBOX parm in the request
    if {[llength [.mapf.map find withtag Bbox]] > 0} {
        lassign [.mapf.map bbox Bbox] x1 y1 x2 y2
        lassign [.mapf.map c2m $x1 $y1] maxlat minlon
        lassign [.mapf.map c2m $x2 $y2] minlat maxlon
        dict set qparms BBOX "$minlat,$minlon,$maxlat,$maxlon"
    } 

    DebugClear

    # NEXT, make the request
    wms server getmap $baseURL $qparms
}

proc computeCanvasDim {} {
    if {[llength [.mapf.map find withtag Bbox]] == 0} {
        return
    }

    lassign [.mapf.map bbox Bbox] x1 y1 x2 y2
    let dx {$x2-$x1}
    let dy {$y2-$y1}
    let ratio {$dx/$dy}

    if {$dx/$dy > 1.65} {
        set ::cwidth 1000
        let ::cheight {int($dy * (1000.0/$dx))}
    } else {
        set ::cheight 650
        let ::cwidth {int($dx * (650.0/$dy))}
    }
}

# SelectLayers 
#
# Given the set of map layers available in the WMS, allow the user
# to choose which ones to see.

proc SelectLayers {} {
    # FIRST, if we already created the window just pop it up
    if {[winfo exists .p]} {
        wm deiconify .p
        return
    }

    # NEXT, first time in, create the window 
    toplevel .p 
    wm title .p "Choose Layers"

    listfield .p.layers \
        -changecmd LayersChanged \
        -height 10               \
        -itemdict $::layers      \
        -showkeys 0              \
        -width 40 

    .p.layers set $::clayers

    ttk::button .p.btn \
        -text "Ok" \
        -command {LayersSelected}

    pack .p.layers -side top -expand no
    pack .p.btn -side bottom -anchor e -expand no

}

proc LayersChanged {arg} {
    # No-Op for now
}

proc LayersSelected {} {
    # The user hit the OK button; pop window down
    set lSelected [.p.layers get]
    if {$::clayers ne $lSelected} {
        set ::clayers $lSelected
        set ::lchanged 1
    }
    wm withdraw .p
}

main $argv
