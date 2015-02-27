#-----------------------------------------------------------------------
# TITLE:
#    bsys.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Belief Systems
#
#    This module wraps the mam(n) object that contains and 
#    computes Athena's belief systems, and also defines the relevant
#    orders.
#
# TBD: Global refs: app/messagebox
#
#-----------------------------------------------------------------------

snit::type ::athena::bsys {
    #-------------------------------------------------------------------
    # Components

    component adb       ;# The athenadb(n) instance
    component mam       ;# The mam module

    #-------------------------------------------------------------------
    # Variables

    # info - Checkpointed data
    #
    #  system-counter  - ID counter for system entities.
    #  topic-counter   - ID counter for topic entities.

    variable info -array { }

    # defaultInfo - Default info() content.

    variable defaultInfo {
        system-counter 0
        topic-counter  0
    }

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        # FIRST, save the athenadb instance.
        set adb $adb_

        # NEXT, initialize the mam typecomponent variable so that
        # delegation will work:
        install mam using ::simlib::mam ${selfns}::mam

        # NEXT, clear the relevant data.
        $self clear
    }

    #-------------------------------------------------------------------
    # Public Methods

    # clear
    #
    # Clears the belief system data, and reinitializes it with the
    # default "Neutral" belief system.

    method clear {} {
        $mam clear

        array set info $defaultInfo

        set info(system-counter) 1
        $mam system add $info(system-counter)
        $self system configure $info(system-counter) -name "Neutral"
    }

    # start
    #
    # Ensures that affinities have been computed on scenario lock.

    method start {} {
        $self compute
    }

    # compute
    #
    # Forces a recalc.

    method compute {} {
        $mam compute
    }

    #-------------------------------------------------------------------
    # saveable(i) interface

    # checkpoint ?-saved?
    #
    # Returns a checkpoint of the non-RDB simulation data.  If 
    # -saved is specified, the data is marked unchanged.

    method checkpoint {{option ""}} {
        dict set checkpoint info [array get info]
        dict set checkpoint mam  [$mam checkpoint $option]

        return $checkpoint
    }

    # restore checkpoint ?-saved?
    #
    # checkpoint - A string returned by the checkpoint method
    #
    # Restores the non-RDB state of the module to that contained
    # in the checkpoint.  If -saved is specified, the data is marked
    # unchanged.
    
    method restore {checkpoint {option ""}} {
        # FIRST, restore the checkpoint data
        $self clear

        if {[dict exists $checkpoint info]} {
            array set info [dict get $checkpoint info]
        }

        if {[dict exists $checkpoint mam]} {
            $mam restore [dict get $checkpoint mam]
        }
        return
    }


    #-------------------------------------------------------------------
    # Public methods


    delegate method {playbox *} to mam using {%c playbox %m}
    delegate method {system *}  to mam using {%c system %m}
    delegate method {topic *}   to mam using {%c topic %m}
    delegate method {belief *}  to mam using {%c belief %m}
    delegate method *           to mam

    # system validate sid
    #
    # sid - A system ID
    #
    # Validates the system ID.

    method {system validate} {sid} {
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

    method {system inuse} {sid} {
        return [$adb exists {
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

    method {editable validate} {sid} {
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

    method {topic validate} {tid} {
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

    method {topic inuse} {tid} {
        return [$adb exists {
            SELECT topic_id FROM hook_topics WHERE topic_id=$tid
        }]
    }


    # belief validate bid
    #
    # bid - An {sid tid} pair
    #
    # Validates the belief ID.

    method {belief validate} {bid} {
        lassign $bid sid tid

        $self editable validate $sid
        $self topic validate $tid

        return $bid
    }

    # belief isdefault bid
    # 
    # bid - An {sid tid} pair.
    #
    # Returns 1 if the belief has its default value, and 0 otherwise.

    method {belief isdefault} {bid} {
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

    method bsysname {bsid} {
        return "[$mam system get $bsid name] ($bsid)"
    }

    # topicname tid
    #
    # tid  - A belief topic ID
    #
    # Returns the topic's name.

    method topicname {tid} {
        return [$mam topic get $tid name]
    }

    #-------------------------------------------------------------------
    # Mutators

    # add etype id
    #
    # etype  - system | topic
    # id     - The entity ID, or "" to assign a new one.
    #
    # Adds an entity of the given type, and returns a list
    # of two items: the assigned ID, and the undo script.

    method add {etype id} {
        set oldCounter $info($etype-counter)

        if {$id eq ""} {
            set id [incr info($etype-counter)]
        } else {
            let info($etype-counter) { max($id, $oldCounter) }
        }

        $mam $etype add $id

        $adb notify bsys <$etype> add $id

        return [list $id [mymethod UndoAdd $etype $oldCounter $id]]
    }

    # UndoAdd etype oldCounter id 
    #
    # etype      - system | topic
    # oldCounter - Old value of the entity counter
    # id         - ID of the entity
    #
    # Undoes the add of the entity.

    method UndoAdd {etype oldCounter id} {
        $mam $etype delete $id
        set info($etype-counter) $oldCounter

        $adb notify bsys <$etype> delete $id
    }

    # update etype id pdict
    #
    # etype    - playbox | system | topic | belief
    # id       - The etype ID
    # pdict    - The parameter dictionary
    #
    # Modifies a mam entity's metadata given its type, ID, and the 
    # new parameters.  For playbox, the id is "" and for
    # belief the id is "$sid $tid".

    method update {etype id pdict} {
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

        $adb notify bsys <$etype> update $id

        return [mymethod UndoUpdate $etype $id $undoData]
    }

    # UndoUpdate etype id undoData 
    #
    # etype    - playbox | system | topic | belief
    # id       - ID of the entity
    # undoData - parameters to restore
    #
    # Undoes the update of the entity.

    method UndoUpdate {etype id undoData} {
        $mam $etype set {*}$id $undoData

        $adb notify bsys <$etype> update $id
    }
    
    # delete etype id
    #
    # etype  - system | topic
    # id     - The etype's ID
    #
    # Deletes the entity, and returns the undo script.

    method delete {etype id} {
        set undoData [$mam $etype delete $id]

        $adb notify bsys <$etype> delete $id

        return [mymethod UndoDelete $etype $id $undoData]
    }

    # UndoDelete etype id undoData 
    #
    # etype    - system | topic
    # id       - ID of the entity
    # undoData - Undo returned by [$mam $entity delete]
    #
    # Undoes the deletion of the entity.

    method UndoDelete {etype id undoData} {
        $mam $etype undelete $undoData

        $adb notify bsys <$etype> add $id
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

    method viewload {etype idict id} {
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

    method system4bid {bid} {
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

    method topic4bid {bid} {
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
    meta title      "Update Playbox-wide Belief System Parameters"
    meta sendstates PREP
    meta parmlist   {gamma}

    method _validate {} {
        my prepare gamma -required -num -type ::simlib::rmagnitude
    }

    method _execute {{flunky ""}} {
        my setundo [$adb bsys update playbox "" [array get parms]]
        return
    }    
}


# BSYS:SYSTEM:ADD
#
# Adds a new belief system with default settings.  Returns new
# system ID.

::athena::orders define BSYS:SYSTEM:ADD {
    meta title      "Add New Belief System"
    meta sendstates PREP
    meta parmlist   {sid}

    method _validate {} {
        my prepare sid -num -type ::marsutil::count
        my returnOnError

        my checkon sid {
            if {$parms(sid) in [$adb bsys system ids]} {
                my reject sid \
                    "Belief system ID is already in use: \"$parms(sid)\""
            }
        }
    }

    method _execute {{flunky ""}} {
        lassign [$adb bsys add system $parms(sid)] sid undoScript

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
    meta title      "Update Belief System Metadata"
    meta sendstates PREP
    meta parmlist   {sid name commonality}

    meta form {
        rcc "System ID:" -for sid
        text sid -context yes \
            -loadcmd {$adb_ bsys viewload system}

        rcc "Name:" -for name
        text name

        rcc "Commonality Fraction:" -for commonality
        range commonality          \
            -datatype    rfraction \
            -showsymbols no        \
            -resetvalue  1.0 
    }


    method _validate {} {
        my prepare sid -toupper -required -type [list $adb bsys editable]
        my prepare name
        my prepare commonality  -num      -type ::simlib::rfraction

        my returnOnError

        my checkon name {
            set oldID [$adb bsys system id $parms(name)]
            if {$oldID ne "" && $oldID ne $parms(sid)} {
                my reject name \
                    "name is in use by another system: \"$parms(name)\""
            }
        }
    }

    method _execute {{flunky ""}} {
        my setundo [$adb bsys update system $parms(sid) [array get parms]]
        return
    }
}

# BSYS:SYSTEM:DELETE
#
# Deletes a belief system.

::athena::orders define BSYS:SYSTEM:DELETE {
    meta title      "Delete Belief System"
    meta sendstates PREP
    meta parmlist   {sid}

    method _validate {} {
        my prepare sid -required -type [list $adb bsys editable]

        my returnOnError

        set inUse [$adb bsys system inuse $parms(sid)]


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
        my setundo [$adb bsys delete system $parms(sid)]
        return
    }
}

# BSYS:TOPIC:ADD
#
# Adds a new topic with default settings.  Returns new
# topic's ID.

::athena::orders define BSYS:TOPIC:ADD {
    meta title      "Add New Belief Topic"
    meta sendstates PREP
    meta parmlist   {tid}

    method _validate {} {
        my prepare tid -num -type ::marsutil::count
        my returnOnError

        my checkon tid {
            if {$parms(tid) in [$adb bsys topic ids]} {
                my reject tid \
                    "Topic ID is already in use: \"$parms(tid)\""
            }
        }
    }

    method _execute {{flunky ""}} {
        lassign [$adb bsys add topic $parms(tid)] tid undoScript

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
    meta title      "Update Topic Metadata"
    meta sendstates PREP
    meta parmlist   {tid name affinity}

    meta form {
        rcc "Topic ID:" -for tid
        text tid -context yes \
            -loadcmd {$adb_ bsys viewload topic}

        rcc "Name:" -for name
        text name -width 30

        rcc "Affects Affinity?" -for affinity
        yesno affinity 
    }


    method _validate {} {
        my prepare tid -toupper -required -type [list $adb bsys topic]
        my prepare name
        my prepare affinity -toupper -type boolean

        my returnOnError

        my checkon name {
            set oldID [$adb bsys topic id $parms(name)]
            if {$oldID ne "" && $oldID ne $parms(tid)} {
                my reject name \
                    "name is in use by another topic: \"$parms(name)\""
            }
        }
    }

    method _execute {{flunky ""}} {
        my setundo [$adb bsys update topic $parms(tid) [array get parms]]
        return
    }
}

# BSYS:TOPIC:DELETE
#
# Deletes a belief topic.

::athena::orders define BSYS:TOPIC:DELETE {
    meta title      "Delete Belief Topic"
    meta sendstates PREP
    meta parmlist   {tid}

    method _validate {} {
        my prepare tid -required -type [list $adb bsys topic]

        my returnOnError

        set inUse [$adb bsys topic inuse $parms(tid)]

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
        my setundo [$adb bsys delete topic $parms(tid)]
        return
    }
}


# BSYS:BELIEF:UPDATE
#
# Updates an existing belief.

::athena::orders define BSYS:BELIEF:UPDATE {
    meta title      "Update Belief"
    meta sendstates PREP
    meta parmlist   {bid system topic position emphasis}

    meta form {
        text bid \
            -invisible yes    \
            -loadcmd  {$adb_ bsys viewload belief}

        rcc "Belief System:" -for system
        disp system -width 30 -textcmd {$adb_ bsys system4bid $bid}

        rcc "Belief Topic:" -for topic
        disp topic -width 30 -textcmd {$adb_ bsys topic4bid $bid}

        rcc "Position:" -for position
        enumlong position -dictcmd {::simlib::qposition namedict}

        rcc "Emphasis is On:" -for emphasis
        enumlong emphasis -dictcmd {::simlib::qemphasis namedict}
    }

    method _validate {} {
        my prepare bid  -toupper -required -type [list $adb bsys belief]
        my prepare position  -num -type qposition
        my prepare emphasis  -num -type qemphasis
    }

    method _execute {{flunky ""}} {
        my setundo [$adb bsys update belief $parms(bid) [array get parms]]
        return
    }
}




