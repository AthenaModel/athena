#-----------------------------------------------------------------------
# TITLE:
#    compdb.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Scenario Comparison Parameters
#
#-----------------------------------------------------------------------

namespace eval ::athena:: {
    namespace export compdb
}


#-------------------------------------------------------------------
# parm

snit::type ::athena::compdb {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Components

    typecomponent ps ;# parmset(n)

    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        snit::double  dlimit -min 0.0
        snit::integer ilimit -min 0
    }

    #-------------------------------------------------------------------
    # Type Variables

    typevariable compdbFile user.compdb
    

    #-------------------------------------------------------------------
    # Public Type Methods

    delegate typemethod cget       to ps
    delegate typemethod configure  to ps
    delegate typemethod docstring  to ps
    delegate typemethod get        to ps
    delegate typemethod getdefault to ps
    delegate typemethod items      to ps
    delegate typemethod names      to ps
    delegate typemethod manlinks   to ps
    delegate typemethod manpage    to ps
    delegate typemethod save       to ps

    #-------------------------------------------------------------------
    # Initialization

    # init
    #
    # Initializes the database.

    typemethod init {} {
        # Initialize only once
        if {$ps ne ""} {
            return
        }

        # FIRST, create and initialize parmset(n)
        set ps [parmset %AUTO%]    

        # main
        $ps subset primary {
            Comparison parameters that are at the highest level of output
            variables.
        } 

        $ps subset primary.a {
            Significance multipliers for the highest level output variables.
            Nominally 1.0, these are used to adjust each outputs significance. 
        }      

        foreach varclass [lsort [info commands ::athena::vardiff::*]] {
            set vartype [namespace tail $varclass]

            $ps subset $vartype \
                "Comparison parameters for variables of type $vartype."

            $ps define $vartype.active ::snit::boolean yes {
                If yes, we look for significant differences in 
                variables of this type; and if not, not.
            }

            if {[$varclass primary]} {
                $ps define primary.a.$vartype ::projectlib::rgain 1.0 "
                    Significance multiplier for output variables of type 
                    $vartype. Setting it to 0.0 makes outputs of this type
                    completely insignificant.
                "
            }

            if {[llength [$varclass inputTypes]]} {
                $ps subset $vartype.a "
                    Significance multipliers for input variables to variables 
                    of type $vartype.  Nominally 1.0, these are used to adjust
                    the significance of the various inputs to each output. 
                "

                foreach input [$varclass inputTypes] {
                    $ps define $vartype.a.$input ::projectlib::rgain 1.0 "
                        The significance multiplier for inputs of type $input to
                        variables of type $vartype. Setting it to 0.0 makes inputs 
                        of this type completely insignificant.
                    "
                }
            }
        }
    }

 
    #-------------------------------------------------------------------
    # Queries

    # validate parm
    #
    # parm     - A parameter name
    #
    # Validates parm as a parameter name.  Returns the name.

    typemethod validate {parm} {
        set canonical [$type names $parm]

        if {$canonical ni [$type names]} {
            return -code error -errorcode INVALID \
                "Unknown comparison parameter: \"$parm\""
        }

        # Return it in canonical form
        return $canonical
    }

    # nondefaults ?pattern?
    #
    # Returns a list of the parameters with non-default values.

    typemethod nondefaults {{pattern ""}} {
        if {$pattern eq ""} {
            set parms [$type names]
        } else {
            set parms [$type names $pattern]
        }

        set result [list]

        foreach parm $parms {
            if {[$type get $parm] ne [$type getdefault $parm]} {
                lappend result $parm
            }
        }

        return $result
    }

    # set parm value
    #
    # parm   A parameter name
    # value  A value
    #
    # Sets the parms value, and save the compdb

    typemethod set {parm value} {
        $ps set $parm $value 
        $type SaveCompDB
    }

    # reset
    #
    # Resets the compdb parameters and saves the result

    typemethod reset {} {
        $ps reset
        $type SaveCompDB
    }

    # list ?pattern?
    #
    # pattern  - A glob pattern
    #
    # Lists all compdb parameters with their values, or those matching the
    # pattern.  If none are found, throws an error.

    typemethod list {{pattern *}} {
        set result [$ps list $pattern]

        if {$result eq ""} {
            error "No matching parameters"
        }

        return $result
    }

    # import filename
    #
    # filename   The name of a compdb(5) parameter file
    #
    # Imports the named file and saves the imported parms as user prefs.

    typemethod import {filename} {
        $ps load $filename
        $type SaveCompDB
    }

    # load
    #
    # Loads the parameters safely from the compdbFile, if it exists.

    typemethod load {} {
        if {[file exists [prefsdir join $compdbFile]]} {
            $ps load [prefsdir join $compdbFile] -safe
        }
    }

    # SaveCompDB 
    #
    # Saves the compdb but only if prefdir is initialized

    typemethod SaveCompDB {} {
        if {[prefsdir initialized]} {
            $ps save [prefsdir join $compdbFile]
        }
    }
}

