------------------------------------------------------------------------
-- TITLE:
--    gui_scenario.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema: Application-specific views, Scenario Data
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
-- ACTORS

-- web_actors: Actor data
CREATE TEMPORARY VIEW web_actors AS
SELECT a                                               AS id,
       a                                               AS a,
       'actor/' || a  || '/index'                      AS url,
       fancy                                           AS fancy,
       longname                                        AS longname,
       bsid                                            AS bsid,
       bsysname                                        AS bsysname,
       supports                                        AS supports,
       CASE WHEN supports NOT IN ('SELF','NONE')
            THEN 'actor/' || supports || '/index'
            ELSE ''
            END                                        AS supports_link,
       atype                                           AS atype,
       auto_maintain                                   AS auto_maintain,
       pretty_am_flag                                  AS pretty_am_flag,
       cash_reserve                                    AS cash_reserve,
       cash_on_hand                                    AS cash_on_hand,
       income_goods                                    AS income_goods,
       shares_black_nr                                 AS shares_black_nr,
       income_black_tax                                AS income_black_tax,
       income_pop                                      AS income_pop,
       income_graft                                    AS income_graft,
       income_world                                    AS income_world,
       budget                                          AS budget,
       income                                          AS income
FROM fmt_actors;

------------------------------------------------------------------------
-- NEIGHBORHOODS

-- web_neighborhoods: Neighborhood data collected from all over
CREATE TEMPORARY VIEW web_nbhoods AS
SELECT id                                           AS id,
       n                                            AS n,
       'nbhood/' || n || '/index'                   AS url,
       pair(longname, n)                            AS fancy,
       longname                                     AS longname,
       local                                        AS local,
       urbanization                                 AS urbanization,
       controller                                   AS controller,
       CASE WHEN controller != 'NONE'
            THEN 'actor/' || controller || '/index'
            ELSE ''
            END                                     AS controller_link,
        since_ticks                                 AS since_ticks,
       since                                        AS since,
       pcf                                          AS pcf,
       stacking_order                               AS stacking_order,
       obscured_by                                  AS obscured_by,
       refpoint                                     AS refpoint,
       polygon                                      AS polygon,
       volatility                                   AS volatility,
       population                                   AS population,
       subsistence                                  AS subsistence,
       consumers                                    AS consumers,
       labor_force                                  AS labor_force,
       unemployed                                   AS unemployed,
       -- TBD: These should be "nbmood", not "mood".
       mood0                                        AS mood0,
       mood                                         AS mood
FROM fmt_nbhoods;

------------------------------------------------------------------------
-- GROUPS

-- web_groups: Data common to all groups
CREATE TEMPORARY VIEW web_groups AS
SELECT id                                            AS id,
       g                                             AS g,
       fancy                                         AS fancy,
       gtype                                         AS gtype,
       longname                                      AS longname,
       bsid                                          AS bsid,
       color                                         AS color,
       demeanor                                      AS demeanor,
       cost                                          AS cost,
       a                                             AS a
FROM fmt_groups;

-- web_civgroups: Civilian group data 
CREATE TEMPORARY VIEW web_civgroups AS
SELECT G.id                                 AS id,
       G.g                                  AS g,
       'civgroup/' || g || '/index'         AS url,
       G.fancy                              AS fancy,
       G.gtype                              AS gtype,
       G.longname                           AS longname,
       G.color                              AS color,
       G.demeanor                           AS demeanor,
       CG.basepop                           AS basepop,
       CG.n                                 AS n,
       'nbhood/' || CG.n || '/index'        AS n_link,
       CG.bsid                              AS bsid,
       CG.bsysname                          AS bsysname,
       CG.pretty_sa_flag                    AS pretty_sa_flag,
       CG.sa_flag                           AS sa_flag,
       CG.pop_cr                            AS pop_cr,
       CG.housing                           AS housing,
       CG.lfp                               AS lfp,
       CG.population                        AS population,
       CG.hist_flag                         AS hist_flag,
       CG.attrition                         AS attrition,
       CG.subsistence                       AS subsistence,
       CG.consumers                         AS consumers,
       CG.labor_force                       AS labor_force,
       CG.unemployed                        AS unemployed,
       CG.req_funding                       AS req_funding, 
       CG.sat_funding                       AS sat_funding, 
       CG.ur                                AS ur,
       CG.upc                               AS upc,
       CG.uaf                               AS uaf,
       CG.tc                                AS tc,
       CG.aloc                              AS aloc,
       CG.eloc                              AS eloc,
       CG.rloc                              AS rloc,
       CG.povfrac                           AS povfrac,
       CG.povpct                            AS povpct,
       CG.mood0                             AS mood0,
       CG.mood                              AS mood
FROM web_groups     AS G
JOIN fmt_civgroups  AS CG USING (g);

-- web_frcgroups: Force group data
CREATE TEMPORARY VIEW web_frcgroups AS
SELECT G.id                                 AS id,
       G.g                                  AS g,
       'frcgroup/' || g || '/index'         AS url,
       F.fancy                              AS fancy,
       F.gtype                              AS gtype,
       F.longname                           AS longname,
       F.color                              AS color,
       F.demeanor                           AS demeanor,
       F.personnel                          AS personnel,
       F.cost                               AS cost,
       F.a                                  AS a,
       CASE WHEN F.a NOT NULL
            THEN 'actor/' || F.a || '/index'           
            ELSE '' 
            END                             AS a_link,
       F.forcetype                          AS forcetype,
       F.training                           AS training,
       F.equip_level                        AS equip_level,
       F.base_personnel                     AS base_personnel,
       F.local                              AS local,
       F.pretty_local                       AS pretty_local
FROM web_groups    AS G
JOIN fmt_frcgroups AS F USING (g);

-- web_orggroups: Organization Group data
CREATE TEMPORARY VIEW web_orggroups AS
SELECT G.id                                 AS id,
       G.g                                  AS g,
       'orggroup/' || g || '/index'         AS url,
       O.fancy                              AS fancy,
       O.gtype                              AS gtype,
       O.longname                           AS longname,
       O.color                              AS color,
       O.demeanor                           AS demeanor,
       O.personnel                          AS personnel,
       O.cost                               AS cost,
       O.a                                  AS a,
       CASE WHEN O.a NOT NULL
            THEN 'actor/' || O.a || '/index'           
            ELSE '' 
            END                             AS a_link,
       O.orgtype                            AS orgtype,
       O.base_personnel                     AS base_personnel
FROM web_groups    AS G
JOIN fmt_orggroups AS O USING (g);

-- web_agroups: All groups that can be owned by actors
CREATE TEMP VIEW web_agroups AS
SELECT g, url, fancy, gtype, longname, a, cost,
       forcetype           AS subtype,
       'FRC/' || forcetype AS fulltype
FROM web_frcgroups
UNION
SELECT g, url, fancy, gtype, longname, a, cost,
       orgtype           AS subtype,
       'ORG/' || orgtype AS fulltype
FROM web_orggroups;

-----------------------------------------------------------------------
-- End of File
-----------------------------------------------------------------------


