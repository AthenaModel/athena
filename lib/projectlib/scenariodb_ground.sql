------------------------------------------------------------------------
-- TITLE:
--    scenariodb_ground.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema for scenariodb(n): Ground Area
--
-- SECTIONS:
--    Personnel and Related Statistics
--    Situations
--    Attrition
--    Services
--
------------------------------------------------------------------------

------------------------------------------------------------------------
-- PERSONNEL AND RELATED STATISTICS 

-- FRC and ORG personnel in playbox.
CREATE TABLE personnel_g (
    -- Symbolic group name
    g          TEXT PRIMARY KEY
               REFERENCES groups(g)
               ON DELETE CASCADE
               DEFERRABLE INITIALLY DEFERRED,

    -- Personnel in playbox
    personnel  INTEGER DEFAULT 0
);

-- Deployment Table: FRC and ORG personnel deployed into neighborhoods.
CREATE TABLE deploy_ng (
    -- Symbolic neighborhood name
    n              TEXT REFERENCES nbhoods(n)
                   ON DELETE CASCADE
                   DEFERRABLE INITIALLY DEFERRED,

    -- Symbolic group name
    g              TEXT REFERENCES groups(g)
                   DEFERRABLE INITIALLY DEFERRED,

    -- Personnel
    personnel     INTEGER DEFAULT 0,

    -- Unassigned personnel.
    unassigned    INTEGER DEFAULT 0,
    
    PRIMARY KEY (n,g)
);

-- Deployment Table: FRC and ORG personnel deployed into neighborhoods,
-- by deploying tactic.  This table is used to implement non-reinforcing
-- deployments.
CREATE TABLE deploy_tng (
    tactic_id  INTEGER,               -- DEPLOY tactic
    n          TEXT,                  -- Neighborhood
    g          TEXT,                  -- FRC/ORG group
    personnel  INTEGER DEFAULT 0,     -- Personnel currently deployed

    -- A single tactic can deploy one group to one or more neighborhoods.
    PRIMARY KEY (tactic_id, n)
);

-- Index so that attrition is efficient.
CREATE INDEX deploy_tng_index ON deploy_tng(n,g);

---------------------------------------------------------------------
-- Attrition Model Tables

-- Battle table for AAM: tracks designated personnel,
-- postures and casualties

CREATE TABLE aam_battle (
    -- Nbhood ID
    n          TEXT,

    -- Force group IDs of combatants
    f          TEXT,
    g          TEXT,

    -- The number of hours of combat remaining in the current week
    -- between f and g
    hours_left   DOUBLE DEFAULT 0.0,

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

    PRIMARY KEY (n, f, g)
);


-- General unit data
CREATE TABLE units (
    -- Symbolic unit name
    u                TEXT PRIMARY KEY,

    -- Tactic ID, or NULL if this is a base unit.
    -- NOTE: There is no FK reference because the unit can outlive the
    -- tactic that created it.  A unit is associated with at most one
    -- tactic.
    tactic_id        INTEGER UNIQUE,

    -- Active flag: 1 if active, 0 otherwise.  A unit is active if it
    -- is currently scheduled.
    active           INTEGER,

    -- Neighborhood to which unit is deployed
    n                TEXT,

    -- Group to which the unit belongs
    g                TEXT,

    -- Group type
    gtype            TEXT,

    -- Unit activity: eactivity(n) value, or NONE if this is a base unit
    a                TEXT,

    -- Total Personnel
    personnel        INTEGER DEFAULT 0,

    -- Location, in map coordinates, within n
    location         TEXT,

    -- Attrition Flag: 1 if the unit is about to be attrited.
    attrit_flag      INTEGER DEFAULT 0
);

CREATE INDEX units_ngap_index ON
units(n,g,a,personnel);

-- Units view, for display
CREATE VIEW units_view AS
SELECT U.u               AS u,
       U.active          AS active,
       U.g               AS g,
       u.gtype           AS gtype,
       U.personnel       AS personnel,
       U.a               AS a,
       U.location        AS location,
       G.color           AS color
FROM units AS U JOIN groups AS G USING (g);

------------------------------------------------------------------------
-- STANCE

CREATE TABLE stance_fg (
    -- Contains the stance (designated relationship) of force group f
    -- toward group g, as specified by a STANCE tactic.  Rows exist only
    -- when stance has been explicitly set.

    f      TEXT,    -- Force group f
    g      TEXT,    -- Other group g

    stance DOUBLE,  -- stance.fg

    PRIMARY KEY (f,g)
);

