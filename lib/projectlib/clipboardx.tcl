#-----------------------------------------------------------------------
# TITLE:
#    clipboardx.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Athena internal clipboard
#
#    This singleton object manages the clipboard for internal
#    Athena objects.  It is meant to be used alongside the standard
#    clipboard command, which manages text.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export clipboardx
}

#-----------------------------------------------------------------------
# clipboardx

snit::type ::projectlib::clipboardx {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type variables

    # buffers: An array of clipboard data, by tag.
    typevariable buffers -array {}


    #-------------------------------------------------------------------
    # Public Methods

    # clear
    #
    # Clears the clipboard.

    typemethod clear {} {
        array unset buffers
    }

    # set tag value
    #
    # tag   - The data type tag
    # value - The copied data
    #
    # Saves the copied data on the clipboard, and marks it as having the
    # specified type tag.

    typemethod set {tag value} {
        set buffers($tag) $value
    }

    # has tag ?tag...?
    #
    # tag   - A data type tag
    #
    # Of the specified tags, returns the first for which data exists, or
    # "" if there is no data for any of them.  A client can use this to
    # determine which data set to use.

    typemethod has {args} {
        foreach tag $args {
            if {[info exists buffers($tag)]} {
                return $tag
            }
        }

        return ""
    }

    # get tag
    #
    # tag   - A data type tag
    #
    # Returns the data associated with the tag, or "" if none.

    typemethod get {tag} {
        if {[info exists buffers($tag)]} {
            return $buffers($tag)
        }

        return ""
    }



    # tags
    #
    # Returns the tags for which data exists.

    typemethod tags {} {
        return [lsort [array names buffers]]
    }

}









