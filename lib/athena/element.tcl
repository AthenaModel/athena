#-----------------------------------------------------------------------
# TITLE:
#   element.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# PACKAGE:
#   athena(n): Athena Scenario Library
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Standard HTML elements for use on Athena HTML pages.
#
#   This module defines standard HTML elements (e.g., page headers and
#   and footers) for use on Athena web pages.  Items are defined here
#   for two reasons:
#
#   * Because they are specific to the visual design of Athena's pages
#   * Because they reference the Athena log, version, or whatever.
#
#-----------------------------------------------------------------------

namespace eval ::athena:: {
    namespace export element
}

snit::type ::athena::element {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    typevariable initialized 0  ;# So we can self-initialize.

    #-------------------------------------------------------------------
    # Initialization

    # reset
    #
    # Creates an htmlbuffer for producing the output.

    typemethod reset {} {
        if {$initialized} {
            hb clear
            return
        }

        set initialized 1
        ::projectlib::htmlbuffer create hb
    }
    
    

    #-------------------------------------------------------------------
    # Elements

    # header appname
    #
    # appname   - The application name
    #
    # Provides a standard page header

    typemethod header {appname} {
        $type reset

        hb tagln a -href "/index.html"
        hb ximg /images/Athena_logo_tiny.png -class logo
        hb tag /a
        hb div -class tagline {
            hb putln "Athena Regional Stability Simulation"
            hb br
            hb putln "$appname v[::athena version]"
            hb br
            hb putln "Better than BOGSAT!"
        }
        hb para

        return [hb get]
    }

    # footer
    #
    # Provides a standard page footer.
    
    typemethod footer {} {
        $type reset

        hb hr
        hb span -class tinyi \
            "Athena v[app version] - [clock format [clock seconds]]"
        hb para

        return [hb get]
    }
}
