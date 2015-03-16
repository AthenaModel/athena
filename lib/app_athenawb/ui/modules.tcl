#-----------------------------------------------------------------------
# FILE: 
#   modules.tcl - subpackage loader
#
# PACKAGE:
#   app_athenawb/ui(n) -- Athena(1) User Interface (i.e., Tk) code.
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
# Because this is an application subpackage, the namespace is mostly
# unused.

namespace eval ::app_athenawb_ui:: {
    variable library [file dirname [info script]]
}

#-----------------------------------------------------------------------
# Load app_athenawb_ui(n) modules

source [file join $::app_athenawb_ui::library activitybrowser.tcl    ]
source [file join $::app_athenawb_ui::library actorbrowser.tcl       ]
source [file join $::app_athenawb_ui::library appwin.tcl             ]
source [file join $::app_athenawb_ui::library bsysbrowser.tcl        ]
source [file join $::app_athenawb_ui::library civgroupbrowser.tcl    ]
source [file join $::app_athenawb_ui::library capbrowser.tcl         ]
source [file join $::app_athenawb_ui::library cgesheet.tcl           ]
source [file join $::app_athenawb_ui::library coopbrowser.tcl        ]
source [file join $::app_athenawb_ui::library ctexteditor.tcl        ]
source [file join $::app_athenawb_ui::library cursebrowser.tcl       ]
source [file join $::app_athenawb_ui::library demogbrowser.tcl       ]
source [file join $::app_athenawb_ui::library demognbrowser.tcl      ]
source [file join $::app_athenawb_ui::library detailbrowser.tcl      ]
source [file join $::app_athenawb_ui::library econexpbrowser.tcl     ]
source [file join $::app_athenawb_ui::library econngbrowser.tcl      ]
source [file join $::app_athenawb_ui::library econtrol.tcl           ]
source [file join $::app_athenawb_ui::library econpopbrowser.tcl     ]
source [file join $::app_athenawb_ui::library absitbrowser.tcl       ]
source [file join $::app_athenawb_ui::library frcgroupbrowser.tcl    ]
source [file join $::app_athenawb_ui::library hookbrowser.tcl        ]
source [file join $::app_athenawb_ui::library hrelbrowser.tcl        ]
source [file join $::app_athenawb_ui::library iombrowser.tcl         ]
source [file join $::app_athenawb_ui::library mapicon_situation.tcl  ]
source [file join $::app_athenawb_ui::library mapicon_unit.tcl       ]
source [file join $::app_athenawb_ui::library mapicons.tcl           ]
source [file join $::app_athenawb_ui::library mapviewer.tcl          ]
source [file join $::app_athenawb_ui::library nbchart.tcl            ]
source [file join $::app_athenawb_ui::library nbcoopbrowser.tcl      ]
source [file join $::app_athenawb_ui::library nbhoodbrowser.tcl      ]
source [file join $::app_athenawb_ui::library nbrelbrowser.tcl       ]
source [file join $::app_athenawb_ui::library ordersentbrowser.tcl   ]
source [file join $::app_athenawb_ui::library orggroupbrowser.tcl    ]
source [file join $::app_athenawb_ui::library plantbrowser.tcl       ] 
source [file join $::app_athenawb_ui::library samsheet.tcl           ]
source [file join $::app_athenawb_ui::library satbrowser.tcl         ]
source [file join $::app_athenawb_ui::library scriptbrowser.tcl      ]
source [file join $::app_athenawb_ui::library securitybrowser.tcl    ]
source [file join $::app_athenawb_ui::library sigeventbrowser.tcl    ]
source [file join $::app_athenawb_ui::library strategybrowser.tcl    ]
source [file join $::app_athenawb_ui::library timechart.tcl          ]
source [file join $::app_athenawb_ui::library vrelbrowser.tcl        ]
source [file join $::app_athenawb_ui::library wmswin.tcl             ]



