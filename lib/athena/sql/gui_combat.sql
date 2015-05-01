------------------------------------------------------------------------
-- TITLE:
--    gui_combat.sql
--
-- AUTHOR:
--    Dave Hanks
--
-- DESCRIPTION:
--    SQL Schema: Application-specific views, COMBAT area
--
--
--    GUI views translate the internal data formats of the scenariodb(n)
--    tables into presentation format.  They are defined here instead of
--    in scenariodb(n) so that they can contain application-specific
--    SQL functions.
--
------------------------------------------------------------------------


------------------------------------------------------------------------
-- Combat views

-- gui_combat: Combat
CREATE TEMPORARY VIEW gui_combat AS
SELECT B.n                           AS n,
       N.longname                    AS longname,
       '/app/combat/' || B.n     AS url,
        pair(longname, B.n)          AS fancy
FROM hist_aam_battle AS B
JOIN nbhoods AS N ON (N.n=B.n)
GROUP BY B.n;

-- gui_battle: AAM battle data
CREATE TEMPORARY VIEW gui_battle AS
SELECT N.longlink                                       AS nlink,
       B.f                                              AS f,
       B.g                                              AS g,
       F.longlink                                       AS longlink_f,
       G.longlink                                       AS longlink_g,
       F.link                                           AS link_f,
       G.link                                           AS link_g,
       F.a                                              AS a_f,
       G.a                                              AS a_g,
       B.t                                              AS t,
       B.n                                              AS n,
       B.roe_f                                          AS roe_f,
       B.roe_g                                          AS roe_g,
       CASE B.roe_f WHEN 'ATTACK' THEN 'A' ELSE 'D' END AS sroe_f,
       CASE B.roe_g WHEN 'ATTACK' THEN 'A' ELSE 'D' END AS sroe_g,
       B.dpers_f                                        AS dpers_f,
       B.dpers_g                                        AS dpers_g,
       B.startp_f                                       AS startp_f,
       B.startp_g                                       AS startp_g,
       B.endp_f                                         AS endp_f,
       B.endp_g                                         AS endp_g,
       B.cas_f                                          AS cas_f,
       B.cas_g                                          AS cas_g,
       B.civcas_f                                       AS civcas_f,
       B.civcas_g                                       AS civcas_g,
       B.civc_f                                         AS civc_f,
       B.civc_g                                         AS civc_g 
FROM hist_aam_battle AS B
JOIN gui_groups  AS F ON (B.f=F.g)
JOIN gui_groups  AS G ON (B.g=G.g)
JOIN gui_nbhoods AS N ON (B.n=N.n);

-- gui_battle_f: AAM battle data from f's point of view; use this
-- view with a WHERE clause on f to get all data from that groups 
-- point of view.
CREATE TEMPORARY VIEW gui_battle_f AS
SELECT N.longlink AS nlink,
       B.f        AS f,
       B.g        AS g,
       F.longlink AS longlink_f,
       G.longlink AS longlink_g,
       F.link     AS link_f,
       G.link     AS link_g,
       F.a        AS a_f,
       G.a        AS a_g,
       B.t        AS t,
       B.n        AS n,
       B.roe_f    AS roe_f,
       B.roe_g    AS roe_g,
       B.dpers_f  AS dpers_f,
       B.dpers_g  AS dpers_g,
       B.startp_f AS startp_f,
       B.startp_g AS startp_g,
       B.endp_f   AS endp_f,
       B.endp_g   AS endp_g,
       B.cas_f    AS cas_f,
       B.cas_g    AS cas_g,
       B.civcas_f AS civcas_f,
       B.civcas_g AS civcas_g,
       B.civc_f   AS civc_f,
       B.civc_g   AS civc_g
FROM hist_aam_battle_fview AS B
JOIN gui_groups  AS F ON (B.f=F.g)
JOIN gui_groups  AS G ON (B.g=G.g)
JOIN gui_nbhoods AS N ON (B.n=N.n);

