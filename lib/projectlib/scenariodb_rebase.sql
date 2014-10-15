------------------------------------------------------------------------
-- TITLE:
--    scenariodb_rebase.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema for scenariodb(n): Simulation Rebase Support
--
------------------------------------------------------------------------

-- The following tables are used to save data in support of Athena's
-- "simulation rebase" capability.

CREATE TABLE rebase_sat (
    -- Satisfaction levels from time t-1.
    g       TEXT,
    c       TEXT,
    current DOUBLE, -- Current level of satisfaction

    PRIMARY KEY (g,c)
);

CREATE TABLE rebase_hrel (
    -- Horizontal relationships from time t-1.
    f       TEXT,    -- First group
    g       TEXT,    -- Second group
    current REAL,    -- Horizontal relationship of f with g.

    PRIMARY KEY (f,g)
);

CREATE TABLE rebase_vrel (
    -- Vertical relationships from time t-1.
    g       TEXT,    -- Civilian group
    a       TEXT,    -- Actor
    current REAL,    -- Vertical relationship of g with a.

    PRIMARY KEY (g,a)
);

------------------------------------------------------------------------
-- End of File
------------------------------------------------------------------------
