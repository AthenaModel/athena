#-----------------------------------------------------------------------
# TITLE:
#    ptype.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): order parameter validation types.
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

snit::type ptype {
    pragma -hasinstances no

    # a+none
    #
    # Actor names + NONE

    typemethod {a+none names} {} {
        linsert [actor names] 0 NONE
    }

    typemethod {a+none validate} {value} {
        EnumVal "actor" [$type a+none names] $value
    }

    # a+self+none
    #
    # SELF + NONE + Actor names

    typemethod {a+self+none names} {} {
        linsert [actor names] 0 SELF NONE
    }

    typemethod {a+self+none validate} {value} {
        EnumVal "actor" [$type a+self+none names] $value
    }


    # n
    #
    # Neighborhood names

    typemethod {n names} {} {
        nbhood names
    }

    typemethod {n validate} {value} {
        EnumVal "neighborhood" [$type n names] $value
    }


    # n+all
    #
    # Neighborhood names + ALL

    typemethod {n+all names} {} {
        linsert [nbhood names] 0 ALL
    }

    typemethod {n+all validate} {value} {
        EnumVal "neighborhood" [$type n+all names] $value
    }


    # fog
    #
    # Force/ORG group names

    typemethod {fog names} {} {
        lsort [concat [frcgroup names] [orggroup names]]
    }

    typemethod {fog namedict} {} {
        rdb eval {
            SELECT g, longname
            FROM groups
            WHERE gtype IN ('FRC', 'ORG')
            ORDER BY g
        }
    }


    typemethod {fog validate} {value} {
        EnumVal "force/org group" [$type fog names] $value
    }

    # g+none
    #
    # Group names + NONE

    typemethod {g+none names} {} {
        linsert [group names] 0 NONE
    }

    typemethod {g+none validate} {value} {
        EnumVal "group" [$type g+none names] $value
    }


    # g+all
    #
    # Group names + ALL

    typemethod {g+all names} {} {
        linsert [lsort [group names]] 0 ALL
    }

    typemethod {g+all validate} {value} {
        EnumVal "group" [$type g+all names] $value
    }


    # goa
    #
    # Group names + Actor names

    typemethod {goa names} {} {
        lsort [concat [group names] [actor names]]
    }

    typemethod {goa namedict} {} {
        rdb eval {
            SELECT g as x, longname
            FROM groups
            UNION
            SELECT a as x, longname
            FROM actors
            ORDER BY x
        }
    }

    typemethod {goa validate} {value} {
        EnumVal "Group/Actor" [$type goa names] $value
    }


    # civg+all
    #
    # Civilian group names + ALL

    typemethod {civg+all names} {} {
        linsert [civgroup names] 0 ALL
    }

    typemethod {civg+all validate} {value} {
        EnumVal "civilian group" [$type civg+all names] $value
    }


    # frcg+none
    #
    # Force group names + NONE
    
    typemethod {frcg+none names} {} {
        linsert [frcgroup names] 0 NONE
    }

    typemethod {frcg+none validate} {value} {
        EnumVal "force group" [$type frcg+none names] $value
    }

    # frcg+all
    #
    # Force group names + ALL

    typemethod {frcg+all names} {} {
        linsert [frcgroup names] 0 ALL
    }

    typemethod {frcg+all validate} {value} {
        EnumVal "force group" [$type frcg+all names] $value
    }


    # orgg+all
    #
    # Organization group names + ALL

    typemethod {orgg+all names} {} {
        linsert [orggroup names] 0 ALL
    }

    typemethod {orgg+all validate} {value} {
        EnumVal "organization group" [$type orgg+all names] $value
    }

    # fog+all
    #
    # Force/ORG group names + ALL

    typemethod {fog+all names} {} {
        linsert [lsort [concat [frcgroup names] [orggroup names]]] 0 ALL
    }

    typemethod {fog+all validate} {value} {
        EnumVal "force/org group" [$type fog+all names] $value
    }

    # c
    #
    # Concern names

    typemethod {c names} {} {
        rdb eval {SELECT c FROM concerns}
    }

    typemethod {c validate} {value} {
        EnumVal "concern" [$type c names] $value
    }

    # c+mood
    #
    # Concern names, plus "MOOD"

    typemethod {c+mood names} {} {
        linsert [ptype c names] 0 MOOD
    }

    typemethod {c+mood validate} {value} {
        EnumVal "concern" [$type c+mood names] $value
    }

    # ecause+unique
    #
    # All ecause values, plus "UNIQUE"

    typemethod {ecause+unique names} {} {
        linsert [ecause names] 0 UNIQUE
    }

    typemethod {ecause+unique validate} {value} {
        EnumVal "cause" [$type ecause+unique names] $value
    }

    # civa
    #
    # All assignable civilian unit activities

    typemethod {civa names} {} {
        activity civ names
    }

    typemethod {civa validate} {value} {
        EnumVal "civilian activity" [$type civa names] $value
    }

    # orga
    #
    # All assignable org unit activities

    typemethod {orga names} {} {
        activity org names
    }

    typemethod {orga validate} {value} {
        EnumVal "organization activity" [$type orga names] $value
    }


    # frca
    #
    # All assignable force unit activities

    typemethod {frca names} {} {
        activity frc names
    }

    typemethod {frca validate} {value} {
        EnumVal "force activity" [$type frca names] $value
    }

    # prox-HERE
    #
    # All proximities but HERE

    typemethod {prox-HERE names} {} {
        lrange [eproximity names] 1 end
    }

    typemethod {prox-HERE validate} {value} {
        EnumVal "proximity" [$type prox-HERE names] $value
    }

    # sam 
    #
    # All Social Accounting Matrix (SAM) cell names

    typemethod {sam names} {} {
        econ samcells
    }

    typemethod {sam validate} {value} {
        EnumVal "SAM cell" [$type sam names] $value
    }

    # cge
    #
    # All Computible General Equilibrim (CGE) cell names

    typemethod {cge names} {} {
        econ cgecells
    }

    typemethod {cge validate} {value} {
        EnumVal "CGE cell" [$type cge names] $value
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

