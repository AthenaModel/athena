#-----------------------------------------------------------------------
# TITLE:
#    bean.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectlib(1): Beans
#
#    A bean is a TclOO object that can be checkpointed.  All bean classes
#    should be defined using beanclass(n), and should subclass bean(n),
#    directly or indirectly.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export bean
}

#-----------------------------------------------------------------------
# beanslot oo::define command

# oo::define::beanslot slot
#
# slot - An instance variable name
#
# This command declares an instance variable in an oo::define script, and
# further marks the variable name as one of the class's "bean slots": i.e.,
# as being a variable that contains a list of zero or more bean object
# names.  All such variables should be declared using this command.

proc oo::define::beanslot {slot} {
    # FIRST, get the name of the class we're defining.
    set cls [namespace which [lindex [info level -1] 1]]

    # NEXT, Define the slot as a normal variable
    oo::define $cls variable $slot

    # NEXT, add a slot method for the slot that returns the list of 
    # bean commands.
    oo::define $cls method $slot {{idx ""}} [format {
        return [my SlotAccessor %s $idx]
    } $slot]

    # NEXT, add it to this class's list of bean slots.
    namespace upvar [info object namespace ::projectlib::bean] slots slots

    if {[dict exists $slots $cls]} {
        set slist [dict get $slots $cls]
        ::marsutil::ladd slist $slot
    } else {
        set slist [list $slot]
    }

    dict set slots $cls $slist
}

#-----------------------------------------------------------------------
# Bean class
#
# Since the bean class has class methods, it is convenient to build it
# up in stages.  First, we create the bare class.

oo::class create ::projectlib::bean 

#-----------------------------------------------------------------------
# bean: class members
#
# The bean class methods manage all beans, and are used to look up, 
# checkpoint, and restore them en masse.

oo::objdefine ::projectlib::bean {
    #-------------------------------------------------------------------
    # Type Variables

    # Dictionary of beanslot names by beanclass.
    # Does not include superclasses.
    variable slots      
    
    #-------------------------------------------------------------------
    # Public Type Methods

    # init
    #
    # Initializes the class object; this happens immediately.

    method init {} {
        namespace import ::marsutil::*

        # Prepare for the definition of slots by subclasses.
        set slots [dict create]
    }

    # getslots cls
    #
    # cls   - A subclass of ::projectlib::bean
    #
    # Returns the full list of slots for the class, including those
    # from superclasses.

    method getslots {cls} {
        set result [list]

        set classes [info class superclasses $cls]
        lappend classes $cls

        foreach c $classes {
            if {[dict exists $slots $c]} {
                lappend result {*}[dict get $slots $c]
            }
        }

        return $result
    }
}

#-----------------------------------------------------------------------
# bean: Class Initialization

::projectlib::bean init

#-----------------------------------------------------------------------
# bean: Instance Members

