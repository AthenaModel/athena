#-----------------------------------------------------------------------
# TITLE:
#    appserver_enums.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Enumerations
#
#    /app/enum/...
#
# CONTENT TYPES:
#    Enum URLs have two content types:
#
#    tcl/enumlist     - A simple list of enumerated values.
#    tcl/enumdict     - A dictionary of symbols and labels (e.g.,
#                       short and long names)
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module ENUMS {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /enum/concerns {enum/concerns}             \
            tcl/enumlist [asproc enum:enumlist econcern]              \
            tcl/enumdict [asproc enum:enumdict econcern]              \
            text/html    [asproc type:html "Enum: Concerns" econcern] \
            "Enumeration: Concerns"

        appserver register /enum/pagesize {enum/pagesize}               \
            tcl/enumlist [asproc enum:enumlist epagesize]               \
            tcl/enumdict [asproc enum:enumdict epagesize]               \
            text/html    [asproc type:html "Enum: epagesize" epagesize] \
            "Enumeration: Page Size (Items per Page)"

        appserver register /enum/parmstate {enum/parmstate}               \
            tcl/enumlist [asproc enum:enumlist eparmstate]                \
            tcl/enumdict [asproc enum:enumdict eparmstate]                \
            text/html    [asproc type:html "Enum: eparmstate" eparmstate] \
            "Enumeration: Model Parameter State"

        appserver register /enum/topitems {enum/topitems}               \
            tcl/enumlist [asproc enum:enumlist etopitems]               \
            tcl/enumdict [asproc enum:enumdict etopitems]               \
            text/html    [asproc type:html "Enum: etopitems" etopitems] \
            "Enumeration: Top Item Limit"
    }
}



