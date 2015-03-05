#-----------------------------------------------------------------------
# TITLE:
#    hook.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena(n): Semantic Hook Manager
#
#    This module is responsible for managing semantic hooks and
#    the operations on them. As such, it is a type ensemble.
#    Semantic hooks are sent as part tactics that employ information
#    operations.
#
#-----------------------------------------------------------------------

snit::type ::athena::hook {
    #-------------------------------------------------------------------
    # Components

    component adb   ;# athenadb(n) component

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_   - The athenadb(n) that owns this instance.
    #
    # Initializes instances of this type
    
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
    # Returns a list of hook short names, also known as the
    # hook ID.

    method names {} {
        set names [$adb eval {
            SELECT hook_id FROM hooks ORDER BY hook_id
        }]
    }

    # namedict
    #
    # Returns the shortname/longname dictionary.

    method namedict {} {
        return [$adb eval {
            SELECT hook_id, longname FROM hooks ORDER BY hook_id
        }]
    }

    # get hook_id ?parm?
    #
    # hook_id    - A hook ID 
    # parm       - A column in the hooks table
    #
    # Retrieves a row dictionary, or a particular column value from
    # hooks.

    method get {hook_id {parm ""}} {
        # FIRST, get the data
        $adb eval {SELECT * FROM gui_hooks WHERE hook_id=$hook_id} row {
            if {$parm ne ""} {
                return $row($parm)
            } else {
                unset row(*)
                return [array get row]
            }
        }

        return ""
    }

    # getdict hook_id
    #
    # hook_id   - A hook ID
    #
    # Retrieves a dictionary of topics and positions defined
    # for the semantic hook with the supplied ID. Only "normal"
    # hook_topics are included.

    method getdict {hook_id} {
        array set data [$adb eval {
            SELECT topic_id, position
            FROM hook_topics
            WHERE hook_id=$hook_id AND state='normal'
        }]

        return [array get data]
    }
        

    # validate hook_id
    #
    # hook_id - Possibly, a hook ID.
    #
    # Validates a hook ID

    method validate {hook_id} {
        set ids [$adb eval {SELECT hook_id FROM hooks}]

        if {$hook_id ni $ids} {
            set valid [join $ids ", "]

            if {$valid ne ""} {
                set msg "should be one of: $valid"
            } else {
                set msg "none are defined"
            }

            return -code error -errorcode INVALID \
                "Invalid hook ID, $msg"
        }

        return $hook_id
    }

    # topic validate id
    #
    # id   - Possibly a hook/topic id pair
    #
    # Validates a hook/topic pair  

    method {topic validate} {id} {
        lassign $id hook_id topic_id

        # FIRST, see if the individual IDs are okay
        set hook_id  [$self validate $hook_id]
        set topic_id [$adb bsys topic validate $topic_id]

        # NEXT, check that they exist together in the hook_topics 
        # table
        set ids [$adb eval {SELECT id FROM hook_topics_view}]

        if {$id ni $ids} {
            set valid [join $ids ", "]

            if {$valid ne ""} {
                set msg "should be one of: $valid"
            } else {
                set msg "none are defined"
            }

            return -code error -errorcode INVALID \
                "Invalid hook/topic pair, $msg"
        }

        return $id
    }

    # topic exists id
    #
    # id   - Possibly a hook/topic id pair
    #
    # Returns 1 if the pair exists, 0 otherwise

    method {topic exists} {id} {
        lassign $id hook_id topic_id

        # FIRST, see if we have an instance of one
        set exists [$adb exists {
            SELECT * FROM hook_topics
            WHERE hook_id=$hook_id AND topic_id=$topic_id
        }]

        return $exists
    }

    # topic get   id ?parm?
    #
    # id      - a hook/topic pair that serves as an ID
    # parm    - a column in the hook_topics table
    #
    # Retrieves a row dictionary, or a particular column value from
    # hook_topics 

    method {topic get} {id {parm ""}} {
        # FIRST, assign the ids to the appropriate columns
        lassign $id hook_id topic_id

        # NEXT, get the data
        $adb eval {
            SELECT * FROM gui_hook_topics 
            WHERE hook_id=$hook_id AND topic_id=$topic_id
        } row {
            if {$parm ne ""} {
                return $row($parm)
            } else {
                unset row(*)
                return [array get row]
            }
        }

        return ""
    }

    #-------------------------------------------------------------------
    # Mutators
    #
    # Mutators are used to implement orders that change the scenario in
    # some way.  Mutators assume that their inputs are valid, and returns
    # a script of one or more commands that will undo the change.  When
    # change cannot be undone, the mutator returns the empty string.

    # create parmdict
    #
    # parmdict     A dictionary of hook parms
    #
    #    hook_id        The semantic hook's short name
    #    longname       The semantic hook's long name
    #
    # Creates a semantic hook given the parms, which are presumed to be
    # valid.

    method create {parmdict} {
        dict with parmdict {
            # FIRST, Put the hook in the database
            $adb eval {
                INSERT INTO 
                hooks(hook_id,  
                      longname)
                VALUES($hook_id, 
                       $longname) 
            }

            # NEXT, Return undo command.
            return [mymethod delete $hook_id]
        }
    }

    # delete hook_id
    #
    # hook_id     A semantic hook ID
    #
    # Deletes the semantic hook.

    method delete {hook_id} {
        # FIRST, get undo information
        set mdata [$adb grab ioms {hook_id=$hook_id}]

        # NEXT, remove it from the database
        set hdata [$adb delete -grab hooks {hook_id=$hook_id}]

        # NEXT, return the undo script
        return [list $adb ungrab [concat $hdata $mdata]]
    }

    # update parmdict
    #
    # parmdict     A dictionary of semantic hook parms
    #
    #    hook_id        A semantic hook short name
    #    longname       A new long name, or ""
    #
    # Updates a semantic hook given the parms, which are presumed to be
    # valid.

    method update {parmdict} {
        dict with parmdict {
            # FIRST, get the undo information
            set data [$adb grab hooks {hook_id=$hook_id}]

            # NEXT, Update the hook
            $adb eval {
                UPDATE hooks
                SET longname = nonempty($longname, longname)
                WHERE hook_id=$hook_id;
            } {}

            # NEXT, Return the undo command
            return [list $adb ungrab $data]
        }
    }


    # topic create parmdict
    #
    # parmdict     A dictionary of hook/topic parms
    #
    #     hook_id    A hook
    #     topic_id   A bsys topic
    #     position   A qposition(n) value 
    #
    # Creates a hook/topic record upon which a semantic hook takes a 
    # position. Used as part of an Info Ops Message (IOM).

    method {topic create} {parmdict} {
        dict with parmdict {

            $adb eval {
                INSERT INTO 
                hook_topics(hook_id,
                            topic_id,
                            position)
                VALUES($hook_id,
                       $topic_id,
                       $position)
            }
            
            return \
                [mymethod topic delete [list $hook_id $topic_id]]
        }
    }

    # topic update parmdict
    #
    # parmdict    A dictionary of hook/topic parms
    #
    #    id       A hook/topic id pair that identifies the record
    #    position A qposition(n) value
    #
    # Updates the database with the supplied hook/topic pair to have the
    # provided position on the topic.

    method {topic update} {parmdict} {
        dict with parmdict {
            lassign $id hook_id topic_id

            set tdata [$adb grab \
                hook_topics {hook_id=$hook_id AND topic_id=$topic_id}]

            $adb eval {
                UPDATE hook_topics
                SET position   = nonempty($position,  position)
                WHERE hook_id=$hook_id AND topic_id=$topic_id
            }

            # NEXT, grab the hook undo information should this
            # topic go away
            set hdata [$adb grab hooks {hook_id=$hook_id}]
            
            return [list $adb ungrab [concat $tdata $hdata]]
        }
    }

    # topic delete id
    # 
    # id    The unique identifier for the hook/topic pair
    #
    # Removes the record from the database that contains the supplied
    # hook/topic pair

    method {topic delete} {id} {
        lassign $id hook_id topic_id

        # FIRST, grab the undo information
        set tdata [$adb delete \
            -grab hook_topics {hook_id=$hook_id AND topic_id=$topic_id}]

        set hdata [$adb grab hooks {hook_id=$hook_id}]

        return [list $adb ungrab [concat $tdata $hdata]]
    }

    # topic state id state
    #
    # id      The unique identifier for the hook/topic pair
    # state   The state of the hook topic: normal
    #
    # Sets the state of the hook topic to one of:
    #    normal, disabled, invalid

    method {topic state} {id state} {
        lassign $id hook_id topic_id

        # FIRST, grab the undo information
        set tdata [$adb grab \
            hook_topics {hook_id=$hook_id AND topic_id=$topic_id}]

        set hdata [$adb grab hooks {hook_id=$hook_id}]

        $adb eval {
            UPDATE hook_topics
            SET state=$state
            WHERE hook_id=$hook_id AND topic_id=$topic_id
        }

        return [list $adb ungrab [concat $tdata $hdata]]
    }


    #-------------------------------------------------------------------
    # SQL Function Implementations

    # hook_narrative hook_id
    #
    # hook_id  - The ID of a semantic hook
    #
    # This method recomputes the user friendly narrative for a semantic
    # hook.
    
    method hook_narrative {hook_id} {
        # FIRST, get the longname of this hook from the $adb
        set longname [$adb onecolumn {
            SELECT longname FROM hooks 
            WHERE hook_id=$hook_id
        }]

        # NEXT, trim of any trailing punctuation and add a colon
        set longname [string trimright $longname ".!;?,:"]

        set narr "$longname: "

        # NEXT, grab all positions on this topic and build the narrative
        set positions [$adb eval {
            SELECT narrative FROM gui_hook_topics 
            WHERE hook_id=$hook_id
            AND   state='normal'
        }]

        if {[llength $positions] == 0} {
            append narr "No position on any topics"

            return $narr
        }
        
        append narr [join $positions "; "]

        return $narr
    }

    

    #-------------------------------------------------------------------
    # Order Helpers

    # UnusedTopics hook_id
    #
    # hook_id   - An existing semantic hook ID
    #
    # Returns an id/name dictionary of the belief system topics not 
    # currently used by this hook.

    method UnusedTopics {hook_id} {
        # FIRST, get the topic IDs used by this hook.

        # FIRST, get the topic id/name dictionary for all topics.
        set ndict [$adb bsys topic namedict]

        # NEXT, remove the ones that have already been used.
        $adb eval {
            SELECT topic_id FROM hook_topics
            WHERE hook_id=$hook_id
        } {
            dict unset ndict $topic_id
        }

        return $ndict
    }

    # LoadPosition idict id
    #
    # idict - Item dictionary
    # id    - hook_topics ID
    #
    # This method returns the position as a symbol.

    method LoadPosition {idict id} {
        set pos [$adb onecolumn {
            SELECT position FROM gui_hook_topics
            WHERE id=$id
        }]

        if {$pos ne ""} {
            return [dict create position [qposition name $pos]]
        } else {
            return ""
        }
    }
}

