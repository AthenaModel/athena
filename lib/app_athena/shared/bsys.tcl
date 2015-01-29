#-----------------------------------------------------------------------
# TITLE:
#    bsys.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n) Belief Systems
#
#    This module wraps the mam(n) object that contains and 
#    computes Athena's belief systems, and also defines the relevant
#    orders.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# bsys ensemble

snit::type bsys {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Components

    typecomponent mam       ;# The mam module

    #-------------------------------------------------------------------
    # Type Variables


    # info - Checkpointed data
    #
    #  system-counter  - ID counter for system entities.
    #  topic-counter   - ID counter for topic entities.

    typevariable info -array { }

    # defaultInfo - Default info() content.

    typevariable defaultInfo {
        system-counter 0
        topic-counter  0
    }

    #-------------------------------------------------------------------
    # Singleton Initializer

    # init
    #
    # Initializes the module from a software point of view.
    # On scenario lock, the "start" typemethod initializes the
    # module from a simulation point of view.

    typemethod init {} {
        log normal bsys "init"

        # FIRST, initialize the mam typecomponent variable so that
        # delegation will work:
        set mam ::simlib::mam

        # NEXT, register this module as a saveable
        athena register $type

        log normal bsys "init complete"
    }

    # clear
    #
    # Clears the belief system data, and reinitializes it with the
    # default "Neutral" belief system.

    typemethod clear {} {
        mam clear

        array set info $defaultInfo

        set info(system-counter) 1
        $mam system add $info(system-counter)
        $type system configure $info(system-counter) -name "Neutral"
    }

    # start
    #
    # Ensures that affinities have been computed on scenario lock.

    typemethod start {} {
        $type compute
    }

    # compute
    #
    # Forces a recalc.

    typemethod compute {} {
        $mam compute
    }

    #-------------------------------------------------------------------
    # saveable(i) interface

    # checkpoint ?-saved?
    #
    # Returns a checkpoint of the non-RDB simulation data.  If 
    # -saved is specified, the data is marked unchanged.

    typemethod checkpoint {{option ""}} {
        dict set checkpoint info [array get info]
        dict set checkpoint mam  [$mam checkpoint $option]

        return $checkpoint
    }

    # restore checkpoint ?-saved?
    #
    # checkpoint - A string returned by the checkpoint typemethod
    #
    # Restores the non-RDB state of the module to that contained
    # in the checkpoint.  If -saved is specified, the data is marked
    # unchanged.
    
    typemethod restore {checkpoint {option ""}} {
        # FIRST, restore the checkpoint data
        $type clear
        array set info [dict get $checkpoint info]

        $mam restore [dict get $checkpoint mam]
        return
    }


    #-------------------------------------------------------------------
    # Public Typemethods


    delegate typemethod {playbox *} to mam using {%c playbox %m}
    delegate typemethod {system *}  to mam using {%c system %m}
    delegate typemethod {topic *}   to mam using {%c topic %m}
    delegate typemethod {belief *}  to mam using {%c belief %m}
    delegate typemethod *           to mam

    # system validate sid
    #
    # sid - A system ID
    #
    # Validates the system ID.

    typemethod {system validate} {sid} {
        if {![$mam system exists $sid]} {
            return -code error -errorcode INVALID \
                "Invalid belief system ID"
        }

        return $sid
    }

    # system inuse sid
    #
    # sid  - A system ID
    #
    # Returns 1 if the system is in use, and 0 otherwise.

    typemethod {system inuse} {sid} {
        return [rdb exists {
            SELECT a FROM actors WHERE bsid=$sid
            UNION
            SELECT g FROM groups WHERE bsid=$sid
        }]
    }

    # editable validate sid
    #
    # sid - An system ID
    #
    # Validates the system ID as an editable system ID.

    typemethod {editable validate} {sid} {
        if {![$mam system exists $sid]} {
            return -code error -errorcode INVALID \
                "Invalid belief system ID"
        }

        if {$sid == 1} {
            return -code error -errorcode INVALID \
                "The Neutral belief system cannot be modified."
        }

        return $sid
    }


    # topic validate tid
    #
    # tid - A topic ID
    #
    # Validates the topic ID.

    typemethod {topic validate} {tid} {
        if {![$mam topic exists $tid]} {
            return -code error -errorcode INVALID \
                "Invalid topic ID"
        }

        return $tid
    }

    # topic inuse tid
    #
    # tid  - A topic ID
    #
    # Returns 1 if the topic is in use, and 0 otherwise.

    typemethod {topic inuse} {tid} {
        return [rdb exists {
            SELECT topic_id FROM hook_topics WHERE topic_id=$tid
        }]
    }


    # belief validate bid
    #
    # bid - An {sid tid} pair
    #
    # Validates the belief ID.

    typemethod {belief validate} {bid} {
        lassign $bid sid tid

        $type editable validate $sid
        $type topic validate $tid

        return $bid
    }

    # belief isdefault bid
    # 
    # bid - An {sid tid} pair.
    #
    # Returns 1 if the belief has its default value, and 0 otherwise.

    typemethod {belief isdefault} {bid} {
        set dict [$mam belief get {*}$bid]

        dict with dict {
            return [expr {$position == 0.0 && $emphasis == 0.5}]
        }
    }

    #-------------------------------------------------------------------
    # SQL Functions
    #
    # These functions are added to the RDB in scenario(sim).

    # bsysname bsid
    #
    # bsid  - A belief system ID
    #
    # Returns the bsid's name.

    proc bsysname {bsid} {
        return "[$mam system get $bsid name] ($bsid)"
    }

    # topicname tid
    #
    # tid  - A belief topic ID
    #
    # Returns the topic's name.

    proc topicname {tid} {
        return [$mam topic get $tid name]
    }

    # affinity bsid1 bsid2
    #
    # bsid1  - A belief system ID
    # bsid2  - A belief system ID
    #
    # Returns affinity of bsid1 for bsid2.

    proc affinity {bsid1 bsid2} {
        return [$mam affinity $bsid1 $bsid2]
    }

    

    #-------------------------------------------------------------------
    # Mutators

    # mutate add etype id
    #
    # etype  - system | topic
    # id     - The entity ID, or "" to assign a new one.
    #
    # Adds an entity of the given type, and returns a list
    # of two items: the assigned ID, and the undo script.

    typemethod {mutate add} {etype id} {
        set oldCounter $info($etype-counter)

        if {$id eq ""} {
            set id [incr info($etype-counter)]
        } else {
            let info($etype-counter) { max($id, $oldCounter) }
        }

        $mam $etype add $id

        notifier send ::bsys <$etype> add $id

        return [list $id [mytypemethod UndoAdd $etype $oldCounter $id]]
    }

    # UndoAdd etype oldCounter id 
    #
    # etype      - system | topic
    # oldCounter - Old value of the entity counter
    # id         - ID of the entity
    #
    # Undoes the add of the entity.

    typemethod UndoAdd {etype oldCounter id} {
        $mam $etype delete $id
        set info($etype-counter) $oldCounter

        notifier send ::bsys <$etype> delete $id
    }

    # mutate update etype id pdict
    #
    # etype    - playbox | system | topic | belief
    # id       - The etype ID
    # pdict    - The parameter dictionary
    #
    # Modifies a mam entity's metadata given its type, ID, and the 
    # new parameters.  For playbox, the id is "" and for
    # belief the id is "$sid $tid".

    typemethod {mutate update} {etype id pdict} {
        set undoData [$mam $etype get {*}$id]

        dict for {parm value} $undoData {
            if {![dict exists $pdict $parm]} {
                # Skip; the attribute is not being set.
                continue
            }

            set value [dict get $pdict $parm]

            if {$value eq ""} {
                # Skip; the attribute is not being set.
                continue
            }

            $mam $etype set {*}$id $parm $value
        }

        notifier send ::bsys <$etype> update $id

        return [mytypemethod UndoUpdate $etype $id $undoData]
    }

    # UndoUpdate etype id undoData 
    #
    # etype    - playbox | system | topic | belief
    # id       - ID of the entity
    # undoData - parameters to restore
    #
    # Undoes the update of the entity.

    typemethod UndoUpdate {etype id undoData} {
        $mam $etype set {*}$id $undoData

        notifier send ::bsys <$etype> update $id
    }
    
    # mutate delete etype id
    #
    # etype  - system | topic
    # id     - The etype's ID
    #
    # Deletes the entity, and returns the undo script.

    typemethod {mutate delete} {etype id} {
        set undoData [$mam $etype delete $id]

        notifier send ::bsys <$etype> delete $id

        return [mytypemethod UndoDelete $etype $id $undoData]
    }

    # UndoDelete etype id undoData 
    #
    # etype    - system | topic
    # id       - ID of the entity
    # undoData - Undo returned by [mam $entity delete]
    #
    # Undoes the deletion of the entity.

    typemethod UndoDelete {etype id undoData} {
        $mam $etype undelete $undoData

        notifier send ::bsys <$etype> add $id
    }


    #-------------------------------------------------------------------
    # Order Helpers

    # viewload etype idict id
    #
    # etype    - playbox | system | topic | belief
    # idict    - field -loadcmd item dictionary
    # id       - The etype ID
    #
    # Generic ID field -loadcmd callback for mam entities.

    proc viewload {etype idict id} {
        if {$id eq ""} {
            return [dict create]
        }

        set view [$mam $etype view {*}$id]

        return $view
    }

    # system4bid bid
    #
    # bid  - A belief ID
    #
    # Returns the belief system's name for display

    proc system4bid {bid} {
        lassign $bid sid tid

        if {![$mam system exists $sid]} {
            return "Unknown"
        } else {
            return "[$mam system cget $sid -name] ($sid)"
        }
    }

    # topic4bid bid
    #
    # bid  - A belief ID
    #
    # Returns the topic name for display

    proc topic4bid {bid} {
        lassign $bid sid tid

        if {![$mam topic exists $tid]} {
            return "Unknown"
        } else {
            return "[$mam topic cget $tid -name] ($tid)"
        }
    }
}

