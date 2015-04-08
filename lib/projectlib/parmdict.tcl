#-----------------------------------------------------------------------
# TITLE:
#   parmdict.tcl
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
#   parmdict: parameter dictionary validation
#
#   A parmdict object is used to retrieve and validate parameter
#   parameter dictionaries, such as query dictionaries from from 
#   HTTP requests.
#
#-----------------------------------------------------------------------

oo::class create ::projectlib::parmdict {
    #-------------------------------------------------------------------
    # Variables

    variable parms   ;# The parmdict
    variable errors  ;# Dictionary of error messages

    #-------------------------------------------------------------------
    # Constructor

    # constructor dict
    #
    # dict - A dictionary of parameter names and values.
    #
    # Initializes the object and sets the initial parameter dictionary.

    constructor {dict} {
        my setdict $dict
    }

    #-------------------------------------------------------------------
    # Public Methods
    
    # setdict dict
    #
    # dict  - A dictionary of parameter names and values
    #
    # Re-initializes the object with the new dictionary.

    method setdict {dict} {
        set parms $dict
        set errors [dict create]
    }

    # getdict
    #
    # Returns the current parameter dictionary.

    method getdict {} {
        return $parms
    }

    # errors
    #
    # Returns the error dictionary: a dictionary of parameter names
    # (or "*") and error messages.

    method errors {} {
        return $errors
    }

    # ok
    #
    # Returns 1 if there are no known parameter errors, and 0 otherwise.

    method ok {} {
        return [expr {[dict size $errors] == 0}]
    }

    # badparm parm
    #
    # parm - A parameter name
    #
    # Returns 1 if the parameter has no value or if it is known to be 
    # bad.  It is primarily for use by checkon.

    method badparm {parm} {
        if {[dict get $parms $parm] eq "" || [dict exists $errors $parm]} {
            return 1
        }

        return 0
    }

    # reject parm message
    #
    # parm     - A parameter name
    # message  - A rejection error message
    #
    # Rejects the parameter with an error message.  The parmdict is no
    # longer "ok".

    method reject {parm message} {
        dict set errors $parm $message
    }

    # prepare parm ?options...?
    #
    # parm   - A parameter name
    #
    # Prepares the parameter for use.  First, ensures that the parameter
    # exists in the dictionary.  Next, executes its options, each of which
    # may transform, validate, or reject the parameter's value.

    method prepare {parm args} {
        set keep 1

        if {![dict exists $parms $parm]} {
            dict set parms $parm ""
        }

        set value [string trim [dict get $parms $parm]]

        while {[llength $args] > 0 && ![dict exists $errors $parm]} {
            switch -exact -- [lshift args] {
                -required {
                    if {$value eq ""} {
                        my reject $parm "Required parameter"
                    }
                }
                -remove {
                    set parms [dict remove $parms $parm]
                    set keep 0
                }
                -toupper {
                    set value [string toupper $value]
                }
                -tolower {
                    set value [string tolower $value]
                }
                -with {
                    set checker [lshift args]

                    my checkon $parm {
                        set value [{*}$checker $value]
                    }
                }
            }
        }

        if {$keep} {
            dict set parms $parm $value
        }
        return $value
    }

    # checkon parm script
    #
    # parm   - A parameter name
    # script - A validation script
    #
    # Executes script only if the parm has a non-empty value and is not
    # already known to be bad.  The script can reject the parameter 
    # explicitly, and if INVALID is caught then the parameter is 
    # rejected implicitly.

    method checkon {parm script} {
        if {[my badparm $parm]} {
            return
        }

        try {
            uplevel 1 $script
        } trap INVALID {result} {
            my reject $parm $result
        }
    }
}