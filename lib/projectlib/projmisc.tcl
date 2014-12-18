#-----------------------------------------------------------------------
# TITLE:
#    projmisc.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectlib(n): Miscellaneous helper commands.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export \
        lpush        \
        lpop         \
        ltop
}

# lpush stackvar item
#
# stackvar - A variable containing a Tcl list
# item     - A value to push onto the stack.
#
# Pushes the item onto the stack.

proc ::projectlib::lpush {stackvar item} {
    upvar $stackvar stack
    lappend stack $item
    return $item
}


# lpop stackvar
#
# stackvar - A variable containing a Tcl list
#
# Removes the top item from the stack, and returns it.

proc ::projectlib::lpop {stackvar} {
    upvar $stackvar stack

    set item [lindex $stack end]
    set stack [lrange $stack 0 end-1]
    return $item
}

# ltop stack
#
# stack - A Tcl list that represents a stack.
#
# Returns the top item from the stack..

proc ::projectlib::ltop {stack} {
    lindex $stack end
}



