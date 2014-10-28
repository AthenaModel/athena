#-----------------------------------------------------------------------
# TITLE:
#   main.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#   app_athena(n) Package, main module.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Commands

# main argv
#
# argv  - Arguments
#
# Application Main Procedure

proc main {argv} {
    # FIRST, get the application directory in the host file system.
    appdir init

    # NEXT, load the mods from the mods directory, if any, and
    # apply any applicable mods.
    athena_mods::load
    athena_mods::apply

    # NEXT, Invoke the app.
    app init $argv
}

#-------------------------------------------------------------------
# Mod code
#
# TBD: Move to app_athena as namespace ensemble.

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
        if {!$::tkloAded} {
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

proc ::athena_mods::errexit {args} {
    set text [join $args \n]

    set f [open "error.log" w]
    puts $f $text
    close $f

    if {[os type] ne "win32" || !$::tkloAded} {
         puts $text
    } else {
        wm withdraw .
        modaltextwin popup \
            -title   "Athena is shutting down" \
            -message $text
    }

    exit 1
}
