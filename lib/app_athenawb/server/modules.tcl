#-----------------------------------------------------------------------
# FILE: 
#   modules.tcl -- subpackage loader
#
# PACKAGE:
#   app_athenawb/server(n) -- Master package for athenawb(1) myserver code.
#
# PROJECT:
#   Athena S&RO Simulation
#
# AUTHOR:
#    Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Namespace definition
#
# Because this is an application package, the namespace is mostly
# unused.

namespace eval ::app_athenawb_server:: {
    variable library [file dirname [info script]]
}

#-----------------------------------------------------------------------
# Load app_athenawb_server(n) modules

source [file join $::app_athenawb_server::library appserver.tcl          ]
source [file join $::app_athenawb_server::library appserver_actor.tcl    ]
source [file join $::app_athenawb_server::library appserver_agent.tcl    ]
source [file join $::app_athenawb_server::library appserver_bean.tcl     ]
source [file join $::app_athenawb_server::library appserver_cap.tcl      ]
source [file join $::app_athenawb_server::library appserver_contribs.tcl ]
source [file join $::app_athenawb_server::library appserver_curses.tcl   ]
source [file join $::app_athenawb_server::library appserver_docs.tcl     ]
source [file join $::app_athenawb_server::library appserver_drivers.tcl  ]
source [file join $::app_athenawb_server::library appserver_econ.tcl     ]
source [file join $::app_athenawb_server::library appserver_enums.tcl    ]
source [file join $::app_athenawb_server::library appserver_firing.tcl   ]
source [file join $::app_athenawb_server::library appserver_group.tcl    ]
source [file join $::app_athenawb_server::library appserver_home.tcl     ]
source [file join $::app_athenawb_server::library appserver_hook.tcl     ]
source [file join $::app_athenawb_server::library appserver_image.tcl    ]
source [file join $::app_athenawb_server::library appserver_iom.tcl      ]
source [file join $::app_athenawb_server::library appserver_marsdocs.tcl ]
source [file join $::app_athenawb_server::library appserver_nbhood.tcl   ]
source [file join $::app_athenawb_server::library appserver_objects.tcl  ]
source [file join $::app_athenawb_server::library appserver_overview.tcl ]
source [file join $::app_athenawb_server::library appserver_parmdb.tcl   ]
source [file join $::app_athenawb_server::library appserver_plant.tcl    ]
source [file join $::app_athenawb_server::library appserver_plot.tcl     ]
source [file join $::app_athenawb_server::library appserver_sanity.tcl   ]
source [file join $::app_athenawb_server::library appserver_sigevents.tcl]
source [file join $::app_athenawb_server::library appserver_bsystems.tcl ]
source [file join $::app_athenawb_server::library appserver_topics.tcl   ]

