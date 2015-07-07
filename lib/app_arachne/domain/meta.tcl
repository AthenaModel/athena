#-----------------------------------------------------------------------
# TITLE:
#   domain/meta.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# PACKAGE:
#   app_arachne(n): Arachne Implementation Package
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   /meta.json: Arachne metadata.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# FIRST, define the domain.

set /meta.json application/json

proc /meta.json {} {
    return [subst -nobackslashes -novariables {
{
    "version":   "[app version]",
    "startTime": "[expr {[app startTime]*1000}]"
}
    }]    
}



