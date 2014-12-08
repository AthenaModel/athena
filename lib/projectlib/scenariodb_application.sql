------------------------------------------------------------------------
-- TITLE:
--    scenariodb_application.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema for scenariodb(n): Application Tables
--
-- SECTIONS:
--    Scenario Management
--    Orders
--    Significant Events
--    Maps
--
------------------------------------------------------------------------

------------------------------------------------------------------------
-- SCENARIO MANAGEMENT

CREATE TABLE saveables (
    -- Saveables Table: saves saveable(i) data.  I.e., this table contains
    -- checkpoints of in-memory data for specific objects.

    saveable   TEXT PRIMARY KEY,
    checkpoint TEXT
);

CREATE TABLE beans (
    -- Beans Table: Saves all bean(n) objects, by beanpot.
    --
    -- Note that a beanpot is a saveable; the bean data is saved to this
    -- table as part of [$pot checkpoint] and restored as part of 
    -- [$pot restore].  DO NOT QUERY THIS TABLE AT RUN-TIME, AS THE
    -- DATA MAY BE OBSOLETE.  IT IS ONLY GUARANTEED TO BE RIGHT IN THE
    -- .adb!

    dbid        TEXT,     -- The bean pot's ID in the app.
    id          INTEGER,  -- The bean's unique ID
    bean_class  TEXT,     -- The bean's beanclass, e.g., ::tactic
    bean_dict   TEXT      -- Dictionary of the bean's instance vars
);

CREATE TABLE snapshots (
    -- Snapshots Table: saves scenario snapshots.  In Athena 5 and
    -- prior, this table held a snapshot for each time at which
    -- the simulation entered the RUNNING state, as well as an
    -- on-lock snapshot.  As of Athena 6, it holds only the
    -- on-lock snapshot.

    -- Time tick at which the snapshot was saved; -1 is the
    -- on-lock checkpoint.
    tick     INTEGER PRIMARY KEY,

    -- TCL-serialized text of the snapshot.
    snapshot TEXT
);


------------------------------------------------------------------------
-- ORDERS


CREATE TABLE cif (
    -- Critical Input Table: Saves user orders and (temporarily) any
    -- undo information.

    -- Unique ID; used for ordering
    id        INTEGER PRIMARY KEY,

    -- Simulation time at which the order was entered.
    time      INTEGER DEFAULT 0,

    -- Kind of entry: order | start | end
    kind      TEXT default 'order',

    -- Order name
    name      TEXT default '',

    -- Order narrative
    narrative TEXT default '',

    -- Parameter Dictionary
    parmdict  TEXT default '',

    -- Undo Script, or ''
    undo      TEXT DEFAULT '',

    -- Redo Helper Script, or ''
    redo      TEXT DEFAULT ''
);

CREATE INDEX cif_index ON cif(time,id);



------------------------------------------------------------------------
-- SIGNIFICANT EVENTS LOG

CREATE TABLE sigevents (
    -- These two tables store significant simulation events, and allow
    -- events to be tagged with zero or more entities.

    -- Used for sorting
    event_id   INTEGER PRIMARY KEY,
    t          INTEGER,               -- Time stamp, in ticks
    level      INTEGER DEFAULT 1,     -- level of importance, -1 to N
    component  TEXT,                  -- component/model logging the event
    narrative  TEXT                   -- Event narrative.
);

CREATE TABLE sigevent_tags (
    -- Tags table.  Individual events can be tagged with 0 or more tags;
    -- this information can later be used to display tailored logs, e.g.,
    -- events involving a particular neighborhood or actor.

    event_id INTEGER REFERENCES sigevents(event_id)
                     ON DELETE CASCADE
                     DEFERRABLE INITIALLY DEFERRED,

    tag      TEXT,

    PRIMARY KEY (event_id, tag)
);

CREATE VIEW sigevents_view AS
SELECT *
FROM sigevents JOIN sigevent_tags USING (event_id);


------------------------------------------------------------------------
-- MAPS

CREATE TABLE maps (
    -- Maps Table: Stores data for map images.
    --
    -- At this time, there's never more than one map image in the table.
    -- The map with id=1 is the map to use.

    -- ID
    id        INTEGER PRIMARY KEY,

    -- Original file name of this map
    filename  TEXT,

    -- projection type eprojtype enumx(n)
    projtype  INTEGER DEFAULT 'REF',
    
    -- Width and Height, in pixels
    width     INTEGER,
    height    INTEGER,

    -- Projection options, used for maps that have projection 
    -- metadata 
    proj_opts TEXT DEFAULT '',

    -- Map data: a BLOB of data in "jpeg" format.
    data      BLOB
);

------------------------------------------------------------------------
-- BOOKMARKS

CREATE TABLE bookmarks (
    -- Detail Browser bookmarks.
    bookmark_id INTEGER PRIMARY KEY,
    url         TEXT,
    title       TEXT,
    rank        INTEGER  -- Used to order bookmarks in Bookmarks Manager
);

------------------------------------------------------------------------
-- EXECUTIVE SCRIPTS

CREATE TABLE scripts (
    -- Scripts Table: Executive scripts, maintained as part of the
    -- scenario.  Scripts are identified by name.  Scripts with
    -- the auto flag set (auto=1) are executed automatically on
    -- executive reset, in order of their sequence numbers.  Other
    -- scripts can be executed on demand.
    
    name     TEXT PRIMARY KEY,
    seq      INTEGER,
    auto     INTEGER DEFAULT 0,
    body     TEXT DEFAULT ''
);


------------------------------------------------------------------------
-- End of File
------------------------------------------------------------------------


