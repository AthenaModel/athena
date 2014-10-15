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
        scenario register $type

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


order define BSYS:PLAYBOX:UPDATE {
    title "Update Playbox-wide Belief System Parameters"

    options -sendstates PREP

    form {
        # NOTE: dialog is not used
        rcc "Gamma:" -for gamma
        text gamma
    }
} {
    # FIRST, prepare and validate the parameters
    prepare gamma -required -num -type ::simlib::rmagnitude

    returnOnError -final

    # NEXT, save the parameter value.
    setundo [bsys mutate update playbox "" [array get parms]]

    return
}


# BSYS:SYSTEM:ADD
#
# Adds a new belief system with default settings.  Returns new
# system ID.

order define BSYS:SYSTEM:ADD {
    title "Add New Belief System"

    options -sendstates PREP

    form {
        # Note: the form is not used.
        rcc "SID:" -for sid
        text sid
    }
} {
    prepare sid -num -type ::marsutil::count
    returnOnError

    validate sid {
        if {$parms(sid) in [bsys system ids]} {
            reject sid \
                "Belief system ID is already in use: \"$parms(sid)\""
        }
    }

    returnOnError -final

    # NEXT, save the parameter value.
    lassign [::bsys mutate add system $parms(sid)] sid undoScript

    setundo $undoScript

    # NOTE: The sid is optional in the order, so we need to return
    # the ID actually used.
    return $sid
}


# BSYS:SYSTEM:UPDATE
#
# Updates system parameters

order define BSYS:SYSTEM:UPDATE {
    title "Update Belief System Metadata"

    options -sendstates PREP

    form {
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
} {
    # FIRST, prepare and validate the parameters
    prepare sid          -toupper -required -type {bsys editable}
    prepare name
    prepare commonality  -num               -type ::simlib::rfraction

    returnOnError

    validate name {
        set oldID [bsys system id $parms(name)]
        if {$oldID ne "" && $oldID ne $parms(sid)} {
            reject name \
                "name is in use by another system: \"$parms(name)\""
        }
    }

    returnOnError -final

    # NEXT, save the parameter value.
    setundo [bsys mutate update system $parms(sid) [array get parms]]

    return
}

# BSYS:SYSTEM:DELETE
#
# Deletes a belief system.

order define BSYS:SYSTEM:DELETE {
    title "Delete Belief System"
    options \
        -sendstates PREP

    form { 
        # TBD: Form isn't used.
        rcc "System ID:" -for sid
        text sid -context yes
    }
} {
    # FIRST, prepare the parameters
    prepare sid -required -type {bsys editable}

    returnOnError

    set inUse [bsys system inuse $parms(sid)]


    if {$inUse && [sender] eq "gui" } {
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

        cancel
    }

    validate sid {
        if {$inUse} {
            reject sid \
                "System is in use by an actor or group: \"$parms(sid)\""
        }
    }

    returnOnError -final

    # NEXT, make sure the user knows what he is getting into.

    if {[sender] eq "gui"} {
        set answer [messagebox popup \
                        -title         "Are you sure?"                  \
                        -icon          warning                          \
                        -buttons       {ok "Delete it" cancel "Cancel"} \
                        -default       cancel                           \
                        -onclose       cancel                           \
                        -ignoretag     BSYS:SYSTEM:DELETE               \
                        -ignoredefault ok                               \
                        -parent        [app topwin]                     \
                        -message       [normalize {
                            Are you sure you really want to delete this 
                            belief system and all of the beliefs it
                            contains?
                        }]]

        if {$answer eq "cancel"} {
            cancel
        }
    }

    # NEXT, Delete the system.
    setundo [bsys mutate delete system $parms(sid)]

    return
}

# BSYS:TOPIC:ADD
#
# Adds a new topic with default settings.  Returns new
# topic's ID.

order define BSYS:TOPIC:ADD {
    title "Add New Belief Topic"

    options -sendstates PREP

    form {
        # NOTE: dialog is not used
        rcc "TID:" -for tid
        text tid
    }
} {
    prepare tid -num -type ::marsutil::count
    returnOnError

    validate tid {
        if {$parms(tid) in [bsys topic ids]} {
            reject tid \
                "Topic ID is already in use: \"$parms(tid)\""
        }
    }

    returnOnError -final

    # NEXT, save the parameter value.
    lassign [::bsys mutate add topic $parms(tid)] tid undoScript

    setundo $undoScript

    # NOTE: The ID is optional in the order, so we need to return
    # the ID actually used.
    return $tid
}

# BSYS:TOPIC:UPDATE
#
# Updates topic metadata

order define BSYS:TOPIC:UPDATE {
    title "Update Topic Metadata"

    options -sendstates PREP

    form {
        rcc "Topic ID:" -for tid
        text tid -context yes \
            -loadcmd {bsys::viewload topic}

        rcc "Name:" -for name
        text name -width 30

        rcc "Affects Affinity?" -for affinity
        yesno affinity 
    }
} {
    # FIRST, prepare and validate the parameters
    prepare tid          -toupper -required -type {bsys topic}
    prepare name
    prepare affinity     -toupper           -type boolean

    returnOnError

    validate name {
        set oldID [bsys topic id $parms(name)]
        if {$oldID ne "" && $oldID ne $parms(tid)} {
            reject name \
                "name is in use by another topic: \"$parms(name)\""
        }
    }

    returnOnError -final

    # NEXT, save the parameter value.
    setundo [bsys mutate update topic $parms(tid) [array get parms]]

    return
}

# BSYS:TOPIC:DELETE
#
# Deletes a belief topic.

order define BSYS:TOPIC:DELETE {
    title "Delete Belief Topic"
    options \
        -sendstates PREP

    form { 
        # TBD: Form isn't used.
        rcc "Topic ID:" -for tid
        text tid -context yes
    }
} {
    # FIRST, prepare the parameters
    prepare tid -required -type {bsys topic}

    returnOnError

    set inUse [bsys topic inuse $parms(tid)]

    if {$inUse && [sender] eq "gui" } {
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

        cancel
    }

    validate tid {
        if {$inUse} {
            reject tid \
                "Topic is in use by a semantic hook: \"$parms(tid)\""
        }
    }


    returnOnError -final

    # NEXT, make sure the user knows what he is getting into.

    if {[sender] eq "gui"} {
        set answer [messagebox popup \
                        -title         "Are you sure?"                  \
                        -icon          warning                          \
                        -buttons       {ok "Delete it" cancel "Cancel"} \
                        -default       cancel                           \
                        -onclose       cancel                           \
                        -ignoretag     BSYS:TOPIC:DELETE               \
                        -ignoredefault ok                               \
                        -parent        [app topwin]                     \
                        -message       [normalize {
                            Are you sure you really want to delete this 
                            belief topic and all of the beliefs that
                            depend on it?
                        }]]

        if {$answer eq "cancel"} {
            cancel
        }
    }

    # NEXT, Delete the topic.
    setundo [bsys mutate delete topic $parms(tid)]

    return
}


# BSYS:BELIEF:UPDATE
#
# Updates an existing belief.

order define BSYS:BELIEF:UPDATE {
    title "Update Belief"
    options -sendstates PREP

    form {
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
} {
    # FIRST, prepare the parameters
    prepare bid       -toupper -required -type {bsys belief}
    prepare position  -num -type qposition
    prepare emphasis  -num -type qemphasis

    returnOnError -final

    # NEXT, modify the belief.
    setundo [bsys mutate update belief $parms(bid) [array get parms]]

    return
}