CREATE TABLE stance_nfg (
    -- Contains neighborhood-specific overrides to stance.fg.  This table
    -- was used to override stance when group f was directed attack 
    -- group g in a neighborhood; at present, there are no overrides.
    -- However, since the mechanism is known to work it seemed better
    -- to retain it for now.

    n      TEXT,    -- Neighborhood n
    f      TEXT,    -- Force group f
    g      TEXT,    -- Other group g

    stance DOUBLE,  -- stance.nfg

    PRIMARY KEY (n,f,g)
);

-- stance_nfg_view:  Group f's stance toward g in n.  Defaults to 
-- hrel.fg.  The default can be overridden by an explicit stance, as
-- contained in stance_fg, and that can be overridden by neighborhood,
-- as contained in stance_nfg.
CREATE VIEW stance_nfg_view AS
SELECT N.n                                           AS n,
       F.g                                           AS f,
       G.g                                           AS g,
       coalesce(SN.stance,S.stance,UH.hrel)          AS stance,
       CASE WHEN SN.stance IS NOT NULL THEN 'OVERRIDE'
            WHEN S.stance  IS NOT NULL THEN 'ACTOR'
            ELSE 'DEFAULT' END                       AS source
FROM nbhoods   AS N
JOIN frcgroups AS F
JOIN groups    AS G
LEFT OUTER JOIN stance_nfg AS SN ON (SN.n=N.n AND SN.f=F.g AND SN.g=G.g)
LEFT OUTER JOIN stance_fg  AS S  ON (S.f=F.g AND S.g=G.g)
LEFT OUTER JOIN uram_hrel  AS UH ON (UH.f=F.g AND UH.g=G.g);

------------------------------------------------------------------------
-- FORCE AND SECURITY STATISTICS

-- nbstat Table: Total Force and Volatility in neighborhoods
CREATE TABLE force_n (
    -- Symbolic nbhood name
    n                   TEXT    PRIMARY KEY,

    -- Criminal suppression in neighborhood. This is the fraction of 
    -- civilian criminal activity that is suppressed by law enforcement
    -- activities.
    suppression         DOUBLE DEFAULT 0.0,

    -- Total force in nbhood, including nearby.
    total_force         INTEGER DEFAULT 0,

    -- Gain on volatility, a multiplier >= 0.0
    volatility_gain     DOUBLE  DEFAULT 1.0,

    -- Nominal Volatility, excluding gain, 0 to 100
    nominal_volatility  INTEGER DEFAULT 0,

    -- Effective Volatility, including gain, 0 to 100
    volatility          INTEGER DEFAULT 0,

    -- Average Civilian Security
    security            INTEGER DEFAULT 0
);

-- nbstat Table: Group force in neighborhoods
CREATE TABLE force_ng (
    n             TEXT,              -- Symbolic nbhood name
    g             TEXT,              -- Symbolic group name

    personnel     INTEGER DEFAULT 0, -- Group's personnel
    own_force     INTEGER DEFAULT 0, -- Group's own force (Q.ng)
    crim_force    INTEGER DEFAULT 0, -- Civ group's criminal force.
                                     -- 0.0 for non-civ groups.
    noncrim_force INTEGER DEFAULT 0, -- Group's own force, less criminals
    local_force   INTEGER DEFAULT 0, -- own_force + friends in n
    local_enemy   INTEGER DEFAULT 0, -- enemies in n
    force         INTEGER DEFAULT 0, -- own_force + friends nearby
    pct_force     INTEGER DEFAULT 0, -- 100*force/total_force
    enemy         INTEGER DEFAULT 0, -- enemies nearby
    pct_enemy     INTEGER DEFAULT 0, -- 100*enemy/total_force
    security      INTEGER DEFAULT 0, -- Group's security in n

    PRIMARY KEY (n, g)
);

-- nbstat Table: Civilian group statistics
CREATE TABLE force_civg (
    g          TEXT PRIMARY KEY,   -- Symbolic civ group name
    nominal_cf DOUBLE DEFAULT 0.0, -- Nominal Criminal Fraction
    actual_cf  DOUBLE DEFAULT 0.0  -- Actual Criminal Fraction
);


