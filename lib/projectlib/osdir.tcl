#-----------------------------------------------------------------------
# TITLE:
#    osdir.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Athena OS-dependence Package
#
#    This module is intended to contain most or all non-GUI 
#    OS-dependent code for the Athena project.  In particular, it 
#    determines locations of directories, use of external tools, and so 
#    forth.
#
# TODO:
#    * Update os(n) to have [os flavors].
#    * Update os(n) to have [os appdata] call.
#    * Update prefsdir(n) to use [os appdata] and get rid of this module.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export osdir
}

#-----------------------------------------------------------------------
# workdir

snit::type ::projectlib::osdir {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Variables

    # info: array of cached values
    #
    #   prefsdir - Location of the preferences directory.
    #   workdir  - Location of the working data directory.

    typevariable info -array {
        prefsdir ""
        workdir  ""
    }


    #-------------------------------------------------------------------
    # Public Methods

    # types
    #
    # Returns a list of the valid OS types.

    typemethod types {} {
        return [list linux osx windows]
    }

    # type
    # 
    # Returns "linux", "windows", or "osx".

    typemethod type {} {
        return [os flavor]
    }

    # prefsdir
    #
    # Returns the name of a directory for storing preference data and
    # the like.

    typemethod prefsdir {} {
        if {$info(prefsdir) eq ""} {
            if {[$type type] eq "windows"} {
                set info(prefsdir) \
                    [file normalize [file join $::env(APPDATA) JPL Athena]]
            } else {
                set info(prefsdir) \
                    [file normalize "~/.athena"]
            }
        }

        return $info(prefsdir)
    }
}











