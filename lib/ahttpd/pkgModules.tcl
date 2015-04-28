#-----------------------------------------------------------------------
# TITLE:
#    pkgModules.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    ahttpd(n) package modules file
#
#    Generated by Kite.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Package Definition

# -kite-provide-start  DO NOT EDIT THIS BLOCK BY HAND
package provide ahttpd 6.3.0a9
# -kite-provide-end

#-----------------------------------------------------------------------
# Required Packages

# Add 'package require' statements for this package's external 
# dependencies to the following block.  Kite will update the versions 
# numbers automatically as they change in project.kite.

# -kite-require-start ADD EXTERNAL DEPENDENCIES
package require md5 2.0.7
package require base64 2.4.2
package require uri 1.2
package require counter 2.0
package require ncgi 1.4.3
package require html 1.4.3
package require kiteutils 0.4.7
package require tls 1.6.4
# -kite-require-end


#-----------------------------------------------------------------------
# Namespace definition

namespace eval ::ahttpd:: {
    variable library [file dirname [info script]]

    namespace import ::kiteutils::foroption
    namespace import ::kiteutils::ladd
    namespace import ::kiteutils::ldelete

}


#-----------------------------------------------------------------------
# Modules

source [file join $::ahttpd::library ahttpd.tcl   ]
source [file join $::ahttpd::library httpd.tcl    ]
source [file join $::ahttpd::library utils.tcl    ]
source [file join $::ahttpd::library mimetype.tcl ]
source [file join $::ahttpd::library log.tcl      ]
source [file join $::ahttpd::library stats.tcl    ]
source [file join $::ahttpd::library cookie.tcl   ]
source [file join $::ahttpd::library fallback.tcl ]
source [file join $::ahttpd::library doc.tcl      ]
source [file join $::ahttpd::library docsubst.tcl ]
source [file join $::ahttpd::library dirlist.tcl  ]
source [file join $::ahttpd::library direct.tcl   ]
source [file join $::ahttpd::library template.tcl ]
source [file join $::ahttpd::library url.tcl      ]
source [file join $::ahttpd::library redirect.tcl ]
source [file join $::ahttpd::library debug.tcl    ]
source [file join $::ahttpd::library status.tcl   ]
source [file join $::ahttpd::library tclcrypt.tcl ]
source [file join $::ahttpd::library digest.tcl   ]
source [file join $::ahttpd::library passgen.tcl  ]
source [file join $::ahttpd::library auth.tcl     ]
source [file join $::ahttpd::library cgi.tcl      ]