-- Note that "a" is constrained to match g's gtype, as indicated
-- in the temporary activity_gtype table.
CREATE TABLE activity_nga (
    n                   TEXT,     -- Symbolic nbhoods name
    g                   TEXT,     -- Symbolic groups name
    a                   TEXT,     -- Symbolic activity name
         
    -- 1 if there's enough security to conduct the activity,
    -- and 0 otherwise.
    security_flag       INTEGER  DEFAULT 0,

    -- 1 if the group can do the activity in the neighborhood,
    -- and 0 otherwise.
    can_do              INTEGER  DEFAULT 0,

    -- Number of personnel in nbhood n belonging to 
    -- group g which are assigned activity a.
    nominal             INTEGER  DEFAULT 0,

    -- Number of the nominal personnel that are effectively performing
    -- the activity.  This will be 0 if security_flag is 0.
    effective           INTEGER  DEFAULT 0,

    -- Coverage fraction, 0.0 to 1.0, for this activity.
    coverage            DOUBLE   DEFAULT 0.0,

    PRIMARY KEY (n,g,a)
);


------------------------------------------------------------------------
-- ABSTRACT SITUATIONS

CREATE TABLE absits (
    -- Abstract Situations

    -- Situation ID
    s         INTEGER PRIMARY KEY,
 
    -- Situation type (this is also the driver type)
    stype     TEXT,

    -- Neighborhood in which the situation exists
    n         TEXT REFERENCES nbhoods(n)
                   ON DELETE CASCADE
                   DEFERRABLE INITIALLY DEFERRED,

    -- Coverage: fraction of neighborhood affected.
    coverage  DOUBLE DEFAULT 1.0,

    -- Inception Flag: 1 if this is a new situation, and inception 
    -- effects should be assessed, and 0 otherwise.  (This will be set 
    -- to 0 for situations that are on-going at time 0.)
    inception INTEGER,

    -- Resolving group: name of the group that resolved/will resolve
    -- the situation, or 'NONE'
    resolver  TEXT DEFAULT 'NONE',

    -- Auto-resolution duration: 0 if the situation will not auto-resolve,
    -- and a duration in ticks otherwise.
    rduration INTEGER DEFAULT 0,

    -- State: esitstate
    state     TEXT DEFAULT 'INITIAL',

    -- Start Time, in ticks
    ts        INTEGER,

    -- Resolution time, in ticks; null if unresolved and not auto-resolving.
    tr        INTEGER,

    -- Location, in map coordinates -- for visualization only.
    location  TEXT
);

------------------------------------------------------------------------
-- SERVICES

-- NOTE: At present, there is only one kind of service,
-- Essential Non-Infrastructure (ENI).  When we add other services,
-- these tables may change considerably.

-- Service Group/Actor table: provision of service to a civilian
-- group by an actor.

CREATE TABLE service_ga (
    -- Civilian Group ID
    g            TEXT REFERENCES civgroups(g) 
                      ON DELETE CASCADE
                      DEFERRABLE INITIALLY DEFERRED,

    -- Actor ID
    a            TEXT REFERENCES actors(a)
                      ON DELETE CASCADE
                      DEFERRABLE INITIALLY DEFERRED,

    -- Funding, $/week (symbol: F.ga)
    funding      REAL DEFAULT 0.0,

    -- Credit, 0.0 to 1.0.  The fraction of unsaturated service
    -- provided by this actor.
    credit       REAL DEFAULT 0.0,

    PRIMARY KEY (g,a)
);

-- Service Table: level of services s experienced by civilian groups g

CREATE TABLE service_sg (
    -- Service ID; eg. ENI, ENERGY...
    s                   TEXT,

    -- Civilian Group ID
    g                   TEXT REFERENCES civgroups(g) 
                             ON DELETE CASCADE
                             DEFERRABLE INITIALLY DEFERRED,

    -- Saturation funding, $/week
    saturation_funding  REAL DEFAULT 0.0,

    -- Required level of service, fraction of saturation
    -- (from parmdb)
    required            REAL DEFAULT 0.0,

    -- Funding, $/week
    funding             REAL DEFAULT 0.0,

    -- Actual level of service, fraction of saturation
    actual              REAL DEFAULT 0.0,

    -- New actual level of service, for abstract services
    new_actual          REAL DEFAULT 0.0,

    -- Expected level of service, fraction of saturation
    expected            REAL DEFAULT 0.0,

    -- Expectations Factor: measures degree to which expected exceeds
    -- actual (or vice versa) for use in ENI rule set.
    expectf             REAL DEFAULT 0.0,

    -- Needs Factor: measures degree to which actual exceeds required
    -- (or vice versa) for use in ENI rule set.
    needs               REAL DEFAULT 0.0,

    PRIMARY KEY (s,g)
);

------------------------------------------------------------------------
-- End of File
------------------------------------------------------------------------

