------------------------------------------------------------------------
-- TITLE:
--    scenariodb_demog.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema for scenariodb(n): Demographics Area
--
------------------------------------------------------------------------

-- Demographics of the region of interest (i.e., of nbhoods for
-- which local=1)

CREATE TABLE demog_local (
    -- Total population in local neighborhoods at the current time.
    population   INTEGER DEFAULT 0,

    -- Total consumers in local neighborhoods at the current time.
    consumers    INTEGER DEFAULT 0,

    -- Total labor force in local neighborhoods at the current time
    labor_force  INTEGER DEFAULT 0
);

-- Demographics of the neighborhood as a whole

CREATE TABLE demog_n (
    -- Symbolic neighborhood name
    n               TEXT PRIMARY KEY,

    -- Total population in the neighborhood at the current time
    population      INTEGER DEFAULT 0,

    -- Total subsistence population in the neighborhood at the current time
    subsistence     INTEGER DEFAULT 0,

    -- Total consumers in the neighborhood at the current time
    consumers       INTEGER DEFAULT 0,

    -- Total labor force in the neighborhood at the current time
    labor_force     INTEGER DEFAULT 0,

    -- Unemployed workers in the neighborhood.
    unemployed      INTEGER DEFAULT 0,

    -- Unemployment rate (percentage)
    ur              DOUBLE DEFAULT 0.0,

    -- Unemployed per capita (percentage)
    upc             DOUBLE DEFAULT 0.0,

    -- Unemployment Attitude Factor
    uaf             DOUBLE DEFAULT 0.0
);

-- Demographics of particular civgroups

CREATE TABLE demog_g (
    -- Symbolic civgroup name
    g              TEXT PRIMARY KEY,

    -- Total residents of this group in its home neighborhood at the
    -- current time.  This is always the integer part of real_pop.
    population     INTEGER DEFAULT 0,
    
    -- Total residents including fractional part (due to rate-based
    -- change).  This column should be ignored by other modules.
    real_pop       DOUBLE DEFAULT 0.0,

    -- Subsistence population: population doing subsistence agriculture
    -- and outside the regional economy.
    subsistence    INTEGER DEFAULT 0,

    -- Consumer population: population within the regional economy
    consumers      INTEGER DEFAULT 0,

    -- Labor Force: workers available to the regional economy
    labor_force    INTEGER DEFAULT 0,

    -- Employed workers
    employed       INTEGER DEFAULT 0,
    
    -- Unemployed workers
    unemployed     INTEGER DEFAULT 0,

    -- Unemployment rate (percentage)
    ur             DOUBLE DEFAULT 0.0,

    -- Unemployed per capita (percentage)
    upc            DOUBLE DEFAULT 0.0,

    -- Unemployment Attitude Factor
    uaf            DOUBLE DEFAULT 0.0,
    
    -- Total consumption of goods baskets this week
    tc             DOUBLE DEFAULT 0.0,
    
    -- Actual Level of Consumption of goods baskets per capita
    aloc           DOUBLE DEFAULT 0.0,
    
    -- Required Level of Consumption of goods baskets per capita
    -- (this defines the poverty line)
    rloc           DOUBLE DEFAULT 0.0,
    
    -- Expected Level of Consumption of goods baskets per capita
    eloc           DOUBLE DEFAULT 0.0,
    
    -- Fraction of the group that is living in poverty
    povfrac        DOUBLE DEFAULT 0.0,

    -- Attrition to this group (total killed to date).
    -- This is an output only; it is no longer used to
    -- compute population week to week.
    attrition      INTEGER DEFAULT 0
);


-- Demographic Situation Context View
--
-- This view identifies the neighborhood groups that can have
-- demographic situations, and pulls in required context from
-- other tables.
CREATE VIEW demog_context AS
SELECT CG.n              AS n,
       DG.g              AS g,
       DG.population     AS population,
       DG.uaf            AS guaf,
       DG.upc            AS gupc,
       DN.uaf            AS nuaf,
       DN.upc            AS nupc
FROM demog_g   AS DG
JOIN civgroups AS CG USING (g)
JOIN demog_n   AS DN USING (n);




------------------------------------------------------------------------
-- End of File
------------------------------------------------------------------------
