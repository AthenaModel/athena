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

    # NEXT, Is this class really a bean class?
    if {[info object class $cls] ne "::projectlib::beanclass"} {
        error "tried to define beanslot on $cls, which is not a bean class"
    }

    # NEXT, Define the slot as a normal variable
    oo::define $cls variable $slot

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

::projectlib::beanclass create ::projectlib::bean 

#-----------------------------------------------------------------------
# bean: class members
#
# The bean class methods manage all beans, and are used to look up, 
# checkpoint, and restore them en masse.

oo::objdefine ::projectlib::bean {
    #-------------------------------------------------------------------
    # Checkpointed Type Variables
    
    variable beans      ;# Dictionary of bean object by ID
    variable pendingId  ;# The next ID to assign, if > [my lastid]

    #-------------------------------------------------------------------
    # Uncheckpointed Type Variables

    variable slots      ;# Dictionary of beanslots by beanclass.
                         # Does not include superclasses.
    variable changed    ;# If true, there are unsaved beans.
    variable restoring  ;# If true, we are in [bean restore].
    variable deleting   ;# If true, we are in [bean delete].
    variable deletions  ;# Dict of deleted beans, accumulated during [bean delete]
    variable onchange   ;# Command to call on change.
    variable rdb        ;# RDB object, for checkpoint/restore.
    
    #-------------------------------------------------------------------
    # Initialization

    # init
    #
    # Initializes the class object; this happens immediately.  This
    # is also called on reset.

    method init {{reset 0}} {
        if {!$reset} {
            namespace import ::marsutil::*
            set slots [dict create]
        }

        set beans [dict create]
        set pendingId 0
        set changed 0
        set restoring 0
        set deleting 0
        set deletions [dict create]

        # onchange isn't bean data; it's part of the glue code.  So
        # don't clear it on reset.
        if {![info exists onchange]} {
            set onchange {}
        }

        # rdb isn't bean data; it's part of the glue code.  So
        # don't clear it on reset.
        if {![info exists rdb]} {
            set rdb {}
        }
    }

    # configure option value ...
    #
    # option   - A bean(n) class option
    # value    - The option value
    #
    # Saves or clears the option values.

    method configure {args} {
        while {[llength $args] > 0} {
            set opt [lshift args]

            switch -exact -- $opt {
                -onchange {
                    set onchange [lshift args] 
                }

                -rdb {
                    set rdb [lshift args]
                }

                default {
                    error "Unknown option: \"$opt\""
                }
            }
        }

        return
    }

    # cget option
    #
    # option - A bean(n) class option
    #
    # Returns the option's value.

    method cget {option} {
        switch -exact -- $option {
            -onchange { return $onchange }
            -rdb      { return $rdb      }

            default {
                error "Unknown option: \"$opt\""
            }
        }
    }


    

    #-------------------------------------------------------------------
    # Private Methods
    #
    # These methods are used by bean instances; they are not for use by
    # outside 

    # register bean
    #
    # bean - A bean that is being created
    #
    # Registers the new bean, assigning it an ID, which is returned.
    # This routine is intended for use only by instances of bean.
    #
    # NOTE: [bean restore] re-creates checkpointed objects by calling
    # their constructors; this will ultimately result in a call to
    # this routine.  In this case only, we do not want to assign
    # a new ID; the old ID will be put back after the object is created.

    method register {bean} {
        if {$restoring} {
            return ""
        } else {
            my markchanged
            set id [my nextid]
            dict set beans $id $bean
            return $id
        }
    }

    # unregister id
    #
    # id  - A bean ID
    #
    # Unregisters the bean; it can no longer be looked up or checkpointed.
    # This routine is intended for use only by instances of bean.
    #
    # If we are deleting a bean, save this bean's data.

    method unregister {id} {
        if {$deleting} {
            if {[dict exists $beans $id]} {
                dict set deletions $id [my Serialize [dict get $beans $id]]
            }
        }
        dict unset beans $id
        my markchanged
        return
    }

    # uncreate bean
    #
    # bean - The bean to uncreate
    #
    # Undoes the creation of a bean, which must be the most recently 
    # created bean.

    method uncreate {bean} {
        require {[$bean id] == [my lastid]} "not most recent bean: \"$bean\""

        $bean destroy
    }

    #-------------------------------------------------------------------
    # beanclass methods
    #
    # NOTE: These methods override the [beanclass] class methods of the
    # same name, and provide the basic implementation of these operations
    # for all bean classes.  In other beanclasses, the [beanclass] class
    # methods call these, and limit the results to those of the appropriate
    # class.

    # get id
    #
    # id   - A bean ID
    #
    # Returns a bean object given its ID.

    method get {id} {
        if {![dict exists $beans $id]} {
            error "No such bean: $id"
        }

        return [dict get $beans $id]
    }

    # exists id
    #
    # id  - A bean ID
    #
    # Returns 1 if the bean exists, and 0 otherwise.

    method exists {id} {
        return [dict exists $beans $id]
    }

    # ids
    #
    # Returns a list of valid bean IDs

    method ids {} {
        return [lsort -integer [dict keys $beans]]
    }


    
    #-------------------------------------------------------------------
    # Public Methods
    
    # lastid 
    #
    # Returns the ID of the most recently created bean, or 0 if 
    # there are no beans.

    method lastid {} {
        if {[dict size $beans] > 0} {
            tcl::mathfunc::max {*}[dict keys $beans]        
        } else {
            return 0
        }
    }

    # nextid
    #
    # Returns the ID of the next bean to create.

    method nextid {} {
        return [expr {max($pendingId,[my lastid] + 1)}]
    }
    
    # setnextid nid
    #
    # nid   - The next ID to assign.
    #
    # Sets the next id to assign.  This is for use in 
    # order setredo scripts, to ensure that orders yield the same IDs
    # on redo.

    method setnextid {nid} {
        set pendingId $nid
    }

    # dump
    #
    # Dumps all beans

    method dump {} {
        set result ""
        foreach id [my ids] {
            set bean [dict get $beans $id]
            append result \
                "$id ([info object class $bean]/$bean): [$bean getdict]\n"
        }
        return $result
    }

    # reset
    #
    # Destroys all beans, and resets the class.

    method reset {} {
        foreach bean [dict values $beans] {
            # Only destroy it if it exists
            if {[info object isa object $bean]} {
                $bean destroy
            }
        }

        my init 1
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

    # view id ?view?
    #
    # id     - A bean's ID
    # view   - Optionally, a view name
    #
    # Given a bean ID, returns a view dictionary.  Returns the empty
    # dictionary if the bean doesn't exist.

    method view {id {view ""}} {
        if {![my exists $id]} {
            return [dict create]
        }

        set bean [my get $id]
        return [$bean view $view]
    }

    #-------------------------------------------------------------------
    # Checkpoint/Restore

    # Serialize bean
    #
    # bean - A bean object
    #
    # Serializes the bean, so that it can be saved in a checkpoint
    # or undelete string.  The serialized form is a list,
    #
    #    <class> <object> <dict>

    method Serialize {bean} {
        list [info object class $bean] $bean [$bean getdict]
    }

    # SerializeAll
    #
    # Serializes all beans, and returns the string.

    method SerializeAll {} {
        set result [dict create]
        dict for {id bean} $beans {
            dict set result $id [my Serialize $bean]
        }

        return $result
    }

    # SaveBeansToRDB
    #
    # Saves all beans to the beans table on checkpoint.

    method SaveBeansToRDB {} {
        $rdb eval {
            DELETE FROM beans;
        }

        foreach {id bean_object} $beans {
            set bean_class [info object class $bean_object]
            set bean_dict [$bean_object getdict]

            $rdb eval {
                INSERT INTO beans(id, bean_class, bean_object, bean_dict)
                VALUES($id, $bean_class, $bean_object, $bean_dict)
            }
        }
    }

    # Deserialize id blist
    #
    # id    - The bean's ID
    # blist - A serialized bean
    #
    # Deserializes the bean: recreates the object, sets its state, and
    # registers it.

    method Deserialize {id blist} { 
        lassign $blist bcls bean bdict

        # FIRST, Recreate the bean with its original name and
        # class.  Because we are "restoring", it will not be
        # registered automatically.
        $bcls create $bean

        # NEXT, restore its data.
        set ns [info object namespace $bean]

        dict for {var value} $bdict {
            set ${ns}::$var $value
        }

        # NEXT, register it.
        dict set beans $id $bean
    }


    # changed
    #
    # Returns 1 if there are unsaved beans, and 0 otherwise.  

    method changed {} {
        return $changed
    }

    # markchanged
    #
    # Sets the changed flag.  This is for use by bean code that
    # changes bean internals.  Note that [$bean set] calls this
    # automatically.

    method markchanged {} {
        set changed 1
        callwith $onchange
    }


    # checkpoint ?-saved?
    #
    # Returns a string that contains the state of all registered beans.
    # It can be used to restore them by calling [bean restore].  If -saved
    # is given, the object's unsaved changes flag is cleared.

    method checkpoint {{flag ""}} {
        set data [dict create]
        
        if {$rdb eq ""} {
            dict set data beans [my SerializeAll]
        } else {
            my SaveBeansToRDB
        }

        if {$flag eq "-saved"} {
            set changed 0
        }

        return $data
    }


    # restore checkpoint ?-saved?
    #
    # checkpoint - A string returned by [bean checkpoint]
    #
    # Restores all checkpointed beans; all other registered beans will 
    # be deleted.
    #
    # By default, this command will leave the changed flag set; if
    # -saved is given, the flag will be cleared.

    method restore {checkpoint {flag ""}} {
        # FIRST, destroy all registered beans.  Note that the
        # beans might have been destroyed with their owners.
        foreach bean [dict values $beans] {
            if {[info object isa object $bean]} {
                $bean destroy
            }
        }

        # NEXT, clear the beans dictionary (this shouldn't strictly
        # be necessary)
        set beans [dict create]

        # NEXT, restore the checkpoint
        set restoring 1

        try {
            if {$rdb eq ""} {
                dict for {id blist} [dict get $checkpoint beans] {
                    my Deserialize $id $blist
                }
            } else {
                $rdb eval {
                    SELECT * FROM beans
                    ORDER BY id
                } {
                    set blist [list $bean_class $bean_object $bean_dict]
                    my Deserialize $id $blist
                }
            }
        } finally {
            set restoring 0
        }

        my markchanged ;# Always, so that onchange gets called

        if {$flag eq "-saved"} {
            set changed 0
        }

        return
    }

    #-------------------------------------------------------------------
    # delete/undelete

    # delete id
    #
    # id   - A bean ID
    #
    # Deletes (destroys) a bean given its ID, returning a deleteSet 
    # string that can be used to undelete it and its dependents.
    #
    # Sets the changed flag implicitly (because [bean unregister] is 
    # called).

    method delete {id} {
        if {![my exists $id]} {
            error "no such bean: \"$id\""
        }

        set deletions [dict create]
        set deleting 1

        try {
            set bean [my get $id]
            $bean destroy
        } finally {
            set deleting 0
        }

        set result $deletions
        set deletions [dict create]

        return $result
    }

    # undelete deleteSet
    #
    # deleteSet  - A delete set string returned by [delete]
    #
    # Under normal "undo" conditions, undoes the full set of bean deletions
    # caused by calling [bean delete $id].  Sets the changed flag.

    method undelete {deleteSet} {
        set restoring 1

        try {
            dict for {id blist} $deleteSet {
                my Deserialize $id $blist
            }
        } finally {
            set restoring 0
        }

        my markchanged
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

    variable id    ;# Every bean has a unique numeric ID
    
    #-------------------------------------------------------------------
    # Constructor/Destructor
    
    # constructor
    #
    # Creates a new bean.  Unless we are restoring a checkpoint, the
    # bean will be assigned an ID; see [bean register] for more.

    constructor {} {
        set id [[self class] register [self]]
    }

    # destructor
    #
    # Unregisters the bean

    destructor {
        my destroyslots {*}[my getslots]
        [self class] unregister $id
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

            foreach bean [my get $slot] {
                # Only destroy it if it exists
                if {[info object isa object $bean]} {
                    $bean destroy
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
    # but the variables must already exist.

    method setdict {dict} {
        dict for {key value} $dict {
            my set $key $value
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

        if {$var eq "id" && $id ne "" && $id ne $value} {
            error "cannot change bean ID"
        }

        [self class] markchanged

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

    method getowned {{mode -deep}} {
        # FIRST, handle shallow mode immediately
        if {$mode eq "-shallow"} {
            set result [list]

            foreach var [my getslots] {
                lappend result {*}[my get $var]
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

            foreach bean [my get $slot] {
                dict lappend cdict $slot [$bean copydata]
            }
        }

        return $cdict
    }

    # GetShallowCopy
    #
    # Returns a copy dict for this object, a dictionary containing all
    # state that can be copied and pasted.  This excludes the id,
    # since a new object will have its own, and its parent (if any), as the
    # new object's parent will be set on paste.  It includes a new
    # key, "class_", the leaf class.
    #
    # NOTE: for pasting, we use orders (so that we get undoability),
    # and orders use use user data formats instead of internal data
    # formats.  Consequently, we copy the default view rather than the
    # the internal data.

    method GetShallowCopy {} {
        set dict [dict remove [my view] id parent]
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
        set bean [$cls new]
        my lappend $slot $bean
        $bean configure -parent [self]

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
        my setdict $undodict
        set bean_id [$bean id]

        # Put the id counter back to what it was
        [self class] uncreate $bean

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
        set bean [[self class] get $bean_id]
        my ldelete $slot $bean
        set delset [[self class] delete $bean_id]

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
        my setdict $undodict
        [self class] undelete $delset

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

        # NEXT, get the bean to move.
        set bean [[self class] get $bean_id]

        # NEXT, move the bean in its slot.
        my set $slot [::projectlib::emoveitem move $where [my get $slot] $bean]

        # NEXT, do activities on move
        my onMoveBean_ $slot [$bean id]

        # NEXT, do notifications
        if {[my subject] ne ""} {
            ::marsutil::notifier send \
                [my subject] <$slot> move [my id] [$bean id]
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
        my setdict $undodict

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
        my setdict $udict

        if {[my subject] ne ""} {
            ::marsutil::notifier send [my subject] <update> [my id]
        }

        ::marsutil::notifier send ::projectlib::bean <Monitor>
    }
    export UndoUpdate
}


