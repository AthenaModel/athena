#-----------------------------------------------------------------------
# TITLE:
#    workdir.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Athena Working Directory Access
#
#    This object is responsible for providing access to
#    the Athena working directory tree, which resides at
#    
#      [fileutil::tempdir]/<NNNNNNNN>/
#
#                   or
#
#      <name>/<NNNNNNNN}/
#
#    where <name> is an optionally supplied directory name to the init
#    method and <NNNNNNNN> is a random 8 digit number.
#
#    It is the responsibility of the caller of init to verify that <name>
#    is a good directory name that the application can write to.
# 
#    Within this directory, "workdir init" will create the following
#    directories:
#
#        log/         For application logs
#        rdb/         For the RDB file(s)
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export workdir
}

#-----------------------------------------------------------------------
# workdir

snit::type ::projectlib::workdir {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Variables

    # The absolute path of the working directory.
    typevariable workdir ""


    #-------------------------------------------------------------------
    # Public Methods

    # init
    #
    # Initializes workdir, creating all directories as needed and 
    # creating the toucher.  Returns the working directory name.

    typemethod init {{name ""}} {
        if {$workdir ne ""} {
            # Already initialized
            return
        }

        # FIRST, by default set workdir root to the system tempdir
        set wdroot [::fileutil::tempdir]

        # NEXT, if name is provided, use that instead
        if {$name ne ""} {
            set wdroot $name
        }

        # NEXT, generate a random 8 digit integer, we want the
        # workdir to be unique, and make sure it doesn't already exist
        while {1} {
            set rnd [expr {round(rand()*10**8)}]

            set workdir [file join $wdroot $rnd]

            if {[file isdirectory $workdir]} {
                continue
            }

            break
        }

        # NEXT, create it, if it doesn't exist.
        file mkdir $workdir

        # NEXT, create the log, checkpoint, and scripts directories.
        file mkdir [file join $workdir log]
        file mkdir [file join $workdir rdb]

        # NEXT, return the local directory
        return $workdir
    }

    # join args
    #
    # Called with no arguments, returns the working directory.  
    # Any arguments are joined to the working directory using [file join].

    typemethod join {args} {
        require {$workdir ne ""} "workdir(n): Not initialized"
        eval file join [list $workdir] $args
    }

    # cleanup
    #
    # Removes the working directory.

    typemethod cleanup {} {
        require {$workdir ne ""} "workdir(n): Not initialized"

        file delete -force -- $workdir

        set workdir ""
    }
}











