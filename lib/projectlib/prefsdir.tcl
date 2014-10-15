#-----------------------------------------------------------------------
# TITLE:
#    prefsdir.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Athena Preferences Directory Access
#
#    This object is responsible for providing access to
#    the Athena preferences directory, which resides at
#
#       [osdir prefsdir]
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export prefsdir
}

#-----------------------------------------------------------------------
# prefsdir

snit::type ::projectlib::prefsdir {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Variables

    # initialized: 1 if initialized, 0 otherwise.
    typevariable initialized 0



    #-------------------------------------------------------------------
    # Public Methods

    # init
    #
    # Initializes prefsdir, creating all directories as needed.
    # Returns the preferences directory name.

    typemethod init {} {
        if {!$initialized} {
            # FIRST, create the prefs dir if it doesn't exist.
            file mkdir [osdir prefsdir]

            set initialized 1
        }

        # NEXT, return the prefs directory
        return [osdir prefsdir]
    }

    # initialized
    #
    # Returns 1 if the preferences dir has been initialized, and 0 
    # otherwise.

    typemethod initialized {} {
        return $initialized
    }

    # join args
    #
    # Called with no arguments, returns the working directory.  
    # Any arguments are joined to the working directory using [file join].

    typemethod join {args} {
        file join [osdir prefsdir] {*}$args
    }
}











