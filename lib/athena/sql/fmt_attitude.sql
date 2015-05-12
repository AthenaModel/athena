------------------------------------------------------------------------
-- TITLE:
--    fmt_attitude.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema: Application-specific views, Attitude area
--
--    This file is loaded by athenadb.tcl!
--
--    Formatted views translate the internal data formats of the scenariodb(n)
--    tables into presentation format.  They are defined here instead of
--    in scenariodb(n) so that they can contain application-specific
--    SQL functions.
--
------------------------------------------------------------------------

------------------------------------------------------------------------
-- COOPERATION VIEWS

-- fmt_coop_view: A view used for editing baseline cooperation levels
-- in Scenario Mode.
CREATE TEMPORARY VIEW fmt_coop AS
SELECT C.f || ' ' || C.g                          AS id,
       C.f                                        AS f,
       C.g                                        AS g,
       format('%5.1f', C.base)                    AS base,
       C.regress_to                               AS regress_to,
       CASE WHEN C.regress_to='BASELINE' 
            THEN format('%5.1f', C.base)
            ELSE format('%5.1f', C.natural) END   AS natural
FROM coop_fg AS C
JOIN civgroups AS F ON (C.f = F.g)
WHERE F.basepop > 0
ORDER BY f,g;

-- fmt_coop_override_view: records with non-default values.
-- Used for scenario export.
CREATE TEMPORARY VIEW fmt_coop_override AS
SELECT f || ' ' || g           AS id,
       base                    AS base,
       regress_to              AS regress_to,
       natural                 AS natural
FROM coop_fg
WHERE base != 50.0 OR regress_to != 'BASELINE' OR natural != 50.0;

------------------------------------------------------------------------
-- HORIZONTAL RELATIONSHIP VIEWS 

-- fmt_hrel_base_view:  A view that puts hrel_base_view together with
-- the mam2(n)-based affinity values to get the base H.fg values for
-- this scenario.  It is used only as a part of the definition
-- of fmt_hrel_view, which looks the way it did with the original 
-- mam(n) implementation.
CREATE TEMPORARY VIEW fmt_hrel_base_view AS
SELECT f                                         AS f,
       ftype                                     AS ftype,
       g                                         AS g,
       gtype                                     AS gtype,
       coalesce(nat,  affinity(fbsid, gbsid))    AS nat,
       coalesce(base, affinity(fbsid, gbsid))    AS base,
       hist_flag                                 AS hist_flag,
       coalesce(current, affinity(fbsid, gbsid)) AS current,
       override                                  AS override
FROM hrel_base_view;

-- fmt_hrel_view: A view used for editing baseline horizontal 
-- relationship levels in Scenario Mode.
CREATE TEMPORARY VIEW fmt_hrel_view AS
SELECT HV.f || ' ' || HV.g                           AS id,
       HV.f                                          AS f,
       HV.ftype                                      AS ftype,
       HV.g                                          AS g,
       HV.gtype                                      AS gtype,
       format('%+4.1f', HV.base)                     AS base,
       HV.hist_flag                                  AS hist_flag,
       format('%+4.1f', HV.current)                  AS current,
       format('%+4.1f', HV.nat)                      AS nat,
       CASE WHEN override THEN 'Y' ELSE 'N' END      AS override
FROM fmt_hrel_base_view AS HV
LEFT OUTER JOIN civgroups AS FC ON (HV.f = FC.g)
LEFT OUTER JOIN civgroups AS GC ON (HV.g = GC.g)
WHERE HV.f != HV.g
AND coalesce(FC.basepop, 1) > 0
AND coalesce(GC.basepop, 1) > 0;

-- A fmt_hrel_view subview: overridden relationships only.
CREATE TEMPORARY VIEW fmt_hrel_override_view AS
SELECT * FROM fmt_hrel_view
WHERE override = 'Y';

------------------------------------------------------------------------
-- SATISFACTION VIEWS

-- fmt_sat_view: A view used for editing baseline satisfaction levels
-- in Scenario Mode.
CREATE TEMPORARY VIEW fmt_sat_view AS
SELECT GC.g || ' ' || GC.c                          AS id,
       GC.g                                         AS g,
       GC.c                                         AS c,
       G.n                                          AS n,
       format('%.3f', GC.base)                      AS base,
       format('%.2f', GC.saliency)                  AS saliency,
       GC.hist_flag                                 AS hist_flag,
       CASE WHEN GC.hist_flag
            THEN format('%.3f', GC.current)
            ELSE format('%.3f', GC.base) END        AS current
FROM sat_gc AS GC
JOIN civgroups AS G ON (GC.g = G.g)
WHERE G.basepop > 0
ORDER BY g,c;

-- fmt_sat_override_view: records with non-default values.
-- Used for scenario export.
CREATE TEMPORARY VIEW fmt_sat_override_view AS
SELECT g || ' ' || c             AS id,
       base                      AS base,
       saliency                  AS saliency,
       hist_flag                 AS hist_flag,
       current                   AS current
FROM sat_gc
WHERE base != 0.0 OR saliency != 1.0 OR hist_flag OR current != 0
ORDER BY g,c;

------------------------------------------------------------------------
-- VERTICAL RELATIONSHIPS VIEWS 

-- fmt_vrel_base_view: A view that puts vrel_base_view together with the
-- mam2(n)-based affinity values to get the base G.fa values for this s
-- scenario.

CREATE TEMPORARY VIEW fmt_vrel_base_view AS
SELECT g                                           AS g,
       gtype                                       AS gtype,
       gbsid                                       AS gbsid,
       owner                                       AS owner,
       a                                           AS a,
       absid                                       AS absid,
       coalesce(nat, affinity(gbsid,absid))        AS nat,
       coalesce(base, affinity(gbsid,absid))       AS base,
       hist_flag                                   AS hist_flag,
       coalesce(current, affinity(gbsid,absid))    AS current,
       override                                    AS override
FROM vrel_base_view;

-- fmt_vrel_view: A view used for editing baseline vertical relationships
-- in Scenario Mode.
CREATE TEMPORARY VIEW fmt_vrel_view AS
SELECT V.g || ' ' || V.a                            AS id,
       V.g                                          AS g,
       V.gtype                                      AS gtype,
       V.a                                          AS a,
       format('%+4.1f', V.base)                     AS base,
       V.hist_flag                                  AS hist_flag,
       format('%+4.1f', V.current)                  AS current,
       format('%+4.1f', V.nat)                      AS nat,
       CASE WHEN V.override THEN 'Y' ELSE 'N' END   AS override
FROM fmt_vrel_base_view AS V
LEFT OUTER JOIN civgroups AS G USING (g)
WHERE coalesce(G.basepop,1) > 0;

-- A fmt_vrel_view subview: overridden relationships only.
CREATE TEMPORARY VIEW fmt_vrel_override_view AS
SELECT * FROM fmt_vrel_view
WHERE override = 'Y';


-----------------------------------------------------------------------
-- End of File
-----------------------------------------------------------------------