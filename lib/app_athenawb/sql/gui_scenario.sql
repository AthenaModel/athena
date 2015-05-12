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

-- gui_actors: Actor data
CREATE TEMPORARY VIEW gui_actors AS
SELECT a                                               AS id,
       a                                               AS a,
       '/app/actor/' || a                              AS url,
       fancy                                           AS fancy,
       link('/app/actor/' || a, a)                     AS link,
       link('/app/actor/' || a, pair(longname, a))     AS longlink,
       longname                                        AS longname,
       bsid                                            AS bsid,
       bsysname                                        AS bsysname,
       supports                                        AS supports,
       CASE WHEN supports NOT IN ('SELF','NONE')
            THEN link('/app/actor/' || supports, supports)
            ELSE supports
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

-- gui_neighborhoods: Neighborhood data collected from all over
CREATE TEMPORARY VIEW gui_nbhoods AS
SELECT id                                           AS id,
       n                                            AS n,
       '/app/nbhood/' || n                          AS url,
       pair(longname, n)                            AS fancy,
       link('/app/nbhood/' || n, n)                 AS link,
       link('/app/nbhood/' || n, pair(longname, n)) AS longlink,
       longname                                     AS longname,
       local                                        AS local,
       urbanization                                 AS urbanization,
       controller                                   AS controller,
       since_ticks                                  AS since_ticks,
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

-- gui_nbrel_mn: Neighborhood Proximities
CREATE TEMPORARY VIEW gui_nbrel_mn AS
SELECT MN.id                                         AS id,
       MN.m                                          AS m,
       M.longlink                                    AS m_longlink,
       MN.n                                          AS n,
       N.longlink                                    AS n_longlink,
       MN.proximity                                  AS proximity
FROM fmt_nbrel_mn AS MN
JOIN gui_nbhoods AS M ON (MN.m = M.n)
JOIN gui_nbhoods AS N ON (MN.n = N.n)
WHERE MN.m != MN.n;

------------------------------------------------------------------------
-- GROUPS

-- gui_groups: Data common to all groups
CREATE TEMPORARY VIEW gui_groups AS
SELECT id                                            AS id,
       g                                             AS g,
       '/app/group/' || g                            AS url,
       fancy                                         AS fancy,
       link('/app/group/' || g, g)                   AS link,
       link('/app/group/' || g, pair(longname, g))   AS longlink,
       gtype                                         AS gtype,
       link('/app/groups/' || lower(gtype), gtype)   AS gtypelink,
       longname                                      AS longname,
       bsid                                          AS bsid,
       color                                         AS color,
       demeanor                                      AS demeanor,
       cost                                          AS cost,
       a                                             AS a
FROM fmt_groups;

-- gui_civgroups: Civilian group data 
CREATE TEMPORARY VIEW gui_civgroups AS
SELECT G.id                   AS id,
       G.g                    AS g,
       G.url                  AS url,
       G.fancy                AS fancy,
       G.link                 AS link,
       G.longlink             AS longlink,
       G.gtype                AS gtype,
       G.longname             AS longname,
       G.color                AS color,
       G.demeanor             AS demeanor,
       CG.basepop             AS basepop,
       CG.n                   AS n,
       CG.bsid                AS bsid,
       CG.bsysname            AS bsysname,
       CG.pretty_sa_flag      AS pretty_sa_flag,
       CG.sa_flag             AS sa_flag,
       CG.pop_cr              AS pop_cr,
       CG.housing             AS housing,
       CG.lfp                 AS lfp,
       CG.population          AS population,
       CG.hist_flag           AS hist_flag,
       CG.attrition           AS attrition,
       CG.subsistence         AS subsistence,
       CG.consumers           AS consumers,
       CG.labor_force         AS labor_force,
       CG.unemployed          AS unemployed,
       CG.req_funding         AS req_funding, 
       CG.sat_funding         AS sat_funding, 
       CG.ur                  AS ur,
       CG.upc                 AS upc,
       CG.uaf                 AS uaf,
       CG.tc                  AS tc,
       CG.aloc                AS aloc,
       CG.eloc                AS eloc,
       CG.rloc                AS rloc,
       CG.povfrac             AS povfrac,
       CG.povpct              AS povpct,
       CG.mood0               AS mood0,
       CG.mood                AS mood
FROM gui_groups     AS G
JOIN fmt_civgroups  AS CG USING (g);

-- gui_frcgroups: Force group data
CREATE TEMPORARY VIEW gui_frcgroups AS
SELECT G.id                   AS id,
       G.g                    AS g,
       G.url                  AS url,
       F.fancy                AS fancy,
       G.link                 AS link,
       G.longlink             AS longlink,
       F.gtype                AS gtype,
       F.longname             AS longname,
       F.color                AS color,
       F.demeanor             AS demeanor,
       F.personnel            AS personnel,
       F.cost                 AS cost,
       F.a                    AS a,
       F.forcetype            AS forcetype,
       F.training             AS training,
       F.equip_level          AS equip_level,
       F.base_personnel       AS base_personnel,
       F.local                AS local,
       F.pretty_local         AS pretty_local
FROM gui_groups    AS G
JOIN fmt_frcgroups AS F USING (g);

-- gui_orggroups: Organization Group data
CREATE TEMPORARY VIEW gui_orggroups AS
SELECT G.id                   AS id,
       G.g                    AS g,
       G.url                  AS url,
       O.fancy                AS fancy,
       G.link                 AS link,
       G.longlink             AS longlink,
       O.gtype                AS gtype,
       O.longname             AS longname,
       O.color                AS color,
       O.demeanor             AS demeanor,
       O.personnel            AS personnel,
       O.cost                 AS cost,
       O.a                    AS a,
       O.orgtype              AS orgtype,
       O.base_personnel       AS base_personnel
FROM gui_groups    AS G
JOIN fmt_orggroups AS O USING (g);

-- gui_agroups: All groups that can be owned by actors
CREATE TEMP VIEW gui_agroups AS
SELECT g, url, fancy, link, longlink, gtype, longname, a, cost,
       forcetype           AS subtype,
       'FRC/' || forcetype AS fulltype
FROM gui_frcgroups
UNION
SELECT g, url, fancy, link, longlink, gtype, longname, a, cost,
       orgtype           AS subtype,
       'ORG/' || orgtype AS fulltype
FROM gui_orggroups;

-----------------------------------------------------------------------
-- End of File
-----------------------------------------------------------------------


