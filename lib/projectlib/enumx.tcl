#-----------------------------------------------------------------------
# TITLE:
#	enumx.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#   projectlib(n) module: enumx objects
#
#   An enumx is an object that defines an enumerated type: a list of
#   symbolic names.  Each symbolic name can have any number of 
#   equivalent forms, which should generally be unique.  The enumx
#   can convert a name to any equivalent.
#    
#   Note that an enumx object does not store individual values;
#   rather, it defines the set of values for the enum.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export Public Commands

namespace eval ::projectlib:: {
    namespace export enumx
}

#-----------------------------------------------------------------------
# enumx

oo::class create ::projectlib::enumx {
    #-------------------------------------------------------------------
    # Instance variables:

    # Definition Dictionary.  The keys are enumerated symbols ("names").
    # The values are dictionaries of alternate forms by form name,
    # e.g., long names.
    variable defdict

    #-------------------------------------------------------------------
    # Constructor

    # constructor def ?custom?
    #
    # def - A definition dictionary.
    # custom - An oo::objdefine customization script
    
    constructor {def {custom ""}} {
        # Allow custom code to access ::marsutil
        namespace import ::marsutil::*

        set defdict [dict create]

        my add $def

        if {$custom ne ""} {
            oo::objdefine [self] $custom
        }
    }

    #-------------------------------------------------------------------
    # Public Methods

    # add def
    #
    # def - A partial definition dictionary, to be merged.
    #
    # Add new values to the definition dictionary.  This can be
    # entirely new symbols, or new equivalents.

    method add {def} {
        dict for {name equivs} $def {
            if {![dict exists $defdict $name]} {
                dict set defdict $name [dict create]
            }
            dict for {form equiv} $equivs {
                dict set defdict $name $form $equiv
            }
        }
    }

    # validate name
    #
    # name - Possibly, a valided enuemrated name.
    #
    # Validates that the name is a valid enum value, ignoring case.  If it is, 
    # the name is returned with its canonical case; 
    # otherwise an error is thrown.
    
    method validate {name} {
        set ndx [my Input2index $name]

        if {$ndx == -1} {

            set list [join [my names] ", "]
            return -code error -errorcode INVALID \
                "invalid value \"$name\", should be one of: $list"
        } 
            
        return [lindex [my names] $ndx]
    }

    # Input2Index name
    #
    # name - Possibly, an enumerated name.
    #
    # Does a case-insensitive lookup of the name, returning its index in
    # the keys.  If not found, returns -1.

    method Input2index {name} {
        return [lsearch -exact -nocase [dict keys $defdict] $name]
    }

    # index name
    #
    # Retrieve the index corresponding to the name.
    # Returns -1 if the name is not recognized.
    method index {name} {
        my Input2index $name
    }

    # names
    #
    # Returns a list of the enumerated names.

    method names {} {
        return [dict keys $defdict]
    }

    # forms
    #
    # A list of the equivalent forms provided by this type.

    method forms {} {
        set result [dict create]

        dict for {name equiv} $defdict {
            set result [dict merge $result $equiv]
        }

        return [dict keys $result]
    }

    # size
    #
    # Returns the number of symbols in the enumeration.
    method size {} {
        dict size $defdict
    }

    # defdict
    #
    # Returns the enum's definition dictionary 

    method defdict {} {
        return $defdict
    }

    # as form name
    #
    # Retrieve the equivalent form corresponding to the name, or "" if 
    # there's no match.  The name must be in canonical form.

    method as {form name} {
        if {[dict exists $defdict $name $form]} {
            return [dict get $defdict $name $form]
        } else {
            return ""
        }
    }

    # aslist form
    #
    # Returns a list of the equivalents of the given form.  If a name
    # has no equivalent of the given form, returns "" is used.

    method aslist {form} {
        set result [list]

        dict for {name equivs} $defdict {
            if {[dict exists $equivs $form]} {
                lappend result [dict get $equivs $form]
            } else {
                lappend result ""
            }
        }

        return $result
    }

    # asdict form
    #
    # Returns a dictionary of names and equivalents for the given
    # form.  If a name has no equivalent of the given form, "" 
    # is used.

    method asdict {form} {
        set result [dict create]

        dict for {name equiv} $defdict {
            if {[dict exists $equiv $form]} {
                dict set result $name [dict get $equiv $form]
            } else {
                dict set result $name ""
            }
        }

        return $result
    }

    # html
    #
    # Returns a snippet of HTML suitable for inclusion in a man page.

    method html {} {
        set forms [my forms]

        append out \
            "<table>\n"                        \
            "<tr>\n"                           \
            "<th align=\"right\">Index</th>\n" \
            "<th align=\"left\">Name</th>\n" 

        foreach form $forms {
            append out \
                "<th align=\"left\">$form</th>\n" 
        }

        append out \
            "</tr>\n"

        set i -1
        dict for {name equiv} $defdict {
            append out \
                "<tr>\n"                                                       \
                "<td valign=\"baseline\" align=\"center\">[incr i]</td>\n"     \
                "<td valign=\"baseline\" align=\"left\"><tt>$name</tt></td>\n"

            foreach form $forms {
                set e [my as $form $name]
                append out \
                    "<td valign=\"baseline\" align=\"left\"><tt>$e</tt></td>\n"
            }

            append out \
                "</tr>\n"
        }

        append out "</table>\n"

        return $out
    } 

}





