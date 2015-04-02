#-----------------------------------------------------------------------
# TITLE:
#    pkgModules.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    app_arachne(n) package modules file
#
#    Generated by Kite.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Package Definition

# -kite-provide-start  DO NOT EDIT THIS BLOCK BY HAND
package provide app_arachne 6.3.0a7
# -kite-provide-end

#-----------------------------------------------------------------------
# Required Packages

# Add 'package require' statements for this package's external 
# dependencies to the following block.  Kite will update the versions 
# numbers automatically as they change in project.kite.

# -kite-require-start ADD EXTERNAL DEPENDENCIES
package require projectlib
package require huddle 0.1.5
package require -exact athena 6.3.0a7
package require -exact ahttpd 6.3.0a7
# -kite-require-end

namespace import projectlib::* athena::* ahttpd::*

#-----------------------------------------------------------------------
# Namespace definition

namespace eval ::app_arachne:: {
    variable library [file dirname [info script]]
}

#-----------------------------------------------------------------------
# Modules

source [file join $::app_arachne::library main.tcl        ]
source [file join $::app_arachne::library app.tcl         ]

