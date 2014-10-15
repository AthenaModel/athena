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
--    This file is loaded by scenario.tcl!
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
       'my://app/actor/' || a                          AS url,
       pair(longname, a)                               AS fancy,
       link('my://app/actor/' || a, a)                 AS link,
       link('my://app/actor/' || a, pair(longname, a)) AS longlink,
       longname                                        AS longname,
       bsid                                            AS bsid,
       bsysname(bsid)                                  AS bsysname,
       CASE WHEN supports = a      THEN 'SELF'
            WHEN supports IS NULL  THEN 'NONE'
            ELSE supports 
            END                                        AS supports,
       CASE WHEN supports = a      THEN 'SELF'
            WHEN supports IS NULL  THEN 'NONE'
            ELSE link('my://app/actor/' || supports, supports)
            END                                        AS supports_link,
       atype                                           AS atype,
       auto_maintain                                   AS auto_maintain,
       CASE auto_maintain WHEN 1 THEN 'Yes' 
                                 ELSE 'No' END         AS pretty_am_flag,
       moneyfmt(cash_reserve)                          AS cash_reserve,
       moneyfmt(cash_on_hand)                          AS cash_on_hand,
       moneyfmt(income_goods)                          AS income_goods,
       shares_black_nr                                 AS shares_black_nr,
       moneyfmt(income_black_tax)                      AS income_black_tax,
       moneyfmt(income_pop)                            AS income_pop,
       moneyfmt(income_graft)                          AS income_graft,
       moneyfmt(income_world)                          AS income_world,
       moneyfmt(budget)                                AS budget,
       moneyfmt(income)                                AS income
FROM actors_view;


------------------------------------------------------------------------
-- NEIGHBORHOODS

-- gui_neighborhoods: Neighborhood data collected from all over
CREATE TEMPORARY VIEW gui_nbhoods AS
SELECT N.n                                                    AS id,
       N.n                                                    AS n,
       'my://app/nbhood/' || N.n                              AS url,
       pair(N.longname, N.n)                                  AS fancy,
       link('my://app/nbhood/' || N.n, N.n)                   AS link,
       link('my://app/nbhood/' || N.n, pair(N.longname, N.n)) AS longlink,
       N.longname                                             AS longname,
       CASE N.local WHEN 1 THEN 'YES' ELSE 'NO' END           AS local,
       N.urbanization                                         AS urbanization,
       CASE WHEN locked()
        THEN COALESCE(C.controller, 'NONE')
        ELSE COALESCE(N.controller, 'NONE')
       END                                                    AS controller,
       COALESCE(C.since, 0)                                   AS since_ticks,
       timestr(COALESCE(C.since, 0))                          AS since,
       format('%4.1f',N.pcf)                                  AS pcf,
       N.stacking_order                                       AS stacking_order,
       N.obscured_by                                          AS obscured_by,
       m2ref(N.refpoint)                                      AS refpoint,
       m2ref(N.polygon)                                       AS polygon,
       COALESCE(F.volatility,0)                               AS volatility,
       COALESCE(D.population,0)                               AS population,
       COALESCE(D.subsistence,0)                              AS subsistence,
       COALESCE(D.consumers,0)                                AS consumers,
       COALESCE(D.labor_force,0)                              AS labor_force,
       COALESCE(D.unemployed,0)                               AS unemployed,
       -- TBD: These should be "nbmood", not "mood".
       format('%.3f',COALESCE(UN.nbmood0, 0.0))               AS mood0,
       format('%.3f',COALESCE(UN.nbmood, 0.0))                AS mood
FROM nbhoods              AS N
LEFT OUTER JOIN demog_n   AS D  USING (n)
LEFT OUTER JOIN force_n   AS F  USING (n)
LEFT OUTER JOIN uram_n    AS UN USING (n)
LEFT OUTER JOIN control_n AS C  USING (n);


-- gui_nbrel_mn: Neighborhood Proximities
CREATE TEMPORARY VIEW gui_nbrel_mn AS
SELECT MN.m || ' ' || MN.n                           AS id,
       MN.m                                          AS m,
       M.longlink                                    AS m_longlink,
       MN.n                                          AS n,
       N.longlink                                    AS n_longlink,
       MN.proximity                                  AS proximity
FROM nbrel_mn AS MN
JOIN gui_nbhoods AS M ON (MN.m = M.n)
JOIN gui_nbhoods AS N ON (MN.n = N.n)
WHERE MN.m != MN.n;


------------------------------------------------------------------------
-- GROUPS

-- gui_groups: Data common to all groups
CREATE TEMPORARY VIEW gui_groups AS
SELECT g                                                 AS id,
       g                                                 AS g,
       'my://app/group/' || g                            AS url,
       pair(longname, g)                                 AS fancy,
       link('my://app/group/' || g, g)                   AS link,
       link('my://app/group/' || g, pair(longname, g))   AS longlink,
       gtype                                             AS gtype,
       link('my://app/groups/' || lower(gtype), gtype)   AS gtypelink,
       longname                                          AS longname,
       bsid                                              AS bsid,
       color                                             AS color,
       demeanor                                          AS demeanor,
       moneyfmt(cost)                                    AS cost,
       a                                                 AS a
