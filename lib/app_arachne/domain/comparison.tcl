#-----------------------------------------------------------------------
# TITLE:
#   domain/comparison.tcl
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
#   /comparison: The smartdomain(n) for comparison data.
#
#-----------------------------------------------------------------------

oo::class create /comparison {
    superclass ::projectlib::smartdomain

    #-------------------------------------------------------------------
    # Constructor

    constructor {} {
        next /comparison

        # FIRST, configure the HTML buffer
        hb configure \
            -cssfile   "/athena.css"         \
            -headercmd [mymethod htmlHeader] \
            -footercmd [mymethod htmlFooter]
    }            

    #-------------------------------------------------------------------
    # Header and Footer

    method htmlHeader {hb title} {
        hb putln [athena::element header Arachne]
    }

    method htmlFooter {hb} {
        hb putln [athena::element footer]
    }

    #-------------------------------------------------------------------
    # Helper Methods

    # ValidateComp comp
    #
    # If comp is not a valid comparison, throws NOTFOUND.

    method ValidateComp {comp} {
        # FIRST, do we have the comparison?
        set comp [string tolower $comp]

        if {$comp ni [comp names]} {
            throw NOTFOUND "No such comparison: \"$comp\""
        }

        return $comp
    }

}

#-------------------------------------------------------------------
# General Content

smarturl /comparison /index.json {
    Returns a JSON list of comparison metadata objects.
} {
    set table [list]

    foreach id [comp names] {
        set cdict [comp metadata $id]

        lappend table $cdict
    }

    return [js dictab $table]
}

smarturl /comparison /new.json {
    Create a new comparison for the case with ID {case1} or for a 
    pair of cases {case1} and {case2}.  On success, returns
    <tt>['ok', <i>metadata</i>, <i>outputs</i>]</tt>, where 
    <i>metadata</i> is the metadata object for the new comparison, and
    <i>outputs</i> is the same list of "vardiff" objects returned by
    /comparison/{comp}/outputs.json.
} {
    qdict prepare case1 -required -tolower -in [case names]
    qdict prepare case2           -tolower -in [case names]

    qdict assign case1 case2

    if {![qdict ok]} {
        return [js reject [qdict errors]]
    }

    try {
        set id [comp new $case1 $case2]
    } trap ARACHNE {result} {
        return [js error $result]
    }

    set meta [huddle compile dict [comp metadata $id]]
    return [js ok $meta [comp with $id diffs huddle]]
}

smarturl /comparison /remove.json {
    Removes a comparison given its {comp} ID.  On success, returns
    <tt>['ok', '<i>message</i>']</tt>.
} {
    qdict prepare comp -required -tolower -in [comp names]
    qdict assign comp

    if {![qdict ok]} {
        return [js reject [qdict errors]]
    }

    comp remove $comp

    return [js ok "Deleted comparison $comp."]
}

smarturl /comparison /{comp}/index.json {
    Returns a list of the significant differences in comparison {comp}
    as "vardiff" objects.
    Initially this list will include only the significant outputs; as
    chains are explored, it will include the causality chains as well.
} {
    set comp [my ValidateComp $comp]

    return [huddle jsondump [comp with $comp diffs huddle]]
}

smarturl /comparison /{comp}/outputs.json {
    Returns a list of the significant outputs in the comparison {comp}
    as "vardiff" objects.  The list of significant outputs
    covers a set of primary output variables and is computed when the
    comparison is created.  To see all significant differences computed
    to date, use /comparison/{comp}/index.json; to see the causality
    chain for a single output, use /comparison/{comp}/chain.json.
} {
    set comp [my ValidateComp $comp]

    return [js error "Not implemented yet"]
}

smarturl /comparison /{comp}/chain.json {
    Returns a list of the significant inputs driving change in 
    a specific output variable {var}.  The list is recursive: we drill
    down as far as we can, producing a "causality chain".  The {var}
    must be one of the variables included in the list returned by
    /comparison/{comp}/index.json.
} {
    set comp [my ValidateComp $comp]

    return [js error "Not implemented yet"]
}

smarturl /comparison /{comp}/explain.json {
    Tries to explain the change in output variable {var} in
    human-readable terms, based on {var}'s causality chain.
    The {var}
    must be one of the variables included in the list returned by
    /comparison/{comp}/index.json.
} {
    set comp [my ValidateComp $comp]

    return [js error "Not implemented yet"]
}
