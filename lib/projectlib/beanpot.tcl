#-----------------------------------------------------------------------
# TITLE:
#    beanpot.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectlib(1): Bean Container
#
#    A bean is a TclOO object that can be checkpointed.  A beanpot
#    is used to create and contain a related collection of beans
#    that can be checkpointed en masse.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export beanpot
}

#-----------------------------------------------------------------------
# beanpot

oo::class create ::projectlib::beanpot {
    #-------------------------------------------------------------------
    # Checkpointed Variables
    
    variable beans      ;# Dictionary of bean objects by ID
    variable pendingId  ;# The next ID to assign, if > [my lastid]

    #-------------------------------------------------------------------
    # Constructor

    constructor {} {
        # FIRST, initialize the variables.
        set beans     [dict create]
        set pendingID 0
    }
    

    #-------------------------------------------------------------------
    # Bean Creation methods
    
    # new beanclass args
    #
    # Create a new bean of the given class, assigning it a name and 
    # ID relative to this beanpot.  The name will be like
    #
    #    <pot>::<bareclass><ID>.

    method new {beanclass args} {
        set root [namespace tail [self]]

        # Get the next bean ID; it will be assigned when the bean is 
        # created.
        set id [my nextid]
        set name [self]::[namespace tail $beanclass]$id

        $beanclass create $name [self] {*}$args

        dict set beans $id $name
        incr pendingID

        return $name
    }

    #-------------------------------------------------------------------
    # Queries
    
    # get id
    #
    # Retrieves an object given a bean ID.  Throws an error if the
    # bean doesn't exist in this pot.

    method get {id} {
        if {[dict exists $beans $id]} {
            return [dict get $beans $id]
        }

        error "[self] contains no bean with ID $id"
    }

    # exists id
    #
    # Returns 1 if there is a bean with the given ID in the pot.

    method exists {id} {
        return [dict exist $beans $id]
    }

    # validate id
    #
    # id   - Possibly, a bean ID in this pot.
    #
    # Throws an error with errorcode INVALID if this is not
    # a bean belonging to this pot.

    method validate {id} {
        if {[my exists $id]} {
            return $id     
        }
        throw INVALID \
            "Invalid object ID: \"$id\""
    }

    # ids ?beanclass?
    #
    # Returns a list of the IDs of all beans in the pot, optionally
    # filtering for a given class.

    method ids {{beanclass ""}} {
        set result [list]

        foreach id [dict keys $beans] {
            if {$beanclass ne ""} {
                set bean [my get $id]

                if {![info object isa typeof $bean $beanclass]} {
                    continue
                }
            }

            lappend result $id
        }

        return $result
    }
}


