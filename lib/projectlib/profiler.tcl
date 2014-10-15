#-----------------------------------------------------------------------
# TITLE:
#    profiler.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectlib(n): Procedure/Method profiler
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export profiler
}

snit::type ::projectlib::profiler {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # data - Array of profiling data
    #
    # procs          - List of procs being profiled
    # stack          - Stack of start times
    # pretty-$proc   - Pretty command name (e.g., for instance calls)
    # count-$proc    - Number of times $proc has been called
    # times-$proc    - List of durations for $proc

    typevariable data -array {
        procs {}
        stack {}
    }

    #-------------------------------------------------------------------
    # Public Type Methods
    
    # profile cmd subcmd... 
    #
    # cmd    - Command, type, or object name
    # subcmd - For Snit typemethods and methods only
    #
    # Determines the name of the proc, and adds execution traces to it
    # so that we can time it.

    typemethod profile {cmd args} {
        # FIRST, get the procedure
        set proc [GetProc $cmd {*}$args]

        if {$proc ni $data(procs)} {
            lappend data(procs) $proc
            if {[llength $args] == 0} {
                set data(pretty-$proc) $proc
            } else {
                set data(pretty-$proc) "$cmd $args"
            }
            set data(count-$proc)  0
            set data(times-$proc)  [list]
            trace add execution $proc enter [myproc Enter $proc]
            trace add execution $proc leave [myproc Leave $proc]
        }
    }

    # unprofile cmd subcmd... 
    #
    # cmd    - Command, type, or object name
    # subcmd - For Snit typemethods and methods only
    #
    # Determines the name of the proc, and adds execution traces to it
    # so that we can time it.

    typemethod unprofile {cmd args} {
        # FIRST, get the procedure
        set proc [GetProc $cmd {*}$args]

        if {$proc in $data(procs)} {
            ldelete data(procs) $proc
            unset data(pretty-$proc)
            unset data(count-$proc)
            unset data(times-$proc)
            trace remove execution $proc enter [myproc Enter $proc]
            trace remove execution $proc leave [myproc Leave $proc]
        }
    }

    # clear
    #
    # Clears the saved data.

    typemethod clear {} {
        set data(stack) [list]

        foreach proc $data(procs) {
            set data(count-$proc) 0
            set data(times-$proc) [list]
        }
    }

    # reset
    #
    # Clears the saved data and unprofiles all procs.

    typemethod reset {} {
        foreach proc $data(procs) {
            trace remove execution $proc enter [myproc Enter $proc]
            trace remove execution $proc leave [myproc Leave $proc]
        }

        array unset data
        set data(procs) [list]
        set data(stack) [list]
    }

    # dump
    #
    # Returns a dump of the saved information.

    typemethod dump {} {
        if {[llength $data(procs)] == 0} {
            return "No commands are being profiled."
        }

        set result [format "%10s %8s  %s\n" "Usecs" "Count" "Command"]

        foreach proc $data(procs) {
            if {[llength $data(times-$proc)] > 0} {
                set total [expr [join $data(times-$proc) +]]
            } else {
                set total 0
            }

            append result [format "%10d %8d  %s\n" \
                $total                             \
                $data(count-$proc)                 \
                $data(pretty-$proc)]
        }

        return $result
    }

    #-------------------------------------------------------------------
    # Profiling Code
   
    proc Enter {proc cmd op} {
        lappend data(stack) [clock microseconds]
    }

    proc Leave {proc cmd code result op} {
        set end [clock microseconds]
        set start [lindex $data(stack) end]
        set data(stack) [lrange $data(stack) 0 end-1]

        incr data(count-$proc)
        lappend data(times-$proc) [expr {$end - $start}]
    }

    #-------------------------------------------------------------------
    # Code to get proc name given command and subcommands 

    # GetProc name args
    #
    # name   - A Tcl proc, type, or instance command name
    # args   - Subcommands; name must be a type or instance
    #
    # Returns the command name 

    proc GetProc {name args} {
        # FIRST, get the absolute name
        set name [uplevel 1 [list namespace origin $name]]

        # NEXT, Get the type of the command
        set ctype [cmdinfo type $name]

        # NEXT, handle it based on the type.  For most things, presume
        # that it's just a command and ignore the subcommands.  If it's
        # a namespace ensemble, assume that it's a Snit type or instance.
        if {$ctype in {proc wproc bin wbin}} {
            # Ignore any args
            return $name
        } elseif {$ctype in {nse wnse}} {
            # FIRST, is it an instance or a type?
            if {![catch {set objtype [$name info type]} result]} {
                # Instance
                return [GetInstanceMethod $objtype $args]
            } else {
                # Is it a type?
                if {[cmdinfo exists ${name}::Snit_typeconstructor]} {
                    return [GetTypeMethod $name $args]
                } else {
                    error "not a proc, snit type, or snit instance: \"$object\""
                }
            }
        } else {
            error "not a proc, snit type, or snit instance: \"$name\""
        }
    }


    # GetTypeMethod objtype subcmd
    #
    # objtype     A snit type
    # subcmd      A typemethod name
    #
    # Retrieves the typemethod's definition

    proc GetTypeMethod {objtype subcmd} {
        if {[llength $subcmd] == 1} {
            set procName "${objtype}::Snit_typemethod${subcmd}"
        } else {
            set procName "${objtype}::Snit_htypemethod[join $subcmd _]"
        }

        if {[llength [info commands $procName]] != 1} {
            error "$objtype has no typemethod called \"$subcmd\""
        }

        return $procName
    }

    # GetInstanceMethod objtype subcmd
    #
    # objtype     A snit type
    # subcmd      A method name
    #
    # Retrieves the method's definition

    proc GetInstanceMethod {objtype subcmd} {
        if {[llength $subcmd] == 1} {
            set procName "${objtype}::Snit_method${subcmd}"
        } else {
            set procName "${objtype}::Snit_hmethod[join $subcmd _]"
        }

        if {[llength [info commands $procName]] != 1} {
            error "$objtype has no method called \"$subcmd\""
        }

        return $procName
    }

}