#-----------------------------------------------------------------------
# Orders: HOOK:*

# HOOK:CREATE
#
# Creates new semantic hooks.

::athena::orders define HOOK:CREATE {
    meta title "Create Semantic Hook"

    meta sendstates PREP

    meta parmlist {
        hook_id
        longname
    }

    meta form {
        rcc "Hook ID:" -for hook_id
        text hook_id

        rcc "Long Name:" -for longname
        text longname -width 40
    }


    method _validate {} {
        my prepare hook_id  -toupper -required -type ident  
        my unused hook_id
        my prepare longname -normalize
    }

    method _execute {{flunky ""}} {
        if {$parms(longname) eq ""} {
            set parms(longname) $parms(hook_id)
        }

        my setundo [$adb hook create [array get parms]]
    }
}

# HOOK:DELETE
#
# Deletes semantic hooks

::athena::orders define HOOK:DELETE {
    meta title "Delete Semantic Hook"
    meta sendstates PREP

    meta parmlist {hook_id}

    meta form {
        rcc "Hook ID:" -for hook_id
        hook hook_id
    }


    method _validate {} {
        my prepare hook_id -toupper -required -type [list $adb hook]
    }

    method _execute {{flunky ""}} {
        if {[my mode] eq "gui"} {
            set answer [messagebox popup \
                            -title         "Are you sure?"                  \
                            -icon          warning                          \
                            -buttons       {ok "Delete it" cancel "Cancel"} \
                            -default       cancel                           \
                            -onclose       cancel                           \
                            -ignoretag     [my name]                        \
                            -ignoredefault ok                               \
                            -parent        [app topwin]                     \
                            -message       [normalize {
                                Are you sure you
                                really want to delete this semantic hook 
                                and all hook topics that depend on it?
                            }]]

            if {$answer eq "cancel"} {
                my cancel
            }
        }

        my setundo [$adb hook delete $parms(hook_id)]
    }
}


