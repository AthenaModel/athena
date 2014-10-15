#-----------------------------------------------------------------------
# TITLE:
#    sigevent.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Significant Event Manager
#
#    This module allows other modules to log significant simulation
#    events, so that they can later be displayed to the user.
#
#-----------------------------------------------------------------------

snit::type sigevent {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Public Methods

    # purge t
    #
    # t - The time in ticks from which to purge.
    #
    # Removes "future history" from the sigevents tables when going
    # backwards in time.

    typemethod purge {t} {
        rdb eval {
            DELETE FROM sigevents WHERE t >= $t;
        }
    }

    # log level component narrative ?tags...?
    #
    # level        - error, warning, or 1-N
    # component    - The component (e.g., model) logging the event
    # narrative    - The narrative text
    # tags         - Zero or more tags, usually entity IDs
    #
    # Adds the log entry to the sigevents table, and any tags to
    # the sigevent_tags table.  Also, write the message to the 
    # debugging log.
    #
    # The narrative can include entity links like this:
    #
    #    {a:$a}, {n:$n}, {g:$g}.  
    #
    # These can be translated into HTML links on output.

    typemethod log {level component narrative args} {
        # FIRST, translate the level
        if {$level eq "error"} {
            set level -1
        } elseif {$level eq "warning"} {
            set level 0
        }

        # NEXT, save it.
        set narrative [normalize $narrative]

        rdb eval {
            INSERT INTO sigevents(t,level,component,narrative)
            VALUES(now(), $level, $component, $narrative);
        }

        set id [rdb last_insert_rowid]

        foreach tag $args {
            # Use "OR IGNORE" in case the same tag is given twice.
            rdb eval {
                INSERT OR IGNORE INTO sigevent_tags(event_id, tag)
                VALUES($id,$tag)
            }
        }
    }
}