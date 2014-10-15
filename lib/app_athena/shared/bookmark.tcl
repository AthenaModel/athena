#-----------------------------------------------------------------------
# TITLE:
#    bookmark.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Bookmark Manager
#
#    This module is responsible for managing bookmarks and operations
#    upon them.  As such, it is a type ensemble.
#
#-----------------------------------------------------------------------

snit::type bookmark {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.

    # names
    #
    # Returns the list of bookmark URLs

    typemethod names {} {
        set names [rdb eval {
            SELECT bookmark_id FROM bookmarks ORDER BY rank ASC
        }]
    }


    # validate bookmark_id
    #
    # bookmark_id - Possibly, a bookmark id.
    #
    # Validates a bookmark id.

    typemethod validate {bookmark_id} {
        if {![rdb exists {
            SELECT bookmark_id FROM bookmarks WHERE bookmark_id=$bookmark_id
        }]} {
            return -code error -errorcode INVALID \
                "Invalid bookmark ID, \"$bookmark_id\""
        }

        return $bookmark_id
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
    # parmdict   - A dictionary of bookmark parms
    #
    #    url          - The bookmark's URL
    #    title        - The bookmark's title
    #
    # Creates a bookmark given the parms, which are presumed to be
    # valid.

    typemethod {mutate create} {parmdict} {
        dict with parmdict {
            # FIRST, Put the bookmark in the database.  It always starts
            # at the bottom rank.
            rdb eval {
                SELECT COALESCE(MAX(rank)+1, 1) AS rank FROM bookmarks
            } {}

            rdb eval {
                INSERT INTO bookmarks(url,title,rank)
                VALUES($url, $title, $rank)
            }

            set bookmark_id [rdb last_insert_rowid]

            # NEXT, Set the undo command
            return [mytypemethod mutate delete $bookmark_id]
        }
    }

    # mutate delete bookmark_id
    #
    # bookmark_id - A bookmark id
    #
    # Deletes the bookmark.  Note that deletion doesn't change the 
    # ranking.

    typemethod {mutate delete} {bookmark_id} {
        # FIRST, get this bookmark's undo information and
        # delete the relevant records.
        set data [rdb delete -grab bookmarks {bookmark_id=$bookmark_id}]

        # NEXT, return the undo script 
        return [list rdb ungrab $data]
    }


    # mutate update parmdict
    #
    # parmdict  - A dictionary of bookmark parms
    #
    #    bookmark_id - A bookmark ID
    #    url         - A new URL, or ""
    #    title       - A new title, or ""
    #
    # Updates a bookmark given the parms, which are presumed to be
    # valid.

    typemethod {mutate update} {parmdict} {
        dict with parmdict {
            # FIRST, get the undo information
            set data [rdb grab bookmarks {bookmark_id=$bookmark_id}]

            # NEXT, Put the bookmark in the database
            rdb eval {
                UPDATE bookmarks
                SET url   = nonempty($url,   url),
                    title = nonempty($title, title)
                WHERE bookmark_id=$bookmark_id
            }

            # NEXT, Set the undo command
            return [list rdb ungrab $data]
        }
    }
   
    # mutate rank bookmark_id rank
    #
    # bookmark_id - The bookmark ID whose rank is changing.
    # rank        - An ePrioUpdate value
    #
    # Re-orders the bookmarks, so that this bookmark has the desired
    # position.

    typemethod {mutate rank} {bookmark_id rank} {
        # NEXT, get the existing ranking
        set oldRanking [rdb eval {
            SELECT bookmark_id,rank FROM bookmarks
            ORDER BY rank ASC
        }]

        # NEXT, Reposition id in the ranking.
        set ranking [lprio [dict keys $oldRanking] $bookmark_id $rank]

        # NEXT, assign new rank numbers
        set count 1

        foreach id $ranking {
            rdb eval {
                UPDATE bookmarks
                SET   rank=$count
                WHERE bookmark_id=$id
            }
            incr count
        }
        
        # NEXT, return the undo script
        return [mytypemethod RestoreRank $oldRanking]
    }

    # RestoreRank ranking
    #
    # ranking  The ranking to restore
    # 
    # Restores an old ranking

   typemethod RestoreRank {ranking} {
       # FIRST, restore the data
        foreach {id rank} $ranking {
            rdb eval {
                UPDATE bookmarks
                SET rank=$rank
                WHERE bookmark_id=$id
            }
        }
    }
    
}

#-------------------------------------------------------------------
# Orders: BOOKMARK:*

# BOOKMARK:CREATE
#
# Creates new bookmarks.

order define BOOKMARK:CREATE {
    title "Create Bookmark"
    options -sendstates {PREP PAUSED}

    form {
        rcc "URL:" -for url
        text url -width 40

        rcc "Title:" -for title
        text title -width 40
    }
} {
    # FIRST, prepare the parameters
    prepare url    -required
    prepare title  -required -normalize

    returnOnError -final

    # NEXT, create the bookmark and dependent entities
    setundo [bookmark mutate create [array get parms]]
}

# BOOKMARK:DELETE

order define BOOKMARK:DELETE {
    title "Delete Bookmark"
    options -sendstates {PREP PAUSED}

    form {
        rcc "Bookmark:" -for bookmark_id
        enum bookmark_id -listcmd {bookmark names}
    }
} {
    # FIRST, prepare the parameters
    prepare bookmark_id  -required -type bookmark

    returnOnError -final

    # NEXT, delete the bookmark and dependent entities
    setundo [bookmark mutate delete $parms(bookmark_id)]
}

# BOOKMARK:UPDATE
#
# Updates existing bookmarks.

order define BOOKMARK:UPDATE {
    title "Update Bookmark"
    options -sendstates {PREP PAUSED}

    form {
        rcc "Select Bookmark:" -for bookmark_id
        key bookmark_id -table bookmarks -keys bookmark_id \
            -loadcmd {orderdialog keyload bookmark_id *}

        rcc "URL:" -for url
        text url -width 40

        rcc "Title:" -for title
        text title -width 40
    }
} {
    # FIRST, prepare the parameters
    prepare bookmark_id   -required   -type bookmark
    prepare url
    prepare title         -normalize

    returnOnError -final

    # NEXT, modify the bookmark
    setundo [bookmark mutate update [array get parms]]
}

# BOOKMARK:RANK
#
# Re-prioritizes a bookmark item.

order define BOOKMARK:RANK {
    # This order dialog isn't usually used.
    title "Change Bookmark Rank"

    options -sendstates {PREP PAUSED}

    form {
        rcc "Bookmark:" -for bookmark_id
        enum bookmark_id -listcmd {bookmark names}

        rcc "Rank Change:" -for rank
        enumlong rank -dictcmd {ePrioUpdate deflist}
    }
} {
    # FIRST, prepare and validate the parameters
    prepare bookmark_id -required          -type bookmark
    prepare rank        -required -tolower -type ePrioUpdate

    returnOnError -final

    setundo [bookmark mutate rank $parms(bookmark_id) $parms(rank)]
}

