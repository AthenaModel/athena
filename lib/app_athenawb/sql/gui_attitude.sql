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

-----------------------------------------------------------------------
-- End of File
-----------------------------------------------------------------------