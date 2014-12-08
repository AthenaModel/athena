#-----------------------------------------------------------------------
# TITLE:
#    helpers.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Helper Procs
#
#    Useful procs that don't belong anywhere else.
#
#-----------------------------------------------------------------------

# isa cls obj
#
# cls   - An oo:: class
# obj   - An oo:: object
#
# Returns 1 if the object is an instance of the class or one of its
# subclasses, and 0 otherwise.

proc isa {cls obj} {
    return [info object isa typeof $obj $cls]
}

# beanload idict id ?view?
#
# idict    - A dynaform(n) field's item metadata dictionary
# id       - A bean ID
# view     - Optionally, a bean view name.  Defaults to "".
#
# This command is intended for use as a dynaform(n) -loadcmd, to
# load a bean's data into a dynaview using a specific bean view.
#
# Note: a pastable bean's normal UPDATE method should always use
# the default view, as that is what will be copied.

proc beanload {idict id {view ""}} {
    return [pot view $id $view]
}

# fillparms parmsVar parmdict
#
# parmsVar - An order parms dictionary
# parmdict - An entity attribute dictionary
#
# This command is for use in *:UPDATE order bodies; given the order
# parms and the data for the entity being updated, it fills in the
# empty parameter values in the parmsVar with the existing data.
# this allows for easier cross-validation of parameters.

proc fillparms {parmsVar parmdict} {
    upvar 1 $parmsVar parms
    
    foreach parm [array names parms] {
        if {$parms($parm) eq "" && [dict exists $parmdict $parm]} {
            set parms($parm) [dict get $parmdict $parm]
        }
    }
}

# optdict2parmdict dict
#
# dict   - A dictionary in which the keys have option syntax
#
# Returns the same dictionary with "-" stripped from the keys.

proc optdict2parmdict {dict} {
    set result [dict create]

    dict for {key value} $dict {
        if {[string index $key 0] eq "-"} {
            set key [string range $key 1 end]
        }

        dict set result $key $value
    }

    return $result
}

# parmdict2optdict dict
#
# dict   - A dictionary in which the keys have option syntax
#
# Returns the same dictionary with "-" added to the keys.

proc parmdict2optdict {dict} {
    set result [dict create]

    dict for {key value} $dict {
        if {[string index $key 0] ne "-"} {
            set key "-$key"
        }

        dict set result $key $value
    }

    return $result
}

# lexcept list element
#
# list      - A list
# element   - some element
#
# Returns the list with the element removed (if it was present).

proc lexcept {list element} {
    set idx [lsearch -exact $list $element]
    
    if {$idx >= 0} {
        return [lreplace $list $idx $idx]
    } else {
        return $list
    }
}

# andlist noun list
#
# noun   - The noun for the list
# list   - A list of things
#
# Formats the list nicely, whether it contains one, two, or more
# elements.  If the list is empty, returns "<noun> ???"

proc andlist {noun list} {
    if {[llength $list] == 0} {
        return "$noun ???"
    } elseif {[llength $list] == 1} {
        return "$noun [lindex $list 0]"
    } elseif {[llength $list] == 2} {
        return "${noun}s [lindex $list 0] and [lindex $list 1]"
    } else {
        set last [lindex $list end]
        set list [lrange $list 0 end-1]

        set text "${noun}s "
        append text [join $list ", "]
        append text " and $last"

        return $text
    }
}


# lprio list item prio
#
# list    A list of unique items
# item    An item in the list
# prio    top, raise, lower, or bottom
#
# Moves the item in the list, and returns the new list.

proc lprio {list item prio} {
    # FIRST, get item's position in the list.
    set index [lsearch -exact $list $item]

    # NEXT, get the new position
    let end {[llength $list] - 1}

    switch -exact -- $prio {
        top     { set newpos 0                       }
        raise   { let newpos {max(0,    $index - 1)} }
        lower   { let newpos {min($end, $index + 1)} }
        bottom  { set newpos $end                    }
        default { error "Unknown prio: \"$prio\""    }
    }

    # NEXT, if the item is already in its position, we're done.
    if {$newpos == $index} {
        return $list
    }

    # NEXT, put the item in its list.
    ldelete list $item
    set list [linsert $list $newpos $item]

    # FINALLY, return the new list.
    return $list
}


# mag* multiplier mag
#
# multiplier    A numeric multiplier
# mag           A qmag(n) value
#
# Returns the numeric value of mag times the multiplier.

proc mag* {multiplier mag} {
    set result [expr {$multiplier * [qmag value $mag]}]

    if {$result == -0.0} {
        set result 0.0
    }

    return $result
}

# mag+ stops mag
#
# stops      Some number of "stops"
# mag        A qmag symbol
#
# Returns the symbolic value of mag, moved up or down the specified
# number of stops, or 0.  I.e., XL +1 stop is XXL; XL -1 stop is L.  
# Stopping up or down never changes the sign.  Stopping down from
# from XXXS returns 0; stopping up from XXXXL returns the value
# of XXXXL.

proc mag+ {stops mag} {
    set symbols [qmag names]
    set index [qmag index $mag]

    if {$index <= 9} {
        # Sign is positive; 0 is XXXXL+, 9 is XXXS+

        let index {$index - $stops}

        if {$index < 0} {
            return [lindex $symbols 0]
        } elseif {$index > 9} {
            return 0
        } else {
            return [lindex $symbols $index]
        }
    } else {
        # Sign is negative; 10 is XXXS-, 19 is XXXXL-

        let index {$index + $stops}

        if {$index > 19} {
            return [lindex $symbols 19]
        } elseif {$index < 10} {
            return 0
        } else {
            return [lindex $symbols $index]
        }
    }


    expr {$stops * [qmag value $mag]}
}


# hrel.fg f g
#
# f    A group
# g    Another group
#
# Returns the relationship of f with g.

proc hrel.fg {f g} {
    set hrel [rdb eval {
        SELECT hrel FROM uram_hrel
        WHERE f=$f AND g=$g
    }]

    return $hrel
}

# vrel.ga g a
#
# g - A civ group
# a - An actor
#
# Returns the vertical relationship between the group and the 
# actor.

proc vrel.ga {g a} {
    rdb onecolumn {SELECT vrel FROM uram_vrel WHERE g=$g AND a=$a}
}

# caller
# 
# Returns the caller's command, if possible.

proc caller {} {
    set dict [info frame -3]

    if {[dict exists $dict cmd]} {
        return [dict get $dict cmd]
    } else {
        return "*unknown*"
    }
}
