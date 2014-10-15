#-----------------------------------------------------------------------
# TITLE:
#    urlquery.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Athena: Tools for manipulating my:// URL query strings
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Export public commands

namespace eval ::projectlib:: {
    namespace export urlquery
}

#-----------------------------------------------------------------------
# urlquery

snit::type ::projectlib::urlquery {
    pragma -hasinstances no

    # fromdict dict
    #
    # dict   - A query parameter dictionary
    #
    # Given a dictionary of parameter names and values, creates
    # a URL query string, e.g., from
    #
    #    a 1 b 2
    #
    # creates 
    #
    #    a=1+b=2
    #
    # Neither names nor values may contain "=" or "+"; however, this
    # is not checked.  If a value is the empty string, the "=" is omitted.
    #
    # TBD: Ideally, we should probably convert spaces in the values.

    typemethod fromdict {dict} {
        set list ""

        dict for {parm value} $dict {
            if {$value ne ""} {
                lappend list "$parm=$value"
            } else {
                lappend list $parm
            }
        }

        return [join $list "+"]
    }

    # todict query
    #
    # query     - A URL query string, e.g., a=1+b=2
    #
    # Converts the query string into a parameter dictionary.  It is assumed
    # that the names and parameters do not contain = or +.  If a name has
    # no corresponding =, the name goes in the dictionary with an empty
    # value.  If a name has multiple ='s, the second and subsequent are
    # ignored.

    typemethod todict {query} {
        # FIRST, split the query on "+"
        set items [split $query "+"]

        # NEXT, handle each one individually.
        set qdict [dict create]

        foreach item $items {
            lassign [split $item "="] parm value

            dict set qdict $parm $value
        }

        return $qdict
    }

    # get query parmlist
    #
    # query     - A URL query string, e.g., a=1+b=2
    # parmlist  - A list of parameter names.  Names may have default values,
    #             as with the [proc] command.
    #
    # Converts the query string into a parameter dictionary, limiting the
    # dictionary to those parameters named in the parmlist.  Parameters
    # not included in the query string get default values.

    typemethod get {query parmlist} {
        # FIRST, initialize the query dictionary.
        set result [dict create]
        foreach pair $parmlist {
            lassign $pair parm value
            dict set result $parm $value
        }

        # NEXT, parse the query
        set qdict [$type todict $query]

        # NEXT, merge the values, only for those parms that are defined.
        dict for {parm value} $qdict {
            if {[dict exists $result $parm]} {
                dict set result $parm $value
            }
        }

        return $result
    }

}


