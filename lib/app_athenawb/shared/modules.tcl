#-----------------------------------------------------------------------
# FILE: 
#   modules.tcl -- subpackage loader
#
# PACKAGE:
#   app_athenawb/shared(n) -- Master package for athena(1) shared code.
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

namespace eval ::app_athenawb_shared:: {
    variable library [file dirname [info script]]
}

#-----------------------------------------------------------------------
# Load app_athenawb_shared(n) modules

source [file join $::app_athenawb_shared::library appserver.tcl          ]
source [file join $::app_athenawb_shared::library appserver_actor.tcl    ]
source [file join $::app_athenawb_shared::library appserver_agent.tcl    ]
source [file join $::app_athenawb_shared::library appserver_bean.tcl     ]
source [file join $::app_athenawb_shared::library appserver_cap.tcl      ]
source [file join $::app_athenawb_shared::library appserver_contribs.tcl ]
source [file join $::app_athenawb_shared::library appserver_curses.tcl   ]
source [file join $::app_athenawb_shared::library appserver_docs.tcl     ]
source [file join $::app_athenawb_shared::library appserver_drivers.tcl  ]
source [file join $::app_athenawb_shared::library appserver_econ.tcl     ]
source [file join $::app_athenawb_shared::library appserver_enums.tcl    ]
source [file join $::app_athenawb_shared::library appserver_firing.tcl   ]
source [file join $::app_athenawb_shared::library appserver_group.tcl    ]
source [file join $::app_athenawb_shared::library appserver_home.tcl     ]
source [file join $::app_athenawb_shared::library appserver_hook.tcl     ]
source [file join $::app_athenawb_shared::library appserver_image.tcl    ]
source [file join $::app_athenawb_shared::library appserver_iom.tcl      ]
source [file join $::app_athenawb_shared::library appserver_marsdocs.tcl ]
source [file join $::app_athenawb_shared::library appserver_nbhood.tcl   ]
source [file join $::app_athenawb_shared::library appserver_objects.tcl  ]
source [file join $::app_athenawb_shared::library appserver_overview.tcl ]
source [file join $::app_athenawb_shared::library appserver_parmdb.tcl   ]
source [file join $::app_athenawb_shared::library appserver_plant.tcl    ]
source [file join $::app_athenawb_shared::library appserver_plot.tcl     ]
source [file join $::app_athenawb_shared::library appserver_sanity.tcl   ]
source [file join $::app_athenawb_shared::library appserver_sigevents.tcl]
source [file join $::app_athenawb_shared::library appserver_bsystems.tcl ]
source [file join $::app_athenawb_shared::library appserver_topics.tcl   ]
source [file join $::app_athenawb_shared::library apptypes.tcl           ]
source [file join $::app_athenawb_shared::library gradient.tcl           ]
source [file join $::app_athenawb_shared::library view.tcl               ]

