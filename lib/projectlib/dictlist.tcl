#-----------------------------------------------------------------------
# TITLE:
#   dictlist.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# PACKAGE:
#   projectlib(n): Athena Project Library
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   dictlist: Buffer for building up a list of dictionaries with
#   identical keys.
#
#-----------------------------------------------------------------------

oo::class create ::projectlib::dictlist {
    #-------------------------------------------------------------------
    # Variables

    variable defdict ;# The default dictionary value
    variable dicts   ;# The actual list of dicts

    #-------------------------------------------------------------------
    # Constructor

    # constructor spec_
    #
    # spec_ - A dictionary spec
    #
    # Initializes the object to work with a particular kind of 
    # dictionary.  At present, the spec is simply an ordered list
    # of keys.

    constructor {spec_} {
        foreach item $spec_ {
            lassign $item key value
            dict set defdict $key $value
        }
        set dicts [list]
    }

    #-------------------------------------------------------------------
    # Public Methods

    # clear
    #
    # Zeroes the list.

    method clear {} {
        set dicts [list]
    }
    
    # append dict
    #
    # Appends a previously formatted dictionary to the list.

    method append {dict} {
        lappend dicts $dict

        return
    }

    # add value value value...
    #
    # value - A column value
    #
    # Adds a dictionary to the list.  The values on the command line
    # are paired up with the key names.  If the list of values is short,
    # the keys get the empty string; if it is too long, that's an error.

    method add {args} {
        set dict $defdict

        set keys [lrange [my keys] 0 [llength $args]-1]

        foreach key $keys value $args {
            if {$key eq ""} {
                error "value with no matching key"
            }
            dict set dict $key $value
        }

        my append $dict

        return
    }


    # addwith -key value ...
    #
    # -key   - The name of a key with "-" prepended
    # value  - A value to be added to a dictionary
    #
    # Adds a dictionary to the list.  The dictionary is initialized 
    # with empty values, and then the options are applied.  It's
    # an error if "-key" doesn't match a defined key.

    method addwith {args} {
        set dict $defdict

        while {[llength $args] > 0} {
            set key [string trimleft [lshift args] -]
            if {![dict exists $dict $key]} {
                error "invalid key: \"$key\""
            }

            dict set dict $key [lshift args]
        }

        my append $dict

        return
    }

    # size
    #
    # Returns the size of the list.

    method size {} {
        return [llength $dicts]
    }

    # dicts
    #
    # Returns the current list.

    method dicts {} {
        return $dicts
    }

    # set list
    #
    # list  - A list of dictionaries.
    #
    # Sets the list of dictionaries.

    method set {list} {
        set dicts $list
    }

    # format ?options?
    #
    # As for dictab(n)'s format command.

    method format {args} {
        kiteutils::dictab format $dicts {*}$args
    }

    # keys
    #
    # Returns the key names.

    method keys {} {
        return [dict keys $defdict]
    }

    # find key value ?key value...?
    #
    # key   - One of the dictionary keys
    # value - A value
    #
    # Returns a list of the dicts that match the keys and values.

    method find {args} {
        set result [list]
        foreach dict $dicts {
            set found 1
            foreach {k v} $args {
                if {[dict get $dict $k] ne $v} {
                    set found 0
                    break
                }
            }

            if {$found} {
                lappend result $dict
            }
        }

        return $result
    }






}