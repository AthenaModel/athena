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

    typevariable initialized 0
    

    #-------------------------------------------------------------------
    # Initialization

    # init
    #
    # Initializes the database.

    typemethod init {} {
        if {$initialized} {
            return
        }
        set initialized 1

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
    # Public Type Methods

    delegate typemethod * to ps

 
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
}

