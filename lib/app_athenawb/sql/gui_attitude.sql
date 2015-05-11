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
--    This file is loaded by app.tcl!
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
CREATE TEMPORARY VIEW gui_coop AS
SELECT * FROM fmt_coop;

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

-- gui_hrel_view: A view used for editing baseline horizontal 
-- relationship levels in Scenario Mode.
CREATE TEMPORARY VIEW gui_hrel_view AS
SELECT * FROM fmt_hrel_view;

-- A gui_hrel_view subview: overridden relationships only.
CREATE TEMPORARY VIEW gui_hrel_override_view AS
SELECT * FROM fmt_hrel_override_view;

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

-- gui_sat_view
CREATE TEMPORARY VIEW gui_sat_view AS
SELECT * FROM fmt_sat_view;

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

-- gui_vrel_view: A view used for editing baseline vertical relationships
-- in Scenario Mode.
CREATE TEMPORARY VIEW gui_vrel_view AS
SELECT * FROM fmt_vrel_view;

-- A gui_vrel_view subview: overridden relationships only.
CREATE TEMPORARY VIEW gui_vrel_override_view AS
SELECT * FROM fmt_vrel_override_view;

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