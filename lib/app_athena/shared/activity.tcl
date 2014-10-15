#-----------------------------------------------------------------------
# TITLE:
#    activity.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Unit Activity module
#
#    This module is responsible for defining and validating the
#    different categories of unit activities.
#
#-----------------------------------------------------------------------

snit::type activity {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.

    # names
    #
    # Returns the list of all activity names

    typemethod names {} {
        set names [rdb eval {
            SELECT a FROM activity
        }]
    }


    # validate a
    #
    # a         Possibly, an activity ID
    #
    # Validates an activity ID

    typemethod validate {a} {
        if {![rdb exists {SELECT a FROM activity WHERE a=$a}]} {
            set names [join [activity names] ", "]

            return -code error -errorcode INVALID \
                "Invalid activity, should be one of: $names"
        }

        return $a
    }

    # frc names
    #
    # Returns the list of activities assignable to force units

    typemethod {frc names} {} {
        set names [rdb eval {
            SELECT a FROM activity_gtype
            WHERE gtype='FRC' AND assignable
        }]
    }


    # frc validate a
    #
    # a         Possibly, an activity ID
    #
    # Validates an activity ID as assignable to force units

    typemethod {frc validate} {a} {
        if {$a ni [activity frc names]} {
            set names [join [activity frc names] ", "]

            return -code error -errorcode INVALID \
                "Invalid activity, should be one of: $names"
        }

        return $a
    }

    
    # org names
    #
    # Returns the list of activities assignable to organization units

    typemethod {org names} {} {
        set names [rdb eval {
            SELECT a FROM activity_gtype
            WHERE gtype='ORG' AND assignable
        }]
    }


    # org validate a
    #
    # a         Possibly, an activity ID
    #
    # Validates an activity ID as assignable to org units

    typemethod {org validate} {a} {
        if {$a ni [activity org names]} {
            set names [join [activity org names] ", "]

            return -code error -errorcode INVALID \
                "Invalid activity, should be one of: $names"
        }

        return $a
    }


    # asched names
    #
    # Returns the list of schedulable activities

    typemethod {asched names} {{g ""}} {
        if {$g eq ""} {
            set names [rdb eval {
                SELECT DISTINCT a FROM activity_gtype
                WHERE assignable
            }]
        } else {
            set gtype [group gtype $g]
            set names [rdb eval {
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

    typemethod {asched validate} {a} {
        if {$a ni [activity asched names]} {
            set names [join [activity asched names] ", "]

            return -code error -errorcode INVALID \
                "Invalid activity, should be one of: $names"
        }

        return $a
    }


    # withcov names
    #
    # Returns the list of activities for group type gtype, minus NONE.

    typemethod {withcov names} {gtype} {
        set names [rdb eval {
            SELECT DISTINCT a FROM activity_gtype
            WHERE gtype=$gtype AND a!='NONE'
        }]
    }

    # withcov frc validate
    #
    # Validates an implicit/explicit activity ID for a frc group

    typemethod {withcov frc validate} {a} {
        if {$a ni [activity withcov names FRC]} {
            set names [join [activity withcov names FRC] ", "]

            return -code error -errorcode INVALID \
                "Invalid activity, should be one of: $names"
        }

        return $a
    }

    # withcov org validate
    #
    # Validates an implicit/explicit activity ID for a org group

    typemethod {withcov org validate} {a} {
        if {$a ni [activity withcov names ORG]} {
            set names [join [activity withcov names ORG] ", "]

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

    typemethod check {g a} {
        set gtype [group gtype $g]

        switch -exact -- $gtype {
            FRC     { set names [activity frc names] }
            ORG     { set names [activity org names] }
            default { error "Unexpected gtype: \"$gtype\""   }
        }

        if {$a ni $names} {
            return -code error -errorcode INVALID \
                "Group $g cannot be assigned activity $a"
        }
    }
}


