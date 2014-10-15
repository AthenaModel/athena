#-----------------------------------------------------------------------
# TITLE:
#    beanclass.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectlib(1): Bean Metaclass
#
#    A bean is a TclOO object that can be checkpointed.  Use beanclass
#    to create bean classes.
#
#    Note that most shared bean behavior is defined by
#    bean(n), the root base class for all bean classes.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export beanclass
}

#-------------------------------------------------------------------
# Metaclass: beanclass
#
# If myclass is a beanclass, then [myclass new] returns an object in
# the ::bean namespace.  This allows us to retain bean names on 
# restore, since restored automatically named beans will not have names that
# might collide with non-beans.
#
# This class provides the [myclass new] behavior, and other methods that
# all beanclasses should have.

oo::class create ::projectlib::beanclass {
    superclass oo::class   ;# This is a metaclass

    #-------------------------------------------------------------------
    # Constructor
    #
    # This is called when a new beanclass is created; the constructor
    # argument is the class definition script.

    constructor {{defscript ""}} {
        # FIRST, set the superclass to ::projectlib::bean by default.
        if {[self] ne "::projectlib::bean"} {
            define [self] superclass ::projectlib::bean
        }

        # NEXT, define the class
        define [self] $defscript
    }
    

    #-------------------------------------------------------------------
    # Instance Creation methods
    
    # new args
    #
    # Create a new object with a name like ::bean::<bareclass><ID>.
    # The counter is distinct from the bean ID counter, though perhaps
    # it shouldn't be.

    method new {args} {
        set root [namespace tail [self]]

        # Get the next bean ID; it will be assigned when the bean is 
        # created.
        set name ::bean::${root}[::projectlib::bean nextid]

        my create $name {*}$args
    }

    #-------------------------------------------------------------------
    # Special Bean Class Methods
    #
    # For every bean class but ::projectlib::bean itself, the following
    # methods can be used to query the instances of members of the class.
    # The ::projectlib::bean class defines its own versions of these
    # methods which apply to all beans; the methods below call the
    # ::projectlib::bean methods explicitly, and then filter the results
    # to apply to only the relevant bean class and its subclasses.
    
    # get id
    #
    # Retrieves an object given a bean ID, and ensures that the object
    # is of the correct type, i.e., the specific beanclass or one of
    # its subclasses.

    method get {id} {
        set bean [::projectlib::bean get $id]

        if {![info object isa typeof $bean [self]]} {
            error "bean $id is not a [self]"
        }

        return $bean
    }

    # exists id
    #
    # Returns 1 if there is a bean with the given ID and it has the
    # correct type.

    method exists {id} {
        if {[::projectlib::bean exists $id]} {
            set bean [::projectlib::bean get $id]

            if {[info object isa typeof $bean [self]]} {
                return 1            
            }
        }

        return 0
    }

    # validate id
    #
    # id   - Possibly, a bean ID of this class's type
    #
    # Throws an error with errorcode INVALID if this is not
    # a bean belonging to this class.

    method validate {id} {
        if {[::projectlib::bean exists $id]} {
            set bean [::projectlib::bean get $id]

            if {[info object isa typeof $bean [self]]} {
                return $id     
            }
        }

        set tail [namespace tail [self]]

        throw INVALID \
            "Invalid $tail ID: \"$id\""
    }

    # ids
    #
    # Returns a list of the IDs of the beans of this class or its
    # subclasses.

    method ids {} {
        set result [list]

        foreach id [::projectlib::bean ids] {
            set bean [::projectlib::bean get $id]
            if {[info object isa typeof $bean [self]]} {
                lappend result $id
            }
        }

        return $result
    }
}


