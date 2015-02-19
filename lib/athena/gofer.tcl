#-----------------------------------------------------------------------
# TITLE:
#    gofer.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Gofer Types
#    
#    A gofer is a data validation type whose values represent different
#    ways of retrieving a data value of interest, so called because
#    on demand the gofer type can go retrieve the desired data.
#    For example, there are many ways to select a list of civilian groups: 
#    an explicit list, all groups resident in a particular neighborhood or 
#    neighborhoods, all groups who support a particular actor, and so forth.
#
#    The value of a gofer is a gofer dictionary, or gdict.  It will 
#    always have a field called "_rule", whose value indicates the algorithm
#    to use to find the data value or values of interest.  Other fields
#    will vary from gofer to gofer.
#
#    See gofer(i) for the methods that a gofer object must 
#    implement.

#-----------------------------------------------------------------------
# gofer: The athenadb(n) component responsible for creating and 
# manipulating gofer types and values.  

snit::type ::athena::goferx {
    #===================================================================
    # Gofer Type and Rule Creation
    #
    # The ::athena::gofer type provides the mechanisms for statically
    # defining gofer types and the rules that belong to them in the
    # form of type methods and type variables.  The code in this 
    # section is concerned solely with defining the gofer types at
    # load time.  
    #
    # An instance of this type is created as an athenadb(n) component;
    # it provides access to the gofer types at run time.  See the
    # instance code section below.
    
    #-------------------------------------------------------------------
    # Type Variables

    # Array, type definitions by type name (e.g., "CIVGROUPS").
    #
    #   name     => The name, for convenience
    #   noun     => The noun used for return elements, e.g., "group"
    #   formspec => The dynaform(n) spec for this type.
    #   rules    => Dictionary of rule classes by name
    #            -> $ruleName => Dictionary of rule parms
    #                         -> $class => The rule's TclOO class.

    typevariable typedefs -array {}
        
    #-------------------------------------------------------------------
    # Gofer Type Definition Type Methos
    
    # define name formspec
    #
    # name       - The name
    # noun       - The noun for the returned values, or ""
    # formspec   - The dynaform spec for this type
    #
    # Defines a new dynaform type.  Rules are added separately.

    typemethod define {name noun formspec} {
        # FIRST, get the names
        set name [string toupper $name]
        identifier validate $name

        # NEXT, add the _type field to the formspec.
        set formhead [outdent {
            resources adb_
            text _type -context yes -invisible yes
        }]

        # NEXT, create the form
        set form ::athena::gofer::$name
        dynaform define $form "$formhead\n\n$formspec"

        # NEXT, save the metadata
        dict set typedefs($name) name   $name
        dict set typedefs($name) noun   $noun
        dict set typedefs($name) form   $form
        dict set typedefs($name) rules  [dict create]

        namespace eval ::athena::gofer::$name {}
    }


    # rule typename rulename body
    #
    # typename   - The type to receive the new rule
    # rulename   - The new rule's name
    # keys       - The rule's parameter names
    # body       - A snit::type body with the rule's typemethods.
    #
    # Defines a new rule, creating a rule object in the type's namespace.

    typemethod rule {typename rulename keys body} {
        # FIRST, get the names
        set typename [string toupper $typename]
        set rulename [string toupper $rulename]

        require {[info exists typedefs($typename)]} \
            "No such gofer type: \"$typename\""
        identifier validate $rulename

        set cls "::athena::gofer::${typename}::${rulename}"

        # NEXT, define the new rule class.
        oo::class create $cls
        oo::define $cls superclass ::athena::gofer_rule
        oo::define $cls variable adb
        oo::define $cls method keys {} [format {
            return %s
        } [list $keys]]
        oo::define $cls $body

        # NEXT, update the metadata
        dict set typedefs($typename) rules $rulename $cls
    }

    # rulefrom typename rulename class
    #
    # typename   - The type to receive the new rule
    # rulename   - The new rule's name
    # class      - A gofer_rule object.
    #
    # Defines a new rule using an existing gofer_rule(i) class.

    typemethod rulefrom {typename rulename class} {
        # FIRST, get the names
        set typename [string toupper $typename]
        set rulename [string toupper $rulename]

        require {[info exists typedefs($typename)]} \
            "No such gofer type: \"$typename\""
        identifier validate $rulename

        # NEXT, save it.
        dict set rules($typename) rules $rulename $class        
    }

    #===================================================================
    # Gofer Management at Run-Time
    #
    # At run-time, an instance of ::athena::gofer is created as a
    # component of athenadb(n).  It in turn makes the gofer types
    # available to the library.

    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Instance variables

    variable types -array {}   ;# Array of gofer type objects by name.
    

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        # FIRST, save the athenadb(n) handle.
        set adb $adb_

        # NEXT, create all of the types.
        foreach typename [array names typedefs] {
            set types($typename) ${selfns}.$typename

            ::athena::gofer_type create $types($typename) \
                $adb                                      \
                $typename                                 \
                [dict get $typedefs($typename) noun]      \
                ::athena::gofer::$typename                \
                [dict get $typedefs($typename) rules]
        }
    }

    #--------------------------------------------------------------------
    # Public Methods
    

    # check
    #
    # Does a sanity check of all defined gofers.  This command is
    # intended for use by the Athena test suite.  An error is thrown
    # if a problem is found; otherwise it returns "OK".

    method check {} {
        foreach typename [array names typedefs] {
            if {[catch {$types($typename) SanityCheck} result eopts]} {
                return {*}$eopts "Error in gofer $typename, $result"
            }
        }

        return "OK"
    }

    #-------------------------------------------------------------------
    # Gofer Value Type Methods

    delegate method * using {%s call %m}

    # call typename args...
    #
    # typename   - A gofer type name
    # args...    - Method and arguments to pass to it.

    method call {typename args} {
        set typename [string toupper $typename]

        return [$types($typename) {*}$args]        
    }
    
    # keys typename rulename
    #
    # Retrieves the gofer type's keys.

    method keys {typename rulename} {
        set typename [string toupper $typename]
        set rulename [string toupper $rulename]

        return [$types($typename) keys $rulename]
    }

    # make typename rulename ?args...?
    #
    # typename   - A gofer type name
    # rulename   - A gofer rule name for this type
    # args       - Any arguments required by the rule
    #
    # Constructs a valid gdict for the given type and rule.

    method make {typename rulename args} {
        set typename [string toupper $typename]
        set rulename [string toupper $rulename]

        require {[info exists types($typename)]} \
            "No such gofer type: \"$typename\""
        
        return [$types($typename) make $rulename {*}$args]
    }

    # validate gdict
    #
    # gdict    - Possibly, a gofer value dictionary
    #
    # Validates the gdict, returning it in canonical form.  The value
    # may belong to any defined gofer type.  (To validate a gdict as
    # belonging to a particular type, use the type's command, e.g.,
    # [gofer::TYPENAME validate])

    method validate {gdict} {
        # FIRST, validate the _type
        set typename [$type GetType "" INVALID $gdict]

        # NEXT, have the type complete the validation.
        return [$types($typename) validate $gdict]
    }

    # narrative gdict ?-brief?
    #
    # gdict    - a valid gofer value dictionary
    # -brief   - If included, lists are truncated with an ellipsis.
    #
    # Returns the narrative string for the gdict.

    method narrative {gdict {opt ""}} {
        # FIRST, if we don't know its type return "???".
        if {![gofer GotType $gdict]} {
            return "???"
        }

        set typename [dict get $gdict _type]

        # NEXT, have the type return the narrative text.
        return [$types($typename) narrative $gdict $opt]
    }


    # eval gdict
    #
    # gdict    - a valid gofer value dictionary
    #
    # Evaluates the gdict, returning the computed value.

    method eval {gdict} {
        # FIRST, get its type (throws error if invalid)
        set typename [$type GetType "" NONE $gdict]

        # NEXT, have the type compute the result.
        return [$types($typename) eval $gdict]
    }

    # get typename rulename ?args...?
    #
    # typename   - A gofer type name
    # rulename   - A gofer rule name for this type
    # args       - Any arguments required by the rule
    #
    # Constructs a valid gdict for the given type and rule, and
    # evaluates it.

    method get {typename rulename args} {
        return [$self eval [$self make $typename $rulename {*}$args]]
    }

    #-------------------------------------------------------------------
    # Helpers
    

    # GotType gdict
    #
    # gdict   - Possibly, a gofer dict.
    #
    # Returns 1 if the gdict has a known _type, and 0 otherwise.

    typemethod GotType {gdict} {
        # FIRST, verify that it's a dictionary, and get its _type.
        if {[catch {
            set gotType [dict exists $gdict _type]
        }]} {
            set gotType 0
        }

        if {!$gotType} {
            return 0
        }

        set typename [string toupper [dict get $gdict _type]]

        # NEXT, verify that we have this type
        if {![info exists typedefs($typename)]} {
            return 0
        }

        return 1
    }

    # GetType name ecode gdict
    #
    # name    - Gofer type name, e.g., "ACTORS", or ""
    # ecode   - The error code, NONE or INVALID
    # gdict   - Possibly, a gofer dict.
    #
    # Throws an error if the gdict has no valid type.

    typemethod GetType {name ecode gdict} {
        # FIRST, verify that it's a dictionary, and get its _type.
        if {[catch {
            set gotType [dict exists $gdict _type]
        }]} {
            set gotType 0
        }

        if {!$gotType} {
            if {$name eq ""} {
                throw $ecode "Not a gofer value"
            } else {
                throw $ecode "Not a gofer $name value"
            }
        }

        set typename [string toupper [dict get $gdict _type]]

        # NEXT, verify that we have this type
        if {![info exists typedefs($typename)]} {
            throw $ecode "No such gofer type: \"$typename\""
        }

        return $typename
    }
}


