------------------------------------------------------------------------
-- TITLE:
--    scenariodb_politics.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema for scenariodb(n): Politics Area
--
-- SECTIONS:
--    Support, Influence, and Control
--    Goals, Tactics, and Conditions
--
------------------------------------------------------------------------

------------------------------------------------------------------------
-- SUPPORT, INFLUENCE, AND CONTROL

-- supports_na table: Actor supported by Actor a in n.

CREATE TABLE supports_na (
    -- Symbolic group name
    n         TEXT REFERENCES nbhoods(n)
              ON DELETE CASCADE
              DEFERRABLE INITIALLY DEFERRED,

    -- Symbolic actor name
    a         TEXT REFERENCES actors(a)
              ON DELETE CASCADE
              DEFERRABLE INITIALLY DEFERRED,

    -- Supported actor name, or NULL
    supports  TEXT REFERENCES actors(a)
              ON DELETE CASCADE
              DEFERRABLE INITIALLY DEFERRED,

    PRIMARY KEY (n, a)
);


-- support_nga table: Support for actor a by group g in nbhood n

CREATE TABLE support_nga (
    -- Symbolic group name
    n                TEXT REFERENCES nbhoods(n)
                     ON DELETE CASCADE
                     DEFERRABLE INITIALLY DEFERRED,

    -- Symbolic group name
    g                TEXT REFERENCES groups(g)
                     ON DELETE CASCADE
                     DEFERRABLE INITIALLY DEFERRED,

    -- Symbolic actor name
    a                TEXT REFERENCES actors(a)
                     ON DELETE CASCADE
                     DEFERRABLE INITIALLY DEFERRED,

    -- Vertical Relationship of g with a
    vrel             REAL DEFAULT 0.0,

    -- g's personnel in n
    personnel        INTEGER DEFAULT 0,

    -- g's security in n
    security         INTEGER DEFAULT 0,

    -- Direct Contribution of g to a's support in n
    direct_support   REAL DEFAULT 0.0,

    -- Actual Contribution of g to a's support in n,
    -- given a's support of other actors, and other actor's support
    -- of a.
    support          REAL DEFAULT 0.0,

    -- Contribution of g to a's influence in n.
    -- (support divided total support in n)
    influence        REAL DEFAULT 0.0,

    PRIMARY KEY (n, g, a)
);


-- influence_na table: Actor's influence in neighborhood.
--
-- Note: We don't cascade deletions, as this table is populated only
-- during simulation, when the referenced entities aren't being deleted.

CREATE TABLE influence_na (
    -- Symbolic group name
    n                TEXT REFERENCES nbhoods(n)
                     ON DELETE CASCADE
                     DEFERRABLE INITIALLY DEFERRED,

    -- Symbolic actor name
    a                TEXT REFERENCES actors(a)
                     ON DELETE CASCADE
                     DEFERRABLE INITIALLY DEFERRED,

    -- Direct Support for a in n
    direct_support   REAL DEFAULT 0.0,

    -- Actual Support for a in n, including direct support and support
    -- from other actors's followers.
    support          REAL DEFAULT 0.0,

    -- Influence of a in n
    influence        REAL DEFAULT 0.0,

    PRIMARY KEY (n, a)
);

-- control_n table: Control of neighborhood n

CREATE TABLE control_n (
    -- Symbolic group name
    n          TEXT PRIMARY KEY
               REFERENCES nbhoods(n)
               ON DELETE CASCADE
               DEFERRABLE INITIALLY DEFERRED,

    -- Actor controlling n, or NULL.
    controller TEXT REFERENCES actors(a)
               ON DELETE CASCADE
               DEFERRABLE INITIALLY DEFERRED,

    -- Time at which controller took control
    since      INTEGER DEFAULT 0
);


------------------------------------------------------------------------
-- AGENTS

-- An agent is an entity that can own a strategy.  In theory, any
-- kind of entity can be an agent.  At present there are two kinds, actors
-- and the SYSTEM.

CREATE VIEW agents AS
SELECT 'SYSTEM' AS agent_id, 'system' AS agent_type
UNION
SELECT a        AS agent_id, 'actor'  AS agent_type  FROM actors;



------------------------------------------------------------------------
-- ACTOR EXPENDITURES

CREATE TABLE expenditures (
    -- The actor
    a   TEXT PRIMARY KEY,

    -- The expenditures at the current time step
    goods  REAL default 0.0,
    black  REAL default 0.0,
    pop    REAL default 0.0,
    actor  REAL default 0.0,
    region REAL default 0.0,
    world  REAL default 0.0,

    -- The total expenditures up to the current time step
    tot_goods  REAL default 0.0,
    tot_black  REAL default 0.0,
    tot_pop    REAL default 0.0,
    tot_actor  REAL default 0.0,
    tot_region REAL default 0.0,
    tot_world  REAL default 0.0
);

------------------------------------------------------------------------
-- End of File
------------------------------------------------------------------------
