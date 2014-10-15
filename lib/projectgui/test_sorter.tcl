lappend auto_path ~/athena/mars/lib ~/athena/lib

package require marsgui
package require projectgui
namespace import -force marsutil::* marsgui::* projectgui::*

# FIRST, define some reports

array set reports {
    1  {Flash Flood}
    2  {Terror Bombing}
    3  {Neighborhood Combat}
    4  {Bad Hair Day}
    5  {Excessive Sarcasm}
    6  {Flushed with Pride}
    7  {Joe wins the Big One}
    8  {Sarcasm on Parade}
    9  {Will and Dave's Excellent Adventure}
    10 {Grand Canyon Goes Missing}
    11 {Sales Riot}
    12 {Dogs Gone Wild}
    13 {Brian Buys A Car}
    14 {Deer in the Headlights}
    15 {Surely You're Joking}
    16 {Overacting}
    17 {Infrastructure Breakdown}
    18 {Industrial Spill}
    19 {Crying About Spilled Industry}
    20 {Intel Oversight}
    21 {Airduct Infiltration}
    22 {Fish with Bicycles}
    23 {Cow Kicks Lantern}
    24 {A Few More Bugs}
    25 {Bull By The Horns}
}

proc ::ReportIDs {} {
    variable reports

    return [lsort [array names reports]]
}

proc ::GetReport {id} {
    variable reports

    dict set rdict id $id
    dict set rdict title $reports($id)

    return $rdict
}

proc ::GetReportDetail {id} {
    variable reports

    append out "<h1>$id</h1>\n"
    append out [join [lrepeat 100 $reports($id)] " "]

    return $out
}

# NEXT, define some bins

set binspec {
    ACCIDENT   "Accident"
    CIVCAS     "Civilian Casualties"
    DEMO       "Demonstration"
    DROUGHT    "Drought"
    EXPLOSION  "Explosion"
    FLOOD      "Flood"
    RIOT       "Riot"
    TRAFFIC    "Traffic"
    VIOLENCE   "Violence"
}

# NEXT, define some help text.

set welcome {
    The first task is to relate the ingested reports to specific
    types of Athena event.<p>

    <ul>
    <li> Click on the report headers in the item list to see the details
         of the report.<p>
    <li> Click and drag each report to the appropriate event
         bin on the right.<p>
    <li> Reports for which no appropriate event type exists can
         be "ignored".<p>
    <li> Reports can be related to multiple events.  Shift-Click and
         drag to copy a report to a bin.<p>
    </ul>
}

# NEXT, define a -changecmd

proc ChangeCmd {value} {
    dict for {bin idlist} $value {
        if {[llength $idlist] > 0} {
            set bins($bin) $idlist
        }
    }

    puts "\nChangeCmd: <"
    parray bins
    puts ">"

}

# NEXT, build the GUI

sorter .sorter \
    -binspec    $binspec          \
    -changecmd  ::ChangeCmd       \
    -detailcmd  ::GetReportDetail \
    -helptext   $welcome          \
    -itemcmd    ::GetReport       \
    -itemlabel  "Reports"         \
    -itemlayout {
        { id    "ID"                     }
        { title "Title" -stretchable yes }
    }

.sorter sortset [lsort [array names reports]]

pack .sorter -fill both -expand yes

bind . <F10> {debugger new}