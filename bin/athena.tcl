#!/bin/sh
# -*-tcl-*-
# The next line restarts using tclsh \
exec tclsh "$0" "$@"

#-----------------------------------------------------------------------
# TITLE:
#    athena.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Athena: Simulation Launcher
#
#    This script serves as the main entry point for the Athena
#    simulation.  The simulation is invoked using 
#    the following syntax:
#
#        $ athena ?args....?
#
#    E.g., 
#
#        $ athena myscenario.adb
#
#    The simulation is defined by a Tcl package called "app_sim",
#    which defines an application ensemble, "app".  The application
#    is invoked as follows:
#
#        package require app_sim
#        app init $argv
#
# TBD:
#    * The mod code can be merged into app_sim.
#     
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Set up the auto_path, so that we can find the correct libraries.  
# In development, there might be directories loaded from TCLLIBPATH;
# strip them out.

# First, remove all TCLLIBPATH directories from the auto_path.

if {[info exists env(TCLLIBPATH)]} {
    set old_path $auto_path
    set auto_path [list]

    foreach dir $old_path {
        if {$dir ni $env(TCLLIBPATH)} {
            lappend auto_path $dir
        }
    }
}

# Next, get the Athena-specific library directories.  Whether we're
# in a starpack or not, the libraries can be found relative to this
# script file.

set appdir  [file normalize [file dirname [info script]]]
set libdir  [file normalize [file join $appdir .. lib]]

# Add Athena libs to the new lib path.
lappend auto_path $libdir

#-------------------------------------------------------------------
# Next, require Tcl/Tk

package require Tcl 8.6

package require kiteinfo

#-----------------------------------------------------------------------
# Application Metadata

set metadata {
    sim {
        text   "Athena Simulation"
        applib app_athena
        mode   gui
    }
}

#-----------------------------------------------------------------------
# Main Program 

# main argv
#
# argv       Command line arguments
#
# This is the main program; it is invoked at the bottom of the file.
# It determines the application to invoke, and does so.

proc main {argv} {
    global metadata
    global appname

    #-------------------------------------------------------------------
    # Get the Metadata

    array set meta $metadata

    #-------------------------------------------------------------------
    # Application Mode.


    # FIRST, Tk is needed if only if we are not in -batch mode
    set ::loadTk 1

    if {"-batch" in $argv} {
        set ::loadTk 0
    }

    # NEXT, get all Non-TK arguments from argv, leaving the Tk-specific
    # stuff in place for processing by Tk.

    if {$::loadTk} {
        #---------------------------------------------------------------
        # Require Tk.
        #
        #    version conflict for package "Tcl": have 8.5.3, 
        #    need exactly 8.5
        #
        # This logic works around the bug.
        set argv [nonTkArgs $argv]

        # NEXT, load Tk.
        package require Tk 8.6
    }

    # NEXT extract the appname, if none specified we assume app_sim(1)
    set appname "sim"
    set appdir "app_sim"
    set mode "gui"

    if {[llength $argv] >= 1} {
        set arg0 [lindex $argv 0]
        # NEXT, if metadata does not exist, pass everything down to
        # app_sim(1) it'll deal with any errors.
        if {[info exists meta($arg0)]} {
            set appname $arg0
            set argv [lrange $argv 1 end]
            set mode [dict get $meta($appname) mode]
        }
    }

    # NEXT, load the application package.
    package require [dict get $meta($appname) applib]

    # NEXT, get the application directory in the host
    # file system.
    appdir init
    
    # NEXT, load the mods from the mods directory, if any.
    ::athena_mods::load

    # NEXT, apply any applicable mods
    ::athena_mods::apply

    # NEXT, Invoke the app.
    app init $argv
}

# from argvar option ?defvalue?
#
# Looks for the named option in the named variable.  If found,
# it and its value are removed from the list, and the value
# is returned.  Otherwise, the default value is returned.
#
# TBD: When the misc utils are ported, use optval (it's available).

proc from {argvar option {defvalue ""}} {
    upvar $argvar argv

    set ioption [lsearch -exact $argv $option]

    if {$ioption == -1} {
        return $defvalue
    }

    set ivalue [expr {$ioption + 1}]
    set value [lindex $argv $ivalue]
    
    set argv [lreplace $argv $ioption $ivalue] 

    return $value
}

# nonTkArgs arglist
#
# arglist        An argument list
#
# Removes non-Tk arguments from arglist, leaving only Tk options like
# -display and -geometry (with their values, of course); these are
# assigned to ::argv.  Returns the non-Tk arguments.

