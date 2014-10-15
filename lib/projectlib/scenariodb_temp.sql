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

