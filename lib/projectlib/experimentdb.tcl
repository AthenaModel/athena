#-----------------------------------------------------------------------
# TITLE:
#    experimentdb.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Athena Experiment Database Object
#
#    This module defines the experimentdb type.  Instances of the 
#    experimentdb type manage SQLite3 database files which contain 
#    experiment data for athena_sim(1).
#
#    The application will use experimentdb(n) to create and manage
#    external .axdb files.
#
#    experimentdb(n) is both a wrapper for sqldocument(n) and an
#    sqlsection(i) defining new database entities.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export experimentdb
}

#-----------------------------------------------------------------------
# scenario

snit::type ::projectlib::experimentdb {
    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        namespace import ::marsutil::*
    }

    #-------------------------------------------------------------------
    # Type Variables


    #-------------------------------------------------------------------
    # sqlsection(i)
    #
    # The following variables and routines implement the module's 
    # sqlsection(i) interface.

    # sqlsection title
    #
    # Returns a human-readable title for the section

    typemethod {sqlsection title} {} {
        return "experimentdb(n)"
    }

    # sqlsection schema
    #
    # Returns the section's persistent schema definitions, if any.

    typemethod {sqlsection schema} {} {
        foreach filename {
            experimentdb.sql
            scenariodb_history.sql
        } {
            append out [readfile [file join $::projectlib::library $filename]]
        }

        return $out
    }

    # sqlsection tempschema
    #
    # Returns the section's temporary schema definitions, if any.

    typemethod {sqlsection tempschema} {} {
        return {}
    }

    # sqlsection tempdata
    # 
    # Returns the section's temporary data

    typemethod {sqlsection tempdata} {} {
        return {}
    }

    # sqlsection functions
    #
    # Returns a dictionary of function names and command prefixes

    typemethod {sqlsection functions} {} {
        return {}
    }

    #-------------------------------------------------------------------
    # Components

    component db                         ;# The sqldocument(n).

    #-------------------------------------------------------------------
    # Constructor
    
    constructor {args} {
        # FIRST, create the sqldocument, naming it so that it
        # will be automatically destroyed.  We don't want
        # automatic transaction batching.
        set db [sqldocument ${selfns}::db         \
                    -subject   $self              \
                    -autotrans off                \
                    -rollback  on]

        # NEXT, pass along any other options
        $db configurelist $args

        # NEXT, register the schema sections
        $db register $type
    }

    #-------------------------------------------------------------------
    # Public Methods

    # Delegated methods
    delegate method * to db
}





