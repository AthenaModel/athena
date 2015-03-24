#-----------------------------------------------------------------------
# TITLE:
#    stats.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    ahttpd(n): Server statistics
#
#    We pre-declare any non-simple counters (e.g., the time-based
#    histogram for urlhits, and the interval-histogram for service times)
#    and everything else defaults to a basic counter.  Once things
#    are declared, the counter::count function counts things for us.
#    
#    Brent Welch (c) 1997 Sun Microsystems
#    Brent Welch (c) 1998-2000 Ajuba Solutions
#    Will Duquette (c) 2015 California Institute of Technology
#
#    See the file "license.terms" for information on usage and 
#    redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
#-----------------------------------------------------------------------

snit::type ::ahttpd::stats {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # counter info array
    #
    # starttime - The start time of the run, in seconds.

    typevariable counter -array {}
    

    # init
    #
    # Initialize the module

    typemethod init {{secsPerMinute 60}} {
        set counter(starttime) [clock seconds]

        # urlhits is the number of requests serviced.
        counter::init urlhits -timehist $secsPerMinute

        # This start/stop timer is used for connection service times.
        # The linear histogram has buckets of 5 msec.
        counter::init serviceTime -hist 0.005

        # These group counters are used for per-page hit, notfound, and error
        # statistics.  If you auto-gen unique URLS, these are a memory leak
        # that you can plug by doing
        #
        #   status::countInit hit -simple

        foreach g {domainHit hit notfound errors} {
            counter::init $g -group $g
        }

        # These are simple counters about each kind of connection event

        foreach c {
            accepts sockets connections urlreply keepalive connclose 
            http1.0 http1.1 cgihits
        } {
            counter::init $c
        }

        Httpd_RegisterShutdown [mytypemethod checkpoint]
    }

    # checkpoint
    #
    # Saves the counter data to a file in the log directory.

    typemethod checkpoint {} {
        if {[::ahttpd::log basename] ne ""} {
            set path [::ahttpd::log basename]counter
            catch {file rename -force $path $path.old}
            if {![catch {open $path w} out]} {
                puts $out \n[parray counter]
                puts $out \n[parray [counter::get urlhits -histVar]]
                puts $out \n[parray [counter::get urlhits -histHourVar]]
                puts $out \n[parray [counter::get urlhits -histDayVar]]
                close $out
            }
        }
    }

    typemethod count {what {delta 1}} {
        if {![counter::exists $what]} {
            counter::init $what
        }
        counter::count $what $delta
    }

    typemethod countname {instance tag} {
        if {![counter::exists $tag]} {
            counter::init $tag
        }
        counter::count $tag 1 $instance
    }

    typemethod reset {what args} {
        eval {counter::reset $what} $args
    }

    typemethod counthist {what {delta 1}} {
        counter::count $what $delta
    }

    typemethod countstart {what instance} {
        counter::start $what $instance
    }

    typemethod countstop {what instance} {
        counter::stop $what $instance
    }

    typemethod varname {what} {
        return [counter::get $what -totalVar]
    }

    typemethod starttime {} {
        return $counter::startTime
    }
}

