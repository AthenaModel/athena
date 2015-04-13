#!/bin/sh
# -*-tcl-*-
# The next line restarts using tclsh \
exec tclsh "$0" "$@"

# tt.tcl

package require athena
package require projectgui
package require Thread

namespace import ::projectlib::*
namespace import ::athena::*
namespace import ::projectgui::*

rotext .log -width 80 -height 20
cli .cli -width 80 -height 20

pack .log -side top -expand yes -fill both
pack .cli -side top -expand yes -fill both

proc log {msg} {
    .log ins end "$msg\n"
    .log see end
}

proc setup {} {
    variable slave
    set slave [thread::create -joinable]
    thread::send $slave [list set master [thread::id]]
    thread::send $slave [list set auto_path $::auto_path]
    thread::send $slave {
        proc notify {tag i n} {
            variable master
            thread::send -async $master [list Notify $tag $i $n]
        }

        package require athena
        namespace import ::projectlib::* ::athena::*
        athena create sdb

        proc doit {script} {
            notify running 0 4
            sdb executive call $script
            notify running 1 4
            # TBD: Need "lock" and "advance" subcommands.
            sdb order send normal SIM:LOCK
            notify running 2 4
            # TBD: Need "lock" and "advance" subcommands.
            sdb order send normal SIM:RUN -weeks 10 -block 1
            notify running 3 4
            sdb save tt.adb
            notify done 0 0
        }
    }
}

proc Notify {tag i n} {
    variable slave
    log "$tag $i $n"


    if {$tag eq "done"} {
        log "Work done: halting thread."
        please thread::release
        thread::join $slave
        log "Thread halted"
        log "Threads: [thread::names]"
    }
}

proc please {args} {
    variable slave
    log "send: $args"
    thread::send -async $slave $args
}

setup