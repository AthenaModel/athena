#-----------------------------------------------------------------------
# FILE: 
#   modules.tcl -- subpackage loader
#
# SUBPACKAGE:
#   app_athena/wintel(n) -- package for athena(1) intel ingestion wizard.
#
# PROJECT:
#   Athena Regional Stability Simulation
#
# AUTHOR:
#    Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Namespace definition

namespace eval ::wintel:: {
    variable library [file dirname [info script]]
}

#-----------------------------------------------------------------------
# Load modules

# NEXT, define the remaining modules in alphabetical order.

# Non-GUI modules
source [file join $::wintel::library wizard.tcl            ]
source [file join $::wintel::library wizdb.tcl             ]
source [file join $::wintel::library tigr.tcl              ]

# Ingested simulation events
source [file join $::wintel::library simevent.tcl          ]
source [file join $::wintel::library simevent_accident.tcl ]
source [file join $::wintel::library simevent_civcas.tcl   ]
source [file join $::wintel::library simevent_demo.tcl     ]
source [file join $::wintel::library simevent_drought.tcl  ]
source [file join $::wintel::library simevent_explosion.tcl]
source [file join $::wintel::library simevent_flood.tcl    ]
source [file join $::wintel::library simevent_riot.tcl     ]
source [file join $::wintel::library simevent_traffic.tcl  ]
source [file join $::wintel::library simevent_violence.tcl ]

# GUI modules
source [file join $::wintel::library wizwin.tcl            ]
source [file join $::wintel::library wizscenario.tcl       ]
source [file join $::wintel::library wiztigr.tcl           ]
source [file join $::wintel::library wizsorter.tcl         ]
source [file join $::wintel::library wizevents.tcl         ]
source [file join $::wintel::library wizexport.tcl         ]
source [file join $::wintel::library wizdummy.tcl          ]






