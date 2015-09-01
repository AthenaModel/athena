#-----------------------------------------------------------------------
# TITLE:
#   domain/debug.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# PACKAGE:
#   app_arachne(n): Arachne Implementation Package
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   /debug: The smartdomain(n) for debugging
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# FIRST, define the domain.

oo::class create /debug {
    superclass ::projectlib::smartdomain

    #-------------------------------------------------------------------
    # Constructor

    constructor {} {
        next /debug

        # FIRST, define helpers
        hb configure \
            -cssfiles  {/athena.css}         \
            -headercmd [mymethod htmlHeader] \
            -footercmd [mymethod htmlFooter]
    }            

    #-------------------------------------------------------------------
    # Header and Footer

    method htmlHeader {hb title} {
        hb putln [athena::element header Arachne]
    }

    method htmlFooter {hb} {
        hb putln [athena::element footer]
    }

    #-------------------------------------------------------------------
    # Helper Methods

    method dummy {} {
        # TBD: dummy method, to test mods.
    }

    # LogToJson logname logfile 
    #
    # logname   - The log name, e.g., case00
    # logfile   - A logger(n) logfile, as used by Athena.
    #
    # Formats the log file for JSON output

    method LogToJson {logname logfile} {
        # FIRST, Is this a scenario log?
        set gotWeek [string match "case*" $logname]

        # NEXT, read the log
        set lines [split [readfile $logfile] \n]

        # NEXT, determine temp file name
        set filename [app namegen ".json"]
        set f [open $filename w]

        try {
            # NEXT, prepare JSON output
            puts -nonewline $f "\["

            set first 1

            # NEXT, output log as JSON to temp file
            foreach line $lines {
                # NEXT, if no data, no output
                if {[llength $line] == 0} {
                    continue
                }

                # NEXT, deal with commas between objects
                if {!$first} {
                    puts -nonewline $f ",\n"
                }

                set data(wallclock) [expr \
                    [clock scan [lindex $line 0] -format {%Y-%m-%dT%H:%M:%S}] * 1000]
                set data(level)     [lindex $line 1]
                set data(component) [lindex $line 2]
                set data(message)   [lindex $line 3]
                if {$gotWeek} {
                    set data(week)  [lindex $line 4]
                }
                set datadict [huddle create {*}[array get data]]
                puts -nonewline $f [huddle jsondump $datadict]

                set first 0
            }
            
            # NEXT, end JSON output
            puts -nonewline $f "]\n"
        } finally {
            catch {close $f}
        }

        return $filename
    }
}

#-------------------------------------------------------------------
# NEXT, define the content.

# /log/{logname}/index.json
smarturl /debug /log/{logname}/index.json {
    Returns the contents of the requested logfile in JSON format.
} {
    # FIRST, the log name might be a ".bg" log, in which case we need
    # to fix up the name.
    if {[string match "*_bg" $logname]} {
        set logname [string map {_bg .bg} $logname]
    }

    set logdir [scratchdir join log $logname]

    if {![file isdirectory $logdir]} {
        throw NOTFOUND "Log $logdir is no longer available"
    }

    set logfiles [lsort [glob -nocomplain -directory $logdir -tails *.log]]

    if {[llength $logfiles] == 0} { 
        return [js ok ""]
    }

    # NEXT, requested logfile or most recent
    set logfile [qdict prepare logfile -default [lindex $logfiles end]]

    # NEXT, convert to JSON, write to file and redirect
    set fname [my LogToJson $logname [scratchdir join log $logname $logfile]]
    my redirect "/temp/[file tail $fname]" 
}

# /log/{logname}/index.json
smarturl /debug /log/index.json {
    Returns the contents of the requested logfile for the requested
    area in JSON format. If no logfile is supplied, the first one is
    default.
} {

    set logarea [qdict prepare logarea -required]
 
    if {![qdict ok]} {
        return [js reject [qdict errors]]
    }

    set logdir [scratchdir join log $logarea]

    if {![file isdirectory $logdir]} {
        throw NOTFOUND "Log $logdir is no longer available"
    }

    set logfiles [lsort [glob -nocomplain -directory $logdir -tails *.log]]

    # TBD, probably should just return an empty list
    if {[llength $logfiles] == 0} { 
        return [js ok ""]
    }

    # NEXT, requested logfile or most recent
    set logfile [qdict prepare logfile -default [lindex $logfiles end]]

    # NEXT, convert to JSON, write to file and redirect
    set fname [my LogToJson $logarea [scratchdir join log $logarea $logfile]]
    my redirect "/temp/[file tail $fname]" 
}


# /code.json
smarturl /debug /code.json {
    Searches for the cmdline.  Returns a JSON list consisting of the
    requested cmdline and the code that was found.  If no code was
    found, the second item will be the empty string.
} {
    set cmdline [qdict prepare cmdline]

    if {$cmdline ne ""} {
        set found [join [cmdinfo getcode $cmdline -related] "\n\n"]    
    } else {
        set found ""
    }

    set hud [huddle list]
    huddle append hud [huddle compile string $cmdline]
    huddle append hud [huddle compile string $found]
    return [huddle jsondump $hud]
}

# /mods.json
smarturl /debug /mods.json {
    Returns a JSON array of Arachne mod records.  If the "op" parameter
    is "reload", tries to reload the mods.
} {
    set op [qdict prepare op]

    if {$op eq "reload"} {
        mod load
        mod apply
    }

    set table [list]
    set t [mod modtime]

    foreach modrec [mod list] {
        dict set modrec modtime [expr {1000*$t}]
        lappend table $modrec
    }
    return [js dictab $table]
}

# /logs.json
smarturl /debug /logs.json {
    Returns a JSON object with one field per log directory; the
    field name is the bare log directory name, and the value is the
    list of available log files in that directory.
} {
    set areas [glob \
                -nocomplain \
                -directory [scratchdir join log] \
                -tails \
                *]

    set hud [huddle create]

    foreach area [lsort $areas] {
        set dir [scratchdir join log $area]
        set logfiles [lsort [glob -nocomplain -directory $dir -tails *.log]]

        huddle set hud $area [huddle compile list $logfiles]
    }

    return [huddle jsondump $hud]
}
