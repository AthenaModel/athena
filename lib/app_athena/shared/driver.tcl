#-----------------------------------------------------------------------
# TITLE:
#   driver.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   NOTE: This is currently called "driver"; eventually it should 
#   replace the existing "driver" module.
#
#   athena_sim(1): Experimental Driver Manager
#
#   This module is responsible for managing drivers and operations
#   upon them.  As such, it is a type ensemble.
#
#   There are a number of different driver types, each associated
#   with a rule set.  The driver type is responsible for:
#
#   * Specifying the signature parms for the driver (used to assign the
#     driver IDs).
#
#   * Producing different kinds of narrative text given the current state 
#     of the driver.
#
#   * The driver's rule set.
#
#   The driver has associated with it a firing dictionary 
#
#   This module is responsible for:
#
#   * Providing the basic infrastructure for driver types.
#
#   * Assigning driver IDs and saving driver records to the RDB.
#
# Driver types should adhere to the driver(i) interface.
#
#-----------------------------------------------------------------------

snit::type driver {
    # Make it a singleton
    pragma -hasinstances no
    
    #-------------------------------------------------------------------
    # Type Variables

    # Initial driver ID.  This is set to 1000 so as to be higher than
    # standard cause's numeric ID, so that numeric driver IDs can be 
    # used as numeric cause ID.  There are fewer than 100 standard causes;
    # using 1000 leaves lots of room and is visually distinctive when
    # looking at the database.

    typevariable initialID 1000


    #===================================================================
    # driver Types: Definition and Query interface.

    #-------------------------------------------------------------------
    # Uncheckpointed Type variables

    # tinfo array: Type Info
    #
    # names           - List of the names of the driver types.
    # sigparms-$ttype - Signature parameters in a driver's fdict.

    typevariable tinfo -array {
        names {}
    }

    # type names
    #
    # Returns the driver type names.

    typemethod {type names} {} {
        return [lsort $tinfo(names)]
    }

    # type define name sigparms defscript
    #
    # name        - The driver name
    # sigparms    - List of fdict parms that determine the signature.
    # defscript   - The definition script (a snit::type script)
    #
    # Defines driver::$name as a type ensemble given the typemethods
    # defined in the defscript.  See driver(i) for documentation of the
    # expected typemethods.

    typemethod {type define} {name sigparms defscript} {
        # FIRST, define the type.
        set header "
            # Make it a singleton
            pragma -hasinstances no

            delegate typemethod getid using {driver getid $name}
        "

        snit::type ${type}::${name} "$header\n$defscript"

        # NEXT, save the type metadata
        ladd tinfo(names) $name
        set tinfo(sigparms-$name) $sigparms
    }


    #-------------------------------------------------------------------
    # driver Ensemble Interface

    # get dtype signature
    #
    # dtype      - A driver type
    # signature  - A driver signature
    #
    # Returns the driver_id for the driver type and signature, if one
    # exists, and "" otherwise.

    typemethod get {dtype signature} {
        return [rdb onecolumn {
            SELECT driver_id FROM drivers
            WHERE dtype=$dtype AND signature=$signature
        }]
    }

    # getid fdict
    #
    # fdict - A rule firing dictionary
    #
    # Retrieves the driver ID for the firing dict, creating a new
    # driver if necessary.

    typemethod getid {fdict} {
        # FIRST, compute the signature from the fdict given the
        # sigparms.
        set signature [list]
        set dtype [dict get $fdict dtype]

        foreach key $tinfo(sigparms-$dtype) {
            lappend signature [dict get $fdict $key]
        }

        # NEXT, if there's a driver with that signature return it.
        set id [$type get $dtype $signature]

        if {$id ne ""} {
            return $id
        }

        # NEXT, this is a new get a new driver ID
        rdb eval {
            SELECT coalesce(max(driver_id)+1, $initialID) 
            AS new_id FROM drivers
        } {}

        # NEXT, create the entry
        rdb eval {
            INSERT INTO drivers(driver_id, dtype, signature)
            VALUES($new_id, $dtype, $signature);
        }

        return $new_id
    }

    # call op fdict ?args...?
    #
    # op    - A driver type subcommands
    # fdict - A rule firing dictionary.
    # args  - Any additional arguments.
    #
    # This is a convenience command that calls the relevant subcommand
    # for the driver.

    typemethod call {op fdict args} {
        [dict get $fdict dtype] $op $fdict {*}$args
    }
}



