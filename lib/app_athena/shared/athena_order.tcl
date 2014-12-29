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

    # parms - brought into scope from parent.
    variable parms
    

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
                reject $parm "An entity with this ID already exists"
            }
        }
    }
}


