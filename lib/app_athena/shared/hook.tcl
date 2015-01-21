#-----------------------------------------------------------------------
# TITLE:
#    hook.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena_sim(1): Semantic Hook Manager
#
#    This module is responsible for managing semantic hooks and
#    the operations on them. As such, it is a type ensemble.
#    Semantic hooks are sent as part tactics that employ information
#    operations.
#
#-----------------------------------------------------------------------

snit::type hook {
    # Make it a singleton
    pragma -hasinstances no


    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.

    # names
    #
    # Returns a list of hook short names, also known as the
    # hook ID.

    typemethod names {} {
        set names [rdb eval {
            SELECT hook_id FROM hooks ORDER BY hook_id
        }]
    }

    # namedict
    #
    # Returns the shortname/longname dictionary.

    typemethod namedict {} {
        return [rdb eval {
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

    typemethod get {hook_id {parm ""}} {
        # FIRST, get the data
        rdb eval {SELECT * FROM gui_hooks WHERE hook_id=$hook_id} row {
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

    typemethod getdict {hook_id} {
        array set data [rdb eval {
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

    typemethod validate {hook_id} {
        set ids [rdb eval {SELECT hook_id FROM hooks}]

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

    typemethod {topic validate} {id} {
        lassign $id hook_id topic_id

        # FIRST, see if the individual IDs are okay
        set hook_id  [hook validate $hook_id]
        set topic_id [bsys topic validate $topic_id]

        # NEXT, check that they exist together in the hook_topics 
        # table
        set ids [rdb eval {SELECT id FROM hook_topics_view}]

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

    typemethod {topic exists} {id} {
        lassign $id hook_id topic_id

        # FIRST, see if we have an instance of one
        set exists [rdb exists {
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

    typemethod {topic get} {id {parm ""}} {
        # FIRST, assign the ids to the appropriate columns
        lassign $id hook_id topic_id

        # NEXT, get the data
        rdb eval {
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

    # mutate create parmdict
    #
    # parmdict     A dictionary of hook parms
    #
    #    hook_id        The semantic hook's short name
    #    longname       The semantic hook's long name
    #
    # Creates a semantic hook given the parms, which are presumed to be
    # valid.

    typemethod {mutate create} {parmdict} {
        dict with parmdict {
            # FIRST, Put the hook in the database
            rdb eval {
                INSERT INTO 
                hooks(hook_id,  
                      longname)
                VALUES($hook_id, 
                       $longname) 
            }

            # NEXT, Return undo command.
            return [mytypemethod mutate delete $hook_id]
        }
    }

    # mutate delete hook_id
    #
    # hook_id     A semantic hook ID
    #
    # Deletes the semantic hook.

    typemethod {mutate delete} {hook_id} {
        # FIRST, get undo information
        set mdata [rdb grab ioms {hook_id=$hook_id}]

        # NEXT, remove it from the database
        set hdata [rdb delete -grab hooks {hook_id=$hook_id}]

        # NEXT, return the undo script
        return [list rdb ungrab [concat $hdata $mdata]]
    }

    # mutate update parmdict
    #
    # parmdict     A dictionary of semantic hook parms
    #
    #    hook_id        A semantic hook short name
    #    longname       A new long name, or ""
    #
    # Updates a semantic hook given the parms, which are presumed to be
    # valid.

    typemethod {mutate update} {parmdict} {
        dict with parmdict {
            # FIRST, get the undo information
            set data [rdb grab hooks {hook_id=$hook_id}]

            # NEXT, Update the hook
            rdb eval {
                UPDATE hooks
                SET longname = nonempty($longname, longname)
                WHERE hook_id=$hook_id;
            } {}

            # NEXT, Return the undo command
            return [list rdb ungrab $data]
        }
    }


    # mutate topic create parmdict
    #
    # parmdict     A dictionary of hook/topic parms
    #
    #     hook_id    A hook
    #     topic_id   A bsys topic
    #     position   A qposition(n) value 
    #
    # Creates a hook/topic record upon which a semantic hook takes a 
    # position. Used as part of an Info Ops Message (IOM).

    typemethod {mutate topic create} {parmdict} {
        dict with parmdict {

            rdb eval {
                INSERT INTO 
                hook_topics(hook_id,
                            topic_id,
                            position)
                VALUES($hook_id,
                       $topic_id,
                       $position)
            }
            
            return \
                [mytypemethod mutate topic delete [list $hook_id $topic_id]]
        }
    }

    # mutate topic update parmdict
    #
    # parmdict    A dictionary of hook/topic parms
    #
    #    id       A hook/topic id pair that identifies the record
    #    position A qposition(n) value
    #
    # Updates the database with the supplied hook/topic pair to have the
    # provided position on the topic.

    typemethod {mutate topic update} {parmdict} {
        dict with parmdict {
            lassign $id hook_id topic_id

            set tdata [rdb grab \
                hook_topics {hook_id=$hook_id AND topic_id=$topic_id}]

            rdb eval {
                UPDATE hook_topics
                SET position   = nonempty($position,  position)
                WHERE hook_id=$hook_id AND topic_id=$topic_id
            }

            # NEXT, grab the hook undo information should this
            # topic go away
            set hdata [rdb grab hooks {hook_id=$hook_id}]
            
            return [list rdb ungrab [concat $tdata $hdata]]
        }
    }

    # mutate topic delete id
    # 
    # id    The unique identifier for the hook/topic pair
    #
    # Removes the record from the database that contains the supplied
    # hook/topic pair

    typemethod {mutate topic delete} {id} {
        lassign $id hook_id topic_id

        # FIRST, grab the undo information
        set tdata [rdb delete \
            -grab hook_topics {hook_id=$hook_id AND topic_id=$topic_id}]

        set hdata [rdb grab hooks {hook_id=$hook_id}]

        return [list rdb ungrab [concat $tdata $hdata]]
    }

    # mutate topic state id state
    #
    # id      The unique identifier for the hook/topic pair
    # state   The state of the hook topic: normal
    #
    # Sets the state of the hook topic to one of:
    #    normal, disabled, invalid

    typemethod {mutate topic state} {id state} {
        lassign $id hook_id topic_id

        # FIRST, grab the undo information
        set tdata [rdb grab \
            hook_topics {hook_id=$hook_id AND topic_id=$topic_id}]

        set hdata [rdb grab hooks {hook_id=$hook_id}]

        rdb eval {
            UPDATE hook_topics
            SET state=$state
            WHERE hook_id=$hook_id AND topic_id=$topic_id
        }

        return [list rdb ungrab [concat $tdata $hdata]]
    }


    #-------------------------------------------------------------------
    # SQL Function Implementations

    # hook_narrative hook_id
    #
    # hook_id  - The ID of a semantic hook
    #
    # This method recomputes the user friendly narrative for a semantic
    # hook.
    
    proc hook_narrative {hook_id} {
        # FIRST, get the longname of this hook from the rdb
        set longname [rdb onecolumn {
            SELECT longname FROM hooks 
            WHERE hook_id=$hook_id
        }]

        # NEXT, trim of any trailing punctuation and add a colon
        set longname [string trimright $longname ".!;?,:"]

        set narr "$longname: "

        # NEXT, grab all positions on this topic and build the narrative
        set positions [rdb eval {
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

    typemethod UnusedTopics {hook_id} {
        # FIRST, get the topic IDs used by this hook.

        # FIRST, get the topic id/name dictionary for all topics.
        set ndict [bsys topic namedict]

        # NEXT, remove the ones that have already been used.
        rdb eval {
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

    typemethod LoadPosition {idict id} {
        set pos [rdb onecolumn {
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

myorders define HOOK:CREATE {
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

        my setundo [hook mutate create [array get parms]]
    }
}

# HOOK:DELETE
#
# Deletes semantic hooks

myorders define HOOK:DELETE {
    meta title "Delete Semantic Hook"
    meta sendstates PREP

    meta parmlist {hook_id}

    meta form {
        rcc "Hook ID:" -for hook_id
        hook hook_id
    }


    method _validate {} {
        my prepare hook_id -toupper -required -type hook
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

        my setundo [hook mutate delete $parms(hook_id)]
    }
}


# HOOK:UPDATE
#
# Updates existing semantic hooks.

myorders define HOOK:UPDATE {
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
        my prepare hook_id      -toupper   -required -type hook
        my prepare longname     -normalize
    }

    method _execute {{flunky ""}} {
        my setundo [hook mutate update [array get parms]]
    }
}

# HOOK:TOPIC:CREATE
#
# Creates a new semantic hook/topic pair

myorders define HOOK:TOPIC:CREATE {
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
        enumlong topic_id -dictcmd {hook UnusedTopics $hook_id} -showkeys 1
        
        rcc "Position:" -for position
        enumlong position -dictcmd {qposition namedict}
    }


    method _validate {} {
        my prepare hook_id       -toupper -required -type hook
        my prepare topic_id      -toupper -required -type {bsys topic}
        my prepare position -num -toupper -required -type qposition 

        my returnOnError 

        if {[hook topic exists [list $parms(hook_id) $parms(topic_id)]]} {
            my reject topic_id "Hook/Topic pair already exists"
        }
    }

    method _execute {{flunky ""}} {
        my setundo [hook mutate topic create [array get parms]]
    }
}

# HOOK:TOPIC:DELETE
#
# Removes a semantic hook topic from the database

myorders define HOOK:TOPIC:DELETE {
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
        my prepare id   -toupper -required -type {hook topic}
    }

    method _execute {{flunky ""}} {
        my setundo [hook mutate topic delete $parms(id)]
    }
}

# HOOK:TOPIC:UPDATE
#
# Updates an existing hook/topic pair

myorders define HOOK:TOPIC:UPDATE {
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
            -loadcmd {hook LoadPosition}

        rcc "Position:" -for position
        enumlong position -dictcmd {qposition namedict}
    }


    method _validate {} {
        my prepare id            -toupper -required -type {hook topic}
        my prepare position -num -toupper -required -type qposition
    }

    method _execute {{flunky ""}} {
        my setundo [hook mutate topic update [array get parms]]
    }
}


# HOOK:TOPIC:STATE
#
# Updates the state of a hook topic

myorders define HOOK:TOPIC:STATE {
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
        my prepare id    -required          -type {hook topic}
        my prepare state -required -tolower -type etopic_state
    }

    method _execute {{flunky ""}} {
        my setundo [hook mutate topic state $parms(id) $parms(state)]
    }
}



