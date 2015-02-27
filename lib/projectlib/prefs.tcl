#-----------------------------------------------------------------------
# TITLE:
#    prefs.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Athena user preferences
#
#    The module delegates most of its function to parmset(n).
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export prefs
}

#-------------------------------------------------------------------
# parm

snit::type ::projectlib::prefs {
    # Make it a singleton
    pragma -hasinstances 0

    #-------------------------------------------------------------------
    # Typecomponents

    typecomponent ps ;# The parmset(n) object

    #-------------------------------------------------------------------
    # Type Variables

    # Name of the user preferences file in the prefsdir
    typevariable prefsFile user.prefs

    #-------------------------------------------------------------------
    # Public typemethods

    delegate typemethod cget       to ps
    delegate typemethod configure  to ps
    delegate typemethod docstring  to ps
    delegate typemethod get        to ps
    delegate typemethod getdefault to ps
    delegate typemethod items      to ps
    delegate typemethod names      to ps
    delegate typemethod manlinks   to ps
    delegate typemethod manpage    to ps


    # init
    #
    # Initializes the module

    typemethod init {} {
        # Don't initialize twice.
        if {$ps ne ""} {
            return
        }

        # FIRST, create the parm set
        set ps [parmset %AUTO%]

        # NEXT, define parameters

        $ps subset appwin {
            Parameters which affect the main window.
        }

        $ps define appwin.cli snit::boolean off {
            If on, the Command Line Interface (CLI) is visible; 
            otherwise not.
        }

        $ps define appwin.orders snit::boolean off {
            If on, the Time/Orders tab is visible; otherwise not.
        }

        $ps define appwin.scripts snit::boolean off {
            If on, the Scripts tab is visible; otherwise not.
        }

        $ps define appwin.slog snit::boolean off {
            If on, the Time/Log tab is visible; otherwise not.
        }


        $ps subset cli {
            Parameters which affect the Command Line Interface (CLI).
        }

        $ps define cli.maxlines ::projectlib::iminlines 500 {
            The maximum number of lines of text to be retained in the
            main window's command line interface scrollback buffer:
            an integer number no less than 100.
        }

        $ps subset wms {
            Parameters which configure the WMS client.
        }

        $ps define wms.urls snit::listtype "" {
            A list of previously visited WMS URLs stored as history
            in the WMS client.
        }

        $ps setdefault wms.urls {
            http://demo.cubewerx.com/demo/cubeserv/simple
        }

        $ps subset helper {
            Names of helper applications.
        }

        foreach ostype [osdir types] {
            $ps subset helper.$ostype \
                "Helper applications for the \"$ostype\" operating system."
        
            $ps define helper.$ostype.browser snit::stringtype "" {
                Name of the command that invokes the system web browser,
                e.g., for viewing Detail Browser pages.
            }
        }

        $ps setdefault helper.linux.browser "firefox"
        $ps setdefault helper.windows.browser "cmd /C start"
        $ps setdefault helper.osx.browser "open"
    }

    # help parm
    #
    # parm   A parameter name
    #
    # Returns the docstring.

    typemethod help {parm} {
        return [$ps docstring $parm]
    }

    # set parm value
    #
    # parm     A parameter name
    # value    A value
    # 
    # Sets the parameter's value, and saves the preferences.

    typemethod set {parm value} {
        $ps set $parm $value
        $type SavePrefs
    }
    
    # prefs reset
    #
    # Resets all parameters to their defaults, and saves the result
    # (if the prefsdir is initialized)
    
    typemethod reset {} {
        $ps reset
        $type SavePrefs
    }

    # list ?pattern?
    #
    # pattern    A glob pattern
    #
    # Lists all parameters with their values, or those matching the
    # pattern.  If none are found, throws an error.

    typemethod list {{pattern *}} {
        set result [$ps list $pattern]

        if {$result eq ""} {
            error "No matching parameters"
        }

        return $result
    }

    # load
    #
    # Loads the parameters safely from the prefsFile, if it exists.

    typemethod load {} {
        if {[file exists [prefsdir join $prefsFile]]} {
            $ps load [prefsdir join $prefsFile] -safe
        }
    }

    # SavePrefs
    #
    # Saves the preferences, only if the prefsdir is initialized.

    typemethod SavePrefs {} {
        if {[prefsdir initialized]} {
            $ps save [prefsdir join $prefsFile]
        }
    }
}