#-----------------------------------------------------------------------
# BSys Orders

# BSYS:PLAYBOX:UPDATE
#
# Updates playbox-wide parameters


::athena::orders define BSYS:PLAYBOX:UPDATE {
    meta title "Update Playbox-wide Belief System Parameters"

    meta sendstates PREP

    meta parmlist {gamma}

    meta form {
        # NOTE: dialog is not used
        rcc "Gamma:" -for gamma
        text gamma
    }


    method _validate {} {
        my prepare gamma -required -num -type ::simlib::rmagnitude
    }

    method _execute {{flunky ""}} {
        my setundo [bsys mutate update playbox "" [array get parms]]
        return
    }    
}


# BSYS:SYSTEM:ADD
#
# Adds a new belief system with default settings.  Returns new
# system ID.

::athena::orders define BSYS:SYSTEM:ADD {
    meta title "Add New Belief System"

    meta sendstates PREP

    meta parmlist {sid}

    meta form {
        # Note: the form is not used.
        rcc "SID:" -for sid
        text sid
    }


    method _validate {} {
        my prepare sid -num -type ::marsutil::count
        my returnOnError

        my checkon sid {
            if {$parms(sid) in [bsys system ids]} {
                my reject sid \
                    "Belief system ID is already in use: \"$parms(sid)\""
            }
        }
    }

    method _execute {{flunky ""}} {
        lassign [::bsys mutate add system $parms(sid)] sid undoScript

        my setundo $undoScript

        # NOTE: The sid is optional in the order, so we need to return
        # the ID actually used.
        return $sid
    }
}


