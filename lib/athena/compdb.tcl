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

namespace eval :: {
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

        foreach varclass [lsort [info commands ::athena::vardiff::*]] {
            set vartype [namespace tail $varclass]

            $ps subset $vartype \
                "Comparison parameters for variables of type $vartype."

            $ps define $vartype.active ::snit::boolean yes {
                If yes, we look for significant differences in 
                variables of this type; and if not, not.
            }

        }

        # bsysmood
        $ps define bsysmood.limit ::athena::compdb::dlimit 20.0 {
            Significant difference limit: minimum 
            absolute difference, in satisfaction points.
        }

        # bsyssat
        $ps define bsyssat.limit ::athena::compdb::dlimit 25.0 {
            Significant difference limit: minimum absolute
            difference, in satisfaction points.
        }

        # control
        # None yet

        # drivermood
        $ps define drivermood.limit ::athena::compdb::dlimit 5.0 {
            Significant difference limit: minimum absolute
            difference, in satisfaction points.
        }

        # driversat
        $ps define driversat.limit ::athena::compdb::dlimit 5.0 {
            Significant difference limit: minimum absolute
            difference, in satisfaction points.
        }

        # gdp
        $ps define gdp.limit ::athena::compdb::dlimit 20.0 {
            Significant difference limit: minimum absolute percentage
            change, in percentage points.
        }

        # goodscap
        $ps define goodscap.limit ::athena::compdb::dlimit 20.0 {
            Significant difference limit: minimum absolute percentage
            change, in percentage points.
        }

        # mood
        $ps define mood.limit ::athena::compdb::dlimit 20.0 {
            Significant difference limit: minimum absolute
            difference, in satisfaction points.
        }

        # nbinfluence
        # None yet

        # nbmood
        $ps define nbmood.limit ::athena::compdb::dlimit 15.0 {
            Significant difference limit: minimum absolute
            difference, in satisfaction points.
        }

        # nbsat
        $ps define nbsat.limit ::athena::compdb::dlimit 20.0 {
            Significant difference limit: minimum absolute
            difference, in satisfaction points.
        }

        # nbsecurity
        $ps define nbsecurity.limit ::athena::compdb::ilimit 20 {
            Significant difference limit: minimum absolute
            difference, in security points.
        }

        # nbunemp
        $ps define nbunemp.limit ::athena::compdb::dlimit 4.0 {
            Significant difference limit: minimum absolute
            difference, in percentage points.
        }

        # pbmood
        $ps define pbmood.limit ::athena::compdb::dlimit 10.0 {
            Significant difference limit: minimum absolute
            difference, in satisfaction points.
        }

        # pbsat
        $ps define pbsat.limit ::athena::compdb::dlimit 15.0 {
            Significant difference limit: minimum absolute
            difference, in satisfaction points.
        }

        # population
        $ps define population.limit ::athena::compdb::dlimit 5.0 {
            Significant difference limit: minimum absolute
            percentage change, in percentage points.
        }

        # sat
        $ps define sat.limit ::athena::compdb::dlimit 25.0 {
            Significant difference limit: minimum absolute
            difference, in satisfaction points.
        }

        # support
        $ps define support.limit ::athena::compdb::dlimit 5.0 {
            Significant difference limit: minimum absolute
            percentage change, in percentage points.
        }

        # unemp
        $ps define unemp.limit ::athena::compdb::dlimit 4.0 {
            Significant difference limit: minimum absolute
            difference, in percentage points.
        }

        # vrel
        $ps define vrel.limit ::athena::compdb::dlimit 0.2 {
            Significant difference limit: minimum absolute
            difference, as a relationship value.
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

