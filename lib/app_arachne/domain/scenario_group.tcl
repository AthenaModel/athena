#-----------------------------------------------------------------------
# TITLE:
#   domain/scenario_group.tcl
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
#   smartdomain(n) and return data related to groups found within a
#   particular Arachne case.
#
#   Additional URLs are defined in domain/scenario_*.tcl.
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# General Content


smarturl /scenario /{case}/group/index.json {
    Returns JSON data for all groups in scenario <i>case</i>.
} {
    set case [my ValidateCase $case]

    set table [list]

    foreach g [case with $case group names] {
        set gdict [case with $case group view $g web]
        set qid   [dict get $gdict qid]
        set a_qid [dict get $gdict a_qid]

        # NEXT, format URLs properly
        dict set gdict url [my domain $case $qid "index.json"]
        if {$a_qid ne ""} {
            dict set gdict a_url [my domain $case $a_qid "index.json"]
        } 
        
        lappend table $gdict
    }

    return [js dictab $table]
}

smarturl /scenario /{case}/group/{g}/index.json {
    Returns JSON list of civilian group data for scenario <i>case</i> and 
    group <i>g</i>.
} {
    set g [my ValidateGroup $case $g]

    set gtype [case with $case group gtype $g]

    if {$gtype eq "CIV"} {
        set gdict [case with $case civgroup view $g web]
        set qid   [dict get $gdict qid] 
        set n_qid [dict get $gdict n_qid]

        # NEXT, format URLs properly
        dict set gdict url   [my domain $case $qid   "index.json"]
        dict set gdict n_url [my domain $case $n_qid "index.json"]
    } elseif {$gtype eq "ORG"} {
        set gdict [case with $case orggroup view $g web]
        set qid   [dict get $gdict qid]
        set a_qid [dict get $gdict a_qid]

        # NEXT, format URLs properly
        dict set gdict url [my domain $case $qid "index.json"]
        if {$a_qid ne ""} {
            dict set gdict a_url [my domain $case $a_qid "index.json"]
        } 
    } elseif {$gtype eq "FRC"} {
        set gdict [case with $case frcgroup view $g web]
        set qid   [dict get $gdict qid]
        set a_qid [dict get $gdict a_qid]

        # NEXT, format URLs properly
        dict set gdict url [my domain $case $qid "index.json"]

        if {$a_qid ne ""} {
            dict set gdict a_url [my domain $case $a_qid "index.json"]
        } 
    }

    return [js dictab [list $gdict]]
}

#----------------------------------------------------------------------
# CIV group content

smarturl /scenario /{case}/group/civ.json {
    Returns a JSON list of civilian group entities in the <i>case</i> 
    specified.
} {
    set case [my ValidateCase $case]

    set table [list]

    foreach g [case with $case civgroup names] {
        set cdict [case with $case civgroup view $g web]
        set qid   [dict get $cdict qid]
        set n_qid [dict get $cdict n_qid]

        # NEXT, format URLs properly
        dict set cdict url    [my domain $case $qid "index.json"]
        dict set cdict n_url  [my domain $case $n_qid "index.json"]

        lappend table $cdict
    }

    return [js dictab $table]
}

#----------------------------------------------------------------------
# FRC group content

smarturl /scenario /{case}/group/frc.json {
    Returns a JSON list of force group entities in the <i>case</i> specified.
} {
    set case [my ValidateCase $case]

    set table [list]

    foreach g [case with $case frcgroup names] {
        set fdict [case with $case frcgroup view $g web]
        set qid   [dict get $fdict qid]
        set a_qid [dict get $fdict a_qid]

        # NEXT, format URLs properly
        dict set fdict url [my domain $case $qid "index.json"]
        if {$a_qid ne ""} {
            dict set fdict a_url [my domain $case $a_qid "index.json"]
        }

        lappend table $fdict
    }

    return [js dictab $table]
}

#--------------------------------------------------------------------------
# ORG group content

smarturl /scenario /{case}/group/org.json {
    Returns a JSON list of organization group entities in the <i>case</i> 
    specified.
} {
    set case [my ValidateCase $case]

    set table [list]

    foreach g [case with $case orggroup names] {
        set odict [case with $case orggroup view $g web]
        set qid   [dict get $odict qid]
        set a_qid [dict get $odict a_qid]

        # NEXT, format URLs properly
        dict set odict url [my domain $case $qid "index.json"]
        if {$a_qid ne ""} {
            dict set odict a_url [my domain $case $a_qid "index.json"]
        }

        lappend table $odict
    }

    return [js dictab $table]
}

