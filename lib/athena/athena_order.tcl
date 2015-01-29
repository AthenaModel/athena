#-----------------------------------------------------------------------
# TITLE:
#    athena_order.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Athena Order Adaptor
#
#    This class subclasses and adapts ::marsutil::order, providing
#    additional features for use by Athena order classes.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Athena Order Adaptor

oo::class create ::athena::athena_order {
    superclass ::marsutil::order

    #-------------------------------------------------------------------
    # Instance Variables

    # rdb - Set automatically as an example.
    variable adb

    # parms - brought into scope from parent.
    variable parms

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_ ?parmdict?
    #
    # adb_       - The athenadb(n) in use
    # parmdict   - A dictionary of initial parameter values

    constructor {adb_ {parmdict ""}} {
        set adb $adb_

        next $parmdict
    }
    
    #-------------------------------------------------------------------
    # Form Helper Methods

    # keyload key fields idict value
    #
    # key     - Name of a dbkey field.  For tables with complex keys, use a
    #           view that concatenates the key columns into one column.
    # fields  - Fields whose values should be loaded given the key field.
    #           If "*", all fields are loaded.  Defaults to "*".
    # idict   - The field item's definition dictionary.
    # value   - The current value of the key field.
    #
    # For use as a dynaform field -loadcmd with dbkey fields.
    #
    # Loads the table row from the context database given 
    # the parameters, and returns it as a dictionary.  If "fields"
    # is not *, only the listed field names will be returned.

    method keyload {key fields idict value} {
        # FIRST, get the metadata.
        set ftype  [dict get $idict ftype]
        set table  [dict get $idict table]

        # NEXT, get the list of fields
        if {$fields eq "*"} {
            set fields [dynaform fields $ftype]
        }

        # NEXT, retrieve the record.
        $adb eval "
            SELECT [join $fields ,] FROM $table
            WHERE $key=\$value
        " row {
            unset row(*)

            return [array get row]
        }

        return ""
    }

    # multiload multi fields idict keyvals
    #
    # multi   - Name of the dbmulti field itself
    # fields  - Fields whose values should be loaded given the multi field.
    #           If "*", all fields are loaded.  Defaults to "*".
    # idict   - The field item's definition dictionary.
    # keyvals - The current value of the multi field.
    #
    # For use as a dynaform field -loadcmd with dbmulti fields.
    #
    # Reads the named fields from the multi's table given the multi's
    # current list of values.  Builds a dictionary of values common
    # to all records, and clears the others.

    method multiload {multi fields idict keyvals} {
        # FIRST, get the field metadata.
        set ftype   [dict get $idict ftype]
        set table   [dict get $idict table] 
        set keycol  [dict get $idict key]

        # NEXT, if the list of key values is empty, clear the values;
        # we're done.
        if {[llength $keyvals] == 0} {
            # TBD: Should clear the set of values, probably.
            return
        }
        
        # NEXT, get the list of fields
        if {$fields eq "*"} {
            set fields [dynaform fields $ftype]
            ldelete fields $multi
        }

        # NEXT, retrieve the first entity's data.
        set key [lshift keyvals]

        set query "
            SELECT [join $fields ,] FROM $table WHERE $keycol=\$key
        "

        $adb eval $query prev {}
        unset prev(*)

        # NEXT, retrieve the remaining entities, looking for
        # mismatches
        foreach key $keyvals {
            $adb eval $query current {}

            foreach field $fields {
                if {$prev($field) ne $current($field)} {
                    set prev($field) ""
                }
            }
        }

        # NEXT, return the loaded values.
        return [array get prev]
    }

    
    #-------------------------------------------------------------------
    # Validation Helper Methods

    # unused parm
    #
    # parm   - A parameter containing an entity short name
    #
    # If the parameter isn't a badparm, verifies that the name it 
    # contains is unused per the "entities" view.  Rejects the 
    # parameter if it is already used.

    unexport unused
    method unused {parm} {
        my checkon $parm {
            set name $parms($parm)

            if {[$adb exists {
                SELECT id FROM entities WHERE id=$name
            }]} {
                my reject $parm "An entity with this ID already exists"
            }
        }
    }
}


