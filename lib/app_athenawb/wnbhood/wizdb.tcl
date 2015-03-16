#-----------------------------------------------------------------------
# FILE: wizdb.tcl
#
#   WDB Module: in-memory SQLite database.
#
# PACKAGE:
#   wnbhood(n) -- package for athena(1) nbhood ingestion wizard.
#
# PROJECT:
#   Athena Regional Stability Simulation
#
# AUTHOR:
#   Dave Hanks
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# wizdb
#
# wnbhood(n) RDB I/F
#
# This module is responsible for creating an in-memory SQLite3 data
# store and making it available to the application.

snit::type ::wnbhood::wizdb {
    #-------------------------------------------------------------------
    # Type Variables

    # SQL schema

    typevariable schema {
        CREATE TABLE polygons (
            -- Polygon ID, must be unique across all polygon IDs
            pid        TEXT PRIMARY KEY,

            -- ID assigned automatically upon read from whatever source
            id         INTEGER,

            -- File name from which polygon was read
            fname      TEXT,

            -- The name of the polygon, could be the empty string or NULL
            name       TEXT,

            -- The display name of the polygon, this is assigned to it 
            dispname   TEXT,

            -- List of any children that are embedded inside this polygon
            children   TEXT,

            -- The parent, if any, of this polygon
            parent     TEXT,

            -- The list of coordinates, normally a flat list of lat/long
            -- pairs
            polygon    TEXT
        );
    }
    #-------------------------------------------------------------------
    # Components

    component db  ;# sqldocument(n)

    #-------------------------------------------------------------------
    # constructor

    # constructor
    #
    # Initializes the wdb, which prepares the data structures.
    
    constructor {} {
        install db using sqldocument ${type}::db \
            -rollback off

        $db open :memory:

        $db eval $schema
    }

    destructor {
        catch {$db destroy}
    }

    #-------------------------------------------------------------------
    # Public Methods
    
    delegate method * to db

}





