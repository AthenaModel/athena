#-----------------------------------------------------------------------
# TITLE:
#    scratchdir.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Athena Scratch Directory Access
#
#    This object is responsible for providing access to
#    the Athena scratch directory tree, which resides at a known
#    location.  By default, it is at [appdir join scratch];
#    however, it can be initialized to be in any desired location.
#
#    This module is similar to scratchdir(n), and is used for the same
#    purpose.  The difference is that the scratchdir(n) is used by the
#    Athena Workbench; no other application need be able to access it
#    other than athenawb(1).  The scratchdir(n) is a well-known 
#    resource, shared by one-at-a-time applications like arachne(n)
#    and the athena_log browser.
#    
#    See the scratchdir(n) man page for details of the structure
#    of the scratch directory.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export scratchdir
}

#-----------------------------------------------------------------------
# scratchdir

snit::type ::projectlib::scratchdir {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Variables

    # The absolute path of the working directory.
    typevariable scratchdir ""


    #-------------------------------------------------------------------
    # Public Methods

    # init
    #
    # Initializes scratchdir, creating all directories as needed.
    # Defaults to [appdir join scratch].

    typemethod init {{name ""}} {
        # FIRST, only initialize once.
        if {$scratchdir ne ""} {
            # Already initialized
            return
        }

        # NEXT, get the directory.
        if {$name ne ""} {
            set scratchdir [file normalize $name]
        } else {
            appdir init
            set scratchdir [appdir join scratch]
        }

        # NEXT, create it, if it doesn't exist.
        file mkdir $scratchdir

        # NEXT, return the local directory
        return $scratchdir
    }

    # join args
    #
    # Called with no arguments, returns the working directory.  
    # Any arguments are joined to the working directory using [file join].

    typemethod join {args} {
        require {$scratchdir ne ""} "scratchdir(n): Not initialized"
        eval file join [list $scratchdir] $args
    }

    # clear
    #
    # Removes the content of the working directory.

    typemethod clear {} {
        require {$scratchdir ne ""} "scratchdir(n): Not initialized"

        foreach fname [glob -nocomplain [$type join *]] {
            catch {file delete -force -- $fname}
        }

        # NEXT, create the required directories.
        file mkdir [file join $scratchdir log]
    }
}











