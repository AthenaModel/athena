#-----------------------------------------------------------------------
# TITLE:
#    ptype.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): order parameter validation types.
#
#    This module gathers together a number of validation types used
#    for validating orders.  The notion is that instead of each
#    order module defining a slew of validation types, we'll 
#    accumulate them here.
#
#    Note that some types, such as "civgroup validate", will continue
#    to be defined by the respective modules.  But peculiar types,
#    like "civg+all" (all civilian groups plus "ALL") will be defined
#    here.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# ptype

snit::type ::athena::ptype {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of this type.

    constructor {adb_} {
        set adb $adb_
    }

    # a+none
    #
    # Actor names + NONE

    method {a+none names} {} {
        linsert [$adb actor names] 0 NONE
    }

    method {a+none validate} {value} {
        EnumVal "actor" [$self a+none names] $value
    }

    # a+self+none
    #
    # SELF + NONE + Actor names

    method {a+self+none names} {} {
        linsert [$adb actor names] 0 SELF NONE
    }

    method {a+self+none validate} {value} {
        EnumVal "actor" [$self a+self+none names] $value
    }


    # n
    #
    # Neighborhood names

    method {n names} {} {
        $adb nbhood names
    }

    method {n validate} {value} {
        EnumVal "neighborhood" [$self n names] $value
    }


    # n+all
    #
    # Neighborhood names + ALL

    method {n+all names} {} {
        linsert [$adb nbhood names] 0 ALL
    }

    method {n+all validate} {value} {
        EnumVal "neighborhood" [$self n+all names] $value
    }


    # fog
    #
    # Force/ORG group names

    method {fog names} {} {
        lsort [concat [$adb frcgroup names] [$adb orggroup names]]
    }

    method {fog namedict} {} {
        $adb eval {
            SELECT g, longname
            FROM groups
            WHERE gtype IN ('FRC', 'ORG')
            ORDER BY g
        }
    }


    method {fog validate} {value} {
        EnumVal "force/org group" [$self fog names] $value
    }

    # g+none
    #
    # Group names + NONE

    method {g+none names} {} {
        linsert [$adb group names] 0 NONE
    }

    method {g+none validate} {value} {
        EnumVal "group" [$self g+none names] $value
    }


    # g+all
    #
    # Group names + ALL

    method {g+all names} {} {
        linsert [lsort [$adb group names]] 0 ALL
    }

    method {g+all validate} {value} {
        EnumVal "group" [$self g+all names] $value
    }


    # goa
    #
    # Group names + Actor names

    method {goa names} {} {
        lsort [concat [$adb group names] [$adb actor names]]
    }

    method {goa namedict} {} {
        $adb eval {
            SELECT g as x, longname
            FROM groups
            UNION
            SELECT a as x, longname
            FROM actors
            ORDER BY x
        }
    }

    method {goa validate} {value} {
        EnumVal "Group/Actor" [$self goa names] $value
    }


    # civg+all
    #
    # Civilian group names + ALL

    method {civg+all names} {} {
        linsert [$adb civgroup names] 0 ALL
    }

    method {civg+all validate} {value} {
        EnumVal "civilian group" [$self civg+all names] $value
    }


    # frcg+none
    #
    # Force group names + NONE
    
    method {frcg+none names} {} {
        linsert [$adb frcgroup names] 0 NONE
    }

    method {frcg+none validate} {value} {
        EnumVal "force group" [$self frcg+none names] $value
    }

    # frcg+all
    #
    # Force group names + ALL

    method {frcg+all names} {} {
        linsert [$adb frcgroup names] 0 ALL
    }

    method {frcg+all validate} {value} {
        EnumVal "force group" [$self frcg+all names] $value
    }


    # orgg+all
    #
    # Organization group names + ALL

    method {orgg+all names} {} {
        linsert [$adb orggroup names] 0 ALL
    }

    method {orgg+all validate} {value} {
        EnumVal "organization group" [$self orgg+all names] $value
    }

    # fog+all
    #
    # Force/ORG group names + ALL

    method {fog+all names} {} {
        linsert [lsort [concat \
                    [$adb frcgroup names] [$adb orggroup names]]] 0 ALL
    }

    method {fog+all validate} {value} {
        EnumVal "force/org group" [$self fog+all names] $value
    }

    # c
    #
    # Concern names

    method {c names} {} {
        $adb eval {SELECT c FROM concerns}
    }

    method {c validate} {value} {
        EnumVal "concern" [$self c names] $value
    }

    # c+mood
    #
    # Concern names, plus "MOOD"

    method {c+mood names} {} {
        linsert [$self c names] 0 MOOD
    }

    method {c+mood validate} {value} {
        EnumVal "concern" [$self c+mood names] $value
    }

    # ecause+unique
    #
    # All ecause values, plus "UNIQUE"

    method {ecause+unique names} {} {
        linsert [ecause names] 0 UNIQUE
    }

    method {ecause+unique validate} {value} {
        EnumVal "cause" [$self ecause+unique names] $value
    }

    # orga
    #
    # All assignable org unit activities

    method {orga names} {} {
        $adb activity org names
    }

    method {orga validate} {value} {
        EnumVal "organization activity" [$self orga names] $value
    }

    # frca
    #
    # All assignable force unit activities

    method {frca names} {} {
        $adb activity frc names
    }

    method {frca validate} {value} {
        EnumVal "force activity" [$self frca names] $value
    }

    # prox-HERE
    #
    # All proximities but HERE

    method {prox-HERE names} {} {
        lrange [eproximity names] 1 end
    }

    method {prox-HERE validate} {value} {
        EnumVal "proximity" [$self prox-HERE names] $value
    }

    # sam 
    #
    # All Social Accounting Matrix (SAM) cell names

    method {sam names} {} {
        $adb econ samcells
    }

    method {sam validate} {value} {
        EnumVal "SAM cell" [$self sam names] $value
    }

    # cge
    #
    # All Computible General Equilibrim (CGE) cell names

    method {cge names} {} {
        $adb econ cgecells
    }

    method {cge validate} {value} {
        EnumVal "CGE cell" [$self cge names] $value
    }

    #-------------------------------------------------------------------
    # Helper Routines

    # EnumVal ptype enum value
    #
    # ptype    Parameter type
    # enum     List of valid values
    # value    Value to validate
    #
    # Validates the value, returning it, or throws a good error message.

    proc EnumVal {ptype enum value} {
        if {$value ni $enum} {
            set enum [join $enum ", "]
            return -code error -errorcode INVALID \
                "Invalid $ptype \"$value\", should be one of: $enum"
        }

        return $value
    }
}

