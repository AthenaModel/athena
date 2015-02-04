#-----------------------------------------------------------------------
# TITLE:
#    control.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Neighborhood Control API
#
#    This module is part of the political model.  It provides the
#    API for tactics that affect political support and neighborhood
#    control.
#
#-----------------------------------------------------------------------

snit::type ::athena::control {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        set adb $adb_
    }

    #-------------------------------------------------------------------
    # Public Methods
    
    # load
    #
    # Loads every actors' default supports into working_supports
    # for use during strategy execution.

    method load {} {
        $adb eval {
            DELETE FROM working_supports;

            INSERT INTO working_supports(n, a, supports)
            SELECT n, a, supports FROM nbhoods JOIN actors;
        }
    }

    # support a b nlist
    #
    # a        - An actor
    # b        - An actor a supports, or NULL
    # nlist    - List of neighborhoods in which a supports b

    method support {a b nlist} {
        # FIRST, handle SELF
        if {$b eq "SELF"} {
            set b $a
        }

        # NEXT, format the nlist clause
        set inClause "IN ('[join $nlist ',']')"

        # NEXT, update the working supports list
        $adb eval "
            UPDATE working_supports
            SET supports = nullif(\$b,'NONE')
            WHERE a = \$a AND n $inClause
        "
    }

    # save
    #
    # Save the actor supports back into the supports table, replacing
    # the previous values.

    method save {} {
        $adb eval {
            DELETE FROM supports_na;

            INSERT INTO supports_na(n, a, supports)
            SELECT n, a, supports FROM working_supports;

            DELETE FROM working_supports;
        }
    }

}
