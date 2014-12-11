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
    variable errdict

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
        require {$orderState ne "EXECUTED"} \
            "Cannot modify an executed order."

        if {![info exists parms($name)]} {
            error "unknown parameter: \"$name\""
        }

        set value [string trim $value]

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

    # valid
    #
    # Returns 1 if the order is valid, and 0 otherwise, calling 
    # _validate if need be.  The leaf class must define _validate.
    #
    # Errors can be retrieved by calling errdict.
    
    method valid {} {
        if {$orderState eq "REJECTED"} {
            return 0
        }

        if {$orderState ne "CHANGED"} {
            return 1
        }

        set errdict [dict create]

        my _validate

        if {[dict size $errdict] == 0} {
            set orderState VALID
            return 1
        } else {
            set orderState REJECTED
            return 0
        }
    }

    # _validate
    #
    # Checks whether there are any problems with the error,
    # adding problems to the errdict.
    #
    # Subclasses should override this method to validate their parameters.
    
    method _validate {} {
        # Nothing to do.
    }

    # errdict
    #
    # Returns the error dictionary.  (It is empty unless the order state
    # is REJECTED.)

    method errdict {} {
        return $errdict
    }

    # execute
    #
    # Executes the order, assuming the "check" is successful.

    method execute {} {
        require {$orderState eq "VALID"} \
            "Only validated orders can be executed."

        set result [my _execute]
        set orderState EXECUTED

        return $result
    }

    # _execute
    #
    # Subclasses should override this.  They can assume that all
    # parameters have been validated.
    method _execute {} {
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
        # TODO: Might want to distinguish between wrong state
        # and no undo script
        require {[my canundo]} "This order cannot be undone."

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
    method prepare {parm args} {
        # FIRST, process the options, so long as there's no explicit
        # error.

        while {![dict exists $errdict $parm] && [llength $args] > 0} {
            set opt [lshift args]
            switch -exact -- $opt {
                -toupper {
                    set parms($parm) [string toupper $parms($parm)]
                }
                -tolower {
                    set parms($parm) [string tolower $parms($parm)]
                }
                -normalize {
                    set parms($parm) [normalize $parms($parm)]
                }
                -num {
                    # Integer numbers beginning with 0 are interpreted as
                    # octal, so we need to trim leading zeroes when the
                    # number is a non-zero integer.
                    if {[string is integer -strict $parms($parm)] &&
                        $parms($parm) != 0
                    } {
                        set parms($parm) [string trimleft $parms($parm) "0"]
                    }
                }
                -required { 
                    if {$parms($parm) eq ""} {
                        my reject $parm "required value"
                    }
                }
                -oldvalue {
                    # TBD: Should this be handled differently?
                    set oldvalue [lshift args]

                    if {$parms($parm) eq $oldvalue} {
                        set parms($parm) ""
                    }
                }
                -oldnum {
                    # TBD: Should this be handled differently?
                    set oldvalue [lshift args]

                    if {$parms($parm) == $oldvalue} {
                        set parms($parm) ""
                    }
                }
                -type {
                    set parmtype [lshift args]

                    my checkon $parm { 
                        set parms($parm) [{*}$parmtype validate $parms($parm)]
                    }
                }
                -listof {
                    set parmtype [lshift args]

                    my checkon $parm {
                        set newvalue [list]

                        foreach val $parms($parm) {
                            lappend newvalue [{*}$parmtype validate $val]
                        }

                        set parms($parm) $newvalue
                    }
                }
                -oneof {
                    set list [lshift args]

                    my checkon $parm {
                        if {$parms($parm) ni $list} {
                            if {[llength $list] > 15} {
                                my reject $parm \
                                    "invalid value: \"$parms($parm)\""
                            } else {
                                my reject $parm \
                                    "invalid value \"$parms($parm)\", should be one of: [join $list {, }]"
                            }
                        }
                    }
                }
                -someof {
                    set list [lshift args]

                    my checkon $parm {
                        foreach val $parms($parm) {
                            if {$val ni $list} {
                                if {[llength $list] > 15} {
                                    my reject $parm \
                                        "invalid value: \"$val\""
                                } else {
                                    my reject $parm \
                                        "invalid value \"$val\", should be one of: [join $list {, }]"
                                }
                            }
                        }
                    }
                }
                -with {
                    set checker [lshift args]

                    my checkon $parm { 
                        set parms($parm) [{*}$checker $parms($parm)]
                    }
                }

                -listwith {
                    set checker [lshift args]

                    my checkon $parm {
                        set newvalue [list]

                        foreach val $parms($parm) {
                            lappend newvalue [{*}$checker $val]
                        }

                        set parms($parm) $newvalue
                    }
                }

                -selector {
                    error "TBD: Not implemented yet"
                    set frm [order options $parms(_order) -dynaform]

                    if {$frm eq ""} {
                        error "Not a dynaform selector: \"$parm\""
                    }

                    set cases [dynaform cases $frm $parm [array get parms]]

                    validate $parm {
                        if {$parms($parm) ni $cases} {
                            reject $parm \
                                "invalid value \"$parms($parm)\", should be one of: [join $cases {, }]"
                        }
                    }
                }
                default { 
                    error "unknown option: \"$opt\"" 
                }
            }
        }
    }

    # badparm parm
    #
    # parm    Parameter name
    #
    # Returns 1 if parm's value is known to be missing or invalid, and
    # 0 otherwise.

    unexport badparm
    method badparm {parm} {
        if {$parms($parm) eq "" || [dict exists $errdict $parm]} {
            return 1
        }

        return 0
    }

    # checkon parm script
    #
    # parm    A parameter to validate
    # script  A script to validate it.
    #
    # Executes the script in the caller's context.  If the script
    # throws an error, and the error code is INVALID, the value
    # is rejected.  Any other error is rethrown as an unexpected
    # error.
    #
    # If the parameter is already known to be invalid, the code is skipped.
    # Further, if the parameter is the empty string, the code is skipped,
    # as presumably it's an optional parameter.

    unexport checkon
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

    # returnOnError
    #
    # Terminates checking if there are accumulated errors.

    unexport returnOnError
    method returnOnError {} {
        # FIRST, Were there any errors?
        if {[dict size $errdict] > 0} {
            # Trigger a return one level up.
            return -code return
        }
    }

    # cancel
    #
    # Use this in the rare case where the user can interactively 
    # cancel an order that's in progress.

    unexport cancel
    method cancel {} {
        return -code error -errorcode CANCEL \
            "The order was cancelled by the user."
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
