------------------------------------------------------------------------
-- TITLE:
--    gui_attitude.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema: Application-specific views, Attitude area
--
--    This file is loaded by scenario.tcl!
--
--    GUI views translate the internal data formats of the scenariodb(n)
--    tables into presentation format.  They are defined here instead of
--    in scenariodb(n) so that they can contain application-specific
--    SQL functions.
--
------------------------------------------------------------------------

------------------------------------------------------------------------
-- COOPERATION VIEWS

-- gui_coop_view: A view used for editing baseline cooperation levels
-- in Scenario Mode.
CREATE TEMPORARY VIEW gui_coop_view AS
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

-- gui_coop_override_view: records with non-default values.
-- Used for scenario export.
CREATE TEMPORARY VIEW gui_coop_override_view AS
SELECT f || ' ' || g           AS id,
       base                    AS base,
       regress_to              AS regress_to,
       natural                 AS natural
FROM coop_fg
WHERE base != 50.0 OR regress_to != 'BASELINE' OR natural != 50.0;


-- gui_uram_coop: A view used for displaying cooperation levels and
-- their components in Simulation Mode.
CREATE TEMPORARY VIEW gui_uram_coop AS
SELECT f || ' ' || g                              AS id,
       f                                          AS f,
       g                                          AS g,
       format('%5.1f', coop0)                     AS coop0,
       format('%5.1f', bvalue0)                   AS base0,
       CASE WHEN uram_gamma('COOP') > 0.0
            THEN format('%5.1f', cvalue0)
            ELSE 'n/a' END                        AS nat0,
       format('%5.1f', coop)                      AS coop,
       format('%5.1f', bvalue)                    AS base,
       CASE WHEN uram_gamma('COOP') > 0.0
            THEN format('%5.1f', cvalue)
            ELSE 'n/a' END                        AS nat,
       curve_id                                   AS curve_id,
       fg_id                                      AS fg_id
FROM uram_coop
WHERE tracked
ORDER BY f,g;


-- gui_coop_ng: Neighborhood cooperation levels.
CREATE TEMPORARY VIEW gui_coop_ng AS
SELECT n || ' ' || g             AS id,
       n                         AS n,
       g                         AS g,
       format('%5.1f', nbcoop0)  AS coop0,
       format('%5.1f', nbcoop)   AS coop
FROM uram_nbcoop;

------------------------------------------------------------------------
-- HORIZONTAL RELATIONSHIP VIEWS 

-- gui_hrel_base_view:  A view that puts hrel_base_view together with
-- the mam2(n)-based affinity values to get the base H.fg values for
-- this scenario.  It is used only as a part of the definition
-- of gui_hrel_view, which looks the way it did with the original 
-- mam(n) implementation.
CREATE TEMPORARY VIEW gui_hrel_base_view AS
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

-- gui_hrel_view: A view used for editing baseline horizontal 
-- relationship levels in Scenario Mode.
CREATE TEMPORARY VIEW gui_hrel_view AS
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
FROM gui_hrel_base_view AS HV
LEFT OUTER JOIN civgroups AS FC ON (HV.f = FC.g)
LEFT OUTER JOIN civgroups AS GC ON (HV.g = GC.g)
WHERE HV.f != HV.g
AND coalesce(FC.basepop, 1) > 0
AND coalesce(GC.basepop, 1) > 0;

-- A gui_hrel_view subview: overridden relationships only.
CREATE TEMPORARY VIEW gui_hrel_override_view AS
SELECT * FROM gui_hrel_view
WHERE override = 'Y';


