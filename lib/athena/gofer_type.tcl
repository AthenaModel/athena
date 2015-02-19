#-----------------------------------------------------------------------
# TITLE:
#    gofer_type.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Gofer Types
#
#    A gofer_type is a manager for a collection of gofer_rules.  See 
#    gofer.tcl for details.
#
#-----------------------------------------------------------------------

snit::type ::athena::gofer_type {
    #-------------------------------------------------------------------
    # Instance Variables

    variable adb   ;# The athenadb(n) object
    variable name  ;# The type name
    variable noun  ;# The noun for the returned item or items
    variable form  ;# Name of the type's dynaform.

    variable rules ;# Dictionary of rule instances by rule name.

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_ name_ noun_ formspec_ ruledict_
    #
    # adb_      - The athenadb(n) instance
    # name_     - The type name
    # noun_     - The noun 
    # form_     - A dynaform name
    # ruledict_ - An array of rule classes by rule name. 
    #
    # Creates the gofer_type.

    constructor {adb_ name_ noun_ form_ ruledict_} {
        # FIRST, save the data
        set adb  $adb_
        set name $name_
        set noun $noun_
        set form $form_

        # NEXT, create the rules.
        dict for {rule cls} $ruledict_ {
            set rules($rule) [$cls new $adb_]
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * using {%s call %m}

    # call rulename args...
    #
    # rulename   - A rule name for this type.
    # args...    - Method and arguments to pass to it.

    method call {rulename args} {
        set rulename [string toupper $rulename]

        return [$rules($rulename) {*}$args]        
    }

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
        return [lsort [array names rules]]
    }

    # keys rule
    #
    # rule   - A rule name
    #
    # Returns the gdict keys for the given rule.

    method keys {rule} {
        set rule [string toupper $rule]
        require {$rule in [array names rules]} "Unknown rule: \"$rule\""
        return [$rules($rule) keys]
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
        set typename [::athena::goferx GetType $name INVALID $gdict]

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

        if {$rule ni [array names rules]} {
            throw INVALID "Unknown rule: \"$rule\""
        }

        # NEXT, make sure it's got all needed keys for the rule
        set stub [dict create]
        foreach key [$rules($rule) keys] {
            dict set stub $key ""
        }
        set gdict [dict merge $stub $gdict]

        # NEXT, validate the remainder of the gdict according to the
        # rule.
        return [dict merge $out [$rules($rule) validate $gdict]]
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
        if {![::athena::goferx GotType $gdict] ||
            [dict get $gdict _type] ne $name} {
            set gdict [$self blank]
        }

        # NEXT, make sure there's a _rule.
        if {![dict exists $gdict _rule]} {
            dict set gdict _rule ""
        }

        set rule [dict get $gdict _rule]

        # NEXT, if we don't know it, that's an error.
        if {$rule eq "" || $rule ni [array names rules]} {
            if {$noun ne ""} {
                return "$noun ???"
            } else {
                return "???"
            }
        }

        # NEXT, call the rule
        return [$rules($rule) narrative $gdict $opt]
    }

    # eval gdict
    #
    # gdict   - A valid gdict
    #
    # Evaluates the gdict and returns a list of civilian groups.

    method eval {gdict} {
        set typename [::athena::goferx GetType $name NONE $gdict]

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
        } elseif {$rule ni [array name rules]} {
            error "Unknown rule: \"$rule\""
        }

        # NEXT, evaluate by rule.
        return [$rules($rule) eval $gdict]
    }

    # blank
    #
    # Creates an empty value of this type.

    method blank {} {
        return [dict create _type $name _rule ""]
    }


    # make rule args..
    #
    # rule    - A a rule name. 
    #           For convenience, convert it to upper case.
    #
    # Calls the constructor for the rule type.

    method make {rule args} {
        set rule [string toupper $rule]

        if {$rule ni [$self rules]} {
            error "Unknown rule: \"$rule\""
        }

        return [dict merge \
            [dict create _type $name _rule $rule] \
            [$rules($rule) make {*}$args]]
    }

    # dump
    #
    # Dumps debugging info.

    method dump {} {
        foreach rule [$self rules] {
            puts "$rule:"
            puts "    obj:  $rules($rule)"
            puts "    keys: [$rules($rule) keys]"
        }
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
        # FIRST, verify that the dynaform begins with a _type field
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

