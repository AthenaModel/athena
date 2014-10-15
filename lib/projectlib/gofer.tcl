#-----------------------------------------------------------------------
# TITLE:
#    gofer.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectlib(n): Gofer Types
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
#
#    In addition to the gofer type, this file also defines the "gofer"
#    dynaform_field(i) type.

namespace eval ::projectlib:: {
    namespace export gofer
}

namespace eval ::gofer:: {
    # Gofer types will be defined in this namespace.
}

#-----------------------------------------------------------------------
# gofer: The ensemble command for creating and manipulating gofer types
# and values.

snit::type ::projectlib::gofer {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # Array, full object names by type names
    typevariable types -array {}

    # Rules array.  The key is a type name; the object is a ruledict,
    # which is a dictionary of rule objects by rule name.
    typevariable rules -array {}
    
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # Define the ::gofer namespace, and make helpers available there.
        namespace eval ::gofer {
            namespace path ::projectlib::gofer
        }
    }
    
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

        set fullname "::gofer::${name}"

        # NEXT, add the _type field to the formspec.
        set formspec "text _type -context yes -invisible yes\n\n$formspec"

        # NEXT, create the gofer type object
        goferType $fullname $name $noun $formspec

        # NEXT, define the type's ::gofer namespace, and make the
        # helper procs available in it.
        namespace eval ::gofer::$name {
            namespace path {::gofer ::projectlib::gofer}
        }

        # NEXT, save the metadata
        set types($name) $fullname
        set rules($name) [dict create]
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

        require {[info exists types($typename)]} \
            "No such gofer type: \"$typename\""
        identifier validate $rulename

        set fullname "::gofer::${typename}::${rulename}"

        # NEXT, define the new object.
        set prefix [format {
            pragma -hasinstances no
            typeconstructor {
                namespace path [list %s %s %s] 
            }

            typemethod keys {} { return %s }
        } ::gofer::${typename} ::gofer:: $type [list $keys]]

        snit::type $fullname "$prefix\n$body"

        # NEXT, update the metadata
        dict set rules($typename) $rulename $fullname
    }

    # rulefrom typename rulename object
    #
    # typename   - The type to receive the new rule
    # rulename   - The new rule's name
    # object     - An object adhering to the gofer_rule(i) interface.
    #
    # Defines a new rule using an existing gofer_rule(i) object.

    typemethod rulefrom {typename rulename object} {
        # FIRST, get the names
        set typename [string toupper $typename]
        set rulename [string toupper $rulename]

        require {[info exists types($typename)]} \
            "No such gofer type: \"$typename\""
        identifier validate $rulename

        # NEXT, save it.
        dict set rules($typename) $rulename $object        
    }

    # check
    #
    # Does a sanity check of all defined gofers.  This command is
    # intended for use by the Athena test suite.  An error is thrown
    # if a problem is found; otherwise it returns "OK".

    typemethod check {} {
        foreach typename [array names types] {
            if {[catch {$types($typename) SanityCheck} result eopts]} {
                return {*}$eopts "Error in gofer $typename, $result"
            }
        }

        return "OK"
    }

    #-------------------------------------------------------------------
    # Gofer Value Type Methods
    

    # construct typename rulename ?args...?
    #
    # typename   - A gofer type name
    # rulename   - A gofer rule name for this type
    # args       - Any arguments required by the rule
    #
    # Constructs a valid gdict for the given type and rule.

    typemethod construct {typename rulename args} {
        set typename [string toupper $typename]
        set rulename [string toupper $rulename]

        require {[info exists types($typename)]} \
            "No such gofer type: \"$typename\""
        
        return [$types($typename) $rulename {*}$args]
    }

    # validate gdict
    #
    # gdict    - Possibly, a gofer value dictionary
    #
    # Validates the gdict, returning it in canonical form.  The value
    # may belong to any defined gofer type.  (To validate a gdict as
    # belonging to a particular type, use the type's command, e.g.,
    # [gofer::TYPENAME validate])

    typemethod validate {gdict} {
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

    typemethod narrative {gdict {opt ""}} {
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

    typemethod eval {gdict} {
        # FIRST, get its type (throws error if invalid)
        set typename [$type GetType "" NONE $gdict]

        # NEXT, have the type compute the result.
        return [$types($typename) eval $gdict]
    }

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
        if {![info exists types($typename)]} {
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
        if {![info exists types($typename)]} {
            throw $ecode "No such gofer type: \"$typename\""
        }

        return $typename
    }

    #-------------------------------------------------------------------
    # Helper commands

    # joinlist list ?maxlen? ?delim?
    #
    # list   - A list
    # maxlen - If given, the maximum number of list items to show.
    #          If "", the default, there is no maximum.
    # delim  - If given, the delimiter to insert between items.
    #          Defaults to ", "
    #
    # Joins the elements of the list using the delimiter, 
    # replacing excess elements with "..." if maxlen is given.

    proc joinlist {list {maxlen ""} {delim ", "}} {
        if {$maxlen ne "" && [llength $list] > $maxlen} {
            set list [lrange $list 0 $maxlen-1]
            lappend list ...
        }

        return [join $list $delim]
    }

    # listval noun vcmd list
    #
    # noun   - A plural noun for use in error messages
    # vcmd   - The validation command for the list members
    # list   - The list to validate
    #
    # Attempts to validate the list, returning it in canonical
    # form for the validation type.  Throws an error if any
    # list member is invalid, or if the list is empty.

    proc listval {noun vcmd list} {
        set out [list]
        foreach elem $list {
            lappend out [{*}$vcmd $elem]
        }

        if {[llength $out] == 0} {
            throw INVALID "No $noun selected"
        }

        return $out
    }

    # listnar snoun pnoun list ?-brief?
    #
    # snoun   - A singular noun, or ""
    # pnoun   - A plural noun
    # list    - A list of items
    # -brief  - If given, truncate list
    #
    # Returns a standard list narrative string.

    proc listnar {snoun pnoun list {opt ""}} {
        if {$opt eq "-brief"} {
            set maxlen 8
        } else {
            set maxlen ""
        }

        if {[llength $list] == 1} {
            if {$snoun ne ""} {
                set text "$snoun [lindex $list 0]"
            } else {
                set text [lindex $list 0]
            }
        } else {
            set text "$pnoun ([joinlist $list $maxlen])" 
        }

        return $text
    }
}


#-----------------------------------------------------------------------
# goferType: The instance type for specific gofer types.

snit::type ::projectlib::goferType {
    #-------------------------------------------------------------------
    # Instance Variables
    
    # Name of this gofer type
    variable name
    variable noun

    # Name of the type's dynaform
    variable form ""

    #-------------------------------------------------------------------
    # Constructor

    # constructor typename typenoun formspec
    #
    # typename - The type's name within ::gofer::
    # typenoun - A noun referring to the value or values returned, or ""
    # formspec - A dynaform spec

    constructor {typename typenoun formspec} {
        # FIRST, save the name.
        set name $typename
        set noun $typenoun

        # NEXT, create the form
        set form $self.form
        dynaform define $form $formspec
    }

    #-------------------------------------------------------------------
    # Public Methods

    # name
    #
    # Returns the type's gofer name, e.g., CIVGROUPS as opposed to
    # its command name, ::gofer::CIVGROUPS.

    method name {} {
        return $name
    }

    # noun
    #
    # Returns the type's noun, e.g., "actor" or "group".

    method noun {} {
        return $noun
    }

    # dynaform 
    #
    # Returns the name of the type's dynaform.

    method dynaform {} {
        return $form
    }

    # testform
    #
    # Pops up the dynaform in a dynabox.

    method testform {} {
        dynabox popup \
            -formtype    $form                       \
            -parent      .main                       \
            -validatecmd [mymethod TestformValidate] \
            -initvalue   [list _type $name _rule BY_VALUE]
    }

    method TestformValidate {value} {
        set value [$self validate $value]
        return [$self narrative $value]
    }

    # rules
    #
    # Returns the names of this type's rules.

    method rules {} {
        return [dict keys $::projectlib::gofer::rules($name)]
    }

    # keys rule
    #
    # rule   - A rule name
    #
    # Returns the gdict keys for the given rule.

    method keys {rule} {
        set rule [string toupper $rule]
        require {$rule in [$self rules]} "Unknown rule: \"$rule\""
        return [$self CallRule $rule keys]
    }


    # validate gdict
    #
    # gdict   - Possibly, a valid gdict
    #
    # Validates the gdict and returns it in canonical form.  Only
    # keys relevant to the rule are checked or included in the result.
    # Throws INVALID if the gdict is invalid.

    method validate {gdict} {
        # FIRST, get the type name.  Throws error if not found.
        set typename [gofer GetType $name INVALID $gdict]

        # NEXT, make sure that it's the correct type.
        if {$typename ne $name} {
            error "Type mismatch, got \"$typename\", expected \"$name\""
        }

        # NEXT, make sure that there's a rule.
        if {![dict exists $gdict _rule]} {
            dict set gdict _rule ""
        }

        # NEXT, get the rule and put it in canonical form.
        set rule [string toupper [dict get $gdict _rule]]
        set out [dict create _type $name _rule $rule]

        # NEXT, if we don't know it, that's an error.
        if {$rule eq ""} {
            throw INVALID "No rule specified"
        }

        if {$rule ni [$self rules]} {
            throw INVALID "Unknown rule: \"$rule\""
        }

        # NEXT, make sure it's got all needed keys for the rule
        set stub [dict create]
        foreach key [$self CallRule $rule keys] {
            dict set stub $key ""
        }
        set gdict [dict merge $stub $gdict]

        # NEXT, validate the remainder of the gdict according to the
        # rule.
        return [dict merge $out [$self CallRule $rule validate $gdict]]
    }

    # narrative gdict ?-brief?
    #
    # gdict   - A valid gdict
    # -brief  - If given, constrains lists to the first few members.
    #
    # Returns a narrative string for the gdict as a phrase to be inserted
    # in a sentence, i.e., "all non-empty groups resident in $n".

    method narrative {gdict {opt ""}} {
        # FIRST, make sure the gdict has the right _type.
        if {![gofer GotType $gdict] ||
            [dict get $gdict _type] ne $name} {
            set gdict [$self blank]
        }

        # NEXT, make sure there's a _rule.
        if {![dict exists $gdict _rule]} {
            dict set gdict _rule ""
        }

        set rule [dict get $gdict _rule]

        # NEXT, if we don't know it, that's an error.
        if {$rule eq "" || $rule ni [$self rules]} {
            if {$noun ne ""} {
                return "$noun ???"
            } else {
                return "???"
            }
        }

        # NEXT, call the rule
        return [$self CallRule $rule narrative $gdict $opt]
    }

    # eval gdict
    #
    # gdict   - A valid gdict
    #
    # Evaluates the gdict and returns a list of civilian groups.

    method eval {gdict} {
        set typename [gofer GetType $name NONE $gdict]

        if {$typename ne $name} {
            error "Type mismatch, got \"$typename\", expected \"$name\""
        }

        # NEXT, make sure there's a _rule.
        if {![dict exists $gdict _rule]} {
            dict set gdict _rule ""
        }

        set rule [dict get $gdict _rule]

        # NEXT, if we don't know it, that's an error.
        if {$rule eq ""} {
            error "No rule specified"
        } elseif {$rule ni [$self rules]} {
            error "Unknown rule: \"$rule\""
        }

        # NEXT, evaluate by rule.
        return [$self CallRule $rule eval $gdict]
    }



    # CallRule rule args
    #
    # rule   - A rule name
    # args   - method name and arguments.
    #
    # Executes the rule and returns the result.

    method CallRule {rule args} {
        set o [dict get $::projectlib::gofer::rules($name) $rule]
        return [$o {*}$args]
    }

    # blank
    #
    # Creates an empty value of this type.

    method blank {} {
        return [dict create _type $name _rule ""]
    }

    #-------------------------------------------------------------------
    # Rule constructors
    
    delegate method * using {%s UnknownSubcommand %m}

    # UnknownSubcommand rule args..
    #
    # rule    - An unknown subcommand; presumably a rule name. 
    #           For convenience, convert it to upper case.
    #
    # Calls the constructor for the rule type.

    method UnknownSubcommand {rule args} {
        set rule [string toupper $rule]

        if {$rule ni [$self rules]} {
            error "Unknown rule: \"$rule\""
        }

        return [dict merge \
            [dict create _type $name _rule $rule] \
            [$self CallRule $rule construct {*}$args]]
    }

    #-------------------------------------------------------------------
    # Other Private Methods

    # SanityCheck
    #
    # Does a sanity check of this gofer, verifying that the 
    # gofer(i) requirements are met, and that the ruledict and
    # formspec are consistent.
    #
    # This check is usually called by [gofer check], which is 
    # intended to be used by the Athena test suite.
    #
    # NOTE: We could do all of these checks on creation, but don't
    # mostly because it would require that the rule objects are
    # loaded before the gofers, whereas the modules are
    # easier to read if it's the other way around.

    method SanityCheck {} {
        # FIRST, get the current array of rules
        array set rules $::projectlib::gofer::rules($name)

        # NEXT, verify that the dynaform begins with a _type field
        # and a _rule selector.
        lassign [dynaform fields $form] first second

        require {$first eq "_type"} \
            "gofer's first field is \"$first\", expected \"_type\""

        require {$second eq "_rule"} \
            "gofer's first explicit field is \"$second\", expected \"_rule\""

        if {[catch {
            set cases [dynaform cases $form _rule {}] 
        } result]} {
            error "gofer's _rule field isn't a selector"
        }

        # NEXT, verify that every rule has a case and vice versa.
        foreach rule [array names rules] {
            require {$rule in $cases} \
                "gofer's form has no case for rule \"$rule\""
        }

        foreach case $cases {
            require {[info exists rules($case)]} \
                "gofer has no rule matching form case \"$case\""
        }

        # NEXT, for each rule verify that the case fields match the 
        # rule keys.
        foreach rule [array names rules] {
            set fields [GetCaseFields $form $rule]

            foreach key [$rules($rule) keys] {
                require {$key in $fields} \
                    "rule $rule's key \"$key\" has no form field"
            }

            foreach field $fields {
                require {$field in [$rules($rule) keys]} \
                    "rule $rule's field $field matches no rule key"
            }
        }
    }    
    
    # GetCaseFields ftype case
    #
    # ftype - A form type
    # case  - A _rule case
    #
    # Returns the names of the fields defined for the given case, walking
    # down the tree as needed.

    proc GetCaseFields {ftype case} {
        # FIRST, get the ID of the _rule field
        set ri [GetRuleItem $ftype]

        # NEXT, get the case items
        set items [dict get [dynaform item $ri cases] $case]

        set fields [list]

        foreach id $items {
            GetFieldNames fields $id
        }

        return $fields
    }

    # GetRuleItem ftype
    #
    # ftype  - A form type
    #
    # Retrieves the ID of the rule item for that form type.

    proc GetRuleItem {ftype} {
        foreach id [dynaform allitems $ftype] {
            set dict [dynaform item $id]

            if {[dict get $dict itype] eq "selector" &&
                [dict get $dict field] eq "_rule"
            } {
                return $id 
            }
        }

        # This should already have been checked.
        error "No _rule selector"
    }

    # GetFieldNames listvar id
    #
    # listvar   - Name of a list to receive the field names
    # id        - An item ID
    #
    # If the ID is a field, adds its name to the list.
    # If it is a selector field, recurses.

    proc GetFieldNames {listvar id} {
        upvar 1 $listvar fields

        set dict [dynaform item $id]

        if {[dict exists $dict field]} {
            lappend fields [dict get $dict field]
        }

        if {[dict get $dict itype] in {selector when}} {
            set casedict [dict get $dict cases]
            foreach case [dict keys $casedict] {
                foreach cid [dict get $dict cases $case] {
                    GetFieldNames fields $cid
                }
            }
        }
    }

}


