------------------------------------------------------------------------
-- TITLE:
--    scenariodb_econ.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema for scenariodb(n): Economics Area
--
------------------------------------------------------------------------

-- Neighborhood inputs and outputs.  
--
-- NOTE: All production capacities and related factors concern the 
-- "goods" sector; when we add additional kinds of production, we'll
-- probably need to elaborate this scheme considerably.

CREATE TABLE econ_n (
    -- Symbolic neighborhood name
    n          TEXT PRIMARY KEY REFERENCES nbhoods(n)
               ON DELETE CASCADE
               DEFERRABLE INITIALLY DEFERRED,

    -- The following columns can be ignored if nbhoods.local == 0.    

    -- Output, Production Capacity at time 0
    cap0       DOUBLE DEFAULT 0,

    -- Output, Production Capacity at time t
    cap        DOUBLE DEFAULT 0,

    -- Jobs at time 0 given production capacity t time 0
    jobs0      DOUBLE DEFAULT 0,

    -- Jobs in neighborhood given production capacity
    jobs       DOUBLE DEFAULT 0
);

-- A view of only those econ_n records that correspond to local
-- neighborhoods.
CREATE VIEW econ_n_view AS
SELECT * FROM nbhoods JOIN econ_n USING (n) WHERE nbhoods.local = 1;

------------------------------------------------------------------------
-- End of File
------------------------------------------------------------------------