oo::define ::projectlib::bean {
    #-------------------------------------------------------------------
    # Instance Variables

    variable pot   ;# Every bean is created in a bean pot
    variable id    ;# Every bean has a unique numeric ID in its pot
    
    #-------------------------------------------------------------------
    # Constructor/Destructor
    
    # constructor
    #
    # Creates a new bean.  Note that a beans should always be created
    # using a beanpot(n) object's new method; this method assigns the
    # bean's pot and ID.

    constructor {} {
        # Nothing to do.
    }

    # destructor
    #
    # Unregisters the bean

    destructor {
        my destroyslots {*}[my getslots]
        $pot forget $id
    }

    # destroyslots beanslot...
    #
    # beanslot - Name of an instance variable containing a list of 
    #            beans owned by this bean.
    #
    # Destroys all beans listed in the bean slots; this is generally
    # used in subclass destructors.  Note that the slot's value remains
    # unchanged; when using destroyslots to explicitly reset a slot,
    # set the slot to [list] explicitly.
    #
    # This method protects against two problems:
    #
    # * Beans that have already been destroyed (i.e., by [bean reset])
    #
    # * Slot variables that have not yet been initialized (as might
    #   happen if there's an error thrown in the constructor).

    unexport destroyslots
    method destroyslots {args} {
        foreach slot $args {
            # Skip the slot if it hasn't been initialized yet.
            if {![info exists [self namespace]::$slot]} {
                continue
            }

            foreach bean_id [my get $slot] {
                # Only destroy it if it exists
                if {[$pot exists $bean_id]} {
                    [$pot get $bean_id] destroy
                }
            }
        }
    }

    #-------------------------------------------------------------------
    # Instance Methods

    # id
    #
    # Returns the bean's ID.

    method id {} {
        return $id
    }
    
    # subject
    #
    # Returns the object's "subject" for mutator ::marsutil::notifier events.
    # By default, the subject is "", meaning no ::marsutil::notifier events will
    # be sent.  Subclasses can override this to enable notification.
    # See the bean(n) manpage for a description of the notification
    # events.

    method subject {} {
        return ""
    }

    # getdict
    #
    # Retrieves the object's state as a dictionary
    #
    # Arrays are ignored.

    method getdict {} {
        foreach var [info vars [self namespace]::*] {
            # Skip arrays
            if {[array exists $var]} {
                continue
            }
            dict set dict [namespace tail $var] [set $var]
        }

        return $dict
    }

    # get var
    #
    # var   - An instance variable name
    #
    # Retrieves the value.  It's an error if the variable is an array.

    method get {var} {
        return [set [self namespace]::$var]
    }

    # setdict dict
    #
    # Sets the object's state as a dictionary.  No validation is done,
    # but the variables must already exist.  "pot" and "id" cannot be set.

    method setdict {dict} {
        dict for {key value} $dict {
            my set $key $value
        }
    }

    # SetDict dict
    #
    # Sets the object's state as a dictionary.  All variables are allowed.
    # This is used in "undo" routines to restore state.

    method SetDict {dict} {
        dict for {key value} $dict {
            set [self namespace]::$key $value
        }
    }

    # set var value
    #
    # var    - An instance variable name
    # value  - A new value
    #
    # Assigns the value to the instance variable; the variable must already
    # exist.  It's an error if the variable is an array.

    method set {var value} {
        if {![info exists [self namespace]::$var]} {
            error "unknown instance variable: \"$var\""
        }

        if {$var in {pot id}} {
            error "cannot set the bean's \"$var\" attribute."
        }

        $pot markchanged

        set [self namespace]::$var $value
    }

    # configure ?option value...?
    #
    # option   - An instance variable name in option form: -$varname
    # value    - The variable value
    #
    # This is equivalent to setdict, but uses option notation.

    method configure {args} {
        foreach {opt value} $args {
            set var [string range $opt 1 end]
            my set $var $value
        }
    }

    # cget opt
    #
    # opt   - An instance variable name in option form: -$varname
    #
    # This is equivalent to get but uses option notation.

    method cget {opt} {
        set var [string range $opt 1 end]
        return [my get $var]
    }

    # lappend listvar value...
    #
    # listvar   - An instance variable name
    # value...  - One or more values
    #
    # Appends the values to the list, and marks the bean changed.

    method lappend {listvar args} {
        set list [my get $listvar]
        lappend list {*}$args
        my set $listvar $list
    }

    # ldelete listvar value
    #
    # listvar   - An instance variable name
    # value     - A list item
    #
    # Deletes the value from the list, and marks the bean changed.

    method ldelete {listvar value} {
        set list [my get $listvar]
        ::marsutil::ldelete list $value
        my set $listvar $list
    }

    # getslots
    #
    # Returns the full list of beanslots for this object.

    method getslots {} {
        return [::projectlib::bean getslots [info object class [self]]]
    }

    # getowned ?-deep|-shallow?
    #
    # Returns a list of the names of the beans owned by this bean.
    # If -deep is given (the default) then the list includes beans 
    # owned directly or indirectly; if -shallow, then the list includes
    # only those beans owned directly by this bean.
    #
    # Note: this bean is not included.
    #
    # TBD: This routine appears to be unused.  We might wish to 
    # remove it.

    method getowned {{mode -deep}} {
        # FIRST, handle shallow mode immediately
        if {$mode eq "-shallow"} {
            set result [list]

            foreach slot [my getslots] {
                lappend result {*}[my $slot]
            }

            return $result
        }

        # NEXT, handle -deep mode
        set candidates [list [self]]

        set result [list]
        while {[llength $candidates] > 0} {
            set bean [::marsutil::lshift candidates]

            set owned [$bean getowned -shallow]
            lappend result {*}$owned
            lappend candidates {*}$owned
        }

        return $result
    }

    # view ?view?
    #
    # view   - An optional view name
    #
    # Returns a view of the bean's data: a dictionary of data.
    # The default view is called "", and by default is just the
    # getdict dictionary.  The bean class provides no alternative views.
    # Subclasses can override view to add data to the default view or
    # define additional views.
    #
    # If a view name isn't know, the view method should just return its
    # default view.

    method view {{view ""}} {
        return [my getdict]
    }

    #-------------------------------------------------------------------
    # Slot Support

    # SlotAccessor slot ?idx?
    #
    # idx - Optionally, a lindex index.
    #
    # Returns all or one entries from the slot, converting the slot
    # ids to bean commands.

    method SlotAccessor {slot {idx ""}} {
        if {$idx eq ""} {
            return [lmap bean_id [my get $slot] { $pot get $bean_id }]
        } else {
            set bean_id [lindex [my get $slot] $idx]
            if {$bean_id ne ""} {
                return [$pot get $bean_id]
            } else {
                return ""
            }
        }
    }
    

    #-------------------------------------------------------------------
    # Copy/Paste Support

    # copydata
    #
    # Creates a copy set for this bean.  The copy set contains all
    # of the information needed to recreate the bean and the beans that
    # it owns using the application's orders.
    #
    # - The id variable and the parent variable (if any) are omitted.
    # - A "class_" variable is added, with the leaf class name.
    # - Beanslot elements are replaced with copy sets for the listed
    #   elements.

    method copydata {} {
        # FIRST, get a shallow copy of this object.
        set cdict [my GetShallowCopy]

        # NEXT, for each bean slot get a copy set.
        foreach slot [my getslots] {
            dict set cdict $slot [list]

            foreach bean [my $slot] {
                dict lappend cdict $slot [$bean copydata]
            }
        }

        return $cdict
    }

    # GetShallowCopy
    #
    # Returns a copy dict for this object, a dictionary containing all
    # state that can be copied and pasted.  This excludes the pot and id,
    # since a new object will have its own, and its parent (if any), as the
    # new object's parent will be set on paste.  It includes a new
    # key, "class_", the leaf class.
    #
    # NOTE: for pasting, we use orders (so that we get undoability),
    # and orders use use user data formats instead of internal data
    # formats.  Consequently, we copy the default view rather than the
    # the internal data.

    method GetShallowCopy {} {
        set dict [dict remove [my view] pot id parent]
        dict set dict class_ [info object class [self]]

        return $dict
    }
    

    #-------------------------------------------------------------------
    # Order Mutators
    #
    # The following commands are for use in defining mutators
    # for bean classes.  Most are unexported.

    # addbean_ slot cls ?beanvar?
    #
    # slot     - A bean instance variable that contains a list 
    #            of beans owned only by this bean.
    # cls      - The new bean's class
    # beanvar  - Name of a variable to receive the new bean object's
    #            name.
    # 
    # Creates a new bean and adds it to the slot, 
    # calling the onAddBean_ method and returning an undo script.  
    #
    # NOTE: The bean class must provide a "parent" parameter.

    unexport addbean_
    method addbean_ {slot cls {beanvar ""}} {
        # FIRST, make the new bean accessible to the caller.
        if {$beanvar ne ""} {
            upvar $beanvar bean
        }

        # NEXT, save the bean's previous state.
        set undodict [my getdict]

        # NEXT, add the new bean to the slot
        set bean [$pot new $cls]
        my lappend $slot [$bean id]
        $bean configure -parent [my id]

        # NEXT, do activities on add to slot
        my onAddBean_ $slot [$bean id]

        # NEXT, do notifications.
        if {[my subject] ne ""} {
            ::marsutil::notifier send \
                [my subject] <$slot> add [my id] [$bean id]
        }

        ::marsutil::notifier send ::projectlib::bean <Monitor>


        # NEXT, return the undo command.

        return [list [self] UndoAddBean $slot $bean $undodict]
    }

    # onAddBean_ slot bean_id
    #
    # This method is called as part of addBean_. Subclasses
    # can override it to do additional work before or after the 
    # notification is sent.

    unexport onAddBean_
    method onAddBean_ {slot bean_id} {
        # Override
    }

    # UndoAddBean slot bean undodict
    #
    # slot      - The slot to which the bean had been added.
    # undodict  - The bean's previous state
    # bean      - The bean that was added to the slot
    #
    # Undoes the addition of a bean to a slot, destroying the bean,
    # resetting the ID counter, and sending a notification
    # if the subject is defined.

    method UndoAddBean {slot bean undodict} {
        my SetDict $undodict
        set bean_id [$bean id]

        # Uncreate the bean, verifying that it really is the most recent
        # in the pot.
        $pot uncreate $bean

        if {[my subject] ne ""} {
            ::marsutil::notifier send \
                [my subject] <$slot> delete [my id] $bean_id
        }

        ::marsutil::notifier send ::projectlib::bean <Monitor>
    }
    export UndoAddBean

    # deletebean_ slot id
    #
    # slot      - A bean instance variable that contains a list 
    #             of beans owned only by this bean.
    # bean_id   - Bean ID of a bean in the named slot.
    #
    # Deletes the bean from the slot and from memory, calls
    # the onDeleteBean_ method, and returns an undo script.

    unexport deletebean_
    method deletebean_ {slot bean_id} {
        # FIRST, save the bean's previous state.
        set undodict [my getdict]

        # NEXT, delete the bean from the slot and from memory,
        # saving the delete set.
        set bean [$pot get $bean_id]
        my ldelete $slot $bean_id
        set delset [$pot delete $bean_id]

        # NEXT, do other activities on delete.
        my onDeleteBean_ $slot $bean_id

        # NEXT, do notifications
        if {[my subject] ne ""} {
            ::marsutil::notifier send \
                [my subject] <$slot> delete [my id] $bean_id
        }

        ::marsutil::notifier send ::projectlib::bean <Monitor>

        # NEXT, return the undo command.
        return [list [self] UndoDeleteBean $slot $bean_id $undodict $delset]
    }

    # onDeleteBean_ slot bean_id
    #
    # This method is called as part of deleteBean_.  Subclasses
    # can override it to do additional work before or after the 
    # notification is sent.

    unexport onDeleteBean_
    method onDeleteBean_ {slot bean_id} {
        # Override
    }

    # UndoDeleteBean undodict delset
    #
    # slot     - The bean slot
    # bean_id  - The bean ID of the undeleted bean
    # undodict - The bean's previous state
    # delset   - The bean delete set
    #
    # Undoes the deletion from the slot, restoring the
    # bean's state.

    method UndoDeleteBean {slot bean_id undodict delset} {
        my SetDict $undodict
        $pot undelete $delset

        # NEXT, send the ::marsutil::notifier event.
        if {[my subject] ne ""} {
            ::marsutil::notifier send [my subject] <$slot> add [my id] $bean_id
        }

        ::marsutil::notifier send ::projectlib::bean <Monitor>
    }
    export UndoDeleteBean

    # movebean_ slot bean_id where
    #
    # slot    - A bean instance variable that contains a list 
    #           of beans owned only by this bean.
    # bean_id - ID of a bean on the the list.
    # where   - emoveitem(n) value, where to move it.
    #
    # Moves an owned bean within its slot,
    # and returning an undo script, sending a notification if the 
    # subject is defined.

    unexport movebean_
    method movebean_ {slot bean_id where} {
        # FIRST, save the bean's previous state.
        set undodict [my getdict]

        # NEXT, move the bean in its slot.
        my set $slot [::projectlib::emoveitem move $where [my get $slot] $bean_id]

        # NEXT, do activities on move
        my onMoveBean_ $slot $bean_id

        # NEXT, do notifications
        if {[my subject] ne ""} {
            ::marsutil::notifier send \
                [my subject] <$slot> move [my id] $bean_id
        }

        ::marsutil::notifier send ::projectlib::bean <Monitor>

        # NEXT, return the undo command.
        return [list [self] UndoMoveBean $slot $bean_id $undodict]
    }

    # onMoveBean_
    #
    # This method is called as part of movebean_.  Subclasses
    # can override it to do additional work before or after the 
    # notifications are sent.

    unexport onMoveBean_
    method onMoveBean_ {slot bean_id} {
        # Override
    }

    # UndoMoveBean slot bean_id undodict
    #
    # slot      - The slot to which the bean had been added.
    # undodict  - The bean's previous state
    # bean_id   - The ID of the bean that was moved
    #
    # Undoes the movement of a bean in a slot, sending out notifications.

    method UndoMoveBean {slot bean_id undodict} {
        my SetDict $undodict

        if {[my subject] ne ""} {
            ::marsutil::notifier send [my subject] <$slot> move [my id] $bean_id
        }

        ::marsutil::notifier send ::projectlib::bean <Monitor>
    }
    export UndoMoveBean

    # update_ varlist userdict
    #
    # varlist   - A list of instance variable names
    # userdict  - A dictionary of variable names and values from
    #             an order.
    #
    # For each variable listed in varlist, sets the variable to the
    # matching value in userdict, if and only if the value exists and is
    # not the empty string, and updates the changed flag.  Calls the
    # onUpdate_ method.  Returns a command to restore the previous bean 
    # dictionary.
    #
    # This command is intended for use as an "update" order mutator for
    # bean objects.

    method update_ {varlist userdict} {
        # FIRST, get the undo data
        set udict [my getdict]

        # NEXT, build up a dictionary of required changes.
        set vdict [dict create]

        foreach var $varlist {
            if {[dict exists $userdict $var]} {
                set value [dict get $userdict $var]

                if {$value ne ""} {
                    dict set vdict $var $value
                }
            }
        }

        # NEXT, apply the changes.
        my setdict $vdict

        # NEXT, do activities on update
        my onUpdate_

        # NEXT, do notifications.
        if {[my subject] ne ""} {
            ::marsutil::notifier send [my subject] <update> [my id]
        }

        ::marsutil::notifier send ::projectlib::bean <Monitor>

        # NEXT, return the undo command.
        return [list [self] UndoUpdate $udict]
    }

    # onUpdate_
    #
    # This method is called as part of an update_, after all changes
    # have been made.  Subclasses can override it
    # to do additional work before or after the notification.

    method onUpdate_ {} {
        # Override
    }

    # UndoUpdate udict
    #
    # udict  - A bean state dictionary
    #
    # Restores the bean's state dictionary.

    method UndoUpdate {udict} {
        my SetDict $udict

        if {[my subject] ne ""} {
            ::marsutil::notifier send [my subject] <update> [my id]
        }

        ::marsutil::notifier send ::projectlib::bean <Monitor>
    }
    export UndoUpdate
}


