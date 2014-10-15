#-----------------------------------------------------------------------
# TITLE:
#    appdir.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Athena Directory Access
#
#    This object is responsible for creating and providing access to
#    the Athena directory tree.  It assumes that the toplevel script
#    being executed is in either athena/bin or athena/tools/bin.
#
#    appdir is a singleton.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export appdir
}

#-----------------------------------------------------------------------
# appdir

snit::type ::projectlib::appdir {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type variables

    typevariable appdir ""   ;# The absolute path of the Athena directory.


    #-------------------------------------------------------------------
    # Public Methods

    # init
    #
    # Initializes appdir.  Gets the full path name of the subdirectory 
    # containing the Athena executable file, whether it is a script
    # or a starpack, e.g., athena.exe; then, strips off any /tools/bin or
    # /bin at the end of that name to get the Athena application directory
    # name.  If the directory does NOT end in /bin, it is assumed to be
    # the application directory itself.
    #
    # Returns the Athena application directory name.

    typemethod init {} {
        global argv0

        # FIRST, if appdir is already set, just return.
        if {$appdir ne ""} {
            return
        }

        # NEXT, we could be running as a Tcl script or as a starpack.
        # If the executable name is a prefix of the Tcl script name,
        # we're running in a starpack.

        # Normalize both names; this guarantees that both strings have
        # the same case on Windows, which is not otherwise guaranteed.
        set scriptName [file normalize $argv0]
        set execName   [file normalize [info nameofexecutable]]

        if {[string match $execName* $scriptName]} {
            # Starpack
            set bindir [file normalize [file dirname $execName]]
        } else {
            # Plain Tcl script
            set bindir [file normalize [file dirname $scriptName]]
        }

        # NEXT, Determine which case we're in.
        if {[string match "*/tools/bin" $bindir]} {
            # Development: dev tool in athena/tools/bin.
            set appdir [file dirname [file dirname $bindir]]
        } elseif {[string match "*/bin" $bindir]} {
            # Development: Normal app in athena/bin
            set appdir [file dirname $bindir]
        } else {
            # Executable or script running in Athena directory itself.
            set appdir $bindir
        }

        # NEXT, ensure that required subdirectories exist.
        # TBD: None yet

        # NEXT, return the athena directory
        return $appdir
    }

    # join args
    #
    # Called with no arguments, returns the athena directory.  Any arguments
    # are joined to the athena directory using [file join].

    typemethod join {args} {
        eval file join [list $appdir] $args
    }
}