# BSYS:SYSTEM:UPDATE
#
# Updates system parameters

::athena::orders define BSYS:SYSTEM:UPDATE {
    meta title "Update Belief System Metadata"

    meta sendstates PREP

    meta parmlist {sid name commonality}

    meta form {
        rcc "System ID:" -for sid
        text sid -context yes \
            -loadcmd {bsys::viewload system}

        rcc "Name:" -for name
        text name

        rcc "Commonality Fraction:" -for commonality
        range commonality          \
            -datatype    rfraction \
            -showsymbols no        \
            -resetvalue  1.0 
    }


    method _validate {} {
        my prepare sid          -toupper -required -type {bsys editable}
        my prepare name
        my prepare commonality  -num               -type ::simlib::rfraction

        my returnOnError

        my checkon name {
            set oldID [bsys system id $parms(name)]
            if {$oldID ne "" && $oldID ne $parms(sid)} {
                my reject name \
                    "name is in use by another system: \"$parms(name)\""
            }
        }
    }

    method _execute {{flunky ""}} {
        my setundo [bsys mutate update system $parms(sid) [array get parms]]
        return
    }
}

# BSYS:SYSTEM:DELETE
#
# Deletes a belief system.

::athena::orders define BSYS:SYSTEM:DELETE {
    meta title "Delete Belief System"
    meta sendstates PREP

    meta parmlist {sid}

    meta form { 
        # TBD: Form isn't used.
        rcc "System ID:" -for sid
        text sid -context yes
    }


    method _validate {} {
        my prepare sid -required -type {bsys editable}

        my returnOnError

        set inUse [bsys system inuse $parms(sid)]


        if {$inUse && [my mode] eq "gui" } {
            set message [normalize "
                The selected belief system is in use by 
                at least one actor or group; see the belief system's
                detail browser page for a complete list.  The
                system cannot be deleted while it is in use.
            "]

            messagebox popup \
                -title   "System is in use"  \
                -icon    error               \
                -buttons {cancel "Cancel"}   \
                -default cancel              \
                -parent  [app topwin]        \
                -message $message

            my cancel
        }

        my checkon sid {
            if {$inUse} {
                my reject sid \
                    "System is in use by an actor or group: \"$parms(sid)\""
            }
        }
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
                                Are you sure you really want to delete this 
                                belief system and all of the beliefs it
                                contains?
                            }]]

            if {$answer eq "cancel"} {
                my cancel
            }
        }

        # NEXT, Delete the system.
        my setundo [bsys mutate delete system $parms(sid)]
        return
    }
}

