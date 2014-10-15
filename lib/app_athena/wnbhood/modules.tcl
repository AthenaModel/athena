#-----------------------------------------------------------------------
# FILE:
#  modules.tcl -- subpackage loader
#
# PACKAGE:
#   wnbhood(n) -- package for athena(1) nbhood ingestion wizard.
#
# PROJECT:
#   Athena Regional Stability Simulation
#
# AUTHOR:
#   Dave Hanks
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Namespace definition

namespace eval ::wnbhood:: {
    variable library [file dirname [info script]]
}

#-----------------------------------------------------------------------
# Load modules

# Non-GUI modules
source [file join $::wnbhood::library wizard.tcl    ]
source [file join $::wnbhood::library wizdb.tcl     ]

# GUI modules
source [file join $::wnbhood::library wizwin.tcl    ]
source [file join $::wnbhood::library wiznbhood.tcl ]
source [file join $::wnbhood::library nbchooser.tcl ]