# HOOK:UPDATE
#
# Updates existing semantic hooks.

::athena::orders define HOOK:UPDATE {
    meta title "Update Semantic Hook"
    meta sendstates PREP

    meta parmlist {
        hook_id
        longname
    }

    meta form {
        rcc "Select Hook:" -for hook_id
        hook hook_id \
            -loadcmd {$order_ keyload hook_id *}

        rcc "Long Name:"
        text longname -width 40
    }


    method _validate {} {
        my prepare hook_id      -toupper   -required -type [list $adb hook]
        my prepare longname     -normalize
    }

    method _execute {{flunky ""}} {
        my setundo [$adb hook update [array get parms]]
    }
}

# HOOK:TOPIC:CREATE
#
# Creates a new semantic hook/topic pair

::athena::orders define HOOK:TOPIC:CREATE {
    meta title "Create Semantic Hook Topic"

    meta sendstates PREP

    meta parmlist {
        hook_id
        longname
        topic_id
        position
    }

    meta form {
        rcc "Hook ID:" -for hook_id
        hook hook_id -context yes

        rcc "Description:" -for longname
        disp longname -width 40

        rcc "Topic ID:" -for topic_id
        enumlong topic_id -dictcmd {$adb_ hook UnusedTopics $hook_id} -showkeys 1
        
        rcc "Position:" -for position
        enumlong position -dictcmd {qposition namedict}
    }


    method _validate {} {
        my prepare hook_id       -toupper -required -type [list $adb hook]
        my prepare topic_id      -toupper -required -type [list $adb bsys topic]
        my prepare position -num -toupper -required -type qposition 

        my returnOnError 

        if {[$adb hook topic exists [list $parms(hook_id) $parms(topic_id)]]} {
            my reject topic_id "Hook/Topic pair already exists"
        }
    }

    method _execute {{flunky ""}} {
        my setundo [$adb hook topic create [array get parms]]
    }
}