# BSYS:TOPIC:ADD
#
# Adds a new topic with default settings.  Returns new
# topic's ID.

::athena::orders define BSYS:TOPIC:ADD {
    meta title "Add New Belief Topic"

    meta sendstates PREP

    meta parmlist {tid}

    meta form {
        # NOTE: dialog is not used
        rcc "TID:" -for tid
        text tid
    }


    method _validate {} {
        my prepare tid -num -type ::marsutil::count
        my returnOnError

        my checkon tid {
            if {$parms(tid) in [bsys topic ids]} {
                my reject tid \
                    "Topic ID is already in use: \"$parms(tid)\""
            }
        }
    }

    method _execute {{flunky ""}} {
        lassign [::bsys mutate add topic $parms(tid)] tid undoScript

        my setundo $undoScript

        # NOTE: The ID is optional in the order, so we need to return
        # the ID actually used.
        return $tid
    }
}

# BSYS:TOPIC:UPDATE
#
# Updates topic metadata

::athena::orders define BSYS:TOPIC:UPDATE {
    meta title "Update Topic Metadata"

    meta sendstates PREP

    meta parmlist {tid name affinity}

    meta form {
        rcc "Topic ID:" -for tid
        text tid -context yes \
            -loadcmd {bsys::viewload topic}

        rcc "Name:" -for name
        text name -width 30

        rcc "Affects Affinity?" -for affinity
        yesno affinity 
    }


    method _validate {} {
        my prepare tid          -toupper -required -type {bsys topic}
        my prepare name
        my prepare affinity     -toupper           -type boolean

        my returnOnError

        my checkon name {
            set oldID [bsys topic id $parms(name)]
            if {$oldID ne "" && $oldID ne $parms(tid)} {
                my reject name \
                    "name is in use by another topic: \"$parms(name)\""
            }
        }
    }

    method _execute {{flunky ""}} {
        my setundo [bsys mutate update topic $parms(tid) [array get parms]]
        return
    }
}

# BSYS:TOPIC:DELETE
#
# Deletes a belief topic.

::athena::orders define BSYS:TOPIC:DELETE {
    meta title "Delete Belief Topic"
    meta sendstates PREP

    meta parmlist {tid}

    meta form { 
        # TBD: Form isn't used.
        rcc "Topic ID:" -for tid
        text tid -context yes
    }


    method _validate {} {
        my prepare tid -required -type {bsys topic}

        my returnOnError

        set inUse [bsys topic inuse $parms(tid)]

        if {$inUse && [my mode] eq "gui" } {
            set message [normalize "
                The selected topic is in use by 
                at least one semantic hook; see the topic's
                detail browser page for a complete list.  The
                topic cannot be deleted while it is in use.
            "]

            messagebox popup \
                -title   "Topic is in use"  \
                -icon    error               \
                -buttons {cancel "Cancel"}   \
                -default cancel              \
                -parent  [app topwin]        \
                -message $message

            my cancel
        }

        my checkon tid {
            if {$inUse} {
                my reject tid \
                    "Topic is in use by a semantic hook: \"$parms(tid)\""
            }
        }
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
                                Are you sure you really want to delete this 
                                belief topic and all of the beliefs that
                                depend on it?
                            }]]

            if {$answer eq "cancel"} {
                my cancel
            }
        }

        # NEXT, Delete the topic.
        my setundo [bsys mutate delete topic $parms(tid)]
        return
    }
}


# BSYS:BELIEF:UPDATE
#
# Updates an existing belief.

::athena::orders define BSYS:BELIEF:UPDATE {
    meta title "Update Belief"
    meta sendstates PREP

    meta parmlist {bid system topic position emphasis}

    meta form {
        text bid \
            -invisible yes    \
            -loadcmd  {bsys::viewload belief}

        rcc "Belief System:" -for system
        disp system -width 30 -textcmd {::bsys::system4bid $bid}

        rcc "Belief Topic:" -for topic
        disp topic -width 30 -textcmd {::bsys::topic4bid $bid}

        rcc "Position:" -for position
        enumlong position -dictcmd {::simlib::qposition namedict}

        rcc "Emphasis is On:" -for emphasis
        enumlong emphasis -dictcmd {::simlib::qemphasis namedict}

    }


    method _validate {} {
        my prepare bid       -toupper -required -type {bsys belief}
        my prepare position  -num -type qposition
        my prepare emphasis  -num -type qemphasis
    }

    method _execute {{flunky ""}} {
        my setundo [bsys mutate update belief $parms(bid) [array get parms]]
        return
    }
}




