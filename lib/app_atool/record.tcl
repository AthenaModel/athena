#-----------------------------------------------------------------------
# TITLE:
#   record.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   "record" mix-in.  Gives set/get access to all object variables.
#
#-----------------------------------------------------------------------

oo::class create record {
    # getdict
    #
    # Retrieves the object's state as a dictionary
    #
    # Arrays are ignored.

    method getdict {} {
        foreach var [info vars [self namespace]::*] {
            # Skip arrays
            if {[array exists $var]} {
                continue
            }
            dict set dict [namespace tail $var] [set $var]
        }

        return $dict
    }

    # get var
    #
    # var   - An instance variable name
    #
    # Retrieves the value.  It's an error if the variable is an array.

    method get {var} {
        return [set [self namespace]::$var]
    }

    # setdict dict
    #
    # Sets the object's state as a dictionary.  No validation is done,
    # but the variables must already exist.  "pot" and "id" cannot be set.

    method setdict {dict} {
        dict for {key value} $dict {
            my set $key $value
        }
    }

    # set var value
    #
    # var    - An instance variable name
    # value  - A new value
    #
    # Assigns the value to the instance variable; the variable must already
    # exist.  It's an error if the variable is an array.

    method set {var value} {
        if {![info exists [self namespace]::$var]} {
            error "unknown instance variable: \"$var\""
        }

        set [self namespace]::$var $value
    }

    # configure ?option value...?
    #
    # option   - An instance variable name in option form: -$varname
    # value    - The variable value
    #
    # This is equivalent to setdict, but uses option notation.

    method configure {args} {
        foreach {opt value} $args {
            set var [string range $opt 1 end]
            my set $var $value
        }
    }

    # cget opt
    #
    # opt   - An instance variable name in option form: -$varname
    #
    # This is equivalent to get but uses option notation.

    method cget {opt} {
        set var [string range $opt 1 end]
        return [my get $var]
    }

    # lappend listvar value...
    #
    # listvar   - An instance variable name
    # value...  - One or more values
    #
    # Appends the values to the list, and marks the bean changed.

    method lappend {listvar args} {
        set list [my get $listvar]
        lappend list {*}$args
        my set $listvar $list
    }

    # ldelete listvar value
    #
    # listvar   - An instance variable name
    # value     - A list item
    #
    # Deletes the value from the list, and marks the bean changed.

    method ldelete {listvar value} {
        set list [my get $listvar]
        ::marsutil::ldelete list $value
        my set $listvar $list
    }


}