#-----------------------------------------------------------------------
# FILE: wizdb.tcl
#
#   WDB Module: in-memory SQLite database.
#
# PACKAGE:
#   wintel(n) -- package for athena(1) intel ingestion wizard.
#
# PROJECT:
#   Athena Regional Stability Simulation
#
# AUTHOR:
#    Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# wizdb
#
# wintel(n) RDB I/F
#
# This module is responsible for creating an in-memory SQLite3 data
# store and making it available to the application.

snit::type ::wintel::wizdb {
    #-------------------------------------------------------------------
    # Type Variables

    # SQL schema

    typevariable schema {
        CREATE TABLE messages (
            -- TIGR Messages retrieved from the data source.

            -- TIGR Fields
            cid        TEXT PRIMARY KEY,
            title      TEXT,    -- Message title
            desc       TEXT,    -- Message description
            start_str  TEXT,    -- start time as string
            end_str    TEXT,    -- end time as string
            start      INTEGER, -- unix timestamp of start time
            end        INTEGER, -- unix timestamp of end time
            tz         TEXT,    -- time zone: +/-hhmm
            locs       TEXT,    -- list of lat/long pairs

            -- Derived Fields
            week   TEXT,    -- Julian week(n) string
            t      INTEGER, -- Simulation week number
            n      TEXT     -- Neighborhood ID
        );

        CREATE TABLE cid2etype (
            -- Mapping from TIGR event IDs to simevent type names.
            cid    TEXT,  -- TIGR ID
            etype  TEXT,  -- Event type name

            PRIMARY KEY (cid, etype)
        );


        -- Event Ingestion Views
        CREATE VIEW ingest_view AS
        SELECT n                                       AS n,
               t                                       AS t,
               etype                                   AS etype,
               '-n'       || ' ' || n    || ' ' || 
               '-t'       || ' ' || t    || ' ' || 
               '-week'    || ' ' || week || ' ' ||
               '-cidlist' || ' ' || cid                AS optlist 
        FROM messages
        JOIN cid2etype USING (cid);


        -- TBD: The purpose of having all of these individual views is 
        -- that a sim event type might have distinguishing
        -- attributes in addition to n and t.  At present, none do; 
        -- and we might be able to avoid them in the long run.  In that
        -- case, the ingestion code can simply use ingest_view 
        -- directly.

        CREATE VIEW ingest_ACCIDENT AS
        SELECT * FROM ingest_view
        WHERE etype = 'ACCIDENT'
        ORDER BY n, t;

        CREATE VIEW ingest_CIVCAS AS
        SELECT * FROM ingest_view
        WHERE etype = 'CIVCAS'
        ORDER BY n, t;

        CREATE VIEW ingest_DEMO AS
        SELECT * FROM ingest_view
        WHERE etype = 'DEMO'
        ORDER BY n, t;

        CREATE VIEW ingest_DROUGHT AS
        SELECT * FROM ingest_view
        WHERE etype = 'DROUGHT'
        ORDER BY n, t;

        CREATE VIEW ingest_EXPLOSION AS
        SELECT * FROM ingest_view
        WHERE etype = 'EXPLOSION'
        ORDER BY n, t;

        CREATE VIEW ingest_FLOOD AS
        SELECT * FROM ingest_view
        WHERE etype = 'FLOOD'
        ORDER BY n, t;

        CREATE VIEW ingest_RIOT AS
        SELECT * FROM ingest_view
        WHERE etype = 'RIOT'
        ORDER BY n, t;

        CREATE VIEW ingest_TRANSPORT AS
        SELECT * FROM ingest_view
        WHERE etype = 'TRANSPORT'
        ORDER BY n, t;

        CREATE VIEW ingest_VIOLENCE AS
        SELECT * FROM ingest_view
        WHERE etype = 'VIOLENCE'
        ORDER BY n, t;
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





