#-----------------------------------------------------------------------
# TITLE:
#    mod.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectlib(n): Software Modification Loader
#
#    This module manages the loading of "mods" into a running 
#    application at start-up (or later).
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export mod
}

#-----------------------------------------------------------------------
# mod type

snit::type ::projectlib::mod {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # info array:
    #
    # ids          - List of mod IDs
    # modtime      - Seconds at which mods were last applied
    # nums-$pkg    - List of mod numbers by package
    # package-$id  - Affected package
    # version-$id  - Package version
    # number-$id   - Mod number for this package and version.
    # modfile-$id  - Mod file it was loaded from.
    # title-$id    - Mod title
    # body-$id     - Body of the mod
    
    typevariable info -array {
        ids     {}
        modtime 0
    }

    # trans array: used while loading mod files
    #
    # modfile  - Modfile currently being loaded

    typevariable trans -array {
        modfile {}
    }

    # load
    #
    # Loads the mod files from disk, if any.  Throws an error if a
    # file cannot be successfully loaded, or if a number of 
    # other conditions are unmet.

    typemethod load {} {
        # FIRST, create the mod interp
        set interp [interp create -safe]
        
        $interp alias mod [myproc ModCmd]

        # NEXT, prepare to save the data.
        array unset info
        set info(ids) {}

        # NEXT, get the mod file names.
        set appdir [appdir join mods]
        set modfiles [glob -nocomplain [file join $appdir *.tcl]]

        set userdir [file normalize [file join ~ athena mods]]

        if {$userdir ne $appdir} {
            lappend modfiles {*}[glob -nocomplain [file join $userdir *.tcl]]
        }

        # NEXT, get a list of all of the mods in the directory
        foreach trans(modfile) $modfiles {
            try {
                $interp invokehidden source $trans(modfile)
            } on error {result} {
                throw {MODERROR} \
                    "Error loading mod [file tail $trans(modfile)]: $result"
            }
        }

        # NEXT, destroy the interp
        rename $interp ""
    }

    # ModCmd pkg ver num title body 
    #
    # pkg    - The package name
    # ver    - The package version, e.g., "6.3.1"
    # num    - The number of the mod
    # title  - The title of the mod
    # body   - The body of the mod
    #
    # Loads the mod into memory.  The mod is ignored if the pkg is not
    # loaded.  It's an error if the ver doesn't match a loaded package's
    # version.  It's an error to have two mods with the
    # same number for the same pkg and ver.

    proc ModCmd {pkg ver num title body} {
        # FIRST, skip packages that aren't loaded.
        if {![IsLoaded $pkg]} {
            return
        }

        # NEXT, it's an error if the versions don't match.
        if {$ver ne [package present $pkg]} {
            throw {MODERROR LOAD} \
                "Package version mismatch, expected [package present $pkg], got mod $pkg $ver $num \"$title\""
        }

        # NEXT, it's an error if we already have a mod with this number
        if {[info exists info(nums-$pkg)] && $num in $info(nums-$pkg)} {
            throw {MODERROR LOAD} \
                "Duplicate mod number, mod $pkg $ver $num \"$title\""
        }

        # NEXT, get the ID; make them sortable by $num for a given
        # package.
        set id [ModID $pkg $num]

        lappend info(ids)       $id
        lappend info(nums-$pkg) $num
        set info(package-$id)   $pkg
        set info(version-$id)   $ver
        set info(num-$id)       $num
        set info(modfile-$id)   [file tail $trans(modfile)]
        set info(title-$id)     $title
        set info(body-$id)      $body
    }

    # apply ?pkg ?num??
    #
    # pkg   - A package name
    # num   - A mod number for the package
    #
    # By default, applies all loaded mods.  Mods for a package are loaded
    # in numerical order.  If pkg is given, only mods for that package
    # are loaded.  If num is given as well, only that mod is loaded.

    typemethod apply {{pkg ""} {num ""}} {
        # FIRST, save the time
        set info(modtime) [clock seconds]

        # NEXT, apply the mods
        foreach id [lsort $info(ids)] {
            # FIRST, skip irrelevant packages
            if {$pkg ne ""} {
                if {$pkg ne $info(package-$id)} {
                    continue
                }

                if {$num ne ""} {
                    if {$num != $info(num-$id)} {
                        continue
                    }
                }
            }

            # NEXT, try to load the mod
            try {
                namespace eval :: $info(body-$id)
            } on error {result eopts} {
                dict set eopts -errorcode {MODERROR APPLY}
                return {*}$eopts "Load failed, mod $id: $result"
            }
        }
    }

    # list
    #
    # Returns a dictab(n) list of mod records.

    typemethod list {} {
        set list [list]

        foreach id [lsort $info(ids)] {
            set dict [dict create \
                        package $info(package-$id) \
                        version $info(version-$id) \
                        num     $info(num-$id)     \
                        title   $info(title-$id)   \
                        modfile $info(modfile-$id)]
            lappend list $dict
        }

        return $list
    }

    # modtime 
    #
    # Returns the time in seconds at which mods were last applied.

    typemethod modtime {} {
        return $info(modtime)
    }


    #-------------------------------------------------------------------
    # Helper Procs

    # IsLoaded pkg
    #
    # Returns 1 if the pkg is loaded, and 0 otherwise.  We assume that
    # each pkg creates a namespace of the same name, and that the
    # package is not loaded if the namespace doesn't exist.

    proc IsLoaded {pkg} {
        return [namespace exists ::$pkg]
    }
    
    # ModID pkg num
    #
    # Returns a formatted mod ID

    proc ModID {pkg num} {
        format "%s-%03d" $pkg $num
    }

}