-- gui_uram_hrel: A view used for displaying the current horizontal
-- relationships and their components in Simulation Mode.
CREATE TEMPORARY VIEW gui_uram_hrel AS
SELECT UH.f || ' ' || UH.g                           AS id,
       UH.f                                          AS f,
       F.gtype                                       AS ftype,
       UH.g                                          AS g,
       G.gtype                                       AS gtype,
       format('%+4.1f', UH.hrel0)                    AS hrel0,
       format('%+4.1f', UH.bvalue0)                  AS base0,
       CASE WHEN uram_gamma('HREL') > 0.0
            THEN format('%+4.1f', UH.cvalue0)
            ELSE 'n/a' END                           AS nat0,
       format('%+4.1f', UH.hrel)                     AS hrel,
       format('%+4.1f', UH.bvalue)                   AS base,
       CASE WHEN uram_gamma('HREL') > 0.0
            THEN format('%+4.1f', UH.cvalue)
            ELSE 'n/a' END                           AS nat,
       UH.curve_id                                   AS curve_id,
       UH.fg_id                                      AS fg_id
FROM uram_hrel AS UH
JOIN groups AS F ON (F.g = UH.f)
JOIN groups AS G ON (G.g = UH.g)
WHERE UH.tracked AND F.g != G.g;

------------------------------------------------------------------------
-- SATISFACTION VIEWS

-- gui_sat_view: A view used for editing baseline satisfaction levels
-- in Scenario Mode.
CREATE TEMPORARY VIEW gui_sat_view AS
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

-- gui_sat_override_view: records with non-default values.
-- Used for scenario export.
CREATE TEMPORARY VIEW gui_sat_override_view AS
SELECT g || ' ' || c             AS id,
       base                      AS base,
       saliency                  AS saliency,
       hist_flag                 AS hist_flag,
       current                   AS current
FROM sat_gc
WHERE base != 0.0 OR saliency != 1.0 OR hist_flag OR current != 0
ORDER BY g,c;

-- gui_uram_sat: A view used for displaying satisfaction levels and
-- their components in Simulation mode.
CREATE TEMPORARY VIEW gui_uram_sat AS
SELECT US.g || ' ' || US.c                           AS id,
       US.g                                          AS g,
       US.c                                          AS c,
       G.n                                           AS n,
       format('%+4.1f', US.sat0)                     AS sat0,
       format('%+4.1f', US.bvalue0)                  AS base0,
       CASE WHEN uram_gamma(c) > 0.0
            THEN format('%+4.1f', US.cvalue0)
            ELSE 'n/a' END                           AS nat0,
       format('%+4.1f', US.sat)                      AS sat,
       format('%+4.1f', US.bvalue)                   AS base,
       CASE WHEN uram_gamma(c) > 0.0
            THEN format('%+4.1f', US.cvalue)
            ELSE 'n/a' END                           AS nat,
       US.curve_id                                   AS curve_id,
       US.gc_id                                      AS gc_id
FROM uram_sat AS US
JOIN civgroups AS G USING (g)
WHERE US.tracked
ORDER BY g,c;


------------------------------------------------------------------------
-- VERTICAL RELATIONSHIPS VIEWS 

-- gui_vrel_base_view: A view that puts vrel_base_view together with the
-- mam2(n)-based affinity values to get the base G.fa values for this s
-- scenario.

CREATE TEMPORARY VIEW gui_vrel_base_view AS
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

-- gui_vrel_view: A view used for editing baseline vertical relationships
-- in Scenario Mode.
CREATE TEMPORARY VIEW gui_vrel_view AS
SELECT V.g || ' ' || V.a                            AS id,
       V.g                                          AS g,
       V.gtype                                      AS gtype,
       V.a                                          AS a,
       format('%+4.1f', V.base)                     AS base,
       V.hist_flag                                  AS hist_flag,
       format('%+4.1f', V.current)                  AS current,
       format('%+4.1f', V.nat)                      AS nat,
       CASE WHEN V.override THEN 'Y' ELSE 'N' END   AS override
FROM gui_vrel_base_view AS V
LEFT OUTER JOIN civgroups AS G USING (g)
WHERE coalesce(G.basepop,1) > 0;

-- A gui_vrel_view subview: overridden relationships only.
CREATE TEMPORARY VIEW gui_vrel_override_view AS
SELECT * FROM gui_vrel_view
WHERE override = 'Y';


