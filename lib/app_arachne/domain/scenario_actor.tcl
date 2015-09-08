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
#   This set of URLs are defined with the context of the /scenario 
#   smartdomain(n) and return data related to actors found within a
#   particular Arachne case.
#
#   Additional URLs are defined in domain/scenario_*.tcl.
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# General Content



smarturl /scenario /{case}/actors/index.json {
    Returns a JSON list of actor entities in the <i>case</i> specified.
    (<link "/arachne.html#/scenario/case/actors/index.json" spec>)    
} {
    set case [my ValidateCase $case]

    set table [list]

    foreach a [case with $case actor names] {
        set adict [case with $case actor view $a web]

        dict with adict {}

        # NEXT, format URLs properly
        dict set adict url [my domain $case $qid "index.json"]
        if {$supports_qid ne ""} {
            dict set adict supports_url \
                [my domain $case $supports_qid "index.json"]
        }

        lappend table $adict
    }

    return [js dictab $table]
}

smarturl /scenario /{case}/actor/{a}/index.json {
    Returns a JSON object of actor data for scenario <i>case</i> and actor 
    <i>a</i>.
    (<link "/arachne.html#/scenario/case/actor/a/index.json" spec>)    
} {
    # FIRST, validate case and actor 
    set a [my ValidateActor $case $a]

    set adict [case with $case actor view $a web]

    set qid          [dict get $adict qid]
    set supports_qid [dict get $adict supports_qid]

    # NEXT, format URLs properly
    dict set adict url [my domain $case $qid "index.json"]
    if {$supports_qid ne ""} {
        dict set adict supports_url \
            [my domain $case $supports_qid "index.json"]
    }


    return [js dictab [list $adict]]
}





