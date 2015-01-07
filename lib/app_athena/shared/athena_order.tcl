#-----------------------------------------------------------------------
# TITLE:
#    athena_order.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_athena(n): Athena Order Adaptor
#
#    This class subclasses and adapts ::projectlib::orderx, providing
#    additional features for use by Athena order classes.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Athena Order Adaptor

oo::class create athena_order {
    superclass ::projectlib::orderx

    #-------------------------------------------------------------------
    # Instance Variables

    # rdb - Set automatically as an example.
    variable rdb

    # parms - brought into scope from parent.
    variable parms

    #-------------------------------------------------------------------
    # Constructor

    # constructor rdb_ ?parmdict?
    #
    # rdb_       - The RDB in used by the application
    # parmdict  - A dictionary of initial parameter values
    #
    # The rdb is set here as an example of how to do it, and to test
    # the framework.

    constructor {rdb_ {parmdict ""}} {
        set rdb $rdb_

        next $parmdict
    }
    
    #-------------------------------------------------------------------
    # Form Helper Methods

    # keyload key fields idict value
    #
    # key     - Name of a key field.  For tables with complex keys, use a
    #           view that concatenates the key columns into one column.
    # fields  - Fields whose values should be loaded given the key field.
    #           If "*", all fields are loaded.  Defaults to "*".
    # idict   - The field item's definition dictionary.
    # value   - The current value of the key field.
    #
    # For use as a dynaform field -loadcmd with key fields.
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
        $rdb eval "
            SELECT [join $fields ,] FROM $table
            WHERE $key=\$value
        " row {
            unset row(*)

            return [array get row]
        }

        return ""
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

            if {[rdb exists {
                SELECT id FROM entities WHERE id=$name
            }]} {
                my reject $parm "An entity with this ID already exists"
            }
        }
    }
}


