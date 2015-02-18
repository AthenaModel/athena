#-----------------------------------------------------------------------
# TITLE:
#    projtypes.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Athena Data Types
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::projectlib:: {
    namespace export     \
        boolean          \
        eabservice       \
        eabsit           \
        eactortype       \
        ebeanstate       \
        ecause           \
        ecivconcern      \
        ecomparator      \
        ecomparatorx     \
        econcern         \
        econdition_type  \
        econdition_state \
        ecurse_state     \
        edamruleset      \
        edemeanor        \
        eeconstate       \
        eforcetype       \
        egoal_state      \
        egoal_predicate  \
        ehousing         \
        einjectpart      \
        einject_state    \
        eiom_state       \
        emoveitem        \
        eorgtype         \
        epagesize        \
        epayload_state   \
        eservice         \
        esitstate        \
        etactic_state    \
        etraining        \
        etopic_state     \
        eurbanization    \
        eunitshape       \
        eunitsymbol      \
        eyesno           \
        iticks           \
        ident            \
        ingpopulation    \
        ioptdays         \
        ipercent         \
        ipositive        \
        iquantity        \
        latpt            \
        longpt           \
        leabsit          \
        money            \
        polygon          \
        projection       \
        qcredit          \
        qsecurity        \
        rdays            \
        rgain            \
        rnomcoverage     \
        rnonneg          \
        roleid           \
        rolemap          \
        rpercent         \
        rpercentpm       \
        rposfrac         \
        rrate            \
        typewrapper      \
        unitname         \
        weight
}

#-------------------------------------------------------------------
# Type Wrapper -- wraps snit::<type> instances so they throw
#                 -errorcode INVALID

# TBD: This is no longer strictly necessary; Snit types now have
# the correct behavior.

snit::type ::projectlib::typewrapper {
    #---------------------------------------------------------------
    # Components

    component basetype

    #---------------------------------------------------------------
    # Options

    delegate option * to basetype

    #---------------------------------------------------------------
    # Constructor

    # typewrapper newtype oldtype ?options....?

    constructor {oldtype args} {
        # FIRST, create the basetype, if need be.
        if {[llength $args] > 0} {
            set basetype [{*}$oldtype ${selfns}::basetype {*}$args]
        } else {
            set basetype $oldtype
        }
    }

    #---------------------------------------------------------------
    # Methods

    delegate method * to basetype


    # validate value
    #
    # value    A value of the type
    #
    # Validates the value, returning it if valid and throwing
    # -errorcode INVALID if not.

    method validate {value} {
        if {[catch {
            {*}$basetype validate $value
        } result]} {
            return -code error -errorcode INVALID $result
        }

        return $value
    }
}



#-------------------------------------------------------------------
# Enumerations

# Group activities

# Actor Types
::marsutil::enum ::projectlib::eactortype {
    NORMAL          "Normal"
    PSEUDO          "Pseudo-actor"
}

