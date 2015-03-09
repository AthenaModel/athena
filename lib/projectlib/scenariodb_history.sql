------------------------------------------------------------------------
-- TITLE:
--    scenariodb_history.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema for scenariodb(n): Simulation History
--
-- These tables are used by both scenariodb(n) and experimentdb(n).  In
-- scenariodb(n), the case_id column is always 0.  In experimentdb(n),
-- the results of multiple cases are saved by setting case_id to the
-- case index, which runs from 1 to N.
--
------------------------------------------------------------------------

-- The following tables contain simulation history data for
-- "after-action analysis".  The tables are grouped by index; e.g.,
-- the hist_civg table contains civilian group outputs over time.

CREATE TABLE hist_nbhood (
    -- History: Neighborhood outputs
    t          INTEGER,
    n          TEXT,       -- Neighborhood name

    a          TEXT,       -- Name of actor controlling n, or NULL if none 
    nbmood     DOUBLE,     -- Neighborhood mood
    volatility INTEGER,    -- Volatility of neighborhood
    population INTEGER,    -- Civilian population of neighborhood
    security   INTEGER,    -- Average civilian security in neighborhood

    PRIMARY KEY (t,n)
);

CREATE VIEW hist_control    AS SELECT t, n, a          FROM hist_nbhood;
CREATE VIEW hist_nbmood     AS SELECT t, n, nbmood     FROM hist_nbhood;
CREATE VIEW hist_volatility AS SELECT t, n, volatility FROM hist_nbhood;
CREATE VIEW hist_npop       AS SELECT t, n, population FROM hist_nbhood;


-- The following tables are used to save time series variable data
-- for plotting, etc.  Each table has a name like "history_<vartype>"
-- where <vartype> is a time series variable type.  In some cases,
-- one table might contain multiple variables; in that case it will
-- be named after the primary one.

CREATE TABLE hist_sat (
    -- History: sat.g.c
    t        INTEGER,
    g        TEXT,
    c        TEXT,
    sat      DOUBLE, -- Current level of satisfaction
    base     DOUBLE, -- Baseline level of satisfaction
    nat      DOUBLE, -- Natural level of satisfaction

    PRIMARY KEY (t,g,c)
);

-- mood.g
CREATE TABLE hist_mood (
    t        INTEGER,
    g        TEXT,
    mood     DOUBLE,

    PRIMARY KEY (t,g)
);

-- coop.f.g
CREATE TABLE hist_coop (
    -- History: coop.f.g
    t        INTEGER,
    f        TEXT,
    g        TEXT,
    coop     DOUBLE, -- Current level of cooperation
    base     DOUBLE, -- Baseline level of cooperation
    nat      DOUBLE, -- Natural level of cooperation

    PRIMARY KEY (t,f,g)
);

-- nbcoop.n.g
CREATE TABLE hist_nbcoop (
    t        INTEGER,
    n        TEXT,
    g        TEXT,
    nbcoop   DOUBLE,

    PRIMARY KEY (t,n,g)
);

-- econ
CREATE TABLE hist_econ (
    t           INTEGER,
    consumers   INTEGER,
    subsisters  INTEGER,
    labor       INTEGER,
    lsf         DOUBLE,
    csf         DOUBLE,
    rem         DOUBLE,
    cpi         DOUBLE,
    dgdp        DOUBLE,
    ur          DOUBLE,

    PRIMARY KEY (t)
);

-- econ.i
CREATE TABLE hist_econ_i (
    t           INTEGER,
    i           TEXT,
    p           DOUBLE,
    qs          DOUBLE,
    rev         DOUBLE,

    PRIMARY KEY (t,i)
);

-- econ.i.j
CREATE TABLE hist_econ_ij (
    t           INTEGER,
    i           TEXT,
    j           TEXT,
    x           DOUBLE,
    qd          DOUBLE,

    PRIMARY KEY (t,i,j)        
);


-- security.n.g
CREATE TABLE hist_security (
    t        INTEGER,
    n        TEXT,     -- Neighborhood
    g        TEXT,     -- Group
    security INTEGER,  -- g's security in n.

    PRIMARY KEY (t,n,g)
);

-- support.n.a
CREATE TABLE hist_support (
    t              INTEGER,
    n              TEXT,    -- Neighborhood
    a              TEXT,    -- Actor
    direct_support REAL,    -- a's direct support in n
    support        REAL,    -- a's total support (direct + derived) in n
    influence      REAL,    -- a's influence in n

    PRIMARY KEY (t,n,a)
);


CREATE TABLE hist_hrel (
    -- History: hrel.f.g
    t        INTEGER,
    f        TEXT,    -- First group
    g        TEXT,    -- Second group
    hrel     REAL,    -- Horizontal relationship of f with g.
    base     REAL,    -- Base Horizontal relationship of f with g.
    nat      REAL,    -- Natural Horizontal relationship of f with g.

    PRIMARY KEY (t,f,g)
);

CREATE TABLE hist_vrel (
    -- History: vrel.g.a
    t        INTEGER,
    g        TEXT,    -- Civilian group
    a        TEXT,    -- Actor
    vrel     REAL,    -- Vertical relationship of g with a.
    base     REAL,    -- Base Vertical relationship of g with a.
    nat      REAL,    -- Natural Vertical relationship of g with a.

    PRIMARY KEY (t,g,a)
);

CREATE TABLE hist_pop (
    -- History: pop.g (civilian group population)
    t           INTEGER,
    g           TEXT,       -- Civilian group
    population  INTEGER,    -- Population
    
    PRIMARY KEY (t,g)
);

CREATE TABLE hist_flow (
    -- History: flow.f.g (population flow from f to g)
    -- This table is sparse; only positive flows are included.
    -- Unlike the other tables, it is not saved by [hist], but
    -- by [demog].
    t       INTEGER,
    f       TEXT,
    g       TEXT,
    flow    INTEGER DEFAULT 0,
    
    PRIMARY KEY (t,f,g)
);

CREATE TABLE hist_service_sg (
    -- History: service.sg (amount of service s to group g)

    t INTEGER,
    s TEXT,
    g TEXT,
    saturation_funding REAL,
    required           REAL,
    funding            REAL,
    actual             REAL,
    expected           REAL,
    expectf            REAL,
    needs              REAL,

    PRIMARY KEY (t,g,s)
);

CREATE TABLE hist_activity_nga (
    -- History: activity.nga (activity by nbhood and group)

    t        INTEGER,
    n        TEXT,
    g        TEXT,
    a        TEXT,
    security_flag INTEGER,
    can_do        INTEGER,
    nominal       INTEGER,
    effective     INTEGER,
    coverage      DOUBLE,
    
    PRIMARY KEY (t,n,g,a)
);


------------------------------------------------------------------------
-- End of File
------------------------------------------------------------------------
