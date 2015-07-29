#-----------------------------------------------------------------------
# TITLE:
#   domain/scenario_nbhood.tcl
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
#   This set of URLs are defined with the context of the /scenario 
#   smartdomain(n) and return data related to nbhoods found within a
#   particular Arachne case.
#
#   Additional URLs are defined in domain/scenario_*.tcl.
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# General Content

smarturl /scenario /{case}/nbhoods/index.json {
    Returns a JSON list of nbhood entities in the <i>case</i> specified.
} {
    set case [my ValidateCase $case]

    set table [list]

    foreach n [case with $case nbhood names] {
        set ndict [case with $case nbhood view $n web]
        set qid            [dict get $ndict qid]
        set controller_qid [dict get $ndict controller_qid]

        dict set ndict url [my domain $case $qid "index.json"]
        if {$controller_qid ne ""} {
            dict set ndict controller_url \
                [my domain $case $controller_qid "index.json"]
        }

        lappend table $ndict
    }

    return [js dictab $table]
}

smarturl /scenario /{case}/nbhood/{n}/index.json {
    Returns JSON list of actor data for scenario <i>case</i> and neighborhood 
    <i>n</i>.
} {
    set n [my ValidateNbhood $case $n]

    set ndict [case with $case nbhood view $n web]

    set qid            [dict get $ndict qid]
    set controller_qid [dict get $ndict controller_qid]

    dict set ndict url [my domain $case $qid "index.json"]

    if {$controller_qid != ""} {
        dict set ndict controller_url \
            [my domain $case $controller_qid "index.json"]
    }

    return [js dictab [list $ndict]]
}