FROM groups;


-- gui_civgroups: Civilian group data collected from all over.
CREATE TEMPORARY VIEW gui_civgroups AS
SELECT G.id                                            AS id,
       G.g                                             AS g,
       G.url                                           AS url,
       G.fancy                                         AS fancy,
       G.link                                          AS link,
       G.longlink                                      AS longlink,
       G.gtype                                         AS gtype,
       G.longname                                      AS longname,
       G.color                                         AS color,
       G.demeanor                                      AS demeanor,
       CG.basepop                                      AS basepop,
       CG.n                                            AS n,
       G.bsid                                          AS bsid,
       bsysname(G.bsid)                                AS bsysname,
       CASE CG.sa_flag WHEN 1 THEN 'Yes' ELSE 'No' END AS pretty_sa_flag,
       CG.sa_flag                                      AS sa_flag,
       format('%.1f', CG.pop_cr)                       AS pop_cr,
       CG.housing                                      AS housing,
       CG.lfp                                          AS lfp,
       coalesce(DG.population, CG.basepop)             AS population,
       CG.hist_flag                                    AS hist_flag,
       DG.attrition                                    AS attrition,
       DG.subsistence                                  AS subsistence,
       DG.consumers                                    AS consumers,
       DG.labor_force                                  AS labor_force,
       DG.unemployed                                   AS unemployed,
       CASE WHEN SR.req_funding IS NULL
            THEN 'N/A' 
            ELSE moneyfmt(SR.req_funding) END          AS req_funding, 
       CASE WHEN SR.sat_funding IS NULL
            THEN 'N/A' 
            ELSE moneyfmt(SR.sat_funding) END          AS sat_funding, 
       format('%.1f', coalesce(DG.ur, 0.0))            AS ur,
       format('%.1f', coalesce(DG.upc, CG.upc))        AS upc,
       format('%.2f', coalesce(DG.uaf, 0.0))           AS uaf,
       format('%.1f', coalesce(DG.tc, 0.0))            AS tc,
       format('%.1f', coalesce(DG.aloc, 0.0))          AS aloc,
       format('%.1f', coalesce(DG.eloc, 0.0))          AS eloc,
       format('%.1f', coalesce(DG.rloc, 0.0))          AS rloc,
       format('%.1f', coalesce(DG.povfrac, 0.0))       AS povfrac,
       format('%.1f', coalesce(DG.povfrac*100, 0.0))   AS povpct,
       format('%.3f', coalesce(UM.mood0, 0.0))         AS mood0,
       format('%.3f', coalesce(UM.mood, 0.0))          AS mood
FROM gui_groups AS G
JOIN civgroups  AS CG USING (g)
LEFT OUTER JOIN demog_g    AS DG USING (g)
LEFT OUTER JOIN sr_service AS SR USING (g)
LEFT OUTER JOIN uram_mood  AS UM USING (g);


-- gui_frcgroups: Force group data
CREATE TEMPORARY VIEW gui_frcgroups AS
SELECT G.id                                             AS id,
       G.g                                              AS g,
       G.url                                            AS url,
       G.fancy                                          AS fancy,
       G.link                                           AS link,
       G.longlink                                       AS longlink,
       G.gtype                                          AS gtype,
       G.longname                                       AS longname,
       G.color                                          AS color,
       G.demeanor                                       AS demeanor,
       coalesce(P.personnel, 0)                         AS personnel,
       G.cost                                           AS cost,
       G.a                                              AS a,
       F.forcetype                                      AS forcetype,
       F.training                                       AS training,
       F.base_personnel                                 AS base_personnel,
       local                                            AS local,
       CASE F.local     WHEN 1 THEN 'Yes' ELSE 'No' END AS pretty_local
FROM gui_groups  AS G
JOIN frcgroups   AS F USING (g)
LEFT OUTER JOIN personnel_g AS P USING (g);


-- gui_orggroups: Organization Group data
CREATE TEMPORARY VIEW gui_orggroups AS
SELECT G.id                                             AS id,
       G.g                                              AS g,
       G.url                                            AS url,
       G.fancy                                          AS fancy,
       G.link                                           AS link,
       G.longlink                                       AS longlink,
       G.gtype                                          AS gtype,
       G.longname                                       AS longname,
       G.color                                          AS color,
       G.demeanor                                       AS demeanor,
       coalesce(P.personnel, 0)                         AS personnel,
       G.cost                                           AS cost,
       G.a                                              AS a,
       O.orgtype                                        AS orgtype,
       O.base_personnel                                 AS base_personnel
FROM gui_groups  AS G
JOIN orggroups   AS O USING (g)
LEFT OUTER JOIN personnel_g AS P USING (g);


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