-- gui_uram_vrel: A view used for display vertical relationships and
-- their components in Simulation Mode.
CREATE TEMPORARY VIEW gui_uram_vrel AS
SELECT UV.g || ' ' || UV.a                           AS id,
       UV.g                                          AS g,
       G.gtype                                       AS gtype,
       UV.a                                          AS a,
       format('%+4.1f', UV.vrel0)                    AS vrel0,
       format('%+4.1f', UV.bvalue0)                  AS base0,
       CASE WHEN uram_gamma('VREL') > 0.0
            THEN format('%+4.1f', UV.cvalue0)
            ELSE 'n/a' END                           AS nat0,
       format('%+4.1f', UV.vrel)                     AS vrel,
       format('%+4.1f', UV.bvalue)                   AS base,
       CASE WHEN uram_gamma('VREL') > 0.0
            THEN format('%+4.1f', UV.cvalue)
            ELSE 'n/a' END                           AS nat,
       UV.curve_id                                   AS curve_id,
       UV.ga_id                                      AS ga_id
FROM uram_vrel AS UV
JOIN groups AS G ON (G.g = UV.g)
WHERE tracked;

------------------------------------------------------------------------
-- DRIVER VIEWS

-- gui_drivers: All Drivers
CREATE TEMPORARY VIEW gui_drivers AS
SELECT driver_id                                        AS driver_id,
       driver_id || ' - ' || 
       sigline(dtype, signature)                        AS longid,
       sigline(dtype, signature)                        AS sigline,
       dtype                                            AS dtype,
       signature                                        AS signature,
       '/app/driver/' || driver_id                  AS url,
       link('/app/driver/' || driver_id, driver_id) AS link
FROM drivers;

-----------------------------------------------------------------------
-- RULE FIRING VIEWS

-- gui_firings:  All rule firings
CREATE TEMPORARY VIEW gui_firings AS
SELECT firing_id                                        AS firing_id,
       t                                                AS t,
       driver_id                                        AS driver_id,
       ruleset                                          AS ruleset,
       rule                                             AS rule,
       fdict                                            AS fdict,
       mklinks(firing_narrative(fdict))                 AS narrative,
       '/app/firing/' || firing_id                  AS url,
       link('/app/firing/' || firing_id, firing_id) AS link
FROM rule_firings;

-- gui_inputs: All rule inputs
CREATE TEMPORARY VIEW gui_inputs AS
SELECT F.t                                              AS t,
       F.firing_id                                      AS firing_id,
       I.input_id                                       AS input_id,
       F.driver_id                                      AS driver_id,
       F.ruleset                                        AS ruleset,
       F.rule                                           AS rule,
       F.fdict                                          AS fdict,
       F.narrative                                      AS narrative,
       F.url                                            AS url,
       F.link                                           AS link,
       I.atype                                          AS atype,
       I.mode                                           AS mode,
       CASE WHEN I.mode = 'P' THEN 'persistent'
                              ELSE 'transient' END      AS longmode,
       I.f                                              AS f,
       I.g                                              AS g,
       I.c                                              AS c,
       I.a                                              AS a,
       atype || '.' ||
       CASE WHEN I.atype='coop' OR I.atype='hrel'
            THEN elink('group',I.f) || '.' || elink('group',I.g)
            WHEN I.atype='sat'
            THEN elink('group',I.g) || '.' || I.c
            WHEN I.atype='vrel'
            THEN elink('group',I.g) || '.' || elink('actor',I.a)
            END                                         AS curve, 
       format('%.2f',I.gain)                            AS gain,
       format('%.2f',I.mag)                             AS mag,
       I.cause                                          AS cause,
       CASE WHEN I.atype IN ('sat', 'coop')
            THEN format('%.2f',I.s) ELSE 'n/a' END      AS s,
       CASE WHEN I.atype IN ('sat', 'coop')
            THEN format('%.2f',I.p) ELSE 'n/a' END      AS p,
       CASE WHEN I.atype IN ('sat', 'coop')
            THEN format('%.2f',I.q) ELSE 'n/a' END      AS q,
       I.note                                           AS note
FROM rule_inputs AS I
JOIN gui_firings AS F USING (firing_id);

-----------------------------------------------------------------------
-- End of File
-----------------------------------------------------------------------