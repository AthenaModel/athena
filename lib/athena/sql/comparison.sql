------------------------------------------------------------------------
-- TITLE:
--    comparison.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema: Temporary views for comparison(n)'s comparison DB.
--
--    This file is loaded by comparison.tcl!
--
--    The comparison(n) object creates an SQLite3 database handle to
--    which are attached the two scenarios being compared.  This file
--    defines temporary views which join matching hist_* tables across
--    the two scenarios and add helpful columns.
--
--    All views in this file have names beginning with "comp_"
--
------------------------------------------------------------------------


-- comp_civg: combines hist_civg tables
CREATE TEMPORARY VIEW comp_civg AS
SELECT H1.g             AS g,
       G.n              AS n,
       G.bsid           AS bsid,
       N.local          AS local,
       H1.population    AS pop1,
       H1.mood          AS mood1,
       H2.population    AS pop2,
       H2.mood          AS mood2
FROM s1.hist_civg      AS H1
JOIN s2.hist_civg      AS H2
     ON (H1.g = H2.g AND H1.t = t1() AND H2.t = t2())
JOIN s1.civgroups_view AS G
     ON (G.g = H1.g)
JOIN s1.nbhoods        AS N
     ON (N.n = G.n);

-- comp_sat: combines hist_sat_raw tables
CREATE TEMPORARY VIEW comp_sat AS
SELECT H1.g             AS g,
       H1.c             AS c,
       G.n              AS n,
       G.bsid           AS bsid,
       N.local          AS local,
       H1.sat           AS sat1,
       H1.base          AS base1,
       H1.nat           AS nat1,
       H2.sat           AS sat2,
       H2.base          AS base2,
       H2.nat           AS nat2
FROM s1.hist_sat_raw   AS H1
JOIN s2.hist_sat_raw   AS H2
     ON (H1.g = H2.g AND H1.c = H2.c AND H1.t = t1() AND H2.t = t2())     
JOIN s1.civgroups_view AS G
     ON (G.g = H1.g)
JOIN s1.nbhoods        AS N
     ON (N.n = G.n);


-----------------------------------------------------------------------
-- End of File
-----------------------------------------------------------------------