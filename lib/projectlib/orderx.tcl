#-----------------------------------------------------------------------
# TITLE:
#    orderx.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectlib(n): Order Class
#
#    orderx(n) is a base class for application orders.  Each order type
#    (e.g., ACTOR:CREATE) will be a TclOO class ultimately derived from
#    ::projectlib::orderx.  Each specific order will be an instance of
#    an order class.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export orderx
}

#-----------------------------------------------------------------------
# orderx class

oo::class create ::projectlib::orderx {
    #-------------------------------------------------------------------
    # Instance Variables

    # orderState: one of CHANGED, REJECTED, VALID, EXECUTED
    #
    # CHANGED  - The object is new, or its parameters have been changed.
    # REJECTED - It was checked, and the check failed.
    # VALID    - It was checked and the check succeeded.
    # EXECUTED - It was valid and executed.

    variable orderState

    # parms: Array of order parameter values by name.
    variable parms

    # defaults: Array of default parameter values by name.
    variable defaults

    # errdict: Dictionary of error values (REJECTED); otherwise empty.

    # undoScript: Script to execute to undo the order.
    variable undoScript
    
    #-------------------------------------------------------------------
    # Constructor/Destructor

    # TODO: The constructor should set any necessary context (as 
    # determined by subclasses) and possibly allow initial values to
    # be passed to setdict or configure.  In any event, it should
    # initialize the order parameters.
    
    constructor {} {
        set orderState CHANGED
        set errdict    [dict create]
        set undoScript ""

        # Can't initializes parms here, no known parms.
    }

    #-------------------------------------------------------------------
    # Public Methods: Parameter access

    # getdict
    #
    # Retrieves the object's parameter values as a dictionary.

    method getdict {} {
        array get parms
    }

    # get var
    #
    # var   - A parameter name
    #
    # Retrieves the value.

    method get {name} {
        return $parms($name)
    }

    # setdict dict
    #
    # Sets the object's parameters tate as a dictionary.  
    # No validation is done. 

    method setdict {dict} {
        dict for {key value} $dict {
            my set $key value
        }

        return
    }

    # set name value
    #
    # name   - A parameter name
    # value  - A new value
    #
    # Assigns the value to the variable; the variable must already
    # exist.  

    method set {name value} {
        assert {$orderState ne "EXECUTED"}

        if {![info exists parms($name)]} {
            error "unknown parameter: \"$name\""
        }

        if {$parms($name) ne $value} {
            set parms($name) $value
            set orderState CHANGED
        }

        return $value
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

        return
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

    #-------------------------------------------------------------------
    # Metadata and queries

    # state
    #
    # Returns the order's state.

    method state {} {
        return $orderState
    }
    
    # title
    #
    # Returns the order's title string.  

    method title {} {
        error "Not defined by subclass"
    }

    # sendstates
    #
    # Returns the order's sendstates value.  

    method sendstates {} {
        error "Not defined by subclass"
    }

    # narrative
    #
    # Returns a human-readable narrative string for this order, usually
    # quite brief.  Defaults to the order title; subclasses can override
    # it.

    method narrative {} {
        return [my title]
    }

    # parms
    #
    # Returns the names of the order's parameters

    method parms {} {
        return [array names parms]
    }

    # prune
    #
    # Returns a dictionary of order parameters containing only those
    # parameters with non-default settings.

    method prune {} {
        throw TBD "Not implemented yet."
    }

    #-------------------------------------------------------------------
    # Public Methods: Order Operations

    # check
    #
    # Attempts to validate the order parameters.  Succeeds silently, or 
    # throws REJECTED with a dictionary of parameter names and error 
    # messages.
    #
    # The leaf class should override CheckParms.
    
    method check {} {
        assert {$orderState ne "EXECUTED"}
        set errdict [dict create]
        my CheckParms

        if {[dict size $errdict] == 0} {
            set orderState VALID
        } else {
            set orderState REJECTED
        }
        return $errdict
    }

    # CheckParms
    #
    # Checks whether there are any problems with the error,
    # adding problems to the errdict.
    #
    # Subclasses should override this method to validate their parameters.
    
    method CheckParms {} {
        # Nothing to do.
    }

    # execute
    #
    # Executes the order, assuming the "check" is successful.

    method execute {} {
        assert {$orderState eq "VALID"}

        set result [my ExecuteOrder]
        set orderState EXECUTED

        return $result
    }

    # ExecuteOrder 
    #
    # Subclasses should override this.  They can assume that all
    # parameters have been validated.
    method ExecuteOrder {} {
        return ""
    }

    # canundo
    #
    # Can undo if executed and there's an undo script.

    method canundo {} {
        return [expr {$orderState eq "EXECUTED" && $undoScript ne ""}]
    }

    # undo
    #
    # Undoes the effect of the order.

    method undo {} {
        assert {[my canundo]}

        namespace eval :: $undoScript

        set orderState VALID
        set undoScript ""
    }

    #-------------------------------------------------------------------
    # Protected Methods: for use in leaf classes

    # defparm name ?defvalue?
    #
    # name      - Parameter name
    # defvalue  - Default value, or "" for none
    #
    # Defines an order parameter.

    unexport defparm
    method defparm {name {defvalue ""}} {
        set parms($name)    $defvalue
        set defaults($name) $defvalue
    }


    # prepare parm options...
    #
    # parm       - A parameter name
    # options... - Controls that affect or check the parameter value.
    #
    # Transforms and validates the parameter's value, setting 
    # errdict if need be.

    unexport prepare
    method prepare {name args} {
        # TBD
    }


    # reject name errtext
    #
    # name    - An order parameter name
    # errtext - Rejection error text.
    #
    # Rejects the parameter given the error text.

    unexport reject
    method reject {name errtext} {
        dict set errdict $name $errtext
    }

    # setundo script
    #
    # script   - An undo script for the order.
    #
    # Used to save the script in the order body.

    unexport setundo 
    method setundo {script} {
        set undoScript $script
    }
}