# Bean State (or, really, anything with these three states.)
::projectlib::enumx create ::projectlib::ebeanstate {
    normal     {color black    font codefont       }
    disabled   {color #999999  font codefontstrike }
    invalid    {color #C7001B  font codefontstrike }
}

# DAM Rule Sets
#
# TBD: this enum is now used only by parmdb.tcl to provide the rule set
# names for dam.$ruleset.*.  Once that is gone, remove it.
::marsutil::enum ::projectlib::edamruleset {
    ACCIDENT  "Accident"
    BADFOOD   "Contaminated Food Supply"
    BADWATER  "Contaminated Water Supply"
    CHKPOINT  "Checkpoint/Control Point"
    CIVCAS    "Civilian Casualties"
    COERCION  "Coercion"
    COMMOUT   "Communications Outage"
    CONSTRUCT "Construction"
    CONSUMP   "Consumption of Goods"
    CONTROL   "Shift in Control of Neighborhood"
    CRIME     "Criminal Activities"
    CULSITE   "Damage to Cultural Site/Artifact"
    CURFEW    "Curfew"
    CURSE     "CURSE Attitude Injects"
    DEMO      "Non-violent Demonstration"
    DISASTER  "Disaster"
    DISEASE   "Disease"
    DISPLACED "Displaced Persons"
    DROUGHT   "Long-term Drought"
    EDU       "Schools"
    EMPLOY    "Provide Employment"
    ENERGY    "Energy Infrastructure Services"
    ENI       "ENI Services"
    EPIDEMIC  "Epidemic"
    EXPLOSION "Explosion"
    FOODSHRT  "Food Shortage"
    FUELSHRT  "Fuel Shortage"
    GARBAGE   "Garbage in the Streets"
    GUARD     "Guard"
    INDSPILL  "Industrial Spill"
    INDUSTRY  "Support Industry"
    INFRA     "Support Infrastructure"
    IOM       "Info Ops Message"
    LAWENF    "Law Enforcement"
    MEDICAL   "Healthcare"
    MINEFIELD "Minefield"
    MOOD      "Civilian Mood Changes"
    ORDNANCE  "Unexploded Ordnance"
    ORGCAS    "Organization Casualties"
    PATROL    "Patrol"
    PIPELINE  "Oil Pipeline Fire"
    PSYOP     "PSYOP"
    REFINERY  "Oil Refinery Fire"
    RELIEF    "Humanitarian Relief"
    RELSITE   "Damage to Religious Site/Artifact"
    RIOT      "Riot"
    SEWAGE    "Sewage Spill"
    TRANSPORT "Transportation Services"
    UNEMP     "Unemployment"
    VIOLENCE  "Random Violence"
    WATER     "Potable Water"
}

# DAM Rule Set Causes
#
# NOTE: DEMO "Demonstration" is provided for use by CURSEs.
::marsutil::enum ::projectlib::ecause {
    CHKPOINT  "Checkpoint/Control Point"
    CIVCAS    "Civilian Casualties"
    COERCION  "Coercion"
    COMMOUT   "Communications Outage"
    CONSTRUCT "Construction"
    CONSUMP   "Consumption of Goods"
    CONTROL   "Shift in Control of Neighborhood"
    CRIME     "Criminal Activities"
    CULSITE   "Damage to Cultural Site/Artifact"
    CURFEW    "Curfew"
    DEMO      "Demonstration"
    DISASTER  "Disaster"
    DISPLACED "Displaced Persons"
    DROUGHT   "Long-term Drought"
    EDU       "Schools"
    EMPLOY    "Provide Employment"
    ENERGY    "Energy Infrastructure Services"
    ENI       "ENI Services"
    FUELSHRT  "Fuel Shortage"
    GARBAGE   "Garbage in the Streets"
    GUARD     "Guard"
    HUNGER    "Hunger"
    INDSPILL  "Industrial Spill"
    INDUSTRY  "Support Industry"
    INFRA     "Support Infrastructure"
    IOM       "Info Ops Message"
    LAWENF    "Law Enforcement"
    MAGIC     "Magic"
    MEDICAL   "Healthcare"
    MOOD      "Mood"
    ORDNANCE  "Unexploded Ordnance/Minefield"
    ORGCAS    "Organization Casualties"
    PATROL    "Patrol"
    PIPELINE  "Oil Pipeline Fire"
    PSYOP     "PSYOP"
    REFINERY  "Oil Refinery Fire"
    RELIEF    "Humanitarian Relief"
    RELSITE   "Damage to Religious Site/Artifact"
    SEWAGE    "Sewage Spill"
    SICKNESS  "Sickness"
    THIRST    "Thirst"
    TRANSPORT "Transportation Services"
    UNEMP     "Unemployment"
    WATER     "Potable Water"
}

# Civ group housing
::marsutil::enum ::projectlib::ehousing {
    AT_HOME    "At Home"
    DISPLACED  "Displaced"
    IN_CAMP    "In Camp"
}

# Training Levels
::marsutil::enum ::projectlib::etraining {
    PROFICIENT  "Proficient"
    FULL        "Fully Trained"
    PARTIAL     "Partially Trained"
    NONE        "Not Trained"
}

# Unit icon shape (per MIL-STD-2525B)
::marsutil::enum ::projectlib::eunitshape {
    FRIEND   "Friend"
    ENEMY    "Enemy"
    NEUTRAL  "Neutral"
}

# Unit icon symbols

::marsutil::enum ::projectlib::eunitsymbol {
    infantry       "Infantry"
    irregular      "Irregular Military"
    police         "Civilian Police"
    criminal       "Criminal"
    organization   "Organization"
    civilian       "Civilian"
}



# Concerns
::marsutil::enum ::projectlib::econcern {
    AUT "Autonomy"
    SFT "Physical Safety"
    CUL "Culture"
    QOL "Quality of Life"
}

# Civilian Group Demeanor
::marsutil::enum ::projectlib::edemeanor {
    APATHETIC  "Apathetic"
    AVERAGE    "Average"
    AGGRESSIVE "Aggressive"
}

# Econ Model State
::marsutil::enum ::projectlib::eeconstate {
    DISABLED  "Disabled"
    ENABLED   "Enabled"
}

# Force Group Type
::marsutil::enum ::projectlib::eforcetype {
    REGULAR        "Regular Military"
    PARAMILITARY   "Paramilitary"
    POLICE         "Police"
    IRREGULAR      "Irregular Military"
    CRIMINAL       "Organized Crime"
}


# Org Group Type
::marsutil::enum ::projectlib::eorgtype {
    NGO "Non-Governmental Organization"
    IGO "Intergovernmental Organization"
    CTR "Contractor"
}

# Services
::marsutil::enum ::projectlib::eservice {
    ENERGY     "Energy Infrastructure Services"
    ENI        "Essential Non-Infrastructure Services"
    TRANSPORT  "Transportation Services"
    WATER      "Potable Water"
}

# Abstract Infrastructure Services
::marsutil::enum ::projectlib::eabservice {
    ENERGY     "Energy Infrastructure Services"
    WATER      "Potable Water"
    TRANSPORT  "Transportation Services"
}

# Situation State
::marsutil::enum ::projectlib::esitstate {
    INITIAL  Initial
    ONGOING  Ongoing
    RESOLVED Resolved
}

# Goal State.

::marsutil::enum ::projectlib::egoal_state {
    normal   "normal"
    disabled "disabled"
    invalid  "invalid"
}

# IOM State.

::marsutil::enum ::projectlib::eiom_state {
    normal   "normal"
    disabled "disabled"
    invalid  "invalid"
}


# Tactic State

::marsutil::enum ::projectlib::etactic_state {
    normal   "normal"
    disabled "disabled"
    invalid  "invalid"
}

# Topic State

::marsutil::enum ::projectlib::etopic_state {
    normal   "normal"
    disabled "disabled"
    invalid  "invalid"
}

# Condition Type.  Conditions are attached to
# tactics (and possibly other things).

::marsutil::enum ::projectlib::econdition_type {
    CASH      "Cash-on-hand"
    GOAL      "Goal State"
}

# TBD: Add egoal_predicate: MET, UNMET

::marsutil::enum ::projectlib::egoal_predicate {
    MET   "Met"
    UNMET "Unmet"
}

# Condition State.

::marsutil::enum ::projectlib::econdition_state {
    normal   "normal"
    disabled "disabled"
    invalid  "invalid"
}


# Comparator Type.  Used in conditions.  It's a standard enumx plus
# the compare method.

::marsutil::enum ::projectlib::ecomparator {
    EQ "equal to"
    GE "greater than or equal to"
    GT "greater than"
    LE "less than or equal to"
    LT "less than"
}

::projectlib::enumx create ::projectlib::ecomparatorx {
    EQ {longname "equal to"                 }
    AE {longname "approximately equal to"   }
    GE {longname "greater than or equal to" }
    GT {longname "greater than"             }
    LE {longname "less than or equal to"    }
    LT {longname "less than"                }
} {
    method compare {x comp y} {
        switch -exact -- $comp {
            EQ      { return [expr {$x == $y}]         }
            AE      { return [my ApproxEqual $x $y] }
            GE      { return [expr {$x >= $y}]         }
            GT      { return [expr {$x >  $y}]         }
            LE      { return [expr {$x <= $y}]         }
            LT      { return [expr {$x <  $y}]         }
            default { error "Invalid comparator: \"$comp\"" }
        }
    }

    # ApproxEqual x y
    #
    # x    - A number
    # y    - A number
    #
    # Returns 1 if x is approximately equal to y, and 0 otherwise.

    method ApproxEqual {x y} {
        if {$x == $y} {
            return 1
        }

        set epsilon 0.000001

        if {abs($x - $y)/max(abs($x),abs($y)) < $epsilon} {
            return 1
        }

        return 0
    }
}

# emoveitem: Ways to move an item in a list

::projectlib::enumx create ::projectlib::emoveitem {
    top    {longname "Move To Top"   }
    up     {longname "Move Up"       }
    down   {longname "Move Down"     }
    bottom {longname "Move To Bottom"}
} {
    # move where list item
    #
    # where  - An emoveitem value
    # list   - A list
    # item   - An item in the list
    #
    # Moves the item in the list, and returns the new list.

    method move {where list item} {
        # FIRST, get item's position in the list.
        set index [lsearch -exact $list $item]

        # NEXT, get the new position
        let end {[llength $list] - 1}

        switch -exact -- $where {
            top     { set newpos 0                         }
            up      { let newpos {max(0,    $index - 1)}   }
            down    { let newpos {min($end, $index + 1)}   }
            bottom  { set newpos $end                      }
            default { error "Unknown movement: \"$where\"" }
        }

        # NEXT, if the item is already in its position, we're done.
        if {$newpos == $index} {
            return $list
        }

        # NEXT, put the item in its list.
        ldelete list $item
        set list [linsert $list $newpos $item]

        # FINALLY, return the new list.
        return $list
    }
}

# CURSE State.

::marsutil::enum ::projectlib::ecurse_state {
    normal   "normal"
    disabled "disabled"
    invalid  "invalid"
}

# CURSE Inject State

::marsutil::enum ::projectlib::einject_state {
    normal   "normal"
    disabled "disabled"
    invalid  "invalid"
}

# IOM Payload State

::marsutil::enum ::projectlib::epayload_state {
    normal   "normal"
    disabled "disabled"
    invalid  "invalid"
}


# Urbanization Level
::marsutil::enum ::projectlib::eurbanization {
    ISOLATED     "Isolated"
    RURAL        "Rural"
    SUBURBAN     "Suburban"
    URBAN        "Urban"
}

# Yes/No
::marsutil::enum ::projectlib::eyesno {
    YES    "Yes"
    NO     "No"
}

# The name is the rule set name, e.g., SEWAGE, and the 
# long name is the full name of the situation
::marsutil::enum ::projectlib::eabsit {
    BADFOOD     "Contaminated Food Supply"
    BADWATER    "Contaminated Water Supply"
    COMMOUT     "Communications Outage"
    CULSITE     "Damage To Cultural Site"
    DISASTER    "Disaster"
    DISEASE     "Disease"
    DROUGHT     "Long-term Drought"
    EPIDEMIC    "Epidemic"
    FOODSHRT    "Food Shortage"
    FUELSHRT    "Fuel Shortage"
    GARBAGE     "Garbage In The Streets"
    INDSPILL    "Industrial Spill"
    MINEFIELD   "Mine Field"
    ORDNANCE    "Unexploded Ordnance"
    PIPELINE    "Oil Pipeline Fire"
    REFINERY    "Oil Refinery Fire"
    RELSITE     "Damage To Religious Site"
    SEWAGE      "Sewage Spill"
}

# List of eabsit values
::projectlib::typewrapper ::projectlib::leabsit \
    snit::listtype -type ::projectlib::eabsit 

# Payload Part Types
::marsutil::enum ::projectlib::epayloadpart {
    COOP  "Cooperation with force group"
    HREL  "Horizontal relationship with group"
    SAT   "Satisfaction with concern"
    VREL  "Vertical relationship with actor"
}

# Curse Input Part Types
::marsutil::enum ::projectlib::einjectpart {
    COOP  "Coop. change"
    HREL  "Horiz. rel. change"
    SAT   "Sat. change"
    VREL  "Vert. rel. change"
}

# Page Sizes for paged myserver tables

::marsutil::enum ::projectlib::epagesize {
    ALL "All items"
    10  "10 items per page"
    20  "20 items per page"
    50  "50 items per page"
    100 "100 items per page"
} -noindex

#-------------------------------------------------------------------
# Qualities

# Credit
::marsutil::quality ::projectlib::qcredit {
    M   "Most"          0.50 0.75 1.00
    S   "Some"          0.20 0.35 0.50
    N   "Negligible"    0.00 0.10 0.20
} -bounds yes -format {%.2f}

# Security
::marsutil::quality ::projectlib::qsecurity {
    H    "High"         25  60  100
    M    "Medium"        5  15   25
    L    "Low"         -25 -10    5
    N    "None"       -100 -60  -25
} -bounds yes -format {%4d}


#-----------------------------------------------------------------------
# Integer Types

# iquantity: non-negative integers
::projectlib::typewrapper ::projectlib::iquantity snit::integer -min 0

# iminlines: Minimum value for prefs.maxlines
::projectlib::typewrapper ::projectlib::iminlines snit::integer -min 100

# ipositive: positive integers
::projectlib::typewrapper ::projectlib::ipositive snit::integer -min 1

# iticks: non-negative ticks
::projectlib::typewrapper ::projectlib::iticks snit::integer -min 0

# ioptdays: days with -1 as sentinal
::projectlib::typewrapper ::projectlib::ioptdays snit::integer -min -1

# ipercent: integer percentages
::projectlib::typewrapper ::projectlib::ipercent snit::integer -min 0 -max 100


#-------------------------------------------------------------------
# Ranges

# Ascending/Descending trends
::snit::double ::projectlib::ratrend -min 0.0
::snit::double ::projectlib::rdtrend -max 0.0

# Duration in decimal days

::marsutil::range ::projectlib::rdays \
    -min 0.0 -format "%.1f"

# Positive Fraction
::projectlib::typewrapper ::projectlib::rposfrac snit::double \
    -min 0.01 \
    -max 1.00

# Non-negative percentage
::projectlib::typewrapper ::projectlib::rpercent snit::double \
    -min   0.0 \
    -max 100.0 

# Positive or negative percentage
::projectlib::typewrapper ::projectlib::rpercentpm snit::double \
    -min -100.0 \
    -max  100.0 

# Gain setting
::marsutil::range ::projectlib::rgain -min 0.0

# Non-negative real number
::marsutil::range ::projectlib::rnonneg -min 0.0

# Rate setting
::marsutil::range ::projectlib::rrate -min 0.0

# Expectations factor
::projectlib::typewrapper ::projectlib::expectf snit::double \
    -min -3.0 \
    -max  3.0

#-------------------------------------------------------------------
# Boolean type
#
# This differs from the snit::boolean type in that it throws INVALID.

snit::type ::projectlib::boolean {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Public Type Methods

    # validate flag
    #
    # flag    Possibly, a boolean value
    #
    # Returns 1 for true and 0 for false.

    typemethod validate {flag} {
        if {[catch {snit::boolean validate $flag} result]} {
            return -code error -errorcode INVALID $result
        }

        if {$flag} {
            return 1
        } else {
            return 0
        }
    }
}

#-----------------------------------------------------------------------
# ident type

snit::type ::projectlib::ident {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Public Type Methods

    # validate name
    #
    # name    Possibly, an identifier
    #
    # Identifiers should begin with a letter, and contain only letters
    # and digits. Identifiers that begin with "@" are allowed.

    typemethod validate {name} {
        if {![regexp {^[A-Z][A-Z0-9]*$} $name]} {
            return -code error -errorcode INVALID \
  "Identifiers begin with a letter and contain only letters and digits."
        }

        return $name
    }
}

#-----------------------------------------------------------------------
# roleid type

snit::type ::projectlib::roleid {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Public Type Methods

    # validate name
    #
    # name    Possibly, a role identifier
    #
    # Role identifiers should begin with "@", and contain only letters
    # and digits. 

    typemethod validate {name} {
        if {![regexp {^[@]?[A-Z]+[A-Z0-9]*$} $name]} {
            return -code error -errorcode INVALID \
  "Role identifiers begin with optional \"@\" followed by a letter and contain only letters and digits."
        }

        if {[string range $name 0 0] ne "@"} {
            return "@$name"
        }

        return $name
    }
}


snit::type ::projectlib::unitname {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Public Type Methods

    # validate name
    #
    # name    Possibly, a unit name
    #
    # Unit names should begin with a letter, and contain only letters,
    # digits, "-", and "/"

    typemethod validate {name} {
        if {![regexp {^[A-Z][A-Z0-9/\-]*$} $name]} {
            return -code error -errorcode INVALID \
  "Unit names begin with a letter and contain only letters, digits, - and /."
        }

        return $name
    }
}

snit::type ::projectlib::latpt {
    pragma -hasinstances no

    typemethod validate {value} {
        if {[catch {latlong validate [list $value 0.0]} result]} {
            return -code error -errorcode INVALID $result
        }

        return $value
    }
}

snit::type ::projectlib::longpt {
    pragma -hasinstances no

    typemethod validate {value} {
        if {[catch {latlong validate [list 0.0 $value]} result]} {
            return -code error -errorcode INVALID $result
        }

        return $value 
    }
}

snit::type ::projectlib::projection {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Public Type Methods

    # validate value
    #
    # value    Possibly, a valid projection dictionary
    #
    # The structure of a projection dictionary depends on the projection
    # type. All projection types are validated in this method.

    typemethod validate {value} {
        if {[llength $value] == 0} {
            return -code error -errorcode INVALID "$value: no data."
        }

        if {[catch {dict keys $value} result]} {
            return -code error -errorcode INVALID "$value: not a dictionary."
        }

        if {![dict exists $value ptype]} {
            return -code error -errorcode INVALUE \
                "$value: missing \"ptype\" key."
        }

        set errmsg {}

        # All projections must have a width and height
        if {![dict exists $value width]} {
            lappend errmsg "Missing \"width\" key."
        }

        if {![dict exists $value height]} {
            lappend errmsg "Missing \"height\" key."
        }

        if {[llength $errmsg] > 0} {
            set msg [join $errmsg ", "]
            return -code error -errorcode INVALID "$value: $msg"
        }
                
        # Projection specific checks
        switch -exact -- [dict get $value ptype] {
            RECT {
                if {![dict exists $value minlon]} {
                    lappend errmsg "Missing \"minlon\" key."
                }

                if {![dict exists $value minlat]} {
                    lappend errmsg "Missing \"minlat\" key."
                }

                if {![dict exists $value maxlon]} {
                    lappend errmsg "Missing \"maxlon\" key."
                }

                if {![dict exists $value maxlat]} {
                    lappend errmsg "Missing \"maxlat\" key."
                }

                if {[llength $errmsg] > 0} {
                    set msg [join $errmsg ", "]
                    return -code error -errorcode INVALID "$value: $msg"
                }

                dict with value {}

                if {[catch {
                    latlong validate [list $minlat $minlon]
                    latlong validate [list $maxlat $maxlon]
                } result ]} {
                    return -code error -errorcode INVALID "$value: $result"
                }
            }

            default {
                return -code error -errorcode INVALID \
                    "Unrecognized projection type: $ptype"
            }
        }

        return $value
    }
}

#-----------------------------------------------------------------------
# polygon type

snit::type ::projectlib::polygon {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Public Type Methods

    # validate coords...
    #
    # coords      A list {x1 y1 x2 y2 x3 y3 ....} of vertices
    #
    # Validates the polygon.  The polygon is valid if:
    #
    # * It has at least three points
    # * There are no duplicated points
    # * No edge intersects any other edge
    #
    # The coordinates can be passed as a single list, or as
    # individual arguments.

    typemethod validate {args} {
        # FIRST, get the coordinate list if passed as one arg.
        if {[llength $args] == 1} {
            set coords [lindex $args 0]
        } else {
            set coords $args
        }

        # NEXT, check the number of coordinates
        set len [llength $coords]
        if {$len % 2 != 0} {
            return -code error -errorcode INVALID \
                "expected even number of coordinates, got $len"
        }

        let size {$len/2}
        if {$size < 3} {
            return -code error -errorcode INVALID \
                "expected at least 3 point(s), got $size"
        }

        # NEXT, check for duplicated points
        for {set i 0} {$i < $len} {incr i 2} {
            for {set j 0} {$j < $len} {incr j 2} {
                if {$i == $j} {
                    continue
                }
                
                lassign [lrange $coords $i $i+1] x1 y1
                lassign [lrange $coords $j $j+1] x2 y2
                
                if  {$x1 == $x2 && $y1 == $y2} {
                    return -code error -errorcode INVALID \
                     "Point [expr {$i/2}] is identical to point [expr {$j/2}]"
                }
            }
        }
        
        # NEXT, check for edge crossings.  Consecutive edges can
        # intersect at their end points.
        set n [clength $coords]
        
        for {set i 0} {$i < $n} {incr i} {
            for {set j [expr {$i + 2}]} {$j <= $i + $n - 2} {incr j} {
                set e1 [cedge $coords $i]
                set e2 [cedge $coords $j]

                set p1 [lrange $e1 0 1]
                set p2 [lrange $e1 2 3]
                set q1 [lrange $e2 0 1]
                set q2 [lrange $e2 2 3]

                if {[intersect $p1 $p2 $q1 $q2]} {
                    return -code error -errorcode INVALID \
                        "Edges $i and $j intersect"
                }
            }
        }


        return $coords
    }
}

#-------------------------------------------------------------------
# Weight type
#
# A weight is a non-negative floating point number.  
# This differs from the snit::double type in that it throws INVALID.

snit::type ::projectlib::weight {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type constructor

    typeconstructor {
        snit::double ${type}::imptype -min 0.0
    }

    #-------------------------------------------------------------------
    # Public Type Methods

    # validate value
    #
    # value    Possibly, a weight value
    #
    # Returns 1 for true and 0 for false.

    typemethod validate {value} {
        if {[catch {imptype validate $value} result]} {
            return -code error -errorcode INVALID $result
        }

        return $value
    }
}

#-----------------------------------------------------------------------
# Rolemap type
#
# A rolemap must be a list with a rolename mapping to a gofer dictionary.

snit::type ::projectlib::rolemap {
    # Singleton
    pragma -hasinstances no

    # validate value
    #
    # value    Possibly, a rolemap dictionary
    #
    # Returns an error on failure, the value on success

    typemethod validate {value} {
        if {[llength $value] == 0} {
            return -code error -errorcode INVALID "$value: no data"
        }

        if {[catch {dict keys $value} result]} {
            return -code error -errorcode INVALID "$value: not a dictionary"
        }

        set rmap [list]
        foreach {role goferdict} $value {
            set gdict [gofer validate $goferdict]
            lappend rmap $role $gdict
        }

        return $rmap
    }
}

#-----------------------------------------------------------------------
# Money type

# A money value is a string defined as for marsutil::moneyscan.  It is
# converted to a real number.

snit::type ::projectlib::money {
    pragma -hasinstances no

    typemethod validate {value} {
        if {[catch {
            set newValue [::marsutil::moneyscan $value]
        } result]} {
            set scanErr 1
        } else {
            set scanErr 0
        }

        if {$scanErr || $newValue < 0.0} {
            return -code error -errorcode INVALID \
                "invalid money value \"$value\", expected positive numeric value with optional K, M, or B suffix"
        }

        return $newValue
    }
}

#-----------------------------------------------------------------------
# Posmoney type

# A positive money value is a string defined as for marsutil::moneyscan.  
# It is converted to a real number. It must be greater than zero.

snit::type ::projectlib::posmoney {
    pragma -hasinstances no

    typemethod validate {value} {
        if {[catch {
            set newValue [::marsutil::moneyscan $value]
        } result]} {
            set scanErr 1
        } else {
            set scanErr 0
        }

        if {$scanErr || $newValue <= 0.0} {
            return -code error -errorcode INVALID \
                "invalid money value \"$value\", expected numeric value > 0 with optional K, M, or B suffix"
        }

        return $newValue
    }
}



