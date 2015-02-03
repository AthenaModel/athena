#-----------------------------------------------------------------------
# TITLE:
#    activity.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Unit Activity module
#
#    This module is responsible for defining and validating the
#    different categories of unit activities.
#
# TBD: Global ref: group
#
#-----------------------------------------------------------------------

snit::type ::athena::activity {
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
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.

    # names
    #
    # Returns the list of all activity names

    method names {} {
        set names [$adb eval {
            SELECT a FROM activity
        }]
    }


    # validate a
    #
    # a         Possibly, an activity ID
    #
    # Validates an activity ID

    method validate {a} {
        if {![$adb exists {SELECT a FROM activity WHERE a=$a}]} {
            set names [join [$self names] ", "]

            return -code error -errorcode INVALID \
                "Invalid activity, should be one of: $names"
        }

        return $a
    }

    # frc names
    #
    # Returns the list of activities assignable to force units

    method {frc names} {} {
        set names [$adb eval {
            SELECT a FROM activity_gtype
            WHERE gtype='FRC' AND assignable
        }]
    }


    # frc validate a
    #
    # a         Possibly, an activity ID
    #
    # Validates an activity ID as assignable to force units

    method {frc validate} {a} {
        if {$a ni [$self frc names]} {
            set names [join [$self frc names] ", "]

            return -code error -errorcode INVALID \
                "Invalid activity, should be one of: $names"
        }

        return $a
    }

    
    # org names
    #
    # Returns the list of activities assignable to organization units

    method {org names} {} {
        set names [$adb eval {
            SELECT a FROM activity_gtype
            WHERE gtype='ORG' AND assignable
        }]
    }


    # org validate a
    #
    # a         Possibly, an activity ID
    #
    # Validates an activity ID as assignable to org units

    method {org validate} {a} {
        if {$a ni [$self org names]} {
            set names [join [$self org names] ", "]

            return -code error -errorcode INVALID \
                "Invalid activity, should be one of: $names"
        }

        return $a
    }


    # asched names
    #
    # Returns the list of schedulable activities

    method {asched names} {{g ""}} {
        if {$g eq ""} {
            set names [$adb eval {
                SELECT DISTINCT a FROM activity_gtype
                WHERE assignable
            }]
        } else {
            set gtype [group gtype $g]
            set names [$adb eval {
                SELECT DISTINCT a FROM activity_gtype
                WHERE assignable AND gtype=$gtype
            }]
        }
    }


    # asched validate
    #
    # a         Possibly, an activity ID
    #
    # Validates a schedulable activity ID

    method {asched validate} {a} {
        if {$a ni [$self asched names]} {
            set names [join [$self asched names] ", "]

            return -code error -errorcode INVALID \
                "Invalid activity, should be one of: $names"
        }

        return $a
    }


    # withcov names
    #
    # Returns the list of activities for group type gtype, minus NONE.

    method {withcov names} {gtype} {
        set names [$adb eval {
            SELECT DISTINCT a FROM activity_gtype
            WHERE gtype=$gtype AND a!='NONE'
        }]
    }

    # withcov frc validate
    #
    # Validates an implicit/explicit activity ID for a frc group

    method {withcov frc validate} {a} {
        if {$a ni [$self withcov names FRC]} {
            set names [join [$self withcov names FRC] ", "]

            return -code error -errorcode INVALID \
                "Invalid activity, should be one of: $names"
        }

        return $a
    }

    # withcov org validate
    #
    # Validates an implicit/explicit activity ID for a org group

    method {withcov org validate} {a} {
        if {$a ni [$self withcov names ORG]} {
            set names [join [$self withcov names ORG] ", "]

            return -code error -errorcode INVALID \
                "Invalid activity, should be one of: $names"
        }

        return $a
    }

    # check g a
    #
    # g    A group
    # a    An activity
    #
    # Verifies that a can be assigned to g.

    method check {g a} {
        set gtype [group gtype $g]

        switch -exact -- $gtype {
            FRC     { set names [$self frc names] }
            ORG     { set names [$self org names] }
            default { error "Unexpected gtype: \"$gtype\""   }
        }

        if {$a ni $names} {
            return -code error -errorcode INVALID \
                "Group $g cannot be assigned activity $a"
        }
    }
}


