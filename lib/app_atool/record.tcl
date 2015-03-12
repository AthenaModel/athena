#-----------------------------------------------------------------------
# TITLE:
#   record.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   "record" base-class.  Gives set/get access to all declared scalar 
#   variables, and getdict to defined fields.
#
#-----------------------------------------------------------------------

oo::class create record {
    # _record - array of metadata
    # 
    #  fields   - List of defined fields
    #  readonly - List of defined fields that cannot be set from outside.
    variable _record

    constructor {} {
        set _record(fields)   {}
        set _record(readonly) {}
    }

    # field name ?value?
    #
    # name  - A field variable name
    # value - An initial value, defaults to ""
    #
    # Defines variable $name as a field.  Only defined fields are 
    # returned by getdict or fields.  Note that fields must also 
    # be declared as variables.

    method field {name {value ""}} {
        lappend _record(fields) $name
        set [self namespace]::$name $value
    }

    # readonly name ?value?
    #
    # name  - A field variable name
    # value - An initial value, defaults to ""
    #
    # Defines $name as a field, and marks it readonly.

    method readonly {name {value ""}} {
        my field $name $value
        lappend _record(readonly) $name
    }

    # fields
    #
    # Returns the list of field names.

    method fields {} {
        return $_record(fields)
    }

    # getdict
    #
    # Retrieves the object's fields and their values as a dictionary.

    method getdict {} {
        set dict [dict create]

        foreach field $_record(fields) {
            dict set dict $field [my get $field]
        }

        return $dict
    }

    # setdict dict
    #
    # dict - A dictionary of field names and values.
    #
    # Sets the record's fields given a dictionary.  Keys that do not
    # correspond to defined fields are ignored.  The command will throw
    # an error if it attempts to modify a readonly field.

    method setdict {dict} {
        foreach field $_record(fields) {
            if {[dict exists $dict $field]} {
                my set $field [dict get $dict $field]
            }
        }
    }

    # get field
    #
    # field   - A field name.
    #
    # Retrieves a field's value, or, really, the value of any 
    # scalar instance variable (because this is useful for debugging).

    method get {var} {
        return [set [self namespace]::$var]
    }

    # set field value
    #
    # field  - A field name
    # value  - A new value
    #
    # Assigns a value to a writable field; or really, to any scalar instance
    # variable that isn't declared as a readonly field (because this is
    # useful for debugging.  Writes to a readonly field will only fail if
    # the value would actually be changed.

    method set {field value} {
        if {![info exists [self namespace]::$field]} {
            error "Unknown instance variable: \"$field\""
        } elseif {$field in $_record(readonly) && $value ne [my get $field]} {
            error "Field is readonly: \"$field\""
        }

        set [self namespace]::$field $value
    }

    # configure ?option value...?
    #
    # option   - A field name in option form: -$field
    # value    - The field value
    #
    # This is equivalent to setdict, but uses option notation.

    method configure {args} {
        foreach {opt value} $args {
            set field [string range $opt 1 end]
            if {$field ni [my fields]} {
                error "Unknown option: \"$opt\""
            }
            my set $field $value
        }
    }

    # cget opt
    #
    # opt   - An field name in option form: -$field
    #
    # This is equivalent to get but uses option notation.

    method cget {opt} {
        set field [string range $opt 1 end]
        return [my get $field]
    }
}