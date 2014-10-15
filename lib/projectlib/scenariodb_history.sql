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

-- The following tables are used to save time series variable data
-- for plotting, etc.  Each table has a name like "history_<vartype>"
-- where <vartype> is a time series variable type.  In some cases,
-- one table might contain multiple variables; in that case it will
-- be named after the primary one.

CREATE TABLE hist_sat (
    -- History: sat.g.c
    case_id  INTEGER DEFAULT 0,
    t        INTEGER,
    g        TEXT,
    c        TEXT,
    sat      DOUBLE, -- Current level of satisfaction
    base     DOUBLE, -- Baseline level of satisfaction
    nat      DOUBLE, -- Natural level of satisfaction

    PRIMARY KEY (case_id,t,g,c)
);

-- mood.g
CREATE TABLE hist_mood (
    case_id  INTEGER DEFAULT 0,
    t        INTEGER,
    g        TEXT,
    mood     DOUBLE,

    PRIMARY KEY (case_id,t,g)
);

-- nbmood.n
CREATE TABLE hist_nbmood (
    case_id  INTEGER DEFAULT 0,
    t        INTEGER,
    n        TEXT,
    nbmood   DOUBLE,

    PRIMARY KEY (case_id,t,n)
);

-- coop.f.g
CREATE TABLE hist_coop (
    -- History: coop.f.g
    case_id  INTEGER DEFAULT 0,
    t        INTEGER,
    f        TEXT,
    g        TEXT,
    coop     DOUBLE, -- Current level of cooperation
    base     DOUBLE, -- Baseline level of cooperation
    nat      DOUBLE, -- Natural level of cooperation

    PRIMARY KEY (case_id,t,f,g)
);

-- nbcoop.n.g
CREATE TABLE hist_nbcoop (
    case_id  INTEGER DEFAULT 0,
    t        INTEGER,
    n        TEXT,
    g        TEXT,
    nbcoop   DOUBLE,

    PRIMARY KEY (case_id,t,n,g)
);

-- econ
CREATE TABLE hist_econ (
    case_id     INTEGER DEFAULT 0,
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

    PRIMARY KEY (case_id,t)
);

-- econ.i
CREATE TABLE hist_econ_i (
    case_id     INTEGER DEFAULT 0,
    t           INTEGER,
    i           TEXT,
    p           DOUBLE,
    qs          DOUBLE,
    rev         DOUBLE,

    PRIMARY KEY (case_id,t,i)
);

-- econ.i.j
CREATE TABLE hist_econ_ij (
    case_id     INTEGER DEFAULT 0,
    t           INTEGER,
    i           TEXT,
    j           TEXT,
    x           DOUBLE,
    qd          DOUBLE,

    PRIMARY KEY (case_id,t,i,j)        
);

-- control.n.a
CREATE TABLE hist_control (
    case_id  INTEGER DEFAULT 0,
    t        INTEGER,
    n        TEXT, -- Neighborhood
    a        TEXT, -- Actor controlling neighborhood n, or NULL if none.

    PRIMARY KEY (case_id,t,n)
);

-- security.n.g
CREATE TABLE hist_security (
    case_id  INTEGER DEFAULT 0,
    t        INTEGER,
    n        TEXT,     -- Neighborhood
    g        TEXT,     -- Group
    security INTEGER,  -- g's security in n.

    PRIMARY KEY (case_id,t,n,g)
);

-- support.n.a
CREATE TABLE hist_support (
    case_id        INTEGER DEFAULT 0,
    t              INTEGER,
    n              TEXT,    -- Neighborhood
    a              TEXT,    -- Actor
    direct_support REAL,    -- a's direct support in n
    support        REAL,    -- a's total support (direct + derived) in n
    influence      REAL,    -- a's influence in n

    PRIMARY KEY (case_id,t,n,a)
);

-- volatility.n.a
CREATE TABLE hist_volatility (
    case_id        INTEGER DEFAULT 0,
    t              INTEGER,
    n              TEXT,    -- Neighborhood
    volatility     INTEGER, -- Volatility of n

    PRIMARY KEY (case_id,t,n)
);

CREATE TABLE hist_hrel (
    -- History: hrel.f.g
    case_id  INTEGER DEFAULT 0,
    t        INTEGER,
    f        TEXT,    -- First group
    g        TEXT,    -- Second group
    hrel     REAL,    -- Horizontal relationship of f with g.
    base     REAL,    -- Base Horizontal relationship of f with g.
    nat      REAL,    -- Natural Horizontal relationship of f with g.

    PRIMARY KEY (case_id,t,f,g)
);

CREATE TABLE hist_vrel (
    -- History: vrel.g.a
    case_id  INTEGER DEFAULT 0,
    t        INTEGER,
    g        TEXT,    -- Civilian group
    a        TEXT,    -- Actor
    vrel     REAL,    -- Vertical relationship of g with a.
    base     REAL,    -- Base Vertical relationship of g with a.
    nat      REAL,    -- Natural Vertical relationship of g with a.

    PRIMARY KEY (case_id,t,g,a)
);

CREATE TABLE hist_pop (
    -- History: pop.g (civilian group population)
    case_id     INTEGER DEFAULT 0,
    t           INTEGER,
    g           TEXT,       -- Civilian group
    population  INTEGER,    -- Population
    
    PRIMARY KEY (case_id,t,g)
);

CREATE TABLE hist_npop (
    -- History: pop.n (civilian neighborhood population)
    case_id     INTEGER DEFAULT 0,
    t           INTEGER,
    n           TEXT,      -- Neighborhood
    population  INTEGER,   -- Population

    PRIMARY KEY (case_id,t,n)
);

CREATE TABLE hist_flow (
    -- History: flow.f.g (population flow from f to g)
    -- This table is sparse; only positive flows are included.
    -- Unlike the other tables, it is not saved by [hist], but
    -- by [demog].
    case_id INTEGER DEFAULT 0,
    t       INTEGER,
    f       TEXT,
    g       TEXT,
    flow    INTEGER DEFAULT 0,
    
    PRIMARY KEY (case_id,t,f,g)
);

CREATE TABLE hist_service_g (
    -- History: service.g (amount of ENI service by g)
    case_id INTEGER DEFAULT 0,

    t INTEGER,
    g TEXT,
    saturation_funding REAL,
    required           REAL,
    funding            REAL,
    actual             REAL,
    expected           REAL,
    expectf            REAL,
    needs              REAL,

    PRIMARY KEY (case_id,t,g)
);


------------------------------------------------------------------------
-- End of File
------------------------------------------------------------------------
