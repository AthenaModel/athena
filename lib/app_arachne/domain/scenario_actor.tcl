#-----------------------------------------------------------------------
# TITLE:
#   domain/scenario_actor.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# PACKAGE:
#   app_arachne(n): Arachne Implementation Package
#
# AUTHOR:
#   Dave Hanks
#
# DESCRIPTION:
#   /scenario: The smartdomain(n) for scenario data.
#
#   Additional URLs are defined in domain/scenario_*.tcl.
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# General Content

smarturl /scenario /{name}/actor/index.html {
    Displays a list of actor entities, with links to the actual actors.
} {
    # FIRST, do we have the scenario?
    set name [string tolower $name]

    if {$name ni [case names]} {
        throw NOTFOUND "No such scenario: \"$name\""
    }

    hb page "Actors"
    hb h1 "Actors"

    hb para

    hb table -headers {
        "ID"
    } {
        foreach actor [case with $name actor names] {
            hb tr {
                hb td [case with $name actor get $actor longname]
            }
        }
    }
    hb para

    return [hb /page]
}