proc nonTkArgs {arglist} {
    set ::argv {}

    foreach opt {-colormap -display -geometry -name -sync -visual -use} {
        set val [from arglist $opt]

        if {$val ne ""} {
            lappend ::argv $opt $val
        }
    }

    return $arglist
}


#-------------------------------------------------------------------
# Mod code

namespace eval ::athena_mods:: {
    # Mods for the app.
    #
    # ids          List of mod IDs
    # version-$id  Athena version
    # modfile-$id  Mod file it was loaded from.
    # title-$id    Mod title
    # body-$id     Body of the mod
    
    variable mods

    array set mods { 
        ids {}
    }

    # Current mod file
    variable modfile {}

}


# load
#
# Loads the mod files from disk, if any.

proc ::athena_mods::load {} {
    variable modfile

    # FIRST, create the mod interp
    set interp [interp create -safe]
    
    $interp alias mod ::athena_mods::ModCmd

    # NEXT, get the mods directory
    set moddir [appdir join mods]

    # NEXT, get a list of all of the mods in the directory
    foreach modfile [glob -nocomplain [file join $moddir *.tcl]] {
        if {[catch {
            $interp invokehidden source $modfile
        } result]} {
            errexit "Error loading mod [file tail $modfile]: $result"
        }
    }

    # NEXT, destroy the interp
    rename $interp ""
}

# ModCmd ver num title body 
#
# ver    The Athena version, e.g., "1.0.x"
# num    The number of the mod
# title  The title of the mod
# body   The body of the mod
#
# Loads the mod into memory.  Mods for other apps are ignored, and
# the version must match.  It's an error to have two mods with the
# same number.

proc ::athena_mods::ModCmd {ver num title body} {
    variable modfile
    variable mods

    # FIRST, it's an error if we already have a mod with this number
    if {$num in $mods(ids)} {
        errexit \
            "Duplicate mod:" \
            "  Mod #$num is defined in [file tail $modfile]"  \
            "  Mod #$num is redefined in $mods(modfile-$num)" \
            "" \
            "Please remove one or the other (or both)."
    }

    # NEXT, save the data
    lappend mods(ids)      $num
    set mods(version-$num) $ver
    set mods(modfile-$num) [file tail $modfile]
    set mods(title-$num)   $title
    set mods(body-$num)    $body
}

# apply
#
# Applies all loaded mods, in numerical order

proc ::athena_mods::apply {} {
    variable mods

    # FIRST, get the mods directory
    set moddir [appdir join mods]

    # NEXT, apply the mods
    foreach num [lsort -integer $mods(ids)] {
        # FIRST, it's an error if the version doesn't match
        if {$mods(version-$num) ne [kiteinfo version]
        } {
            errexit \
                "Version mismatch:" \
                "  Mod file $mods(modfile-$num) is for Athena $mods(version-$num)." \
                "  This is Athena [kiteinfo version]." \
                "" \
                "Remove $mods(modfile-$num) from $moddir."
        }

        if {[catch {
            namespace eval :: $mods(body-$num)
        } result]} {
            errexit \
                "Could not load mod $num from $mods(modfile-$num)\n  $result" \
                "" \
                "Remove $mods(modfile-$num) from $moddir."
        }
    }
}

# logmods
#
# Logs the mods for the application

proc ::athena_mods::logmods {} {
    variable mods

    foreach num [lsort -integer $mods(ids)] {
        log normal app "mod loaded: $num, \"$mods(title-$num)\", from $mods(modfile-$num)"
        if {!$::loadTk} {
            puts  "mod loaded: $num, \"$mods(title-$num)\", from $mods(modfile-$num)"
        }

    }
}

# errexit line...
#
# line   -  One or more lines of text, as distinct arguments.
#
# On Linux/OS X or when Tk is not loaded, writes the text to standard 
# output, and exits. On Windows, pops up a messagebox and exits when 
# the box is closed.

proc errexit {args} {
    set text [join $args \n]

    set f [open "error.log" w]
    puts $f $text
    close $f

    if {[os type] ne "win32" || !$::loadTk} {
         puts $text
    } else {
        wm withdraw .
        modaltextwin popup \
            -title   "Athena is shutting down" \
            -message $text
    }

    exit 1
}


#-----------------------------------------------------------------------
# Run the program

# FIRST, run the main routine, to set everything up.
main $argv



