------------------------------------------------------------------------
-- TITLE:
--    scenariodb_infrastructure.sql
--
-- AUTHOR:
--    Dave Hanks
--
-- DESCRIPTION:
--    SQL Schema for scenariodb(n): Infrastructure Tables
--
-- SECTIONS:
--
------------------------------------------------------------------------

------------------------------------------------------------------------
-- INFRASTRUCTURE

-- Plants Table: plants owned and operated by actors.  Each plant has
-- a capacity to produce goods.  Taken together, the output of all plants
-- is the total capacity of goods produced in the modeled economy.

CREATE TABLE plants_na (
    -- Neighborhood ID
    n                TEXT,

    -- Agent ID, can be actor ID or 'SYSTEM'
    a                TEXT,

    -- Number of plants in operation by agent a in in nbhood n
    num              INTEGER DEFAULT 0,

    -- Average repair level of all plants in operation by agent a in nbhood n
    rho              REAL DEFAULT 1.0,

    PRIMARY KEY (n, a)
);

-- Plants Shares: during prep the analyst specifies which actors get some
-- number of shares of the total infrastructure along with the initial
-- repair levels.

CREATE TABLE plants_shares (
    -- Neighborhood ID
    n               TEXT REFERENCES nbhoods(n)
                    ON DELETE CASCADE
                    DEFERRABLE INITIALLY DEFERRED,

    -- Agent ID, can be actor ID or 'SYSTEM'
    a               TEXT,

    -- The number of shares of plants in the nbhood that the
    -- agent owns
    num             INTEGER DEFAULT 1,

    -- Average repair level of all plants in operation by agent a in
    -- nbhood n. The defaul level is fully repaired.
    rho             REAL DEFAULT 1.0,

    PRIMARY KEY (n, a)
);

-- Plants under construction: during strategy execution an agent may 
-- use the BUILD tactic to build new infrastructure, this table tracks
-- the progress of that construction

CREATE TABLE plants_build (
    -- Neighborhood ID
    n              TEXT,

    -- Agent ID
    a              TEXT,

    -- List of build levels of plants under construction, numbers
    -- between 0.0 and 1.0
    levels         TEXT,

    -- Number of plants currently under construction by nbhood and actor
    num            INTEGER DEFAULT 0,

    PRIMARY KEY (n,a)
);

-- Plants neighborhood view. Used during prep and initialization to 
-- determine how infrastructure plants are distributed among the 
-- neighborhoods as a function of total neighborhood population and
-- production capacity.

CREATE VIEW plants_n_view AS
SELECT N.n                                     AS n,
       N.pcf                                   AS pcf,
       total(
        CASE C.sa_flag WHEN 0
            THEN coalesce(D.consumers,C.basepop)
            ELSE 0.0 END
       )                                       AS nbpop
FROM civgroups          AS C
JOIN local_nbhoods      AS N USING (n)
LEFT OUTER JOIN demog_n AS D USING (n)
GROUP BY n;

-- Plants allocation view. Used during prep by appserver pages to give
-- an estimate of the breakdown of goods production plants in 
-- neighborhoods by neighborhood and agent.

CREATE VIEW plants_alloc_view AS
SELECT N.n                     AS n,
       N.pcf                   AS pcf,
       coalesce(PS.a,'SYSTEM') AS a,
       coalesce(PS.num,1)      AS shares,
       coalesce(PS.rho,1.0)    AS rho
FROM local_nbhoods AS N
LEFT OUTER JOIN plants_shares AS PS USING (n);

------------------------------------------------------------------------
-- End of File
------------------------------------------------------------------------


