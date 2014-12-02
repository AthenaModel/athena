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

snit::type ::projectlib::beanpot {
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        namespace import ::marsutil::*
    }
    
    #-------------------------------------------------------------------
    # Type Variables

    # Active pot list: a list of -rdb/-dbid pairs.   It's illegal to
    # have two beanpots with the same -dbid in one -rdb.

    typevariable potList {}
    

    #-------------------------------------------------------------------
    # Options

    # -rdb  rdb
    #
    # The handle of the sqlite3 database into which the pot will be saved.
    option -rdb \
        -readonly yes

    # -dbid text
    #
    # The database ID of this beanpot, used when saving and restoring.

    option -dbid \
        -default  pot \
        -readonly yes

    #-------------------------------------------------------------------
    # Instance Variables
    
    variable beans      ;# Dictionary of bean objects by ID
    variable pendingId  ;# The next ID to assign, if > [my lastid]
    variable changed    ;# If true, there are unsaved beans.
    variable deleting   ;# If true, we are in [bean delete].
    variable deletions  ;# Dict of deleted beans, accumulated 
                         # during [bean delete]

    #-------------------------------------------------------------------
    # Constructor/Destructor

    constructor {args} {
        # FIRST, get the options.
        $self configurelist $args

        # NEXT, check the -rdb/-dbid pair
        if {$options(-rdb) ne ""} {
            set tag "$options(-rdb)/$options(-dbid)"

            if {$tag in $potList} {
                error "There exist two ::projectlib:beanpot objects for ($tag)."
            }
            lappend potList $tag
        }


        # FIRST, initialize the variables.
        set beans [dict create]
        $self reset
    }

    destructor {
        # FIRST, remove this beanpot from the potlist.
        ldelete potList "$options(-rdb)/$options(-dbid)"

        # NEXT, Destroy all beans in the pot.
        $self reset
    }

    #-------------------------------------------------------------------
    # Beanpot Reset

    # reset
    #
    # Destroys all beans, and resets the pot to its initial state.

    method reset {} {
        foreach bean [dict values $beans] {
            # Only destroy it if it exists
            if {[info object isa object $bean]} {
                $bean destroy
            }
        }

        set beans     [dict create]
        set pendingID 0
        set changed   0
        set deleting  0
        set deletions [dict create]
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
        # FIRST Get the next bean ID and object name.
        set id [$self nextid]
        incr pendingID
        set bean ${self}::[namespace tail $beanclass]$id

        # NEXT, create the new object.
        $beanclass create $bean {*}$args

        # NEXT, set its pot and ID.
        #
        # TBD: Since the pot and ID are embedded in the name, the
        # bean could retrieve them from the name.
        set ns [info object namespace $bean]
        set ${ns}::pot $self
        set ${ns}::id  $id

        # NEXT, remember it for lookup.
        dict set beans $id $bean

        # NEXT, the beanpot is now unsaved.
        $self markchanged

        # NEXT, return the name of the new bean.
        return $bean
    }

    # forget id
    #
    # id   - A bean ID for a bean in this pot.
    #
    # Forgets this bean, and prepares it for undeletion if we are deleting.
    # This is for use in the bean(n) destructor, and nowhere else.

    method forget {id} {
        if {$deleting} {
            if {[dict exists $beans $id]} {
                dict set deletions $id [$self UndeleteData [dict get $beans $id]]
            }
        }

        dict unset beans $id
        $self markchanged
        return
    }

    # uncreate bean
    #
    # bean - The bean to uncreate
    #
    # Undoes the creation of a bean, which must be the most recently 
    # created bean.

    method uncreate {bean} {
        require {[$bean id] == [$self lastid]} "not most recent bean: \"$bean\""

        $bean destroy
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
    # Sets the changed flag implicitly (because [$pot forget] is 
    # called).

    method delete {id} {
        if {![$self exists $id]} {
            error "no such bean: \"$id\""
        }

        set deletions [dict create]
        set deleting 1

        try {
            set bean [$self get $id]
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
        dict for {id blist} $deleteSet {
            my UndeleteBean $id $blist
        }

        my markchanged
    }

    # UndeleteData bean
    #
    # bean - A bean object
    #
    # Serializes the bean, so that it can be saved in a delete set.
    # The serialized form is a list,
    #
    #    <class> <object> <dict>

    method UndeleteData {bean} {
        list [info object class $bean] $bean [$bean getdict]
    }

    # UndeleteBean id blist
    #
    # id    - The bean's ID
    # blist - A serialized bean
    #
    # Deserializes the bean: recreates the object, sets its state, and
    # registers it.

    method UndeleteBean {id blist} { 
        lassign $blist bcls bean bdict

        # FIRST, Recreate the bean with its original name and
        # class.
        $bcls create $bean

        # NEXT, restore its data.
        set ns [info object namespace $bean]

        dict for {var value} $bdict {
            set ${ns}::$var $value
        }

        # NEXT, register it.
        dict set beans $id $bean
    }

    #-------------------------------------------------------------------
    # Checkpoint/Restore



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
    }


    # checkpoint ?-saved?
    #
    # Saves the pot to the -rdb
    # It can be used to restore them by calling [$pot restore].  If -saved
    # is given, the object's unsaved changes flag is cleared.

    method checkpoint {{flag ""}} {
        set data [dict create]
        
        my SaveBeansToRDB

        if {$flag eq "-saved"} {
            set changed 0
        }

        return
    }

    # SaveBeansToRDB
    #
    # Saves all beans to the beans table on checkpoint.

    method SaveBeansToRDB {} {
        set dbid $options(-dbid)

        $rdb eval {
            DELETE FROM beans WHERE dbid=$dbid;
        }

        foreach {id bean} $beans {
            set cls [info object class $bean_object]

            set bdict [$bean getdict]

            $rdb eval {
                INSERT INTO beans(dbid, id, bean_class, bean_dict)
                VALUES($dbid, $id, $cls, $bdict)
            }
        }
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
        # FIRST, destroy all registered beans.
        $self reset

        # NEXT, restore the checkpoint
        set dbid      $options(-dbid)

        $rdb eval {
            SELECT * FROM beans
            WHERE dbid=$dbid
            ORDER BY id
        } {
            set blist [list $bean_class $bean_dict]
            $self RestoreBean $id $bean_class $bean_dict
        }

        set changed [expr {$flag eq "-saved"}]

        return
    }

    # RestoreBean id cls bdict
    #
    # id    - The bean's ID
    # cls   - The bean's class
    # bdict - The bean's data dictionary.
    #
    # Deserializes the bean: recreates the object, sets its state, and
    # registers it.

    method RestoreBean {id cls bdict} { 
        # FIRST, Recreate the bean with its original ID and
        # class, naming it for use in this beanpot.  

        set bean ${self}::[namespace tail $cls]$id
        $cls create $bean

        # NEXT, restore its data.
        set ns [info object namespace $bean]

        dict for {var value} $bdict {
            set ${ns}::$var $value
        }
        set {$ns}::pot $self

        # NEXT, register it.
        dict set beans $id $bean
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

        error "$self contains no bean with ID $id"
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
        if {![$self exists $id]} {
            throw INVALID "Invalid object ID: \"$id\""
        }

        return $id     
    }

    # ids ?beanclass?
    #
    # Returns a list of the IDs of all beans in the pot, optionally
    # filtering for a given class.

    method ids {{beanclass ""}} {
        set result [list]

        foreach id [dict keys $beans] {
            if {$beanclass ne ""} {
                set bean [$self get $id]

                if {![info object isa typeof $bean $beanclass]} {
                    continue
                }
            }

            lappend result $id
        }

        return $result
    }

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

        set bean [$self get $id]

        return [$bean view $view]
    }

    # dump
    #
    # Dumps all beans

    method dump {} {
        set result ""
        foreach id [$self ids] {
            set bean [dict get $beans $id]
            append result \
                "$id ([info object class $bean]/$bean): [$bean getdict]\n"
        }
        return $result
    }

}


