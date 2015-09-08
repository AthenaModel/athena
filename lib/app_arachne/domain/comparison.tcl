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
            -cssfiles  {/athena.css}         \
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
    Returns a JSON list of comparison objects.
    (<link "/arachne.html#/comparison/index.json" spec>)    
} {
    set table [huddle list]

    foreach id [comp names] {
        huddle append table [comp huddle $id]
    }

    return [huddle jsondump $table]
}

smarturl /comparison /request.json {
    Requests a comparison object for the case with ID <i>case1</i> or for a 
    pair of cases <i>case1</i> and <i>case2</i>.  
    (<link "/arachne.html#/comparison/request.json" spec>)    
} {
    qdict prepare case1 -required -tolower -in [case names]
    qdict prepare case2           -tolower -in [case names]

    qdict assign case1 case2

    if {![qdict ok]} {
        return [js reject [qdict errors]]
    }

    try {
        set id [comp get $case1 $case2]
    } trap ARACHNE {result} {
        return [js error $result]
    }

    return [js ok [comp huddle $id]]
}

smarturl /comparison /chain.json {
    Returns a list of the significant inputs driving change in 
    a specific output variable <i>varname</i> in comparison <i>comp</i>.  
    (<link "/arachne.html#/comparison/request.json" spec>)    
} {
    qdict prepare comp    -required -type comp

    if {![qdict ok]} {
        return [js reject [qdict errors]]
    }
    qdict assign comp

    qdict prepare varname -required -type [list comp with $comp]
    qdict assign varname


    return [js ok [comp with $comp chain huddle $varname]]
}
