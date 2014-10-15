#-----------------------------------------------------------------------
# TITLE:
#	week.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#   Athena: projectlib 
#
# Julian Week Translation
#
# A julian week string is a representation of a particular week of a
# particular year in this format:
#
#     yyyyWww
#
# where
#
#     yyyy  - 4-digit year
#     ww    - 2-digit week, 01-52.
#
# It is assumed that each year begins on January 1st and consists
# of exactly 52 weeks, each week corresponding to one Athena simulation 
# tick.
#
# This module contains routines to convert between julian week strings
# absolute week numbers since the epoch, where the epoch is 2000W01.
#
# This is a rather arbitrary scheme; but when simulating by weeks, we
# don't actually need anything more precise.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Exported commands

namespace eval ::projectlib:: {
    namespace export week
}


#-----------------------------------------------------------------------
# week Ensemble

snit::type ::projectlib::week {
    # Make it an ensemble
    pragma -hasinstances 0

    #-------------------------------------------------------------------
    # Ensemble subcommands

    # toString week
    #
    # week   - Number of weeks since the epoch
    #
    # Converts an integer number of weeks to a week string.
    
    typemethod toString {week} {
        set year [expr {2000 + (entier($week) / 52)}]
        set week [expr {1 + (entier($week) % 52)}]

        return [format "%04dW%02d" $year $week]
    }

    # toWeek ts
    #
    # ts   - A unix timestamp in seconds since 1/1/1970
    #
    # Converts a unix timestamp to a week number using Athena's
    # epoch of 1/1/2000

    typemethod toWeek {ts} {
        # FIRST, timestamp must be a positive number
        assert {$ts > -1}

        # NEXT, use unix timestamp for 1/1/2000 00:00:00 (GMT) to convert
        # to weeks
        set epochSecs [expr {entier($ts) - 946684800}]
        set week      [expr {($epochSecs/86400) / 7}]

        return $week
    }

    # toTimestamp wstring
    #
    # wstring - A julian week string
    #
    # Converts a julian week string to a unix timestamp at GMT. Athena's
    # epoch of 1/1/2000 is assumed

    typemethod toTimestamp {wstring} {
        set weeks [$type toInteger $wstring]

        set epochSecs [expr {entier($weeks*7*86400)}]

        # Add unix time stamp for 1/1/2000 00:00:00 (GMT) to the
        # seconds 
        return [expr {946684800 + $epochSecs}]
    }

    # toInteger wstring
    #
    # wstring  - A julian week string
    #
    # Converts a julian week string back into an integer.

    typemethod toInteger {wstring} {
        set count [scan [string toupper $wstring] "%4dW%2d%n" year week chars]

        if {$count != 3 || 
            $chars != 7 ||
            $year  < 0  ||
            $week  < 1  ||
            $week  > 52
        } {
            throw INVALID "Invalid week string: \"$wstring\""
        }

        return [expr {52*($year - 2000) + $week - 1}]
    }

    # validate wstring
    #
    # wstring   - A week time string
    #
    # Validates a week time string

    typemethod validate {wstring} {
        # FIRST, convert to uppercase
        set upweek [string toupper $wstring]

        # NEXT, do the conversion; this will validate
        $type toInteger $wstring

        # NEXT, return the string in canonical form.
        return $upweek
    }
}