# HOOK:TOPIC:DELETE
#
# Removes a semantic hook topic from the database

::athena::orders define HOOK:TOPIC:DELETE {
    meta title "Delete Semantic Hook Topic"

    meta sendstates PREP

    meta parmlist {
        id
    }
    
    meta form {
        rcc "Hook/Topic:" -for id
        dbkey id -table gui_hook_topics -keys {hook_id topic_id} \
            -labels {"Of" "On"}
    }


    method _validate {} {
        my prepare id   -toupper -required -type [list $adb hook topic]
    }

    method _execute {{flunky ""}} {
        my setundo [$adb hook topic delete $parms(id)]
    }
}

# HOOK:TOPIC:UPDATE
#
# Updates an existing hook/topic pair

::athena::orders define HOOK:TOPIC:UPDATE {
    meta title "Update Semantic Hook Topic"

    meta sendstates PREP 

    meta parmlist {
        id
        position
    }

    meta form {
        rcc "Hook/Topic:" -for id
        dbkey id -table gui_hook_topics -keys {hook_id topic_id} \
            -labels {"Of" "On"} \
            -loadcmd {$adb_ hook LoadPosition}

        rcc "Position:" -for position
        enumlong position -dictcmd {qposition namedict}
    }


    method _validate {} {
        my prepare id            -toupper -required -type [list $adb hook topic]
        my prepare position -num -toupper -required -type qposition
    }

    method _execute {{flunky ""}} {
        my setundo [$adb hook topic update [array get parms]]
    }
}


# HOOK:TOPIC:STATE
#
# Updates the state of a hook topic

::athena::orders define HOOK:TOPIC:STATE {
    meta title "Set Semantic Hook State"

    meta sendstates {PREP}

    meta parmlist {
        id
        state
    }

    meta form {
        dbkey id -table gui_hook_topics -keys {hook_id topic_id} 
        text state
    }


    method _validate {} {
        my prepare id    -required          -type [list $adb hook topic]
        my prepare state -required -tolower -type etopic_state
    }

    method _execute {{flunky ""}} {
        my setundo [$adb hook topic state $parms(id) $parms(state)]
    }
}



