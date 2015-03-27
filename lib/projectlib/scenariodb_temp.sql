------------------------------------------------------------------------
-- TITLE:
--    scenariodb_temp.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Temporary Entity Schema for scenariodb(n).
--
------------------------------------------------------------------------


------------------------------------------------------------------------
-- Concerns and concern views

-- Concern definitions
CREATE TEMPORARY TABLE concerns (
    -- Symbolic concern name
    c         TEXT PRIMARY KEY,

    -- Full concern name
    longname  TEXT,

    -- Concern type: egrouptype
    gtype     TEXT
);

CREATE TEMPORARY VIEW civ_concerns AS
SELECT * FROM concerns WHERE gtype='CIV';

CREATE TEMPORARY VIEW org_concerns AS
SELECT * FROM concerns WHERE gtype='ORG';


--------------------------------------------------------------------
-- Activity Definition Tables

-- Main activity table.  Lists all activity names and long names
CREATE TEMPORARY TABLE activity (
    -- Symbolic activity name
    a         TEXT PRIMARY KEY,

    -- Human-readable name
    longname  TEXT
);

-- Activity/group type table.
CREATE TEMPORARY TABLE activity_gtype (
    -- Symbolic activity name
    a            TEXT,

    -- Symbolic group type: FRC or ORG
    gtype        TEXT,

    -- Assignable: 1 or 0
    assignable   INTEGER DEFAULT 0,

    PRIMARY KEY (a, gtype)
);

--------------------------------------------------------------------
-- Abstract Infrastructure Services

CREATE TEMPORARY TABLE abservice (
    -- Symbolic abstract service name
    s        TEXT PRIMARY KEY,

    -- Human readable name
    longname TEXT
);

--------------------------------------------------------------------
-- Saturation/Required Service funding levels

CREATE TEMPORARY TABLE sr_service (
    g            TEXT,              -- Group name
    req_funding  REAL DEFAULT 0.0,  -- Required Funding Level $/week
    sat_funding  REAL DEFAULT 0.0,  -- Saturation Funding Level $/week

    PRIMARY KEY (g)
);

--------------------------------------------------------------------
-- Strategy Tock Working Tables

-- Actor's Working Cash
CREATE TEMPORARY TABLE working_cash (
    -- Symbolic actor name
    a           TEXT PRIMARY KEY,

    -- Money saved for later, in $.
    cash_reserve DOUBLE,

    -- Income/strategy tock, in $.
    income      DOUBLE,

    -- Money available to be spent, in $.
    -- Unspent cash accumulates from tock to tock.
    cash_on_hand DOUBLE,

    -- gifts from other actors, in $.  Gifts are unavailable
    -- to be spent until the next strategy execution.
    gifts        DOUBLE DEFAULT 0
);

-- FRC and ORG personnel in playbox and available for deployment.
CREATE TEMPORARY TABLE working_personnel (
    -- Symbolic group name
    g          TEXT PRIMARY KEY,

    -- Personnel in playbox
    personnel  INTEGER,

    -- Personnel available for deployment
    available  INTEGER
);

-- working_supports table: Actor supported by Actor a in n.

CREATE TEMPORARY TABLE working_supports (
    -- Symbolic group name
    n         TEXT,

    -- Symbolic actor name
    a         TEXT,

    -- Supported actor name, or NULL
    supports  TEXT,

    PRIMARY KEY (n, a)
);


-- Deployment Table: FRC and ORG personnel deployed into neighborhoods.
CREATE TEMPORARY TABLE working_deployment (
    -- Symbolic neighborhood name
    n          TEXT,

    -- Symbolic group name
    g          TEXT,

    -- Personnel
    personnel  INTEGER DEFAULT 0,

    -- Unassigned personnel.
    unassigned INTEGER DEFAULT 0,
    
    PRIMARY KEY (n,g)
);

-- Working Service Group/Actor table: funding for service to the group
-- by the actor.

CREATE TEMPORARY TABLE working_service_ga (
    -- Civilian Group ID
    g            TEXT,

    -- Actor ID
    a            TEXT,

    -- Funding, $/week (symbol: F.ga)
    funding      REAL DEFAULT 0.0,

    PRIMARY KEY (g,a)
);


--------------------------------------------------------------------
-- Temporary Infrastructure Tables

-- Working Construction table for Infrastructure: tracks the progress
-- of construction as BUILD tactics execute by nbhood and actor

CREATE TEMPORARY TABLE working_build (
    -- Nbhood ID
    n         TEXT,
    
    -- Actor ID
    a         TEXT,

    -- List of pairs (current, delta)
    -- Each pair tracks construction level of one infrastructure plant
    progress  TEXT,

    PRIMARY KEY (n, a)
);

---------------------------------------------------------------------
-- Temporary Attrition Model Tables

-- Working force table for AAM: tracks designated personnel,
-- postures and casualties

CREATE TEMPORARY TABLE working_force (
    -- Nbhood ID
    n          TEXT,

    -- Force group IDs of combatants
    f          TEXT,
    g          TEXT,

    -- ROE of f to g and g to f
    roe_f      TEXT,
    roe_g      TEXT,

    -- Posture f takes wrt to g and g takes wrt f
    posture_f  TEXT,
    posture_g  TEXT,

    -- Total personnel and those designated in fight 
    pers_f     INTEGER DEFAULT 0,
    pers_g     INTEGER DEFAULT 0,
    dpers_f    INTEGER DEFAULT 0,
    dpers_g    INTEGER DEFAULT 0,

    -- Casualties suffered by f and g
    cas_f      INTEGER DEFAULT 0,
    cas_g      INTEGER DEFAULT 0,

    -- The number of hours of combat remaining in the current week
    -- between f and g
    hours_left   DOUBLE DEFAULT 0.0,

    PRIMARY KEY (n, f, g)
);

